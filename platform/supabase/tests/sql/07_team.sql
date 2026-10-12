-- Owners managing their team: adding managers and staff, staff linked to a
-- staff record, and setup links only for logins that belong here alone.
begin;

select tests.seed_business('Salon A') as a \gset
select tests.seed_business('Salon B') as b \gset
select (:'a'::jsonb ->> 'business') as bid, (:'b'::jsonb ->> 'business') as b_bid,
       (:'a'::jsonb ->> 'owner') as owner_id, (:'b'::jsonb ->> 'owner') as b_owner \gset
insert into auth.users (email) values ('zola@example.test') returning id as zola \gset
insert into auth.users (email) values ('sam@example.test') returning id as sam \gset
insert into auth.users (email) values ('lindi@example.test') returning id as lindi \gset
insert into public.staff (business_id, full_name) values (:'bid', 'Lindi') returning id as lindi_staff \gset
select set_config('t.bid', :'bid', false), set_config('t.zola', :'zola', false), set_config('t.sam', :'sam', false),
       set_config('t.lindi', :'lindi_staff', false);

-- The edge function adds a manager, a new staff member, and one for an existing staff record.
set local role service_role;
select public.add_team_member(:'bid', :'zola', 'Zola Manager', 'manager');
select public.add_team_member(:'bid', :'sam', 'Sam', 'staff');
select public.add_team_member(:'bid', :'lindi', 'Lindi Mthembu', 'staff', :'lindi_staff');
select tests.expect_error(format($$select public.add_team_member(%L, %L, 'X', 'owner')$$, :'bid', :'sam'), 'managers and staff');
select tests.expect_error(format($$select public.add_team_member(%L, %L, 'X', 'staff', %L)$$, :'bid', :'zola', :'lindi_staff'),
  'already has a login');
reset role;
do $$ begin
  assert (select count(*) from public.staff where user_id = current_setting('t.sam')::uuid) = 1, 'new staff record for Sam';
  assert (select user_id from public.staff where id = current_setting('t.lindi')::uuid) is not null, 'Lindi linked to her record';
  assert (select count(*) from public.staff where user_id = current_setting('t.zola')::uuid) = 0, 'managers need no staff record';
end $$;

-- The owner sees the team with emails; managers and staff can't.
select tests.sign_in(:'owner_id');
set local role authenticated;
do $$
declare t jsonb := public.team_members(current_setting('t.bid')::uuid);
begin
  assert public.is_business_owner(current_setting('t.bid')::uuid), 'owner recognised';
  assert jsonb_array_length(t) = 6, 'owner, manager, stylist and three new: ' || jsonb_array_length(t);
  assert t -> 0 ->> 'role' = 'owner', 'owners first';
  assert (select m ->> 'staff_name' from jsonb_array_elements(t) m where m ->> 'email' = 'lindi@example.test') = 'Lindi',
    'shows the linked staff record';
end $$;
-- Owners change roles and deactivate people directly (row-level security allows it).
update public.business_members set role = 'manager' where user_id = :'sam';
update public.business_members set active = false where user_id = :'zola';
reset role;
select tests.sign_in(:'zola');
set local role authenticated;
do $$ begin assert (select count(*) from public.businesses) = 0, 'a deactivated manager is locked out'; end $$;
reset role;
select tests.sign_in((:'a'::jsonb ->> 'manager')::uuid);
set local role authenticated;
select tests.expect_error(format('select public.team_members(%L)', :'bid'), 'not allowed');
do $$ begin assert not public.is_business_owner(current_setting('t.bid')::uuid), 'a manager is not an owner'; end $$;
select tests.expect_error(format($$select public.add_team_member(%L, %L, 'x', 'staff')$$, :'bid', :'zola'), 'permission denied');
reset role;
-- Another business's owner can't see this team.
select tests.sign_in(:'b_owner');
set local role authenticated;
select tests.expect_error(format('select public.team_members(%L)', :'bid'), 'not allowed');
reset role;

-- Setup links: only for managers and staff whose login belongs to this business alone.
set local role service_role;
do $$ begin
  assert public.team_link_target(current_setting('t.bid')::uuid, 'SAM@example.test') = current_setting('t.sam')::uuid,
    'Sam belongs only here: a link is allowed';
  assert public.team_link_target(current_setting('t.bid')::uuid, 'owner@salon-a.test') is null, 'never for an owner';
  assert public.team_link_target(current_setting('t.bid')::uuid, 'owner@salon-b.test') is null,
    'never for someone who isn''t in this business';
end $$;
reset role;
-- Salon B's owner is added to Salon A as staff: Salon A's owner still can't get a link for them.
set local role service_role;
select public.add_team_member(:'bid', :'b_owner', 'Borrowed', 'staff');
do $$ begin
  assert public.team_link_target(current_setting('t.bid')::uuid, 'owner@salon-b.test') is null,
    'a login that also belongs to another business gets no link';
end $$;
reset role;
insert into public.platform_admins (user_id, full_name) values (:'sam', 'Sam');
set local role service_role;
do $$ begin
  assert public.team_link_target(current_setting('t.bid')::uuid, 'sam@example.test') is null, 'never for an admin';
end $$;
reset role;

rollback;
