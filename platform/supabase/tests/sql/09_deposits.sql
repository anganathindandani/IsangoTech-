-- Deposits: a booking with a deposit is held until the business marks it
-- paid (or waives it), the customer is given the business's own way to pay,
-- and a hold that isn't paid in time is released.
begin;

select tests.seed_business('Salon A') as a \gset
select (:'a'::jsonb ->> 'business') as bid, (:'a'::jsonb ->> 'service') as service_id,
       (:'a'::jsonb ->> 'owner') as owner, (:'a'::jsonb ->> 'staff_user') as staff_user \gset
select ((now() at time zone 'Africa/Johannesburg')::date + 7)::text as day \gset
select set_config('t.bid', :'bid', false), set_config('t.service', :'service_id', false), set_config('t.day', :'day', false);

-- The owner asks for a 20% deposit, paid through their own payment link or EFT, within 12 hours.
update public.business_settings
set opening_hours = (select jsonb_object_agg(d, '[["08:00", "17:00"]]'::jsonb)
                     from unnest(array['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) d),
    assistant_enabled = true, reminders_enabled = true, reminder_template = 'booking_reminder', reminder_hours_before = 72
where business_id = :'bid';
select tests.sign_in(:'owner'::uuid);
set local role authenticated;
update public.business_settings
set deposit_required = true, deposit_percent = 20, deposit_hold_hours = 12,
    deposit_payment_link = 'https://pay.yoco.com/salon-a',
    deposit_payment_instructions = 'Or EFT to FNB 62000000000, using your reference.'
where business_id = :'bid';
select tests.expect_error(format($$update public.business_settings set deposit_payment_link = 'http://pay.example' where business_id = %L$$, :'bid'),
  'check constraint');
select tests.expect_error(format($$update public.business_settings set deposit_hold_hours = 0 where business_id = %L$$, :'bid'),
  'check constraint');
reset role;

-- A customer books on WhatsApp: held, with the amount, the way to pay, a reference and a pay-by time.
set local role service_role;
select public.assistant_receive('wa-salon-a', '27825550009', 'Ayanda', 'wamid-d1', 'Braids next week please') ->> 'conversation_id' as conv \gset
select set_config('t.conv', :'conv', true);
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
  jsonb_build_object('service_id', current_setting('t.service'), 'starts_at', current_setting('t.day') || 'T10:00'));
  d jsonb := r -> 'booking' -> 'deposit';
begin
  assert r ->> 'ok' = 'true', 'booked: ' || r::text;
  assert r -> 'booking' ->> 'status' = 'pending', 'held until the deposit is paid';
  assert d ->> 'amount' = 'R90.00', '20% of R450';
  assert d ->> 'payment_link' = 'https://pay.yoco.com/salon-a', 'the business''s own payment link';
  assert d ->> 'payment_instructions' like 'Or EFT%', 'and its EFT details';
  assert d ->> 'reference' = upper(left(replace(r -> 'booking' ->> 'booking_id', '-', ''), 6)), 'a reference from the booking';
  assert d ->> 'pay_by' is not null, 'with a pay-by time';
  perform set_config('t.booking', r -> 'booking' ->> 'booking_id', true);
end $$;
do $$ begin
  assert (select deposit_due_by between now() + interval '11 hours 59 minutes' and now() + interval '12 hours 1 minute'
          from public.bookings where id = current_setting('t.booking')::uuid), 'due after the 12-hour hold';
  assert (public.assistant_tool(current_setting('t.conv')::uuid, 'my_bookings', '{}') -> 'bookings' -> 0 -> 'deposit_due' ->> 'amount')
    = 'R90.00', 'my_bookings shows what is still owed';
  -- The slot stays taken while it's held.
  assert not (public.assistant_tool(current_setting('t.conv')::uuid, 'check_availability',
               jsonb_build_object('service_id', current_setting('t.service'), 'date', current_setting('t.day')))
             -> 'free_slots' @> '[{"time": "10:00"}]'), 'a held slot isn''t offered to anyone else';
  -- No reminder for a booking still waiting for its deposit.
  assert not exists (select 1 from jsonb_array_elements(public.claim_due_reminders()) e
                     where e ->> 'booking_id' = current_setting('t.booking')), 'no reminder while the deposit is due';
end $$;
reset role;

-- A booking soon after it's made must be paid at least an hour before it starts.
do $$ begin
  assert private.deposit_due_by(now() + interval '5 hours', 24) = now() + interval '4 hours', 'an hour before the appointment';
  assert private.deposit_due_by(now() + interval '1 hour', 24) = now() + interval '30 minutes', 'never sooner than 30 minutes';
end $$;

-- Staff can't mark deposits; the owner (or a manager) can, which confirms the booking.
select tests.sign_in(:'staff_user'::uuid);
set local role authenticated;
select tests.expect_error(format($$update public.bookings set deposit_status = 'paid' where id = %L$$, current_setting('t.booking')::uuid),
  'only change a booking''s status and notes');
reset role;
select tests.sign_in(:'owner'::uuid);
set local role authenticated;
update public.bookings set deposit_status = 'paid' where id = current_setting('t.booking')::uuid;
do $$ begin
  assert (select status = 'confirmed' and deposit_paid_at is not null from public.bookings
          where id = current_setting('t.booking')::uuid), 'paid: confirmed, with the time it was marked';
end $$;
select tests.expect_error(format($$update public.bookings set deposit_status = 'owing' where id = %L$$, current_setting('t.booking')::uuid), 'check constraint');
select tests.expect_error(format($$update public.bookings set deposit_paid_at = now() where id = %L$$, current_setting('t.booking')::uuid), 'permission denied');
reset role;

-- With the deposit paid, the Assistant doesn't cancel it: a person deals with the money.
set local role service_role;
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'cancel_booking',
  jsonb_build_object('booking_id', current_setting('t.booking')));
begin
  assert r ->> 'ok' = 'false' and r ->> 'error' like '%hand_over%', 'a paid deposit is handed over: ' || r::text;
  assert (select status from public.bookings where id = current_setting('t.booking')::uuid) = 'confirmed', 'still booked';
end $$;

-- A second booking that's never paid: released after its pay-by time, with a message while the chat window is open.
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
  jsonb_build_object('service_id', current_setting('t.service'), 'starts_at', current_setting('t.day') || 'T14:00'));
