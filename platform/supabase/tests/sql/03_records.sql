-- Bookings, chats and the POPIA rules: double bookings, WhatsApp retries,
-- the 24-hour window, deleting old chats and deleting a customer on request.
begin;

select tests.seed_business('Salon A') as a \gset
select (:'a'::jsonb ->> 'business') as bid, (:'a'::jsonb ->> 'staff_id') as staff_id,
       (:'a'::jsonb ->> 'customer') as customer_id, (:'a'::jsonb ->> 'conversation') as conversation_id,
       (:'a'::jsonb ->> 'manager') as manager_id \gset

-- A new business gets its settings row straight away, Assistant off until set up.
do $$ begin
  assert (select count(*) from public.business_settings) = 1, 'settings created with the business';
  assert not (select assistant_enabled from public.business_settings), 'assistant starts switched off';
  assert (select message_retention_months from public.business_settings) = 12, 'chats kept 12 months by default';
end $$;

-- The same stylist can't be booked twice for overlapping times...
select tests.sign_in(:'manager_id');
set local role authenticated;
select tests.expect_error(format(
  $$insert into public.bookings (business_id, customer_id, staff_id, starts_at, ends_at, source)
    select business_id, customer_id, staff_id, starts_at + interval '30 minutes', ends_at + interval '30 minutes', 'portal'
    from public.bookings where staff_id = %L$$, :'staff_id'), 'no_double_booking');
-- ...but once the first booking is cancelled, the slot is free again.
update public.bookings set status = 'cancelled' where staff_id = :'staff_id';
insert into public.bookings (business_id, customer_id, staff_id, starts_at, ends_at, source)
select business_id, customer_id, staff_id, starts_at, ends_at, 'portal' from public.bookings where staff_id = :'staff_id';
select tests.expect_error(format(
  $$insert into public.bookings (business_id, customer_id, starts_at, ends_at, source) values (%L, %L, now(), now() - interval '1 hour', 'portal')$$,
  :'bid', :'customer_id'), 'check constraint');
do $$ begin
  assert (select count(*) from public.bookings where created_by = auth.uid()) = 1, 'bookings record who made them';
end $$;
reset role;

-- Opting in to WhatsApp updates records when; opting out clears it.
do $$ begin
  assert (select whatsapp_opt_in_at from public.customers) is not null, 'opt-in time recorded';
end $$;
update public.customers set whatsapp_opt_in = false;
do $$ begin
  assert (select whatsapp_opt_in_at from public.customers) is null, 'opt-out clears it';
end $$;

-- Phone numbers are stored as WhatsApp sends them, and are unique per business.
select tests.expect_error(format($$insert into public.customers (business_id, whatsapp_number) values (%L, '+27 82 123')$$, :'bid'),
  'check constraint');

-- A WhatsApp retry delivers the same message twice; it's saved once.
select tests.expect_error(format(
  $$insert into public.messages (business_id, conversation_id, direction, sender, body, whatsapp_message_id)
    values (%L, %L, 'inbound', 'customer', 'Hi, braids on Saturday?', 'wamid-salon-a')$$,
  :'bid', :'conversation_id'), 'duplicate key');
-- A customer can't be recorded as the sender of an outgoing message.
select tests.expect_error(format(
  $$insert into public.messages (business_id, conversation_id, direction, sender, body) values (%L, %L, 'outbound', 'customer', 'x')$$,
  :'bid', :'conversation_id'), 'check constraint');

-- Messages keep the chat's timestamps current; only customer messages open the 24-hour window.
update public.conversations set last_customer_message_at = now() - interval '2 days', last_message_at = now() - interval '2 days';
insert into public.messages (business_id, conversation_id, direction, sender, body)
values (:'bid', :'conversation_id', 'outbound', 'assistant', 'Hi Thandi! We have 09:00 or 13:30.');
do $$ begin
  assert (select last_message_at from public.conversations) > now() - interval '1 minute', 'reply updates last message time';
  assert (select last_customer_message_at from public.conversations) < now() - interval '1 day',
    'an outgoing message does not reopen the 24-hour window';
end $$;
insert into public.messages (business_id, conversation_id, direction, sender, body)
values (:'bid', :'conversation_id', 'inbound', 'customer', '13:30 please');
do $$ begin
  assert (select last_customer_message_at from public.conversations) > now() - interval '1 minute', 'customer message opens the window';
end $$;

-- Old chats are deleted after the business's retention period.
update public.business_settings set message_retention_months = 6;
insert into public.messages (business_id, conversation_id, direction, sender, body, created_at)
values (:'bid', :'conversation_id', 'inbound', 'customer', 'An old message', now() - interval '7 months'),
       (:'bid', :'conversation_id', 'inbound', 'customer', 'Not old enough', now() - interval '5 months');
set local role service_role;
do $$ begin
  assert private.delete_expired_messages() = 1, 'exactly one message was past six months';
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from public.messages where body = 'An old message'), 'old message deleted';
  assert exists (select 1 from public.messages where body = 'Not old enough'), 'newer message kept';
end $$;
-- Only IsangoTech's scheduled job can run it.
set local role authenticated;
select tests.expect_error('select private.delete_expired_messages()', 'permission denied');
reset role;

-- A customer asks to be forgotten: the owner deletes them, and their bookings
-- and chats go with them. The audit log keeps only that it happened.
select tests.sign_in((:'a'::jsonb ->> 'owner')::uuid);
set local role authenticated;
delete from public.customers where id = :'customer_id';
reset role;
do $$ begin
  assert (select count(*) from public.bookings) = 0, 'their bookings are gone';
  assert (select count(*) from public.conversations) = 0, 'their chat is gone';
  assert (select count(*) from public.messages) = 0, 'their messages are gone';
  assert (select count(*) from public.unanswered_questions where conversation_id is not null) = 0,
    'unanswered questions no longer point at the chat';
  assert exists (select 1 from public.audit_log where table_name = 'customers' and action = 'delete'),
    'the deletion is in the audit log';
  assert not exists (select 1 from public.audit_log where changed_fields && array['full_name', 'whatsapp_number']
                     and table_name = 'customers' and action = 'update'),
    'the audit log holds field names, never personal details';
end $$;

-- Offboarding a business removes everything it had, audit log included.
delete from public.businesses where id = :'bid';
do $$
declare r record; n bigint;
begin
  for r in select table_name from information_schema.columns
           where table_schema = 'public' and column_name = 'business_id' loop
    execute format('select count(*) from public.%I', r.table_name) into n;
    assert n = 0, r.table_name || ' still has rows after the business was deleted';
  end loop;
end $$;

rollback;
