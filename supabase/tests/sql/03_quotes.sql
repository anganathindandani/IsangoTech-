-- Lead → prospect client → quote → approval → sent → accepted or declined.
begin;

select tests.create_staff('founder@isangotech.co.za') as admin_id \gset
select tests.sign_in(:'admin_id');
set local role authenticated;

insert into public.packages (name, growth_stage, price, billing) values
  ('Starter website', 1, 4500, 'once_off'),
  ('Core Business', 3, 25000, 'once_off'),
  ('Care plan', null, 650, 'monthly');

insert into public.leads (full_name, business_name, phone, source, stage_needed)
values ('Lindiwe Dlamini', 'Lindi Caters', '0829998888', 'whatsapp', 1)
returning id as lead_id \gset
select set_config('vars.lead_id', :'lead_id', true);
insert into public.consents (lead_id, purpose, privacy_policy_version, source)
values (:'lead_id', 'whatsapp', '1', 'whatsapp');

-- Converting the lead creates a prospect with a primary contact and copies consent.
select public.convert_lead_to_client(:'lead_id') as client_id \gset
select set_config('vars.client_id', :'client_id', true);
do $$
declare cid uuid := current_setting('vars.client_id')::uuid;
begin
  assert (select status from public.clients where id = cid) = 'prospect', 'new client is a prospect';
  assert (select business_name from public.clients where id = cid) = 'Lindi Caters', 'business name copied';
  assert (select growth_stage from public.clients where id = cid) = 1, 'growth stage taken from stage needed';
  assert (select count(*) from public.contacts where client_id = cid and is_primary) = 1, 'primary contact created';
  assert (select count(*) from public.consents c join public.contacts k on k.id = c.contact_id where k.client_id = cid and c.purpose = 'whatsapp') = 1,
    'WhatsApp consent follows the person to the contact';
  assert public.convert_lead_to_client(current_setting('vars.lead_id')::uuid) = cid, 'converting twice returns the same client';
  assert (select count(*) from public.stage_changes where client_id = cid) = 1, 'first growth stage is recorded';
end $$;

-- Small quote: numbered, no approval needed.
insert into public.quotes (client_id, lead_id, number, status, total)
values (:'client_id', :'lead_id', 'HACKED', 'accepted', 1)
returning id as small_quote, number as small_number \gset
select set_config('vars.small_quote', :'small_quote', true);
select set_config('vars.small_number', :'small_number', true);
do $$ begin
  assert current_setting('vars.small_number') ~ '^Q-\d{4}-0001$', 'quote number assigned by the database';
  assert (select status from public.quotes where id = current_setting('vars.small_quote')::uuid) = 'draft', 'new quotes start as drafts';
  assert (select total from public.quotes where id = current_setting('vars.small_quote')::uuid) = 0, 'total can''t be set by hand';
  assert (select valid_until from public.quotes where id = current_setting('vars.small_quote')::uuid) = current_date + 30, 'default validity';
end $$;

select tests.expect_error(format($$update public.quotes set status = 'sent' where id = '%s'$$, :'small_quote'), 'at least one line item');

insert into public.quote_line_items (quote_id, package_id, description, quantity, unit_price, billing)
select :'small_quote', id, name, 1, price, billing from public.packages where name in ('Starter website', 'Care plan');
do $$ begin
  assert (select total from public.quotes where id = current_setting('vars.small_quote')::uuid) = 4500, 'once-off total';
  assert (select monthly_total from public.quotes where id = current_setting('vars.small_quote')::uuid) = 650, 'monthly total';
end $$;

update public.quotes set status = 'sent' where id = :'small_quote';
do $$ begin
  assert (select sent_at from public.quotes where id = current_setting('vars.small_quote')::uuid) is not null, 'sent time recorded';
  assert (select pipeline_stage from public.leads where id = current_setting('vars.lead_id')::uuid) = 'quoted', 'lead moves to quoted';
end $$;

