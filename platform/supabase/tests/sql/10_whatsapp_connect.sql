-- Connecting a WhatsApp number: saved for the right business, never twice,
-- and its token is readable only by the edge functions.
begin;

select tests.seed_business('Salon A') as a \gset
select tests.seed_business('Salon B') as b \gset
select (:'a'::jsonb ->> 'business') as a_id, (:'b'::jsonb ->> 'business') as b_id, (:'a'::jsonb ->> 'owner') as a_owner \gset
select set_config('t.a', :'a_id', false), set_config('t.b', :'b_id', false);

-- The connect-whatsapp function saves the number and token.
set local role service_role;
select public.connect_whatsapp(:'a_id', ' pn-new-a ', '+27 82 555 0100', 'waba-1', repeat('t', 40), true);
do $$ begin
  assert (select whatsapp_phone_number_id = 'pn-new-a' and whatsapp_display_number = '+27 82 555 0100'
            and whatsapp_waba_id = 'waba-1' and whatsapp_coexistence and whatsapp_connected_at is not null
          from public.businesses where id = current_setting('t.a')::uuid), 'number, account and coexistence saved';
  assert public.whatsapp_access_token('pn-new-a') = repeat('t', 40), 'the business''s own token is found by its number';
  assert public.whatsapp_access_token('wa-salon-b') is null, 'a business connected by hand uses the platform token';
  assert public.whatsapp_access_token('pn-nobody') is null, 'an unknown number has no token';
end $$;

-- Reconnecting replaces the token; the same number can't go to a second business.
select public.connect_whatsapp(:'a_id', 'pn-new-a', '+27 82 555 0100', 'waba-1', repeat('u', 40), true);
do $$ begin assert public.whatsapp_access_token('pn-new-a') = repeat('u', 40), 'a new token replaces the old'; end $$;
select tests.expect_error(format($$select public.connect_whatsapp(%L, 'pn-new-a', '', 'waba-2', repeat('v', 40), false)$$, :'b_id'),
  'already connected to another business');
select tests.expect_error(format($$select public.connect_whatsapp(%L, 'pn-x', '', 'waba-2', 'short', false)$$, :'b_id'),
  'check constraint');
reset role;

-- Owners and managers can't read tokens or connect numbers themselves.
select tests.sign_in(:'a_owner'::uuid);
set local role authenticated;
select tests.expect_error('select access_token from private.whatsapp_credentials', 'permission denied');
select tests.expect_error($$select public.whatsapp_access_token('pn-new-a')$$, 'permission denied');
select tests.expect_error(format($$select public.connect_whatsapp(%L, 'pn-y', '', 'w', repeat('t', 40), false)$$, :'a_id'),
  'permission denied');
-- They do see that the number is connected.
do $$ begin
  assert (select whatsapp_display_number from public.businesses where id = current_setting('t.a')::uuid) = '+27 82 555 0100',
    'the owner sees the connected number';
end $$;
reset role;

-- Edge functions reach tokens only through the function, not the table.
set local role service_role;
select tests.expect_error('select access_token from private.whatsapp_credentials', 'permission denied');
reset role;

-- Deleting a business deletes its token.
delete from public.businesses where id = :'a_id';
do $$ begin assert not exists (select 1 from private.whatsapp_credentials), 'token gone with the business'; end $$;

rollback;
