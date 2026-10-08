-- Test helpers. Loaded after the migrations, only in the test database.
create schema tests;
grant usage on schema tests to anon, authenticated, service_role;

-- Creates a login and its team member row; returns the user id.
create function tests.create_staff(p_email text, p_role text default 'admin', p_active boolean default true)
returns uuid language plpgsql as $$
declare uid uuid;
begin
  insert into auth.users (email) values (p_email) returning id into uid;
  insert into public.team_members (id, full_name, role, email, active)
  values (uid, initcap(split_part(p_email, '@', 1)), p_role, p_email, p_active);
  return uid;
end $$;

-- Sets the JWT claims PostgREST would set for a signed-in user. Follow with
-- "set local role authenticated".
create function tests.sign_in(p_user uuid, p_aal text default 'aal2')
returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

-- Runs p_sql and fails unless it raises an error whose message contains p_expected.
create function tests.expect_error(p_sql text, p_expected text)
returns void language plpgsql as $$
begin
  execute p_sql;
  raise exception 'Expected an error containing "%" from: %', p_expected, p_sql;
exception when others then
  if sqlerrm like 'Expected an error containing%' then raise; end if;
  if position(lower(p_expected) in lower(sqlerrm)) = 0 then
    raise exception 'Expected an error containing "%" but got "%" from: %', p_expected, sqlerrm, p_sql;
  end if;
end $$;

grant execute on all functions in schema tests to anon, authenticated, service_role;
