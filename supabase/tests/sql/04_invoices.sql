-- Invoices: numbering on send, locking, partial payments, overdue and void.
begin;

select tests.create_staff('founder@isangotech.co.za') as admin_id \gset
select tests.sign_in(:'admin_id');
set local role authenticated;

insert into public.clients (business_name, status) values ('Ubuntu Eats', 'active') returning id as client_id \gset

select tests.expect_error(format($$insert into public.invoices (client_id, type, amount, status) values ('%s', 'setup', 100, 'sent')$$, :'client_id'), 'start as drafts');

insert into public.invoices (client_id, type, amount, number) values (:'client_id', 'setup', 4500, 'INV-FAKE')
returning id as inv_id \gset
select set_config('vars.inv_id', :'inv_id', true);

do $$ begin
  assert (select number from public.invoices where id = current_setting('vars.inv_id')::uuid) is null, 'drafts have no number';
end $$;

select tests.expect_error(format($$insert into public.payments (invoice_id, amount, method) values ('%s', 100, 'eft')$$, :'inv_id'), 'sent invoice');

-- A draft can be deleted without leaving a gap in the numbering.
insert into public.invoices (client_id, type, amount) values (:'client_id', 'custom', 1) returning id as draft_id \gset
delete from public.invoices where id = :'draft_id';

update public.invoices set status = 'sent', issue_date = current_date - 10 where id = :'inv_id';
do $$
declare i public.invoices;
begin
  select * into i from public.invoices where id = current_setting('vars.inv_id')::uuid;
  assert i.number ~ '^INV-\d{4}-0001$', 'first invoice number is 0001';
  assert i.due_date = i.issue_date + 7, 'due date from the default terms';
  assert i.sent_at is not null, 'sent time recorded';
end $$;

select tests.expect_error(format($$update public.invoices set amount = 1 where id = '%s'$$, :'inv_id'), 'can''t be changed');
select tests.expect_error(format($$update public.invoices set status = 'draft' where id = '%s'$$, :'inv_id'), 'void it instead');
do $$
declare n text;
begin
  update public.invoices set number = 'INV-X' where id = current_setting('vars.inv_id')::uuid returning number into n;
  assert n <> 'INV-X', 'invoice numbers can''t be changed';
end $$;

-- Unpaid and overdue.
do $$ begin
  assert (select payment_status from public.invoice_summaries where id = current_setting('vars.inv_id')::uuid) = 'unpaid', 'unpaid';
  assert (select is_overdue from public.invoice_summaries where id = current_setting('vars.inv_id')::uuid), 'overdue after the due date';
end $$;

-- Partial, then full payment; overpayment refused.
insert into public.payments (invoice_id, amount, method, reference) values (:'inv_id', 2000, 'eft', 'Ubuntu deposit');
do $$ begin
  assert (select payment_status from public.invoice_summaries where id = current_setting('vars.inv_id')::uuid) = 'part_paid', 'part paid';
  assert (select balance from public.invoice_summaries where id = current_setting('vars.inv_id')::uuid) = 2500, 'balance';
end $$;
select tests.expect_error(format($$insert into public.payments (invoice_id, amount, method) values ('%s', 3000, 'eft')$$, :'inv_id'), 'more than the R2500');
insert into public.payments (invoice_id, amount, method) values (:'inv_id', 2500, 'eft');
do $$ begin
  assert (select payment_status from public.invoice_summaries where id = current_setting('vars.inv_id')::uuid) = 'paid', 'paid';
  assert not (select is_overdue from public.invoice_summaries where id = current_setting('vars.inv_id')::uuid), 'paid invoices are not overdue';
end $$;

-- Invoices with payments can't be voided; one without can, and is then frozen.
select tests.expect_error(format($$update public.invoices set status = 'void' where id = '%s'$$, :'inv_id'), 'payments recorded');
insert into public.invoices (client_id, type, amount) values (:'client_id', 'custom', 300) returning id as second_id \gset
update public.invoices set status = 'sent' where id = :'second_id';
select set_config('vars.second_id', :'second_id', true);
do $$ begin
  assert (select number from public.invoices where id = current_setting('vars.second_id')::uuid) ~ '-0002$', 'numbers are sequential';
end $$;
update public.invoices set status = 'void' where id = :'second_id';
select tests.expect_error(format($$update public.invoices set status = 'sent' where id = '%s'$$, :'second_id'), 'void invoice');

-- A care plan can't be billed twice for the same month.
insert into public.care_plans (client_id, monthly_fee, start_date) values (:'client_id', 650, current_date) returning id as plan_id \gset
insert into public.invoices (client_id, care_plan_id, type, amount, period_start) values (:'client_id', :'plan_id', 'monthly', 650, date_trunc('month', current_date));
select tests.expect_error(format($$insert into public.invoices (client_id, care_plan_id, type, amount, period_start) values ('%s', '%s', 'monthly', 650, date_trunc('month', current_date))$$, :'client_id', :'plan_id'), 'duplicate key');

reset role;
rollback;
