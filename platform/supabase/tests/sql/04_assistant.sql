-- The Assistant's database side: recording messages, availability and the
-- tools, and that a conversation can only ever reach its own business and
-- its own customer.
begin;

select tests.seed_business('Salon A') as a \gset
select tests.seed_business('Salon B') as b \gset
select (:'a'::jsonb ->> 'business') as bid, (:'a'::jsonb ->> 'service') as service_id,
       (:'a'::jsonb ->> 'staff_id') as stylist, (:'b'::jsonb ->> 'service') as b_service,
       (:'b'::jsonb ->> 'booking') as b_booking \gset

-- Open 08:00 to 17:00 every day; 2 hours' notice to book, 24 to change.
update public.business_settings
set opening_hours = (select jsonb_object_agg(d, '[["08:00", "17:00"]]'::jsonb)
                     from unnest(array['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) d),
    assistant_enabled = true, deposit_required = true, deposit_percent = 20;
-- A second stylist who works afternoons only and doesn't do braids.
insert into public.staff (business_id, full_name, working_hours)
values (:'bid', 'Afternoons', (select jsonb_object_agg(d, '[["13:00", "17:00"]]'::jsonb)
                               from unnest(array['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) d));
select ((now() at time zone 'Africa/Johannesburg')::date + 7)::text as day \gset
select set_config('t.bid', :'bid', false);

set local role service_role;

-- Messages to a number with no business are ignored.
do $$ begin
  assert public.assistant_receive('wa-nobody', '27820000001', 'X', 'wamid-1', 'Hi') ->> 'status' = 'unknown_number',
    'unknown number is ignored';
end $$;

-- A new customer writes in: saved, with their WhatsApp name, and a new 24-hour window counted.
select public.assistant_receive('wa-salon-a', '27825550001', 'Nomsa', 'wamid-2', 'Hi, do you do braids?') as r \gset
select set_config('t.conv', :'r'::jsonb ->> 'conversation_id', true);
do $$ begin
  assert (select count(*) from public.customers where full_name = 'Nomsa') = 1, 'new customer saved with their name';
  assert (select count(*) from public.usage_events where kind = 'whatsapp_conversation'
          and conversation_id = current_setting('t.conv')::uuid) = 1, 'a new conversation is counted';
end $$;
select :'r'::jsonb ->> 'status' = 'reply' and (:'r'::jsonb ->> 'new_customer')::boolean as ok \gset
\if :ok
\else
  select 1/0 as "a first message should get a reply and be marked new";
\endif

-- The same WhatsApp message delivered again is saved once; a second message in the window isn't counted again.
do $$ begin
  assert public.assistant_receive('wa-salon-a', '27825550001', 'Nomsa', 'wamid-2', 'Hi, do you do braids?') ->> 'status'
    = 'duplicate', 'retry is a duplicate';
  assert public.assistant_receive('wa-salon-a', '27825550001', 'Nomsa', 'wamid-3', 'Saturday?') ->> 'status' = 'reply',
    'second message gets a reply';
  assert (select count(*) from public.messages where conversation_id = current_setting('t.conv')::uuid) = 2,
    'two messages saved';
  assert (select count(*) from public.usage_events where kind = 'whatsapp_conversation'
          and conversation_id = current_setting('t.conv')::uuid) = 1, 'still one conversation counted';
end $$;

-- What the AI reads: this business, these settings, this chat.
do $$
declare ctx jsonb := public.assistant_context(current_setting('t.conv')::uuid);
begin
  assert ctx -> 'business' ->> 'name' = 'Salon A', 'context names the business';
  assert ctx -> 'customer' ->> 'name' = 'Nomsa', 'context names the customer';
  assert jsonb_array_length(ctx -> 'history') = 2, 'context has the chat so far';
  assert ctx -> 'history' -> 1 ->> 'body' = 'Saturday?', 'oldest first';
end $$;

-- find_services: real prices, only this business's services.
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'find_services', '{}');
begin
  assert jsonb_array_length(r -> 'services') = 1, 'one service';
  assert r -> 'services' -> 0 ->> 'price' = 'R450.00', 'the real price';
  assert r -> 'services' -> 0 -> 'staff' = '["Stylist"]', 'who does it';
end $$;

-- check_availability: braids take 2 hours, only "Stylist" does them, 08:00 to 17:00.
select set_config('t.day', :'day', true), set_config('t.service', :'service_id', true),
       set_config('t.b_service', :'b_service', true), set_config('t.b_booking', :'b_booking', true);
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'check_availability',
  jsonb_build_object('service_id', current_setting('t.service'), 'date', current_setting('t.day')));
begin
  assert r ->> 'ok' = 'true', 'availability works: ' || r::text;
  assert r -> 'free_slots' -> 0 ->> 'time' = '08:00', 'first slot at opening';
  assert (select max(s ->> 'time') from jsonb_array_elements(r -> 'free_slots') s) = '15:00',
    'last slot ends at closing';
  assert not exists (select 1 from jsonb_array_elements(r -> 'free_slots') s where s ->> 'staff_name' = 'Afternoons'),
    'staff who don''t do the service aren''t offered';
end $$;

-- Another business's service is refused.
do $$ begin
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'check_availability',
    jsonb_build_object('service_id', current_setting('t.b_service'), 'date', current_setting('t.day'))) ->> 'ok' = 'false',
    'cannot check another business''s service';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
    jsonb_build_object('service_id', current_setting('t.b_service'), 'starts_at', current_setting('t.day') || 'T10:00'))
    ->> 'ok' = 'false', 'cannot book another business''s service';
end $$;

-- create_booking: books the slot with the 20% deposit, then the slot is gone.
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
  jsonb_build_object('service_id', current_setting('t.service'), 'starts_at', current_setting('t.day') || 'T10:00'));
begin
  assert r ->> 'ok' = 'true', 'booking made: ' || r::text;
  assert r -> 'booking' ->> 'staff' = 'Stylist', 'with the stylist who does braids';
  assert r -> 'booking' -> 'deposit' ->> 'amount' = 'R90.00', '20% deposit of R450';
  assert r -> 'booking' ->> 'status' = 'pending', 'held until the deposit is paid';
  perform set_config('t.booking', r -> 'booking' ->> 'booking_id', true);
end $$;
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'check_availability',
  jsonb_build_object('service_id', current_setting('t.service'), 'date', current_setting('t.day')));
begin
  assert not exists (select 1 from jsonb_array_elements(r -> 'free_slots') s
                     where s ->> 'time' between '08:30' and '11:30'), 'overlapping slots are gone';
  assert exists (select 1 from jsonb_array_elements(r -> 'free_slots') s where s ->> 'time' = '12:00'),
    'the next slot after the booking is free';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
    jsonb_build_object('service_id', current_setting('t.service'), 'starts_at', current_setting('t.day') || 'T11:00'))
    ->> 'ok' = 'false', 'a taken time is refused';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
    jsonb_build_object('service_id', current_setting('t.service'), 'starts_at', current_setting('t.day') || 'T16:00'))
    ->> 'ok' = 'false', 'a time that would run past closing is refused';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
    jsonb_build_object('service_id', current_setting('t.service'), 'starts_at', 'tomorrow at ten'))
    ->> 'ok' = 'false', 'an unreadable time is refused, not guessed';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
    jsonb_build_object('service_id', current_setting('t.service'),
                       'starts_at', to_char(now() at time zone 'Africa/Johannesburg' + interval '30 minutes', 'YYYY-MM-DD"T"HH24:MI')))
    ->> 'ok' = 'false', 'less than the minimum notice is refused';
