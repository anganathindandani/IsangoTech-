-- The promise the whole platform rests on: no one in one business can read,
-- change or delete another business's records, whatever their role.
begin;

select tests.seed_business('Salon A') as a \gset
select tests.seed_business('Salon B') as b \gset
select (:'a'::jsonb ->> 'business') as a_id, (:'b'::jsonb ->> 'business') as b_id \gset

-- One column per table that a signed-in person is allowed to update.
create temp table editable (tbl text, col text);
insert into editable values
  ('businesses', 'name'), ('business_members', 'full_name'), ('business_settings', 'tone'),
  ('staff', 'full_name'), ('services', 'name'), ('service_staff', 'staff_id'),
  ('knowledge_items', 'answer'), ('customers', 'notes'), ('bookings', 'notes'),
  ('conversations', 'handled_by'), ('unanswered_questions', 'status');
grant select on editable to authenticated;

create temp table every_table (tbl text, key text);
insert into every_table
select table_name, case when table_name = 'businesses' then 'id' else 'business_id' end
from information_schema.columns
where table_schema = 'public' and column_name = 'business_id'
union select 'businesses', 'id';
grant select on every_table to authenticated;

-- Sanity check: every client table is covered, and RLS is on for all of them.
do $$
begin
  assert (select count(*) from every_table) = 14, 'expected 14 client tables, found ' || (select count(*) from every_table);
  assert not exists (
    select 1 from every_table t join pg_class c on c.relname = t.tbl and c.relnamespace = 'public'::regnamespace
    where not c.relrowsecurity
  ), 'every client table must have row-level security on';
end $$;

-- Each role in business A tries every table in business B.
create function pg_temp.cannot_reach(p_user uuid, p_other uuid) returns void language plpgsql as $$
declare
  r record;
  n bigint;
begin
  perform tests.sign_in(p_user);
  set local role authenticated;
  for r in select t.tbl, t.key, e.col from every_table t left join editable e on e.tbl = t.tbl loop
    execute format('select count(*) from public.%I where %I = $1', r.tbl, r.key) into n using p_other;
    assert n = 0, format('%s can read %s rows of the other business', p_user, r.tbl);

    if r.col is not null then
      execute format('update public.%I set %I = %I where %I = $1', r.tbl, r.col, r.col, r.key) using p_other;
      get diagnostics n = row_count;
      assert n = 0, format('%s can update %s rows of the other business', p_user, r.tbl);
    end if;

    begin
      execute format('delete from public.%I where %I = $1', r.tbl, r.key) using p_other;
      get diagnostics n = row_count;
      assert n = 0, format('%s can delete %s rows of the other business', p_user, r.tbl);
    exception when insufficient_privilege then null;
    end;
  end loop;
  reset role;
end $$;

select pg_temp.cannot_reach((:'a'::jsonb ->> 'owner')::uuid, :'b_id');
select pg_temp.cannot_reach((:'a'::jsonb ->> 'manager')::uuid, :'b_id');
select pg_temp.cannot_reach((:'a'::jsonb ->> 'staff_user')::uuid, :'b_id');
select pg_temp.cannot_reach((:'b'::jsonb ->> 'owner')::uuid, :'a_id');

-- Nothing was changed or removed in either business.
do $$ begin
  assert (select count(*) from public.bookings) = 2, 'both bookings still exist';
  assert (select count(*) from public.customers) = 2, 'both customers still exist';
  assert (select count(*) from public.messages) = 2, 'both messages still exist';
end $$;

-- Writing into the other business is refused, both directly and by pointing
-- at the other business's customer, service or staff member.
select tests.sign_in((:'a'::jsonb ->> 'owner')::uuid);
set local role authenticated;
select tests.expect_error(format(
  $$insert into public.customers (business_id, full_name) values (%L, 'Spy')$$, :'b_id'), 'row-level security');
select tests.expect_error(format(
  $$insert into public.services (business_id, name) values (%L, 'Spy')$$, :'b_id'), 'row-level security');
select tests.expect_error(format(
  $$insert into public.business_members (business_id, user_id, full_name, role) values (%L, %L, 'Me', 'owner')$$,
  :'b_id', :'a'::jsonb ->> 'owner'), 'row-level security');
-- A booking in A for B's customer: the database refuses the link.
select tests.expect_error(format(
  $$insert into public.bookings (business_id, customer_id, starts_at, ends_at, source)
    values (%L, %L, now() + interval '3 days', now() + interval '3 days 1 hour', 'portal')$$,
  :'a_id', :'b'::jsonb ->> 'customer'), 'foreign key');
-- A's booking with B's staff member or service: also refused.
select tests.expect_error(format(
  $$update public.bookings set staff_id = %L where id = %L$$, :'b'::jsonb ->> 'staff_id', :'a'::jsonb ->> 'booking'),
  'foreign key');
select tests.expect_error(format(
  $$update public.bookings set service_id = %L where id = %L$$, :'b'::jsonb ->> 'service', :'a'::jsonb ->> 'booking'),
  'foreign key');
-- Moving a record into the other business isn't possible either.
select tests.expect_error(format(
  $$update public.customers set business_id = %L where id = %L$$, :'b_id', :'a'::jsonb ->> 'customer'),
  'permission denied');
reset role;

-- Anonymous callers get nothing at all.
set local role anon;
select tests.expect_error('select * from public.businesses', 'permission denied');
select tests.expect_error('select * from public.customers', 'permission denied');
select tests.expect_error('select * from public.messages', 'permission denied');
select tests.expect_error(format('select * from public.usage_this_month(%L)', :'a_id'), 'permission denied');
reset role;

-- Someone signed in who belongs to no business sees nothing.
insert into auth.users (email) values ('stranger@example.test') returning id as stranger \gset
select tests.sign_in(:'stranger');
set local role authenticated;
do $$
declare r record; n bigint;
begin
  for r in select tbl from every_table loop
    execute format('select count(*) from public.%I', r.tbl) into n;
    assert n = 0, 'a stranger can read ' || r.tbl;
  end loop;
end $$;
reset role;

rollback;
