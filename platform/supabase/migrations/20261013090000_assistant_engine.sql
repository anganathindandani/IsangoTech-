-- The WhatsApp Assistant's database side: recording incoming messages, the
-- context the AI reads, and the tools it may use.
--
-- Only the service role (the whatsapp-webhook edge function) can call these.
-- Every tool takes the conversation id, not a business or customer id, and
-- works out both from it. Whatever the AI asks for, it can only ever see this
-- business's services and slots and change this customer's own bookings.

-- Messages are timestamped when they're written, not when the transaction
-- started, so several saved together still come back in the order they arrived.
alter table public.messages alter column created_at set default clock_timestamp();

-- ---------------------------------------------------------------------------
-- Incoming messages
-- ---------------------------------------------------------------------------

-- Saves a customer's message and says what to do next:
--   unknown_number  no business with the Assistant on this WhatsApp number
--   duplicate       WhatsApp delivered this message before; ignore it
--   person          someone on the team took over this chat; stay quiet
--   assistant_off   the business hasn't switched the Assistant on yet
--   reply           the Assistant should answer
create function public.assistant_receive(
  p_phone_number_id text,
  p_from text,
  p_profile_name text,
  p_whatsapp_message_id text,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  biz public.businesses;
  settings public.business_settings;
  cust_id uuid;
  conv public.conversations;
  msg_id uuid;
  new_customer boolean := false;
begin
  select * into biz from public.businesses b
  where b.whatsapp_phone_number_id = p_phone_number_id
    and b.status in ('onboarding', 'active') and 'assistant' = any (b.products);
  if not found then
    return jsonb_build_object('status', 'unknown_number');
  end if;
  select * into settings from public.business_settings s where s.business_id = biz.id;

  select c.id into cust_id from public.customers c
  where c.business_id = biz.id and c.whatsapp_number = p_from;
  if cust_id is null then
    insert into public.customers (business_id, whatsapp_number, full_name)
    values (biz.id, p_from, nullif(trim(p_profile_name), ''))
    on conflict (business_id, whatsapp_number) do nothing
    returning id into cust_id;
    new_customer := cust_id is not null;
    if cust_id is null then
      select c.id into cust_id from public.customers c
      where c.business_id = biz.id and c.whatsapp_number = p_from;
    end if;
  end if;

  insert into public.conversations (business_id, customer_id) values (biz.id, cust_id)
  on conflict (business_id, customer_id) do nothing;
  select * into conv from public.conversations c where c.business_id = biz.id and c.customer_id = cust_id
  for update;

  insert into public.messages (business_id, conversation_id, direction, sender, body, whatsapp_message_id)
  values (biz.id, conv.id, 'inbound', 'customer', left(p_body, 4000), p_whatsapp_message_id)
  on conflict (whatsapp_message_id) do nothing
  returning id into msg_id;
  if msg_id is null then
    return jsonb_build_object('status', 'duplicate');
  end if;

  -- A message after 24 hours of quiet opens a new WhatsApp conversation, which
  -- counts against the plan's allowance.
  if conv.last_customer_message_at is null or conv.last_customer_message_at < now() - interval '24 hours' then
    insert into public.usage_events (business_id, kind, conversation_id) values (biz.id, 'whatsapp_conversation', conv.id);
  end if;

  return jsonb_build_object(
    'status', case
      when conv.handled_by = 'person' then 'person'
      when not settings.assistant_enabled then 'assistant_off'
      else 'reply'
    end,
    'business_id', biz.id,
    'conversation_id', conv.id,
    'new_customer', new_customer
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- What the AI reads before answering
-- ---------------------------------------------------------------------------

create function public.assistant_context(p_conversation uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'business', jsonb_build_object('name', b.name, 'industry', b.industry, 'time_zone', b.time_zone),
    'settings', jsonb_build_object(
      'opening_hours', s.opening_hours,
      'languages', s.languages,
      'tone', s.tone,
      'policies', s.policies,
      'handover_topics', s.handover_topics,
      'min_booking_notice_hours', s.min_booking_notice_hours,
      'change_notice_hours', s.change_notice_hours,
      'deposit_required', s.deposit_required,
      'deposit_percent', s.deposit_percent,
      'privacy_notice_url', s.privacy_notice_url
    ),
    'customer', jsonb_build_object('name', cu.full_name),
    -- The last 20 messages of the past week, oldest first.
    'history', coalesce((
      select jsonb_agg(jsonb_build_object('sender', m.sender, 'body', m.body) order by m.created_at, m.id)
      from (
        select * from public.messages m
        where m.conversation_id = c.id and m.created_at > now() - interval '7 days'
        order by m.created_at desc, m.id desc
        limit 20
      ) m
    ), '[]'::jsonb),
    'now_local', to_char(now() at time zone b.time_zone, 'FMDay DD FMMonth YYYY, HH24:MI'),
    -- Lets the edge function see that a newer message arrived while it was
    -- thinking, so only the newest run replies.
    'last_inbound', (
      select m.whatsapp_message_id from public.messages m
      where m.conversation_id = c.id and m.direction = 'inbound'
      order by m.created_at desc, m.id desc limit 1
    )
  )
  from public.conversations c
  join public.businesses b on b.id = c.business_id
  join public.business_settings s on s.business_id = b.id
  join public.customers cu on cu.id = c.customer_id
  where c.id = p_conversation;
$$;

-- ---------------------------------------------------------------------------
-- Availability
-- ---------------------------------------------------------------------------

-- Opening intervals for one day from an hours object like
-- {"sat": [["08:00", "14:00"]]}, as timestamps in the business's time zone.
create function private.day_intervals(p_hours jsonb, p_day date, p_tz text)
returns table (opens timestamptz, closes timestamptz)
language sql
stable
set search_path = ''
as $$
  select
    (p_day + (iv ->> 0)::time) at time zone p_tz,
    (p_day + (iv ->> 1)::time) at time zone p_tz
  from jsonb_array_elements(
    coalesce(p_hours -> (array['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'])[extract(isodow from p_day)::int],
             '[]'::jsonb)
  ) as iv
  where jsonb_typeof(iv) = 'array' and jsonb_array_length(iv) = 2;
$$;

-- Free start times for a service on one day, every 30 minutes, per staff
-- member who can do it. Respects opening hours, each staff member's own hours,
-- minimum notice and existing bookings. p_ignore_booking lets a booking being
-- moved not block itself.
create function private.free_slots(
  p_business uuid,
  p_service uuid,
  p_day date,
  p_staff uuid default null,
  p_ignore_booking uuid default null
)
returns table (starts_at timestamptz, ends_at timestamptz, staff_id uuid, staff_name text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  tz text;
  hours jsonb;
  notice int;
  minutes int;
  has_staff boolean;
begin
  select b.time_zone, s.opening_hours, s.min_booking_notice_hours
  into tz, hours, notice
  from public.businesses b join public.business_settings s on s.business_id = b.id
  where b.id = p_business;

  select coalesce(sv.duration_minutes, 60) into minutes
  from public.services sv where sv.id = p_service and sv.business_id = p_business and sv.active;
  if minutes is null then
    return;
  end if;

  select exists (select 1 from public.staff st where st.business_id = p_business and st.active) into has_staff;

  if not has_staff then
    -- No staff on record (a restaurant, say): any time within opening hours.
    return query
    select t, t + make_interval(mins => minutes), null::uuid, null::text
    from private.day_intervals(hours, p_day, tz) d,
         generate_series(d.opens, d.closes - make_interval(mins => minutes), interval '30 minutes') t
    where t >= now() + make_interval(hours => notice)
    order by t;
    return;
  end if;

  return query
  with eligible as (
    select st.id, st.full_name, case when st.working_hours = '{}'::jsonb then hours else st.working_hours end as hrs
    from public.staff st
    where st.business_id = p_business and st.active
      and (p_staff is null or st.id = p_staff)
      and (
        not exists (select 1 from public.service_staff ss where ss.service_id = p_service)
        or exists (select 1 from public.service_staff ss where ss.service_id = p_service and ss.staff_id = st.id)
      )
  ),
  candidates as (
    select e.id, e.full_name, t
    from eligible e,
         private.day_intervals(e.hrs, p_day, tz) d,
         generate_series(d.opens, d.closes - make_interval(mins => minutes), interval '30 minutes') t
    -- A staff member's own hours only count within the business's opening hours.
    where exists (
      select 1 from private.day_intervals(hours, p_day, tz) o
      where t >= o.opens and t + make_interval(mins => minutes) <= o.closes
    )
  )
  select c.t, c.t + make_interval(mins => minutes), c.id, c.full_name
  from candidates c
  where c.t >= now() + make_interval(hours => notice)
    and not exists (
      select 1 from public.bookings bk
      where bk.business_id = p_business and bk.staff_id = c.id
        and bk.status in ('pending', 'confirmed')
        and bk.id is distinct from p_ignore_booking
        and tstzrange(bk.starts_at, bk.ends_at) && tstzrange(c.t, c.t + make_interval(mins => minutes))
    )
  order by c.t, c.full_name;
end;
$$;

-- ---------------------------------------------------------------------------
-- The tools
-- ---------------------------------------------------------------------------

-- Reads a local date-time the AI sends ("2026-10-17T13:30") in the business's
-- time zone. A time with an explicit offset is taken as given.
create function private.local_time(p_value text, p_tz text)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_value ~ '(Z|[+-]\d\d:?\d\d)$' then
    return p_value::timestamptz;
  end if;
  return p_value::timestamp at time zone p_tz;
exception when others then
  return null;
end;
$$;

-- Runs one tool for one conversation. Returns {"ok": true, ...} or
-- {"ok": false, "error": "..."} for the AI to read; never raises for
-- something the customer asked for.
create function public.assistant_tool(p_conversation uuid, p_name text, p_args jsonb)
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
    begin
      insert into public.bookings (business_id, customer_id, service_id, staff_id, starts_at, ends_at, source,
                                   deposit_amount, deposit_status, notes)
      values (
        biz.id, conv.customer_id, svc.id, slot.staff_id, slot.starts_at, slot.ends_at, 'whatsapp',
        case when settings.deposit_required and svc.price is not null
             then round(svc.price * settings.deposit_percent / 100, 2) else 0 end,
        case when settings.deposit_required and svc.price is not null then 'requested' else 'not_required' end,
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
      'deposit_due', case when bk.deposit_status = 'requested' then 'R' || bk.deposit_amount::text end
    ));

  when 'my_bookings' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'booking_id', b.id,
      'service', sv.name,
      'staff', st.full_name,
      'starts', to_char(b.starts_at at time zone biz.time_zone, 'FMDay DD FMMonth YYYY, HH24:MI'),
      'status', b.status
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

-- ---------------------------------------------------------------------------
-- Recording what the Assistant sent and what it cost
-- ---------------------------------------------------------------------------

create function public.assistant_record_reply(p_conversation uuid, p_body text, p_whatsapp_message_id text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.messages (business_id, conversation_id, direction, sender, body, whatsapp_message_id)
  select c.business_id, c.id, 'outbound', 'assistant', p_body, p_whatsapp_message_id
  from public.conversations c where c.id = p_conversation;
$$;

create function public.assistant_record_ai_call(
  p_conversation uuid,
  p_model text,
  p_input_tokens int,
  p_cached_input_tokens int,
  p_output_tokens int,
  p_cost_zar numeric
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.usage_events (business_id, kind, conversation_id, model, input_tokens, cached_input_tokens,
                                   output_tokens, cost_zar)
  select c.business_id, 'ai_call', c.id, p_model, p_input_tokens, p_cached_input_tokens, p_output_tokens,
         greatest(coalesce(p_cost_zar, 0), 0)
  from public.conversations c where c.id = p_conversation;
$$;

-- ---------------------------------------------------------------------------
-- Grants: the edge function (service role) only
-- ---------------------------------------------------------------------------

revoke all on function
  public.assistant_receive(text, text, text, text, text),
  public.assistant_context(uuid),
  public.assistant_tool(uuid, text, jsonb),
  public.assistant_record_reply(uuid, text, text),
  public.assistant_record_ai_call(uuid, text, int, int, int, numeric)
  from public, anon, authenticated;
grant execute on function
  public.assistant_receive(text, text, text, text, text),
  public.assistant_context(uuid),
  public.assistant_tool(uuid, text, jsonb),
  public.assistant_record_reply(uuid, text, text),
  public.assistant_record_ai_call(uuid, text, int, int, int, numeric)
  to service_role;
revoke all on function
  private.day_intervals(jsonb, date, text),
  private.free_slots(uuid, uuid, date, uuid, uuid),
  private.local_time(text, text)
  from public;
