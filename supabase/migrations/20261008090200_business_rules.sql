-- Business rules from the spec, enforced in the database so the portal, the
-- website intake and any future tool all follow them.

-- ---------------------------------------------------------------------------
-- Stamps and audit triggers on every business table
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'industries', 'packages', 'clients', 'contacts', 'leads', 'lead_activities', 'consents',
    'booking_slots', 'assessments', 'quotes', 'quote_line_items', 'projects', 'tasks',
    'care_plans', 'invoices', 'payments', 'tickets', 'documents'
  ] loop
    execute format(
      'create trigger stamp before insert or update on public.%I for each row execute function private.stamp()', t);
    execute format(
      'create trigger audit after insert or update or delete on public.%I for each row execute function private.audit()', t);
  end loop;
end;
$$;

create trigger audit after insert or update or delete on public.stage_changes
  for each row execute function private.audit();

-- ---------------------------------------------------------------------------
-- Growth stage history
-- ---------------------------------------------------------------------------

create function private.log_stage_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and new.growth_stage is null then
    return null;
  end if;
  if tg_op = 'UPDATE' and new.growth_stage is not distinct from old.growth_stage then
    return null;
  end if;
  insert into public.stage_changes (client_id, from_stage, to_stage, changed_by)
  values (new.id, case when tg_op = 'UPDATE' then old.growth_stage end, new.growth_stage, auth.uid());
  return null;
end;
$$;

create trigger log_stage_change after insert or update of growth_stage on public.clients
  for each row execute function private.log_stage_change();

-- Lost prospects start their retention clock when they are marked lost.
create function private.client_status_dates()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'lost' and (tg_op = 'INSERT' or old.status <> 'lost') then
    new.lost_at := now();
  elsif new.status <> 'lost' then
    new.lost_at := null;
  end if;
  if new.status = 'active' and new.start_date is null then
    new.start_date := current_date;
  end if;
  return new;
end;
$$;

create trigger client_status_dates before insert or update of status on public.clients
  for each row execute function private.client_status_dates();

-- ---------------------------------------------------------------------------
-- Leads become clients
-- ---------------------------------------------------------------------------

-- Creates a prospect client (with a primary contact and copies of the lead's
-- active consents) from a lead, ready for its first quote. Runs with the
-- caller's permissions, so row-level security still applies.
create function public.convert_lead_to_client(p_lead_id uuid)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  l public.leads;
  new_client_id uuid;
  new_contact_id uuid;
begin
  select * into l from public.leads where id = p_lead_id for update;
  if not found then
    raise exception 'Lead not found' using errcode = 'PT404';
  end if;
  if l.client_id is not null then
    return l.client_id;
  end if;

  insert into public.clients (business_name, industry_id, growth_stage, status)
  values (coalesce(nullif(l.business_name, ''), l.full_name), l.industry_id, l.stage_needed, 'prospect')
  returning id into new_client_id;

  insert into public.contacts (client_id, full_name, phone, email, is_primary)
  values (new_client_id, l.full_name, l.phone, l.email, true)
  returning id into new_contact_id;

  insert into public.consents (contact_id, purpose, given_at, privacy_policy_version, source, withdrawn_at)
  select new_contact_id, c.purpose, c.given_at, c.privacy_policy_version, c.source, c.withdrawn_at
  from public.consents c
  where c.lead_id = l.id;

  update public.leads set client_id = new_client_id where id = l.id;
  return new_client_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Booking slots and assessments
-- ---------------------------------------------------------------------------

create function private.assessment_slot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.booking_slots;
  old_slot uuid := case when tg_op in ('UPDATE', 'DELETE') then old.booking_slot_id end;
  new_slot uuid := case when tg_op in ('INSERT', 'UPDATE') and new.status = 'booked' then new.booking_slot_id end;
begin
  if old_slot is not null and old_slot is distinct from new_slot then
    update public.booking_slots set status = 'open' where id = old_slot and status = 'booked';
  end if;

  if new_slot is not null and new_slot is distinct from old_slot then
    select * into s from public.booking_slots where id = new_slot for update;
    if s.status <> 'open' then
      raise exception 'That booking slot is no longer available' using errcode = 'PT409';
    end if;
    update public.booking_slots set status = 'booked' where id = new_slot;
    new.scheduled_at := s.starts_at;
    new.location := coalesce(new.location, s.location, case when s.mode = 'online' then 'Online' end);
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger assessment_slot before insert or update of booking_slot_id, status or delete on public.assessments
  for each row execute function private.assessment_slot();

-- ---------------------------------------------------------------------------
-- Quotes
-- ---------------------------------------------------------------------------

create function private.quote_before_insert()
returns trigger
language plpgsql
as $$
begin
  new.number := private.next_number('Q');
  new.status := 'draft';
  new.total := 0;
  new.monthly_total := 0;
  new.approved_by := null;
  new.approved_at := null;
  new.sent_at := null;
  new.decided_at := null;
  new.valid_until := coalesce(new.valid_until, current_date + (private.setting('quote_valid_days'))::int);
  return new;
end;
$$;

