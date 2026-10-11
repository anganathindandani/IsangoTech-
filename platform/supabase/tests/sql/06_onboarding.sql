-- Onboarding by IsangoTech's admins: who may, what it creates, and that an
-- admin still can't read a business's customers or chats.
begin;

select tests.seed_business('Salon A') as a \gset
insert into auth.users (email) values ('anga@isangotech.co.za') returning id as admin_id \gset
insert into public.platform_admins (user_id, full_name) values (:'admin_id', 'Anga');
insert into auth.users (email) values ('new.owner@example.test') returning id as new_owner \gset
select set_config('t.new_owner', :'new_owner', false);

-- The edge function (service role) creates the business and its owner in one step.
set local role service_role;
select public.user_id_by_email('NEW.owner@example.test ') = :'new_owner' as found \gset
select public.onboard_business(
  '{"name": "Lindi''s Kitchen", "industry": "caterer", "products": ["assistant"], "whatsapp_phone_number_id": "pn-lindi"}',
  :'new_owner', 'Lindiwe Dube') as bid \gset
reset role;
select set_config('t.bid', :'bid', false);
do $$ begin
  assert (select status from public.businesses where id = current_setting('t.bid')::uuid) = 'onboarding', 'starts in onboarding';
  assert (select role from public.business_members where user_id = current_setting('t.new_owner')::uuid) = 'owner', 'owner added';
  assert (select assistant_enabled from public.business_settings where business_id = current_setting('t.bid')::uuid) = false,
    'the Assistant starts switched off';
end $$;

-- The new owner sees their business straight away.
select tests.sign_in(:'new_owner');
set local role authenticated;
do $$ begin
  assert (select name from public.businesses) = 'Lindi''s Kitchen', 'owner sees their new business';
end $$;
-- Owners can't use the admin functions or the service-only ones.
select tests.expect_error('select public.admin_businesses()', 'not allowed');
select tests.expect_error(format($$select public.admin_update_business(%L, '{"monthly_conversation_allowance": 9999}')$$, :'bid'), 'not allowed');
select tests.expect_error($$select public.onboard_business('{}', gen_random_uuid(), 'x')$$, 'permission denied');
select tests.expect_error($$select public.user_id_by_email('x')$$, 'permission denied');
do $$ begin assert not public.is_platform_admin(), 'an owner is not an admin'; end $$;
reset role;

-- The admin sees every business with its owners, and can change the plan.
select tests.sign_in(:'admin_id');
set local role authenticated;
do $$
declare list jsonb := public.admin_businesses();
begin
  assert public.is_platform_admin(), 'admin recognised';
  assert jsonb_array_length(list) = 2, 'both businesses listed';
  assert (select b -> 'owners' -> 0 ->> 'email' from jsonb_array_elements(list) b where b ->> 'name' = 'Lindi''s Kitchen')
    = 'new.owner@example.test', 'listed with the owner''s email';
  perform public.admin_update_business(current_setting('t.bid')::uuid,
    '{"status": "active", "monthly_conversation_allowance": 500, "whatsapp_display_number": "+27 82 555 0001"}');
  assert (select count(*) from public.businesses) = 0, 'an admin can''t read businesses directly, only through these functions';
  -- An admin isn't a member: no customers, chats or bookings of any business.
  assert (select count(*) from public.customers) = 0, 'admin sees no customers';
  assert (select count(*) from public.messages) = 0, 'admin sees no chats';
  assert (select count(*) from public.bookings) = 0, 'admin sees no bookings';
end $$;
select tests.expect_error(format($$select public.admin_update_business(%L, '{"status": "deleted"}')$$, :'bid'), 'check constraint');
reset role;
do $$ begin
  assert (select monthly_conversation_allowance from public.businesses where id = current_setting('t.bid')::uuid) = 500,
    'allowance changed';
  assert (select status from public.businesses where id = current_setting('t.bid')::uuid) = 'active', 'status changed';
  assert (select products from public.businesses where id = current_setting('t.bid')::uuid) = '{assistant}',
    'fields not sent are left alone';
end $$;

-- With two-step sign-in on, an admin's password alone isn't enough.
select tests.add_authenticator(:'admin_id');
select tests.sign_in(:'admin_id', 'aal1');
set local role authenticated;
select tests.expect_error('select public.admin_businesses()', 'not allowed');
reset role;

-- Nobody can make themselves an admin through the API.
select tests.sign_in(:'new_owner');
set local role authenticated;
select tests.expect_error(format($$insert into public.platform_admins (user_id, full_name) values (%L, 'Me')$$, :'new_owner'),
  'permission denied');
reset role;

rollback;
