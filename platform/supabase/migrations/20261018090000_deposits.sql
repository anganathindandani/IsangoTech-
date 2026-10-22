-- Deposits. A business that asks for one gives its own way to pay: a payment
-- link (Yoco, SnapScan, PayFast and so on) and/or EFT instructions. The money
-- goes straight to the business; IsangoTech never holds it.
--
-- A booking with a deposit due is held (pending) until someone at the business
-- marks the deposit paid (or waives it), which confirms it. A hold that isn't
-- paid by its pay-by time is released, so the slot opens again.

alter table public.business_settings
  -- The business's own payment page; https only.
  add column deposit_payment_link text
    check (deposit_payment_link ~ '^https://[^[:space:]]+$' and length(deposit_payment_link) <= 500),
  -- Other ways to pay, e.g. EFT details, in the owner's words.
  add column deposit_payment_instructions text not null default ''
    check (length(deposit_payment_instructions) <= 600),
  -- How long an unpaid booking is held.
  add column deposit_hold_hours int not null default 24 check (deposit_hold_hours between 1 and 72);

grant update (deposit_payment_link, deposit_payment_instructions, deposit_hold_hours)
  on public.business_settings to authenticated;

alter table public.bookings drop constraint bookings_deposit_status_check;
alter table public.bookings
  add constraint bookings_deposit_status_check
    check (deposit_status in ('not_required', 'requested', 'paid', 'waived', 'refunded')),
  add column deposit_due_by timestamptz,
  add column deposit_paid_at timestamptz;

grant update (deposit_due_by) on public.bookings to authenticated;

-- What the customer quotes when paying, so the business can match the payment:
-- the first six characters of the booking's id. The app shows the same.
create function private.deposit_reference(p_booking uuid)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(left(replace(p_booking::text, '-', ''), 6));
$$;

-- When the deposit for a booking is due: after the hold period, but always at
-- least an hour before the appointment (and never sooner than 30 minutes away).
create function private.deposit_due_by(p_starts_at timestamptz, p_hold_hours int)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select greatest(least(now() + make_interval(hours => p_hold_hours), p_starts_at - interval '1 hour'),
                  now() + interval '30 minutes');
$$;

-- Marking a deposit paid or waived confirms a held booking.
create function private.settle_deposit()
returns trigger
language plpgsql
as $$
begin
  if new.deposit_status is distinct from old.deposit_status then
    if new.deposit_status = 'paid' then
      new.deposit_paid_at := now();
    elsif new.deposit_status <> 'refunded' then
      new.deposit_paid_at := null;
    end if;
    if new.deposit_status in ('paid', 'waived') and new.status = 'pending' then
      new.status := 'confirmed';
    end if;
  end if;
  return new;
end;
$$;

create trigger settle_deposit before update on public.bookings
  for each row execute function private.settle_deposit();