create trigger quote_before_insert before insert on public.quotes
  for each row execute function private.quote_before_insert();

create function private.quote_before_update()
returns trigger
language plpgsql
as $$
declare
  allowed text[];
  first_year_value numeric;
  approval_amount numeric := (private.setting('quote_approval_amount'))::numeric;
begin
  -- private.quote_line_items_changed() recalculates totals with this flag set.
  if current_setting('isangotech.recalculating_quote', true) = new.id::text then
    return new;
  end if;

  new.number := old.number;
  new.total := old.total;
  new.monthly_total := old.monthly_total;

  if new.approved_at is not null and old.approved_at is null then
    if not private.is_admin() then
      raise exception 'Only an admin can approve quotes' using errcode = '42501';
    end if;
    new.approved_by := auth.uid();
    new.approved_at := now();
  elsif new.approved_at is null then
    new.approved_by := null;
  else
    new.approved_by := old.approved_by;
    new.approved_at := old.approved_at;
  end if;

  if new.status is distinct from old.status then
    allowed := case old.status
      when 'draft' then array['pending_approval', 'sent']
      when 'pending_approval' then array['draft', 'sent']
      when 'sent' then array['accepted', 'declined', 'expired']
      else array[]::text[]
    end;
    if not new.status = any (allowed) then
      raise exception 'A % quote can''t be changed to %', old.status, new.status using errcode = 'PT400';
    end if;

    if new.status = 'sent' then
      if not exists (select 1 from public.quote_line_items where quote_id = new.id) then
        raise exception 'Add at least one line item before sending the quote' using errcode = 'PT400';
      end if;
      first_year_value := old.total + 12 * old.monthly_total;
      if first_year_value > approval_amount and new.approved_at is null then
        raise exception 'Quotes worth more than R% in the first year need admin approval before they are sent', approval_amount
          using errcode = 'PT400';
      end if;
      new.sent_at := now();
    elsif new.status in ('accepted', 'declined', 'expired') then
      new.decided_at := now();
    end if;
  elsif old.status not in ('draft', 'pending_approval')
    and (new.client_id is distinct from old.client_id or new.valid_until is distinct from old.valid_until) then
    raise exception 'A sent quote can''t be changed. Create a new quote instead.' using errcode = 'PT400';
  end if;

  return new;
end;
$$;

create trigger quote_before_update before update on public.quotes
  for each row execute function private.quote_before_update();

-- Sending a quote moves its lead to "quoted"; accepting it makes the client
-- active and the lead won; declining sends the lead back for follow-up.
create function private.quote_after_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is not distinct from old.status then
    return null;
  end if;

  if new.status = 'sent' then
    update public.leads set pipeline_stage = 'quoted'
    where id = new.lead_id and pipeline_stage in ('new', 'contacted', 'assessment');
  elsif new.status = 'accepted' then
    update public.clients set status = 'active' where id = new.client_id and status in ('prospect', 'lost', 'past');
    update public.leads set pipeline_stage = 'won' where id = new.lead_id;
  elsif new.status = 'declined' then
    update public.leads set pipeline_stage = 'contacted', next_follow_up = coalesce(next_follow_up, current_date + 7)
    where id = new.lead_id and pipeline_stage = 'quoted';
  end if;
  return null;
end;
$$;

create trigger quote_after_update after update of status on public.quotes
  for each row execute function private.quote_after_update();

-- Line items can change only while the quote is a draft or awaiting approval,
-- and any change clears an earlier approval.
create function private.quote_line_items_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  qid uuid := coalesce(new.quote_id, old.quote_id);
  q_status text;
begin
  select status into q_status from public.quotes where id = qid for update;
  if q_status is null then
    -- The quote itself is being deleted (cascade).
    return null;
  end if;
  if q_status not in ('draft', 'pending_approval') then
    raise exception 'A sent quote can''t be changed. Create a new quote instead.' using errcode = 'PT400';
  end if;

  -- Totals are read-only to quote_before_update, so recalculate with its bypass
  -- flag set for this quote only.
  perform set_config('isangotech.recalculating_quote', qid::text, true);
  update public.quotes q set
    total = coalesce((select sum(line_total) from public.quote_line_items where quote_id = qid and billing = 'once_off'), 0),
    monthly_total = coalesce((select sum(line_total) from public.quote_line_items where quote_id = qid and billing = 'monthly'), 0),
    approved_at = null,
    approved_by = null
  where q.id = qid;
  perform set_config('isangotech.recalculating_quote', '', true);
  return null;
end;
$$;

create trigger quote_line_items_changed after insert or update or delete on public.quote_line_items
  for each row execute function private.quote_line_items_changed();

-- ---------------------------------------------------------------------------
-- Projects: go-live sets the next-stage review date
-- ---------------------------------------------------------------------------

create function private.project_go_live()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'live' and (tg_op = 'INSERT' or old.status <> 'live') then
    new.go_live_date := coalesce(new.go_live_date, current_date);
    update public.clients
    set next_stage_review_date = new.go_live_date
      + make_interval(months => (private.setting('next_stage_review_months'))::int)
    where id = new.client_id;
  end if;
  return new;
