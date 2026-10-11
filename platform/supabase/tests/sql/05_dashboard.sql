-- The owner's dashboard: today's summary per role, answering questions, and
-- replying in person within WhatsApp's 24-hour window.
begin;

select tests.seed_business('Salon A') as a \gset
select tests.seed_business('Salon B') as b \gset
select (:'a'::jsonb ->> 'business') as bid, (:'a'::jsonb ->> 'conversation') as conv,
       (:'b'::jsonb ->> 'conversation') as b_conv \gset
select set_config('t.bid', :'bid', false), set_config('t.conv', :'conv', false), set_config('t.b_conv', :'b_conv', false);

-- A booking for today, so the summary has something to show.
update public.bookings set starts_at = date_trunc('day', now() at time zone 'Africa/Johannesburg') at time zone 'Africa/Johannesburg' + interval '23 hours',
  ends_at = date_trunc('day', now() at time zone 'Africa/Johannesburg') at time zone 'Africa/Johannesburg' + interval '23 hours 30 minutes'
where business_id = :'bid';

-- Owner: everything, including usage.
select tests.sign_in((:'a'::jsonb ->> 'owner')::uuid);
set local role authenticated;
do $$
declare s jsonb := public.today_summary(current_setting('t.bid')::uuid);
begin
  assert jsonb_array_length(s -> 'bookings_today') = 1, 'today''s booking: ' || s::text;
  assert s -> 'bookings_today' -> 0 ->> 'customer' = 'Thandi', 'with the customer''s name';
  assert (s ->> 'open_questions')::int = 1, 'one open question';
  assert (s -> 'usage' ->> 'conversations')::int = 1, 'usage this month';
end $$;

-- Answering a question adds it to what the Assistant knows.
do $$
declare q uuid := (select id from public.unanswered_questions where business_id = current_setting('t.bid')::uuid);
begin
  perform public.answer_question(q, 'Not yet, but soon.');
  assert (select status from public.unanswered_questions where id = q) = 'answered', 'marked answered';
  assert exists (select 1 from public.knowledge_items where question = 'Do you do nails?' and answer = 'Not yet, but soon.'),
    'added to the business''s answers';
end $$;
select tests.expect_error(format($$select public.answer_question(%L, 'again')$$,
  (select id from public.unanswered_questions where business_id = :'bid')), 'no longer open');
reset role;

-- Manager: no usage in the summary.
select tests.sign_in((:'a'::jsonb ->> 'manager')::uuid);
set local role authenticated;
do $$ begin
  assert public.today_summary(current_setting('t.bid')::uuid) -> 'usage' = 'null'::jsonb, 'managers don''t see usage';
end $$;

-- Replying in person: allowed inside the 24-hour window, takes the chat over.
do $$
declare target jsonb := public.prepare_person_reply(current_setting('t.conv')::uuid);
begin
  assert target ->> 'phone_number_id' = 'wa-salon-a', 'sends from the business''s number';
  assert target ->> 'to' like '2782%', 'to the customer';
  perform public.record_person_reply(current_setting('t.conv')::uuid, 'Hi Thandi, this is the owner.', 'wamid-person-1');
  assert (select handled_by from public.conversations where id = current_setting('t.conv')::uuid) = 'person',
    'replying takes the chat over';
  assert (select sent_by from public.messages where whatsapp_message_id = 'wamid-person-1') = auth.uid(),
    'records who replied';
end $$;
-- Not for another business's chat.
select tests.expect_error(format('select public.prepare_person_reply(%L)', :'b_conv'), 'not allowed');
select tests.expect_error(format($$select public.record_person_reply(%L, 'x', 'y')$$, :'b_conv'), 'not allowed');
reset role;

-- Outside the window WhatsApp won't deliver a free reply, so it's refused up front.
update public.conversations set last_customer_message_at = now() - interval '25 hours' where id = :'conv';
select tests.sign_in((:'a'::jsonb ->> 'manager')::uuid);
set local role authenticated;
select tests.expect_error(format('select public.prepare_person_reply(%L)', :'conv'), '24 hours');
reset role;

-- Staff can't reply on WhatsApp, and see only their own bookings today.
update public.conversations set last_customer_message_at = now();
select tests.sign_in((:'a'::jsonb ->> 'staff_user')::uuid);
set local role authenticated;
select tests.expect_error(format('select public.prepare_person_reply(%L)', :'conv'), 'not allowed');
do $$ begin
  assert jsonb_array_length(public.today_summary(current_setting('t.bid')::uuid) -> 'bookings_today') = 1,
    'the stylist sees their own booking today';
end $$;
reset role;

rollback;