end $$;

-- my_bookings shows only this customer's bookings; others can't be changed or cancelled.
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'my_bookings', '{}');
begin
  assert jsonb_array_length(r -> 'bookings') = 1, 'only their own booking';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'cancel_booking',
    jsonb_build_object('booking_id', current_setting('t.b_booking'))) ->> 'ok' = 'false',
    'cannot cancel another business''s booking';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'cancel_booking', '{"booking_id": "not-an-id"}') ->> 'ok'
    = 'false', 'a made-up id is refused';
end $$;

-- change_booking moves it (its old slot doesn't block it); cancel frees it.
do $$
declare r jsonb := public.assistant_tool(current_setting('t.conv')::uuid, 'change_booking',
  jsonb_build_object('booking_id', current_setting('t.booking'), 'starts_at', current_setting('t.day') || 'T11:00'));
begin
  assert r ->> 'ok' = 'true', 'moved by an hour, overlapping its own old time: ' || r::text;
  assert (select to_char(starts_at at time zone 'Africa/Johannesburg', 'HH24:MI') from public.bookings
          where id = current_setting('t.booking')::uuid) = '11:00', 'new time saved';
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'cancel_booking',
    jsonb_build_object('booking_id', current_setting('t.booking'))) ->> 'ok' = 'true', 'cancelled';
  assert (select status from public.bookings where id = current_setting('t.booking')::uuid) = 'cancelled', 'status saved';
