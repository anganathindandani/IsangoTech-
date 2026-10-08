-- Who can reach what: anonymous visitors, staff without 2FA, inactive staff,
-- non-admin roles, and an admin signed in with 2FA.
begin;

select tests.create_staff('founder@isangotech.co.za') as admin_id \gset
select tests.create_staff('dev@isangotech.co.za', 'developer') as dev_id \gset
select tests.create_staff('former@isangotech.co.za', 'admin', false) as former_id \gset

insert into public.leads (full_name, phone, source) values ('Existing Lead', '0821234567', 'whatsapp');

-- Anonymous visitors: no access to any table, not even the price list.
set local role anon;
select tests.expect_error('select * from public.leads', 'permission denied');
select tests.expect_error('select * from public.packages', 'permission denied');
select tests.expect_error('select * from public.settings', 'permission denied');
select tests.expect_error($$insert into public.leads (full_name, phone, source) values ('x', '0820000000', 'other')$$, 'permission denied');
select tests.expect_error($$select public.submit_enquiry('{}')$$, 'permission denied');
reset role;

-- Admin who signed in without 2FA: sees nothing and can't write.
select tests.sign_in(:'admin_id', 'aal1');
set local role authenticated;
do $$ begin assert (select count(*) from public.leads) = 0, 'aal1 session must not see leads'; end $$;
select tests.expect_error($$insert into public.leads (full_name, phone, source) values ('x', '0820000000', 'other')$$, 'row-level security');
reset role;

-- Former staff member (inactive): locked out even with 2FA.
select tests.sign_in(:'former_id');
set local role authenticated;
do $$ begin assert (select count(*) from public.leads) = 0, 'inactive admin must not see leads'; end $$;
reset role;

-- Developer role: no Phase 1 rules yet, so no access.
select tests.sign_in(:'dev_id');
set local role authenticated;
do $$ begin assert (select count(*) from public.leads) = 0, 'developer must not see leads in phase 1'; end $$;
do $$
declare n int;
begin
  update public.settings set value = '0' where key = 'quote_approval_amount';
  get diagnostics n = row_count;
  assert n = 0, 'developer must not change settings';
end $$;
reset role;

-- Admin with 2FA: full access.
select tests.sign_in(:'admin_id');
set local role authenticated;
do $$ begin assert (select count(*) from public.leads) = 1, 'admin must see leads'; end $$;
insert into public.leads (full_name, phone, source) values ('Walk-in', '0831112222', 'walk_in');
update public.settings set value = '25000' where key = 'quote_approval_amount';
do $$ begin
  assert (select updated_by from public.settings where key = 'quote_approval_amount') = auth.uid(),
    'settings record who changed them';
end $$;

-- The audit log is readable but can't be changed, even by an admin.
do $$ begin assert (select count(*) from public.audit_log) > 0, 'admin can read the audit log'; end $$;
select tests.expect_error('delete from public.audit_log', 'permission denied');
select tests.expect_error($$update public.audit_log set action = 'insert'$$, 'permission denied');
select tests.expect_error($$insert into public.audit_log (table_name, action) values ('leads', 'insert')$$, 'permission denied');
select tests.expect_error('delete from public.stage_changes', 'permission denied');
reset role;

-- The service role (edge functions) can't edit the audit log either.
set local role service_role;
select tests.expect_error('delete from public.audit_log', 'permission denied');
reset role;

rollback;