-- Sent quotes are locked.
select tests.expect_error(format($$update public.quote_line_items set unit_price = 1 where quote_id = '%s'$$, :'small_quote'), 'can''t be changed');
select tests.expect_error(format($$delete from public.quote_line_items where quote_id = '%s'$$, :'small_quote'), 'can''t be changed');
select tests.expect_error(format($$insert into public.quote_line_items (quote_id, description, unit_price) values ('%s', 'Extra', 100)$$, :'small_quote'), 'can''t be changed');
select tests.expect_error(format($$update public.quotes set status = 'draft' where id = '%s'$$, :'small_quote'), 'can''t be changed to draft');
select tests.expect_error(format($$update public.quotes set valid_until = current_date + 90 where id = '%s'$$, :'small_quote'), 'can''t be changed');

-- Declining sends the lead back to the pipeline for follow-up.
update public.quotes set status = 'declined' where id = :'small_quote';
do $$ begin
  assert (select pipeline_stage from public.leads where id = current_setting('vars.lead_id')::uuid) = 'contacted', 'lead back in the pipeline';
  assert (select next_follow_up from public.leads where id = current_setting('vars.lead_id')::uuid) = current_date + 7, 'follow-up set';
  assert (select status from public.clients where id = current_setting('vars.client_id')::uuid) = 'prospect', 'still a prospect';
end $$;
select tests.expect_error(format($$update public.quotes set status = 'accepted' where id = '%s'$$, :'small_quote'), 'can''t be changed to accepted');

-- Large quote: first-year value 25 000 + 12 × 650 = 32 800, above the 20 000 threshold.
insert into public.quotes (client_id, lead_id) values (:'client_id', :'lead_id') returning id as big_quote \gset
select set_config('vars.big_quote', :'big_quote', true);
insert into public.quote_line_items (quote_id, package_id, description, quantity, unit_price, billing)
select :'big_quote', id, name, 1, price, billing from public.packages where name in ('Core Business', 'Care plan');

select tests.expect_error(format($$update public.quotes set status = 'sent' where id = '%s'$$, :'big_quote'), 'need admin approval');
update public.quotes set status = 'pending_approval' where id = :'big_quote';

-- Approval stamps who and when; editing a line afterwards clears it.
update public.quotes set approved_at = '2000-01-01', approved_by = null where id = :'big_quote';
do $$ begin
  assert (select approved_by from public.quotes where id = current_setting('vars.big_quote')::uuid) = auth.uid(), 'approver recorded';
  assert (select approved_at from public.quotes where id = current_setting('vars.big_quote')::uuid) > now() - interval '1 minute', 'approval time is now';
end $$;
update public.quote_line_items set quantity = 2 where quote_id = :'big_quote' and billing = 'once_off';
do $$ begin
  assert (select approved_at from public.quotes where id = current_setting('vars.big_quote')::uuid) is null, 'edit clears approval';
  assert (select total from public.quotes where id = current_setting('vars.big_quote')::uuid) = 50000, 'total recalculated';
  assert (select status from public.quotes where id = current_setting('vars.big_quote')::uuid) = 'pending_approval', 'still pending approval';
end $$;
select tests.expect_error(format($$update public.quotes set status = 'sent' where id = '%s'$$, :'big_quote'), 'need admin approval');

update public.quotes set approved_at = now() where id = :'big_quote';
update public.quotes set status = 'sent' where id = :'big_quote';
update public.quotes set status = 'accepted' where id = :'big_quote';
do $$ begin
  assert (select status from public.clients where id = current_setting('vars.client_id')::uuid) = 'active', 'accepted quote makes the client active';
  assert (select start_date from public.clients where id = current_setting('vars.client_id')::uuid) = current_date, 'start date set';
  assert (select pipeline_stage from public.leads where id = current_setting('vars.lead_id')::uuid) = 'won', 'lead won';
  assert (select decided_at from public.quotes where id = current_setting('vars.big_quote')::uuid) is not null, 'decision time recorded';
end $$;

reset role;
rollback;