end $$;

-- Too close to the time: changes go to a person.
update public.business_settings set change_notice_hours = 24 * 30 where business_id = current_setting('t.bid', true)::uuid;
do $$
declare r jsonb;
begin
  r := public.assistant_tool(current_setting('t.conv')::uuid, 'create_booking',
    jsonb_build_object('service_id', current_setting('t.service'), 'starts_at', current_setting('t.day') || 'T13:00'));
  r := public.assistant_tool(current_setting('t.conv')::uuid, 'cancel_booking',
    jsonb_build_object('booking_id', r -> 'booking' ->> 'booking_id'));
  assert r ->> 'ok' = 'false' and r ->> 'error' like '%notice%', 'late cancellation is refused: ' || r::text;
end $$;

-- lookup_answer finds the business's own facts.
do $$ begin
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'lookup_answer', '{"question": "Where can I park?"}')
    -> 'answers' -> 0 ->> 'answer' = 'Free parking at the back.', 'finds the parking answer';
  assert jsonb_array_length(public.assistant_tool(current_setting('t.conv')::uuid, 'lookup_answer',
    '{"question": "Do you sell gift cards?"}') -> 'answers') = 0, 'no answer means none, not a guess';
end $$;

-- hand_over: the team takes it from here and the question is listed for the owner.
do $$ begin
  assert public.assistant_tool(current_setting('t.conv')::uuid, 'hand_over',
    '{"reason": "gift cards", "question": "Do you sell gift cards?"}') ->> 'ok' = 'true', 'handed over';
  assert (select handled_by from public.conversations where id = current_setting('t.conv')::uuid) = 'person',
    'the chat is now with a person';
  assert exists (select 1 from public.unanswered_questions where question = 'Do you sell gift cards?'),
    'the question is listed for the owner';
  assert public.assistant_receive('wa-salon-a', '27825550001', 'Nomsa', 'wamid-4', 'Hello?') ->> 'status' = 'person',
    'the Assistant stays quiet once a person has taken over';
end $$;

-- Replies and AI costs are recorded against the right business.
do $$ begin
  perform public.assistant_record_reply(current_setting('t.conv')::uuid, 'Someone will reply shortly.', 'wamid-out-1');
  perform public.assistant_record_ai_call(current_setting('t.conv')::uuid, 'anthropic/claude-haiku-5.5', 5000, 4000, 200, 0.05);
  assert (select count(*) from public.messages where sender = 'assistant'
          and conversation_id = current_setting('t.conv')::uuid) = 1, 'reply recorded';
  assert (select cost_zar from public.usage_events where kind = 'ai_call' and model = 'anthropic/claude-haiku-5.5') = 0.05,
    'cost recorded';
end $$;

-- A business that hasn't switched the Assistant on: messages are saved, no reply.
update public.business_settings set assistant_enabled = false;
do $$ begin
  assert public.assistant_receive('wa-salon-b', '27825550009', 'Sipho', 'wamid-5', 'Hi') ->> 'status' = 'assistant_off',
    'no reply while switched off';
end $$;
reset role;

-- Nobody signed in to the app can call any of this.
select tests.sign_in((:'a'::jsonb ->> 'owner')::uuid);
set local role authenticated;
select tests.expect_error($$select public.assistant_receive('wa-salon-a', '1', 'x', 'y', 'z')$$, 'permission denied');
select tests.expect_error(format($$select public.assistant_tool(%L, 'find_services', '{}')$$, :'r'::jsonb ->> 'conversation_id'),
  'permission denied');
select tests.expect_error(format($$select public.assistant_context(%L)$$, :'r'::jsonb ->> 'conversation_id'),
  'permission denied');
reset role;
set local role anon;
select tests.expect_error($$select public.assistant_receive('wa-salon-a', '1', 'x', 'y', 'z')$$, 'permission denied');
reset role;

rollback;
