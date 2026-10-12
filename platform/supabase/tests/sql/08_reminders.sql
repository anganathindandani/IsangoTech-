-- Booking reminders: which bookings are due, claiming them once, recording
-- what was sent, and a moved booking getting a fresh reminder.
begin;

select tests.seed_business('Salon A') as a \gset
select (:'a'::jsonb ->> 'business') as bid, (:'a'::jsonb ->> 'booking') as booking, (:'a'::jsonb ->> 'customer') as cust,
       (:'a'::jsonb ->> 'service') as svc, (:'a'::jsonb ->> 'staff_id') as stylist \gset
select set_config('t.bid', :'bid', false), set_config('t.booking', :'booking', false);

-- The seeded booking is tomorrow, made on WhatsApp. Reminders are off by default.
set local role service_role;
do $$ begin assert public.claim_due_reminders() = '[]', 'nothing is sent until the owner switches reminders on'; end $$;
reset role;

-- The owner switches reminders on (24 hours before) with their approved template.
select tests.sign_in((:'a'::jsonb ->> 'owner')::uuid);
set local role authenticated;
update public.business_settings set reminders_enabled = true, reminder_template = 'booking_reminder', reminder_hours_before = 30
where business_id = :'bid';
select tests.expect_error(format($$update public.business_settings set reminder_template = 'Booking Reminder!' where business_id = %L$$, :'bid'),
  'check constraint');
reset role;

-- A second booking, made in the dashboard for a customer who never opted in: no reminder for them.
insert into public.customers (business_id, full_name, whatsapp_number) values (:'bid', 'Walk In', '27849990000') returning id as walkin \gset
insert into public.bookings (business_id, customer_id, starts_at, ends_at, source)
values (:'bid', :'walkin', now() + interval '20 hours', now() + interval '21 hours', 'portal') returning id as no_consent \gset
-- And one in 10 days: not due yet.
insert into public.bookings (business_id, customer_id, service_id, starts_at, ends_at, source)
values (:'bid', :'cust', :'svc', now() + interval '10 days', now() + interval '10 days 1 hour', 'whatsapp');

set local role service_role;
do $$
declare due jsonb := public.claim_due_reminders();
begin
  assert jsonb_array_length(due) = 1, 'only the opted-in booking within the window: ' || due::text;
  assert due -> 0 ->> 'booking_id' = current_setting('t.booking'), 'it''s the WhatsApp booking';
  assert due -> 0 ->> 'template' = 'booking_reminder' and due -> 0 ->> 'language' = 'en', 'with the template';
  assert due -> 0 ->> 'phone_number_id' = 'wa-salon-a', 'sent from the business''s number';
  assert due -> 0 -> 'parameters' ->> 0 = 'Thandi' and due -> 0 -> 'parameters' ->> 1 = 'Braids'
     and due -> 0 -> 'parameters' ->> 2 = 'Salon A', 'name, service and business filled in';
  -- Claimed: a second run at the same time gets nothing.
  assert public.claim_due_reminders() = '[]', 'a claimed reminder isn''t handed out twice';
end $$;
reset role;

-- WhatsApp didn't accept it: ten minutes later it's tried again.
update public.bookings set reminder_claimed_at = now() - interval '11 minutes' where id = :'booking';
set local role service_role;
do $$ begin assert jsonb_array_length(public.claim_due_reminders()) = 1, 'a failed send is retried after 10 minutes'; end $$;
reset role;
-- After three attempts it stops trying.
update public.bookings set reminder_attempts = 3, reminder_claimed_at = null where id = :'booking';
set local role service_role;
do $$ begin assert public.claim_due_reminders() = '[]', 'no fourth attempt'; end $$;
reset role;
update public.bookings set reminder_attempts = 1 where id = :'booking';

-- Sent: recorded once, in the chat and in usage.
set local role service_role;
select public.record_reminder(:'booking', 'wamid-reminder-1', 'Reminder: Braids at Salon A tomorrow at 10:00', 0.30);
reset role;
do $$ begin
  assert (select reminder_sent_at from public.bookings where id = current_setting('t.booking')::uuid) is not null, 'marked sent';
  assert exists (select 1 from public.messages where whatsapp_message_id = 'wamid-reminder-1' and sender = 'assistant'),
    'the reminder shows in the chat';
  assert (select count(*) from public.usage_events where kind = 'whatsapp_template') = 1, 'counted as a template message';
  assert not exists (select 1 from public.audit_log
                     where changed_fields && array['reminder_attempts', 'reminder_sent_at', 'reminder_claimed_at']),
    'reminder bookkeeping stays out of the audit log';
end $$;
set local role service_role;
do $$ begin assert public.claim_due_reminders() = '[]', 'never reminded twice'; end $$;
reset role;

-- The customer moves the booking: a fresh reminder will go for the new time.
update public.bookings set starts_at = starts_at + interval '2 hours', ends_at = ends_at + interval '2 hours' where id = :'booking';
do $$ begin
  assert (select reminder_sent_at is null and reminder_attempts = 0 and reminder_claimed_at is null from public.bookings
          where id = current_setting('t.booking')::uuid), 'moving a booking re-arms its reminder';
end $$;

-- A cancelled booking gets no reminder.
update public.bookings set status = 'cancelled' where id = :'booking';
set local role service_role;
do $$ begin assert public.claim_due_reminders() = '[]', 'no reminder for a cancelled booking'; end $$;
reset role;

-- Owners and managers can't trigger sends themselves.
select tests.sign_in((:'a'::jsonb ->> 'owner')::uuid);
set local role authenticated;
select tests.expect_error('select public.claim_due_reminders()', 'permission denied');
select tests.expect_error(format($$select public.record_reminder(%L, 'x', 'y', 0)$$, :'booking'), 'permission denied');
reset role;

rollback;