end;
$$;

create trigger project_go_live before insert or update of status on public.projects
  for each row execute function private.project_go_live();

-- ---------------------------------------------------------------------------
-- Invoices and payments
-- ---------------------------------------------------------------------------

create function private.invoice_before_write()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.number := null;
    new.sent_at := null;
    if new.status <> 'draft' then
      raise exception 'New invoices start as drafts' using errcode = 'PT400';
    end if;
    return new;
  end if;

  new.number := old.number;

  if old.status = 'void' then
    raise exception 'A void invoice can''t be changed' using errcode = 'PT400';
  end if;

  if old.status = 'sent' then
    if new.status = 'draft' then
      raise exception 'A sent invoice can''t go back to draft. Void it instead.' using errcode = 'PT400';
    end if;
    if new.amount is distinct from old.amount or new.client_id is distinct from old.client_id
      or new.issue_date is distinct from old.issue_date then
      raise exception 'A sent invoice can''t be changed. Void it and issue a new one.' using errcode = 'PT400';
    end if;
    if new.status = 'void' and exists (select 1 from public.payments where invoice_id = new.id) then
      raise exception 'This invoice has payments recorded, so it can''t be voided' using errcode = 'PT400';
    end if;
  end if;

  if old.status = 'draft' and new.status = 'sent' then
    new.number := private.next_number('INV');
    new.sent_at := now();
    new.issue_date := coalesce(new.issue_date, current_date);
    new.due_date := coalesce(new.due_date, new.issue_date + (private.setting('invoice_due_days'))::int);
  end if;

  return new;
end;
$$;

create trigger invoice_before_write before insert or update on public.invoices
  for each row execute function private.invoice_before_write();

create function private.payment_check()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  inv public.invoices;
  paid numeric;
begin
  select * into inv from public.invoices where id = new.invoice_id for update;
  if inv.status <> 'sent' then
    raise exception 'Payments can only be recorded against a sent invoice' using errcode = 'PT400';
  end if;
  select coalesce(sum(amount), 0) into paid
  from public.payments
  where invoice_id = new.invoice_id and id <> new.id;
  if paid + new.amount > inv.amount then
    raise exception 'This payment is more than the R% still owed on the invoice', inv.amount - paid
      using errcode = 'PT400';
  end if;
  return new;
end;
$$;

create trigger payment_check before insert or update on public.payments
  for each row execute function private.payment_check();

-- ---------------------------------------------------------------------------
-- Tickets: close and reopen times
-- ---------------------------------------------------------------------------

create function private.ticket_times()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'closed' and (tg_op = 'INSERT' or old.status <> 'closed') then
    new.closed_at := coalesce(new.closed_at, now());
  elsif new.status <> 'closed' then
    new.closed_at := null;
  end if;
  if new.status <> 'open' and new.first_response_at is null then
    new.first_response_at := now();
  end if;
  return new;
end;
$$;

create trigger ticket_times before insert or update of status on public.tickets
  for each row execute function private.ticket_times();

-- ---------------------------------------------------------------------------
-- POPIA retention
-- ---------------------------------------------------------------------------

-- Anonymises leads that never became clients and prospects marked lost, once
-- their retention period (in Settings) has passed. Scheduled in phase 2; until
-- then an admin can run: select private.apply_retention();
create function private.apply_retention()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  lead_months int := (private.setting('lead_retention_months'))::int;
  lost_months int := (private.setting('lost_prospect_retention_months'))::int;
  lead_ids uuid[];
  client_ids uuid[];
begin
  select coalesce(array_agg(id), '{}') into lead_ids
  from public.leads
  where client_id is null
    and anonymised_at is null
    and updated_at < now() - make_interval(months => lead_months);

  delete from public.lead_activities where lead_id = any (lead_ids);
  delete from public.consents where lead_id = any (lead_ids);
  update public.leads set
    full_name = 'Anonymised', business_name = null, phone = null, email = null,
    biggest_pain = null, lost_reason = null, anonymised_at = now()
  where id = any (lead_ids);

  select coalesce(array_agg(id), '{}') into client_ids
  from public.clients
  where status = 'lost'
    and anonymised_at is null
    and lost_at < now() - make_interval(months => lost_months);

  delete from public.contacts where client_id = any (client_ids);
  delete from public.lead_activities where client_id = any (client_ids);
  update public.clients set
    business_name = 'Anonymised', address = null, systems_used = null, notes = null, anonymised_at = now()
  where id = any (client_ids);
  update public.leads set
    full_name = 'Anonymised', business_name = null, phone = null, email = null,
    biggest_pain = null, lost_reason = null, anonymised_at = now()
  where client_id = any (client_ids) and anonymised_at is null;
  delete from public.lead_activities where lead_id in (select id from public.leads where client_id = any (client_ids));
  delete from public.consents where lead_id in (select id from public.leads where client_id = any (client_ids));

  return jsonb_build_object('leads_anonymised', cardinality(lead_ids), 'prospects_anonymised', cardinality(client_ids));
end;
$$;