-- The Assistant's tools, with held bookings and payment details.
create or replace function public.assistant_tool(p_conversation uuid, p_name text, p_args jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  conv public.conversations;
  biz public.businesses;
  settings public.business_settings;
  svc public.services;
  bk public.bookings;
  slot record;
  day date;
  start_at timestamptz;
  deposit numeric(10, 2);
  result jsonb;
  args jsonb := coalesce(p_args, '{}'::jsonb);
begin
  select * into conv from public.conversations c where c.id = p_conversation;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Unknown conversation');
  end if;
  select * into biz from public.businesses b where b.id = conv.business_id;
  select * into settings from public.business_settings s where s.business_id = biz.id;

  case p_name

  when 'find_services' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'service_id', sv.id,
      'name', sv.name,
      'description', nullif(sv.description, ''),
      'price', case when sv.price is null then 'price on request'
                    when sv.price_from then 'from R' || sv.price::text
                    else 'R' || sv.price::text end,
      'duration_minutes', sv.duration_minutes,
      'staff', (
        select jsonb_agg(st.full_name order by st.full_name)
        from public.service_staff ss join public.staff st on st.id = ss.staff_id
        where ss.service_id = sv.id and st.active
      )
    ) order by sv.name), '[]'::jsonb)
    into result
    from public.services sv where sv.business_id = biz.id and sv.active;
    return jsonb_build_object('ok', true, 'services', result);

  when 'check_availability' then
    begin
      day := (args ->> 'date')::date;
    exception when others then
      return jsonb_build_object('ok', false, 'error', 'date must look like 2026-10-17');
    end;
    if day is null then
      return jsonb_build_object('ok', false, 'error', 'date is required');
    end if;
    if not exists (select 1 from public.services sv where sv.id = (args ->> 'service_id')::uuid
                   and sv.business_id = biz.id and sv.active) then
      return jsonb_build_object('ok', false, 'error', 'Unknown service; call find_services first');
    end if;
    select coalesce(jsonb_agg(jsonb_build_object(
      'time', to_char(f.starts_at at time zone biz.time_zone, 'HH24:MI'),
      'staff_id', f.staff_id,
      'staff_name', f.staff_name
    ) order by f.starts_at, f.staff_name), '[]'::jsonb)
    into result
    from (
      select * from private.free_slots(biz.id, (args ->> 'service_id')::uuid, day, (args ->> 'staff_id')::uuid)
      limit 40
    ) f;
    return jsonb_build_object('ok', true, 'date', day, 'free_slots', result);

  when 'create_booking' then
    select * into svc from public.services sv
    where sv.id = (args ->> 'service_id')::uuid and sv.business_id = biz.id and sv.active;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'Unknown service; call find_services first');
    end if;
    start_at := private.local_time(args ->> 'starts_at', biz.time_zone);
    if start_at is null then
      return jsonb_build_object('ok', false, 'error', 'starts_at must look like 2026-10-17T13:30');
    end if;
    select * into slot from private.free_slots(biz.id, svc.id, (start_at at time zone biz.time_zone)::date,
                                               (args ->> 'staff_id')::uuid) f
    where f.starts_at = start_at
    order by f.staff_name limit 1;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'That time is not free; check availability again');
    end if;
    if nullif(trim(args ->> 'customer_name'), '') is not null then
      update public.customers set full_name = trim(args ->> 'customer_name')
      where id = conv.customer_id and full_name is null;
    end if;
    deposit := case when settings.deposit_required and svc.price is not null
                    then round(svc.price * settings.deposit_percent / 100, 2) else 0 end;
    begin
      insert into public.bookings (business_id, customer_id, service_id, staff_id, starts_at, ends_at, source,
                                   status, deposit_amount, deposit_status, deposit_due_by, notes)
      values (
        biz.id, conv.customer_id, svc.id, slot.staff_id, slot.starts_at, slot.ends_at, 'whatsapp',
        case when deposit > 0 then 'pending' else 'confirmed' end,
        deposit,
        case when deposit > 0 then 'requested' else 'not_required' end,
        case when deposit > 0 then private.deposit_due_by(slot.starts_at, settings.deposit_hold_hours) end,
        left(coalesce(args ->> 'notes', ''), 500)
      )
      returning * into bk;
    exception when exclusion_violation then
      return jsonb_build_object('ok', false, 'error', 'That time was just taken; check availability again');
    end;
    return jsonb_build_object('ok', true, 'booking', jsonb_build_object(
      'booking_id', bk.id,
      'service', svc.name,
      'staff', slot.staff_name,
      'starts', to_char(bk.starts_at at time zone biz.time_zone, 'FMDay DD FMMonth YYYY, HH24:MI'),
      'status', bk.status,
      'deposit', case when bk.deposit_status = 'requested' then jsonb_strip_nulls(jsonb_build_object(
        'amount', 'R' || bk.deposit_amount::text,
        'reference', private.deposit_reference(bk.id),
        'pay_by', to_char(bk.deposit_due_by at time zone biz.time_zone, 'FMDay DD FMMonth, HH24:MI'),
        'payment_link', settings.deposit_payment_link,
        'payment_instructions', nullif(settings.deposit_payment_instructions, ''),
        'note', 'The booking is held until the deposit is paid by pay_by, then released. Give the customer the amount, '
                || 'how to pay, the reference and the pay-by time.'
      )) end
    ));

  when 'my_bookings' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'booking_id', b.id,
      'service', sv.name,
      'staff', st.full_name,
      'starts', to_char(b.starts_at at time zone biz.time_zone, 'FMDay DD FMMonth YYYY, HH24:MI'),
      'status', b.status,
      'deposit_due', case when b.deposit_status = 'requested' then jsonb_strip_nulls(jsonb_build_object(
        'amount', 'R' || b.deposit_amount::text,
        'reference', private.deposit_reference(b.id),
        'pay_by', to_char(b.deposit_due_by at time zone biz.time_zone, 'FMDay DD FMMonth, HH24:MI'),
        'payment_link', settings.deposit_payment_link,
        'payment_instructions', nullif(settings.deposit_payment_instructions, '')
      )) end
    ) order by b.starts_at), '[]'::jsonb)
    into result
    from public.bookings b
    left join public.services sv on sv.id = b.service_id
    left join public.staff st on st.id = b.staff_id
    where b.business_id = biz.id and b.customer_id = conv.customer_id
      and b.status in ('pending', 'confirmed') and b.starts_at > now();
    return jsonb_build_object('ok', true, 'bookings', result);

  when 'change_booking', 'cancel_booking' then
    select * into bk from public.bookings b
    where b.id = (args ->> 'booking_id')::uuid
      and b.business_id = biz.id and b.customer_id = conv.customer_id
      and b.status in ('pending', 'confirmed') and b.starts_at > now()
    for update;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'No such upcoming booking for this customer; call my_bookings');
    end if;
    if bk.starts_at < now() + make_interval(hours => settings.change_notice_hours) then
      return jsonb_build_object('ok', false, 'error',
        format('Changes need %s hours'' notice; hand over to a person', settings.change_notice_hours));
    end if;

    if p_name = 'cancel_booking' and bk.deposit_status = 'paid' then
      return jsonb_build_object('ok', false, 'error',
        'This booking has a paid deposit; call hand_over so the business can cancel it and deal with the deposit');
    end if;
    if p_name = 'cancel_booking' then
      update public.bookings set status = 'cancelled' where id = bk.id;
      return jsonb_build_object('ok', true, 'cancelled', bk.id);
    end if;

    start_at := private.local_time(args ->> 'starts_at', biz.time_zone);
    if start_at is null then
      return jsonb_build_object('ok', false, 'error', 'starts_at must look like 2026-10-17T13:30');
    end if;
    select * into slot from private.free_slots(biz.id, bk.service_id, (start_at at time zone biz.time_zone)::date,
                                               coalesce((args ->> 'staff_id')::uuid, bk.staff_id), bk.id) f
    where f.starts_at = start_at
    order by f.staff_name limit 1;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'That time is not free; check availability again');
    end if;
    begin
      update public.bookings
      set starts_at = slot.starts_at, ends_at = slot.ends_at, staff_id = slot.staff_id, reminder_sent_at = null
      where id = bk.id;
    exception when exclusion_violation then
      return jsonb_build_object('ok', false, 'error', 'That time was just taken; check availability again');
    end;
    return jsonb_build_object('ok', true, 'booking_id', bk.id, 'staff', slot.staff_name,
      'starts', to_char(slot.starts_at at time zone biz.time_zone, 'FMDay DD FMMonth YYYY, HH24:MI'));

  when 'lookup_answer' then
    -- Matches any word of three letters or more; small businesses have few
    -- items, so a plain word match is enough.
    select coalesce(jsonb_agg(jsonb_build_object('question', k.question, 'answer', k.answer)), '[]'::jsonb)
    into result
    from (
      select k.* from public.knowledge_items k
      where k.business_id = biz.id and k.active
        and exists (
          select 1 from regexp_split_to_table(lower(coalesce(args ->> 'question', '')), '[^[:alnum:]]+') w
          where length(w) >= 3 and (lower(k.question) like '%' || w || '%' or lower(k.answer) like '%' || w || '%')
        )
      limit 5
    ) k;
    return jsonb_build_object('ok', true, 'answers', result);

  when 'hand_over' then
    update public.conversations set handled_by = 'person' where id = conv.id;
    if nullif(trim(args ->> 'question'), '') is not null then
      insert into public.unanswered_questions (business_id, conversation_id, question)
      values (biz.id, conv.id, left(trim(args ->> 'question'), 1000));
    end if;
    return jsonb_build_object('ok', true, 'handed_over', true);

  else
    return jsonb_build_object('ok', false, 'error', 'Unknown tool ' || coalesce(p_name, ''));
  end case;
