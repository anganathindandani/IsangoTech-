-- Inside one business: what owners, managers and staff can each do, two-step
-- sign-in, people who have left, and the columns nobody may change.
begin;

select tests.seed_business('Salon A') as a \gset
select (:'a'::jsonb ->> 'business') as bid, (:'a'::jsonb ->> 'owner') as owner_id,
       (:'a'::jsonb ->> 'manager') as manager_id, (:'a'::jsonb ->> 'staff_user') as staff_user,
       (:'a'::jsonb ->> 'booking') as booking_id, (:'a'::jsonb ->> 'customer') as customer_id,
       (:'a'::jsonb ->> 'conversation') as conversation_id \gset

-- A second stylist with a booking of their own, to check staff see only theirs.
select tests.create_member(:'bid', 'second@salon-a.test', 'staff') as second_user \gset
insert into public.staff (business_id, full_name, user_id) values (:'bid', 'Second', :'second_user') returning id as second_staff \gset
insert into public.customers (business_id, full_name, whatsapp_number) values (:'bid', 'Lindiwe', '27831112222') returning id as other_customer \gset
insert into public.bookings (business_id, customer_id, staff_id, starts_at, ends_at, source)
values (:'bid', :'other_customer', :'second_staff', now() + interval '2 days', now() + interval '2 days 1 hour', 'portal');

-- Owner: sees and runs everything, including usage, the audit log and the team.
select tests.sign_in(:'owner_id');
set local role authenticated;
do $$ begin
  assert (select count(*) from public.businesses) = 1, 'owner sees their business';
  assert (select count(*) from public.bookings) = 2, 'owner sees all bookings';
  assert (select count(*) from public.customers) = 2, 'owner sees all customers';
  assert (select count(*) from public.messages) = 1, 'owner sees chats';
  assert (select count(*) from public.usage_events) = 2, 'owner sees usage';
  assert (select count(*) from public.audit_log) > 0, 'owner sees the audit log';
end $$;
select set_config('t.bid', :'bid', true);
do $$ begin
  assert (select row(conversations, allowance, cost_zar)::text from public.usage_this_month(current_setting('t.bid')::uuid))
    = '(1,300,0.0400)', 'usage this month adds up';
end $$;
update public.businesses set name = 'Salon A Hair Studio' where id = :'bid';
update public.services set price = 480 where business_id = :'bid';
update public.business_settings set languages = array['en', 'xh'], opening_hours = '{"sat": [["08:00", "14:00"]]}';
-- Plans, products and WhatsApp numbers are IsangoTech's to change.
select tests.expect_error(format($$update public.businesses set products = '{assistant}' where id = %L$$, :'bid'), 'permission denied');
select tests.expect_error(format($$update public.businesses set monthly_conversation_allowance = 9999 where id = %L$$, :'bid'), 'permission denied');
select tests.expect_error(format($$update public.businesses set whatsapp_phone_number_id = 'x' where id = %L$$, :'bid'), 'permission denied');
select tests.expect_error($$insert into public.businesses (name, industry) values ('New', 'salon')$$, 'permission denied');
-- The record of what was said and what it cost can't be edited from the app.
select tests.expect_error('delete from public.messages', 'permission denied');
select tests.expect_error($$update public.messages set body = 'changed'$$, 'permission denied');
select tests.expect_error('delete from public.usage_events', 'permission denied');
select tests.expect_error('delete from public.audit_log', 'permission denied');
select tests.expect_error(format(
  $$insert into public.messages (business_id, conversation_id, direction, sender, body) values (%L, %L, 'outbound', 'assistant', 'x')$$,
  :'bid', :'conversation_id'), 'permission denied');
-- System columns stay as the system set them.
select tests.expect_error(format($$update public.bookings set created_by = null where id = %L$$, :'booking_id'), 'permission denied');
select tests.expect_error(format($$update public.bookings set reminder_sent_at = now() where id = %L$$, :'booking_id'), 'permission denied');
reset role;

-- Every change above is in the audit log with who made it.
do $$ begin
  assert exists (select 1 from public.audit_log where table_name = 'services' and action = 'update'
                 and changed_fields = array['price'] and changed_by is not null), 'price change is audited';
  assert exists (select 1 from public.audit_log where table_name = 'business_settings' and action = 'update'
                 and changed_fields = array['languages', 'opening_hours']), 'settings change is audited';
end $$;

