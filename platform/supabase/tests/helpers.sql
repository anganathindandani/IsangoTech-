-- Test helpers. Loaded after the migrations, only in the test database.
create schema tests;
grant usage on schema tests to anon, authenticated, service_role;

-- Creates a business the way IsangoTech onboards one; returns its id.
create function tests.create_business(p_name text, p_industry text default 'salon')
returns uuid language sql as $$
  insert into public.businesses (name, industry, products, whatsapp_phone_number_id)
  values (p_name, p_industry, array['assistant', 'portal'], 'wa-' || lower(replace(p_name, ' ', '-')))
  returning id;
$$;

-- Creates a login and makes it a member of a business; returns the user id.
create function tests.create_member(p_business uuid, p_email text, p_role text default 'owner', p_active boolean default true)
returns uuid language plpgsql as $$
declare uid uuid;
begin
  insert into auth.users (email) values (p_email) returning id into uid;
  insert into public.business_members (business_id, user_id, full_name, role, active)
  values (p_business, uid, initcap(split_part(p_email, '@', 1)), p_role, p_active);
  return uid;
end $$;

-- Turns on two-step sign-in for a user (a verified authenticator app).
create function tests.add_authenticator(p_user uuid)
returns void language sql as $$
  insert into auth.mfa_factors (user_id, status) values (p_user, 'verified');
$$;

-- Sets the JWT claims PostgREST would set for a signed-in user. Follow with
-- "set local role authenticated".
create function tests.sign_in(p_user uuid, p_aal text default 'aal1')
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

-- Number of rows p_sql affects (for updates and deletes RLS silently skips).
create function tests.affected(p_sql text)
returns bigint language plpgsql as $$
declare n bigint;
begin
  execute p_sql;
  get diagnostics n = row_count;
  return n;
end $$;

-- A business with one of everything, as IsangoTech's systems would create it.
-- Returns the ids: business, owner, manager, staff_user, staff_id, service,
-- customer, booking, conversation, knowledge_item.
create function tests.seed_business(p_name text)
returns jsonb language plpgsql as $$
declare
  key text := lower(replace(p_name, ' ', '-'));
  ids jsonb;
  bid uuid;
  staff_user uuid;
  staff_id uuid;
  service_id uuid;
  customer_id uuid;
  booking_id uuid;
  conversation_id uuid;
  item_id uuid;
begin
  bid := tests.create_business(p_name);
  ids := jsonb_build_object(
    'business', bid,
    'owner', tests.create_member(bid, 'owner@' || key || '.test', 'owner'),
    'manager', tests.create_member(bid, 'manager@' || key || '.test', 'manager'));
  staff_user := tests.create_member(bid, 'stylist@' || key || '.test', 'staff');
  insert into public.staff (business_id, full_name, user_id) values (bid, 'Stylist', staff_user) returning id into staff_id;
  insert into public.services (business_id, name, price, duration_minutes) values (bid, 'Braids', 450, 120) returning id into service_id;
  insert into public.service_staff (business_id, service_id, staff_id) values (bid, service_id, staff_id);
  insert into public.knowledge_items (business_id, question, answer) values (bid, 'Parking?', 'Free parking at the back.') returning id into item_id;
  insert into public.customers (business_id, full_name, whatsapp_number, whatsapp_opt_in)
  values (bid, 'Thandi', '2782' || lpad((abs(hashtext(key)) % 10000000)::text, 7, '0'), true) returning id into customer_id;
  insert into public.bookings (business_id, customer_id, service_id, staff_id, starts_at, ends_at, source)
  values (bid, customer_id, service_id, staff_id, now() + interval '1 day', now() + interval '1 day 2 hours', 'whatsapp')
  returning id into booking_id;
  insert into public.conversations (business_id, customer_id) values (bid, customer_id) returning id into conversation_id;
  insert into public.messages (business_id, conversation_id, direction, sender, body, whatsapp_message_id)
  values (bid, conversation_id, 'inbound', 'customer', 'Hi, braids on Saturday?', 'wamid-' || key);
  insert into public.unanswered_questions (business_id, conversation_id, question) values (bid, conversation_id, 'Do you do nails?');
  insert into public.usage_events (business_id, kind, conversation_id, cost_zar) values (bid, 'whatsapp_conversation', conversation_id, 0);
  insert into public.usage_events (business_id, kind, conversation_id, model, input_tokens, output_tokens, cost_zar)
  values (bid, 'ai_call', conversation_id, 'claude-haiku-5-5', 5000, 250, 0.04);
  return ids || jsonb_build_object(
    'staff_user', staff_user, 'staff_id', staff_id, 'service', service_id, 'customer', customer_id,
    'booking', booking_id, 'conversation', conversation_id, 'knowledge_item', item_id);
end $$;

grant execute on all functions in schema tests to anon, authenticated, service_role;