exception when invalid_text_representation then
  return jsonb_build_object('ok', false, 'error', 'An id was not valid; use the ids the tools returned');
end;
$$;

-- Reminders skip bookings still waiting for a deposit.
create or replace function public.claim_due_reminders(p_limit int default 50)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  with due as (
    select bk.id
    from public.bookings bk
    join public.businesses b on b.id = bk.business_id
    join public.business_settings s on s.business_id = b.id
    join public.customers cu on cu.id = bk.customer_id
    where s.reminders_enabled and s.reminder_template is not null
      and b.whatsapp_phone_number_id is not null
      and b.status in ('onboarding', 'active') and 'assistant' = any (b.products)
      and bk.status in ('pending', 'confirmed') and bk.deposit_status <> 'requested'
      and bk.reminder_sent_at is null and bk.reminder_attempts < 3
      and (bk.reminder_claimed_at is null or bk.reminder_claimed_at < now() - interval '10 minutes')
      and bk.starts_at > now() + interval '1 hour'
      and bk.starts_at <= now() + make_interval(hours => s.reminder_hours_before)
      and cu.whatsapp_number is not null
      and (bk.source = 'whatsapp' or cu.whatsapp_opt_in)
    order by bk.starts_at
    limit p_limit
    for update of bk skip locked
  ),
  claimed as (
    update public.bookings bk set reminder_attempts = bk.reminder_attempts + 1, reminder_claimed_at = now()
    from due where bk.id = due.id
    returning bk.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'booking_id', c.id,
    'phone_number_id', b.whatsapp_phone_number_id,
    'to', cu.whatsapp_number,
    'template', s.reminder_template,
    'language', s.reminder_template_language,
    -- The template's {{1}} to {{5}}: first name, service, business, day, time.
    'parameters', jsonb_build_array(
      coalesce(nullif(split_part(trim(cu.full_name), ' ', 1), ''), 'there'),
      coalesce(sv.name, 'booking'),
      b.name,
      to_char(c.starts_at at time zone b.time_zone, 'FMDay FMDD FMMonth'),
      to_char(c.starts_at at time zone b.time_zone, 'HH24:MI')
    )
  ) order by c.starts_at), '[]'::jsonb)
  from claimed c
  join public.businesses b on b.id = c.business_id
  join public.business_settings s on s.business_id = b.id
  join public.customers cu on cu.id = c.customer_id
  left join public.services sv on sv.id = c.service_id;
