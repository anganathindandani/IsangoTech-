-- Booking reminders on WhatsApp. Outside WhatsApp's 24-hour window a business
-- may only send a message template Meta has approved, so each business sets
-- the name of its approved reminder template. The send-reminders edge
-- function runs every 15 minutes, claims the reminders that are due and sends them.

alter table public.business_settings
  add column reminders_enabled boolean not null default false,
  add column reminder_hours_before int not null default 24 check (reminder_hours_before between 1 and 72),
  -- The template's name and language as approved in Meta (e.g. booking_reminder, en).
  add column reminder_template text check (reminder_template ~ '^[a-z0-9_]+$' and length(reminder_template) <= 512),
  add column reminder_template_language text not null default 'en' check (reminder_template_language ~ '^[a-z]{2}(_[A-Z]{2})?$');

grant update (reminders_enabled, reminder_hours_before, reminder_template, reminder_template_language)
  on public.business_settings to authenticated;

-- How many times sending this booking's reminder has been tried (at most
-- three), and when a run last claimed it. A claim holds for 10 minutes, so a
-- run that's still sending isn't overtaken by the next, and a failed send is
-- retried a little later.
alter table public.bookings
  add column reminder_attempts int not null default 0,
  add column reminder_claimed_at timestamptz;

-- A booking moved to a new time gets a fresh reminder.
create function private.rearm_reminder()
returns trigger
language plpgsql
as $$
begin
  if new.starts_at is distinct from old.starts_at then
    new.reminder_sent_at := null;
    new.reminder_attempts := 0;
    new.reminder_claimed_at := null;
  end if;
  return new;
end;
$$;

create trigger rearm_reminder before update on public.bookings
  for each row execute function private.rearm_reminder();

-- Reminder bookkeeping isn't something people change, so it stays out of the audit log.
create or replace function private.audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_row jsonb;
  new_row jsonb;
  fields text[];
  bid uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then old_row := to_jsonb(old); end if;
  if tg_op in ('INSERT', 'UPDATE') then new_row := to_jsonb(new); end if;

  if tg_op = 'UPDATE' then
    select array_agg(k order by k) into fields
    from jsonb_object_keys(new_row) as k
    where k not in ('updated_at', 'reminder_attempts', 'reminder_sent_at', 'reminder_claimed_at')
      and new_row -> k is distinct from old_row -> k;
    if fields is null then
      return null;
    end if;
  end if;

  bid := (coalesce(new_row, old_row) ->> coalesce(tg_argv[0], 'business_id'))::uuid;
  if not exists (select 1 from public.businesses b where b.id = bid) then
    return null;
  end if;

  insert into public.audit_log (business_id, table_name, record_id, action, changed_fields, changed_by)
  values (
    bid,
    tg_table_name,
    coalesce(new_row ->> 'id', old_row ->> 'id', new_row ->> 'user_id', old_row ->> 'user_id', bid::text),
    lower(tg_op),
    fields,
    auth.uid()
  );
  return null;
end;
$$;

-- Claims the reminders due now and returns what to send. Claiming counts an
-- attempt and locks the rows, so two runs at once never send the same one.
--
-- Due: a pending or confirmed booking starting within the business's window
-- (and more than an hour away), not yet reminded, tried fewer than three
-- times, for a customer who booked on WhatsApp or agreed to WhatsApp updates.
create function public.claim_due_reminders(p_limit int default 50)
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
      and bk.status in ('pending', 'confirmed')
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

-- Records a reminder WhatsApp accepted: marks the booking, adds the message
-- to the customer's chat, and counts the template message for billing.
create function public.record_reminder(p_booking uuid, p_whatsapp_message_id text, p_body text, p_cost_zar numeric)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  bk public.bookings;
  conv_id uuid;
begin
  update public.bookings set reminder_sent_at = now() where id = p_booking returning * into bk;
  if not found then
    return;
  end if;
  insert into public.conversations (business_id, customer_id) values (bk.business_id, bk.customer_id)
  on conflict (business_id, customer_id) do nothing;
  select id into conv_id from public.conversations where business_id = bk.business_id and customer_id = bk.customer_id;
  insert into public.messages (business_id, conversation_id, direction, sender, body, whatsapp_message_id)
  values (bk.business_id, conv_id, 'outbound', 'assistant', p_body, nullif(p_whatsapp_message_id, ''));
  insert into public.usage_events (business_id, kind, conversation_id, cost_zar)
  values (bk.business_id, 'whatsapp_template', conv_id, greatest(coalesce(p_cost_zar, 0), 0));
end;
$$;

revoke all on function public.claim_due_reminders(int), public.record_reminder(uuid, text, text, numeric)
  from public, anon, authenticated;
grant execute on function public.claim_due_reminders(int), public.record_reminder(uuid, text, text, numeric)
  to service_role;