begin
  assert r -> 'booking' ->> 'status' = 'pending', 'held: ' || r::text;
  perform set_config('t.unpaid', r -> 'booking' ->> 'booking_id', true);
end $$;
do $$ begin assert public.release_unpaid_bookings() = '[]', 'nothing released before its pay-by time'; end $$;
reset role;
update public.bookings set deposit_due_by = now() - interval '1 minute' where id = current_setting('t.unpaid')::uuid;
set local role service_role;
do $$
declare r jsonb := public.release_unpaid_bookings();
begin
  assert jsonb_array_length(r) = 1, 'one released: ' || r::text;
  assert r -> 0 ->> 'booking_id' = current_setting('t.unpaid'), 'the unpaid one';
  assert r -> 0 ->> 'conversation_id' = current_setting('t.conv'), 'in the customer''s chat';
  assert r -> 0 ->> 'phone_number_id' = 'wa-salon-a' and r -> 0 ->> 'to' = '27825550009', 'from the business to the customer';
  assert r -> 0 ->> 'message' like 'Hi Ayanda, we didn''t receive the deposit for your Braids booking%', 'told why';
  assert (select status = 'cancelled' and notes = 'Released: the deposit wasn''t paid in time.' from public.bookings
          where id = current_setting('t.unpaid')::uuid), 'released, with a note saying why';
  assert (select status from public.bookings where id = current_setting('t.booking')::uuid) = 'confirmed', 'the paid one stays';
  assert public.release_unpaid_bookings() = '[]', 'released once';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'check_availability',
           jsonb_build_object('service_id', current_setting('t.service'), 'date', current_setting('t.day')))
         -> 'free_slots' @> '[{"time": "14:00"}]', 'the released time is free again';
end $$;
reset role;

-- Outside WhatsApp's 24-hour window the release is silent: only a template could reach the customer.
set local role service_role;
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
  jsonb_build_object('service_id', current_setting('t.service'), 'starts_at', current_setting('t.day') || 'T08:00'));
begin
  perform set_config('t.quiet', r -> 'booking' ->> 'booking_id', true);
end $$;
reset role;
update public.bookings set deposit_due_by = now() - interval '1 minute' where id = current_setting('t.quiet')::uuid;
update public.conversations set last_customer_message_at = now() - interval '2 days' where id = :'conv';
set local role service_role;
do $$
declare r jsonb := public.release_unpaid_bookings();
begin
  assert jsonb_array_length(r) = 1 and r -> 0 -> 'message' = 'null'::jsonb, 'released without a message: ' || r::text;
end $$;
reset role;

-- A waived deposit confirms the booking too.
insert into public.bookings (business_id, customer_id, service_id, starts_at, ends_at, source, status, deposit_amount, deposit_status)
select :'bid', customer_id, :'service_id', now() + interval '3 days', now() + interval '3 days 2 hours', 'portal', 'pending', 90, 'requested'
from public.conversations where id = :'conv'
returning id as waived \gset
select tests.sign_in(:'owner'::uuid);
set local role authenticated;
update public.bookings set deposit_status = 'waived' where id = :'waived';
reset role;
select status = 'confirmed' and deposit_paid_at is null as ok from public.bookings where id = :'waived' \gset
\if :ok
\else
  select 1/0 as "a waived deposit should confirm the booking";
\endif

-- Only the scheduled job releases bookings.
select tests.sign_in(:'owner'::uuid);
set local role authenticated;
select tests.expect_error('select public.release_unpaid_bookings()', 'permission denied');
reset role;

rollback;
