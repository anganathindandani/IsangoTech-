-- Audit trail, record stamps, growth-stage history, tickets, go-live,
-- booking slots, exports and POPIA retention.
begin;

select tests.create_staff('founder@isangotech.co.za') as admin_id \gset
select set_config('vars.admin_id', :'admin_id', true);
select tests.sign_in(:'admin_id');
set local role authenticated;

-- Stamps can't be spoofed.
insert into public.clients (business_name, created_by, created_at, growth_stage)
values ('Kei Mouth Lodge', gen_random_uuid(), '2000-01-01', 1)
returning id as client_id \gset
select set_config('vars.client_id', :'client_id', true);
do $$
declare c public.clients;
begin
  select * into c from public.clients where id = current_setting('vars.client_id')::uuid;
  assert c.created_by = current_setting('vars.admin_id')::uuid, 'created_by is the signed-in user';
  assert c.created_at > now() - interval '1 minute', 'created_at is now';
end $$;

-- Audit log records inserts, changed fields (not values) and deletes.
update public.clients set address = '1 Beach Road', notes = 'Sea views' where id = :'client_id';
update public.clients set address = '1 Beach Road' where id = :'client_id';  -- no real change
do $$
declare cid text := current_setting('vars.client_id');
begin
  assert (select count(*) from public.audit_log where table_name = 'clients' and record_id = cid and action = 'insert') = 1, 'insert logged';
  assert (select changed_fields from public.audit_log where table_name = 'clients' and record_id = cid and action = 'update')
    = array['address', 'notes'], 'only changed fields are logged';
  assert (select count(*) from public.audit_log where table_name = 'clients' and record_id = cid and action = 'update') = 1,
    'updates that change nothing are not logged';
  assert (select changed_by from public.audit_log where table_name = 'clients' and record_id = cid and action = 'update')
    = current_setting('vars.admin_id')::uuid, 'who made the change';
  assert not exists (select 1 from public.audit_log where changed_fields::text like '%Beach%'), 'values are not stored';
end $$;

-- Growth stage history.
update public.clients set growth_stage = 3 where id = :'client_id';
do $$ begin
  assert (select array_agg(to_stage order by changed_at, to_stage) from public.stage_changes
          where client_id = current_setting('vars.client_id')::uuid) = array[1, 3]::smallint[], 'stage history';
  assert (select from_stage from public.stage_changes
          where client_id = current_setting('vars.client_id')::uuid and to_stage = 3) = 1, 'from stage recorded';
end $$;

-- Marking a prospect lost starts its retention clock.
insert into public.clients (business_name, status) values ('Gone Quiet Salon', 'prospect') returning id as lost_id \gset
update public.clients set status = 'lost' where id = :'lost_id';
select set_config('vars.lost_id', :'lost_id', true);
do $$ begin
  assert (select lost_at from public.clients where id = current_setting('vars.lost_id')::uuid) is not null, 'lost_at set';
end $$;

-- Go-live sets the next-stage review date three months later.
insert into public.projects (client_id, name, type) values (:'client_id', 'Lodge website', 'website') returning id as project_id \gset
update public.projects set status = 'live' where id = :'project_id';
do $$ begin
  assert (select next_stage_review_date from public.clients where id = current_setting('vars.client_id')::uuid)
    = current_date + interval '3 months', 'next-stage review date';
end $$;

-- Ticket first-response and close times.
insert into public.tickets (client_id, subject, channel) values (:'client_id', 'Booking form down', 'whatsapp') returning id as ticket_id \gset
select set_config('vars.ticket_id', :'ticket_id', true);
update public.tickets set status = 'in_progress' where id = :'ticket_id';
update public.tickets set status = 'closed' where id = :'ticket_id';
do $$
declare t public.tickets;
begin
  select * into t from public.tickets where id = current_setting('vars.ticket_id')::uuid;
  assert t.first_response_at is not null and t.closed_at is not null, 'response and close times';
end $$;
update public.tickets set status = 'open' where id = :'ticket_id';
do $$ begin
  assert (select closed_at from public.tickets where id = current_setting('vars.ticket_id')::uuid) is null, 'reopening clears closed time';
end $$;

-- Booking slots can't overlap; cancelling an assessment reopens its slot.
insert into public.booking_slots (starts_at, ends_at) values ('2030-03-01 09:00+02', '2030-03-01 10:00+02') returning id as slot_id \gset
select set_config('vars.slot_id', :'slot_id', true);
select tests.expect_error($$insert into public.booking_slots (starts_at, ends_at) values ('2030-03-01 09:30+02', '2030-03-01 10:30+02')$$, 'booking_slots_no_overlap');
insert into public.assessments (client_id, booking_slot_id) values (:'client_id', :'slot_id') returning id as assessment_id \gset
select tests.expect_error(format($$insert into public.assessments (client_id, booking_slot_id) values ('%s', '%s')$$, :'client_id', :'slot_id'), 'no longer available');
update public.assessments set status = 'cancelled' where id = :'assessment_id';
do $$ begin
  assert (select status from public.booking_slots where id = current_setting('vars.slot_id')::uuid) = 'open', 'slot reopened';
end $$;
insert into public.assessments (client_id, booking_slot_id) values (:'client_id', :'slot_id');
do $$ begin
  assert (select status from public.booking_slots where id = current_setting('vars.slot_id')::uuid) = 'booked', 'reopened slot can be rebooked';
end $$;

-- Exports are logged.
select public.log_export('clients', array[:'client_id']);
do $$ begin
  assert exists (select 1 from public.audit_log where action = 'export' and record_id = current_setting('vars.client_id')), 'export logged';
end $$;

reset role;

-- POPIA retention: old unconverted leads and long-lost prospects are anonymised.
insert into public.leads (full_name, phone, email, source, biggest_pain)
values ('Old Enquiry', '0820000001', 'old@example.co.za', 'website_form', 'Private details')
returning id as old_lead \gset
insert into public.consents (lead_id, purpose, privacy_policy_version, source) values (:'old_lead', 'enquiry', '1', 'form');
insert into public.leads (full_name, phone, source) values ('Recent Enquiry', '0820000002', 'whatsapp');
insert into public.contacts (client_id, full_name, phone) values (:'lost_id', 'Lost Contact', '0820000003');
alter table public.leads disable trigger stamp;
alter table public.clients disable trigger stamp;
update public.leads set updated_at = now() - interval '13 months' where id = :'old_lead';
update public.clients set lost_at = now() - interval '13 months' where id = :'lost_id';
alter table public.leads enable trigger stamp;
alter table public.clients enable trigger stamp;

select private.apply_retention() as result \gset
select set_config('vars.old_lead', :'old_lead', true);
do $$
declare l public.leads;
begin
  select * into l from public.leads where id = current_setting('vars.old_lead')::uuid;
  assert l.full_name = 'Anonymised' and l.phone is null and l.email is null and l.biggest_pain is null, 'old lead anonymised';
  assert not exists (select 1 from public.consents where lead_id = l.id), 'its consents removed';
  assert (select phone from public.leads where full_name = 'Recent Enquiry') is not null, 'recent lead kept';
  assert (select business_name from public.clients where id = current_setting('vars.lost_id')::uuid) = 'Anonymised', 'lost prospect anonymised';
  assert not exists (select 1 from public.contacts where client_id = current_setting('vars.lost_id')::uuid), 'its contacts removed';
  assert (select business_name from public.clients where id = current_setting('vars.client_id')::uuid) = 'Kei Mouth Lodge', 'active client kept';
end $$;

rollback;