-- Manager: daily work, but no usage, billing or audit log, and can't manage the team.
select tests.sign_in(:'manager_id');
set local role authenticated;
do $$ begin
  assert (select count(*) from public.bookings) = 2, 'manager sees all bookings';
  assert (select count(*) from public.messages) = 1, 'manager sees chats';
  assert (select count(*) from public.usage_events) = 0, 'manager does not see usage';
  assert (select count(*) from public.audit_log) = 0, 'manager does not see the audit log';
end $$;
select tests.expect_error(format('select * from public.usage_this_month(%L)', :'bid'), 'not allowed');
insert into public.customers (business_id, full_name, whatsapp_number) values (:'bid', 'Walk-in', '27840000000');
insert into public.knowledge_items (business_id, question, answer) values (:'bid', 'Do you do nails?', 'Not yet.');
update public.business_settings set tone = 'Warm' where business_id = :'bid';
-- Take over a chat, then hand it back: who and when is recorded, then cleared.
update public.conversations set handled_by = 'person' where id = :'conversation_id';
do $$ begin
  assert (select taken_over_by from public.conversations) = auth.uid(), 'take-over records who';
end $$;
update public.conversations set handled_by = 'assistant' where id = :'conversation_id';
do $$ begin
  assert (select taken_over_by from public.conversations) is null, 'handing back clears it';
end $$;
do $$ begin
  assert tests.affected(format('update public.business_members set role = %L', 'owner')) = 0, 'manager cannot change roles';
  assert tests.affected('delete from public.customers') = 0, 'manager cannot delete customers';
  assert tests.affected('delete from public.bookings') = 0, 'manager cannot delete bookings';
end $$;
reset role;

-- Staff: only their own bookings and those customers; can update status and notes only.
select tests.sign_in(:'staff_user');
set local role authenticated;
do $$ begin
  assert (select count(*) from public.bookings) = 1, 'staff see only their own booking';
  assert (select count(*) from public.customers) = 1, 'staff see only their own customers';
  assert (select full_name from public.customers) = 'Thandi', 'and it is the right customer';
  assert (select count(*) from public.messages) = 0, 'staff do not see chats';
  assert (select count(*) from public.conversations) = 0, 'staff do not see conversations';
  assert (select count(*) from public.usage_events) = 0, 'staff do not see usage';
  assert (select count(*) from public.services) = 1, 'staff can read the service list';
  assert (select count(*) from public.business_members) = 4, 'staff can see the team';
end $$;
update public.bookings set status = 'completed', notes = 'Arrived on time' where id = :'booking_id';
select tests.expect_error(format($$update public.bookings set starts_at = starts_at + interval '1 hour' where id = %L$$, :'booking_id'),
  'only change a booking''s status and notes');
select tests.expect_error(format($$insert into public.customers (business_id, full_name) values (%L, 'x')$$, :'bid'), 'row-level security');
do $$ begin
  assert tests.affected('update public.services set price = 1') = 0, 'staff cannot change prices';
  assert tests.affected('update public.business_settings set tone = $q$x$q$') = 0, 'staff cannot change settings';
end $$;
reset role;

-- Two-step sign-in: once someone turns it on, their password alone isn't enough.
select tests.add_authenticator(:'manager_id');
select tests.sign_in(:'manager_id', 'aal1');
set local role authenticated;
do $$ begin
  assert (select count(*) from public.bookings) = 0, 'password-only session sees nothing once 2FA is on';
end $$;
reset role;
select tests.sign_in(:'manager_id', 'aal2');
set local role authenticated;
do $$ begin
  assert (select count(*) from public.bookings) = 2, 'after the code, full access again';
end $$;
reset role;

-- Someone who has left: set inactive by the owner, locked out at once.
select tests.sign_in(:'owner_id');
set local role authenticated;
update public.business_members set active = false where user_id = :'second_user';
-- The last owner can't be removed or demoted, so the business is never locked out.
select tests.expect_error(format($$update public.business_members set role = 'manager' where user_id = %L$$, :'owner_id'),
  'at least one active owner');
select tests.expect_error(format($$delete from public.business_members where user_id = %L$$, :'owner_id'),
  'at least one active owner');
select tests.expect_error(format($$update public.business_members set active = false where user_id = %L$$, :'owner_id'),
  'at least one active owner');
-- Promoting a second owner first makes it possible.
update public.business_members set role = 'owner' where user_id = :'manager_id';
update public.business_members set role = 'manager' where user_id = :'owner_id';
reset role;

select tests.sign_in(:'second_user');
set local role authenticated;
do $$ begin
  assert (select count(*) from public.bookings) = 0, 'a former team member sees nothing';
  assert (select count(*) from public.businesses) = 0, 'not even the business';
end $$;
reset role;

rollback;