$$;

-- Releases held bookings whose deposit wasn't paid in time, and returns a
-- message for each customer still inside WhatsApp's 24-hour window (outside
-- it, only a template could reach them, so the release is silent). Called by
-- the send-reminders function every 15 minutes.
create function public.release_unpaid_bookings(p_limit int default 50)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  with due as (
    select bk.id
    from public.bookings bk
    where bk.status = 'pending' and bk.deposit_status = 'requested'
      and bk.deposit_due_by is not null and bk.deposit_due_by < now()
    order by bk.deposit_due_by
    limit p_limit
    for update skip locked
  ),
  released as (
    update public.bookings bk
    set status = 'cancelled',
        notes = ltrim(bk.notes || E'\n' || 'Released: the deposit wasn''t paid in time.', E'\n')
    from due where bk.id = due.id
    returning bk.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'booking_id', r.id,
    'conversation_id', c.id,
    'phone_number_id', b.whatsapp_phone_number_id,
    'to', cu.whatsapp_number,
    'message', case when c.last_customer_message_at > now() - interval '23 hours 30 minutes'
                     and b.whatsapp_phone_number_id is not null and cu.whatsapp_number is not null then
      format('Hi %s, we didn''t receive the deposit for your %s booking on %s at %s, so the time has been released. '
             || 'Reply here if you''d like to book again.',
             coalesce(nullif(split_part(trim(cu.full_name), ' ', 1), ''), 'there'),
             coalesce(sv.name, 'booking'),
             to_char(r.starts_at at time zone b.time_zone, 'FMDay DD FMMonth'),
             to_char(r.starts_at at time zone b.time_zone, 'HH24:MI'))
    end
  )), '[]'::jsonb)
  from released r
  join public.businesses b on b.id = r.business_id
  join public.customers cu on cu.id = r.customer_id
  left join public.services sv on sv.id = r.service_id
  left join public.conversations c on c.business_id = r.business_id and c.customer_id = r.customer_id;
$$;

revoke all on function public.release_unpaid_bookings(int) from public, anon, authenticated;
grant execute on function public.release_unpaid_bookings(int) to service_role;
revoke all on function private.deposit_due_by(timestamptz, int), private.deposit_reference(uuid) from public;
