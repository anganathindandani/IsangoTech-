-- Row-level security, grants, website intake and file storage.
--
-- Phase 1: only an active admin, signed in with 2FA, can reach any record.
-- When the first developer, sales or finance hire is close, add that role's
-- policies from the permissions table in the spec, each in its own migration.

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'team_members', 'settings', 'industries', 'packages', 'clients', 'contacts', 'leads',
    'lead_activities', 'consents', 'booking_slots', 'assessments', 'quotes', 'quote_line_items',
    'projects', 'tasks', 'care_plans', 'invoices', 'payments', 'tickets', 'documents'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "Admins have full access" on public.%I for all to authenticated '
      'using ((select private.is_admin())) with check ((select private.is_admin()))', t);
  end loop;
end;
$$;

-- Written only by triggers; admins can read them, nobody can change them.
alter table public.audit_log enable row level security;
create policy "Admins can read the audit log" on public.audit_log
  for select to authenticated using ((select private.is_admin()));

alter table public.stage_changes enable row level security;
create policy "Admins can read stage changes" on public.stage_changes
  for select to authenticated using ((select private.is_admin()));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- The website never reads portal data directly; it goes through the edge
-- functions below. Anonymous visitors get nothing.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon, public;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on functions from anon, public;

revoke insert, update, delete, truncate on public.audit_log, public.stage_changes from authenticated, service_role;

-- Helpers that policies and triggers call while running as the signed-in user.
revoke all on all functions in schema private from public;
grant execute on function private.is_admin(), private.setting(text), private.next_number(text)
  to authenticated, service_role;

grant execute on function public.convert_lead_to_client(uuid) to authenticated;
grant execute on function public.log_export(text, text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Website intake (called only by edge functions with the service role key)
-- ---------------------------------------------------------------------------

-- What the Get started form needs: industries, open assessment slots and the
-- current privacy policy version. Nothing personal.
create function public.enquiry_options()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'industries', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'name', i.name) order by i.sort_order, i.name)
      from public.industries i
      where i.active
    ), '[]'),
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'starts_at', s.starts_at, 'ends_at', s.ends_at, 'mode', s.mode
      ) order by s.starts_at)
      from public.booking_slots s
      where s.status = 'open'
        and s.starts_at > now() + make_interval(hours => (private.setting('booking_min_notice_hours'))::int)
        and s.starts_at < now() + make_interval(days => (private.setting('booking_window_days'))::int)
    ), '[]'),
    'privacy_policy_version', private.setting('privacy_policy_version') #>> '{}'
  );
$$;

-- Creates the lead, its consent records and (optionally) an assessment booking
-- in one transaction. Input is the JSON the edge function received, already
-- checked for spam.
create function public.submit_enquiry(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_full_name text := btrim(p ->> 'full_name');
  v_business text := nullif(btrim(p ->> 'business_name'), '');
  v_phone text := nullif(regexp_replace(coalesce(p ->> 'phone', ''), '[^0-9+]', '', 'g'), '');
  v_email text := nullif(lower(btrim(p ->> 'email')), '');
  v_pain text := nullif(btrim(p ->> 'biggest_pain'), '');
  v_stage smallint;
  v_industry uuid;
  v_slot uuid;
  v_policy text := private.setting('privacy_policy_version') #>> '{}';
  v_lead_id uuid;
  v_slot_row public.booking_slots;
begin
  if coalesce((p ->> 'consent')::boolean, false) is not true then
    raise exception 'Please agree to the privacy policy so we can reply to you' using errcode = 'PT400';
  end if;
  if v_full_name is null or length(v_full_name) not between 1 and 120 then
    raise exception 'Please tell us your name' using errcode = 'PT400';
  end if;
  if v_phone is null or length(v_phone) not between 9 and 16 then
    raise exception 'Please give a phone number we can reach you on' using errcode = 'PT400';
  end if;
  if v_email is not null and (length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') then
    raise exception 'That email address doesn''t look right' using errcode = 'PT400';
  end if;
  if length(v_business) > 160 or length(v_pain) > 2000 then
    raise exception 'Some answers are too long' using errcode = 'PT400';
  end if;

  if nullif(p ->> 'stage_needed', '') is not null then
    v_stage := (p ->> 'stage_needed')::smallint;
    if v_stage not between 1 and 4 then
      raise exception 'Unknown growth stage' using errcode = 'PT400';
    end if;
  end if;

  if nullif(p ->> 'industry_id', '') is not null then
    select id into v_industry from public.industries where id = (p ->> 'industry_id')::uuid and active;
    if v_industry is null then
      raise exception 'Unknown industry' using errcode = 'PT400';
    end if;
  end if;

  insert into public.leads (full_name, business_name, industry_id, phone, email, source, stage_needed, biggest_pain)
  values (v_full_name, v_business, v_industry, v_phone, v_email, 'website_form', v_stage, v_pain)
  returning id into v_lead_id;

  insert into public.consents (lead_id, purpose, privacy_policy_version, source)
  values (v_lead_id, 'enquiry', v_policy, 'form');
  if coalesce((p ->> 'whatsapp_opt_in')::boolean, false) then
    insert into public.consents (lead_id, purpose, privacy_policy_version, source)
    values (v_lead_id, 'whatsapp', v_policy, 'form');
  end if;

  if nullif(p ->> 'booking_slot_id', '') is not null then
    v_slot := (p ->> 'booking_slot_id')::uuid;
    select * into v_slot_row from public.booking_slots where id = v_slot for update;
    if v_slot_row.id is null or v_slot_row.status <> 'open'
      or v_slot_row.starts_at <= now() + make_interval(hours => (private.setting('booking_min_notice_hours'))::int) then
      raise exception 'Sorry, that time has just been taken. Please pick another.' using errcode = 'PT409';
    end if;
    insert into public.assessments (lead_id, booking_slot_id) values (v_lead_id, v_slot);
    update public.leads set pipeline_stage = 'assessment' where id = v_lead_id;
  end if;

  return jsonb_build_object(
    'lead_id', v_lead_id,
    'assessment_starts_at', v_slot_row.starts_at
  );
exception
  when invalid_text_representation then
    raise exception 'Some answers are in the wrong format' using errcode = 'PT400';
end;
$$;

revoke all on function public.enquiry_options() from public, anon, authenticated;
revoke all on function public.submit_enquiry(jsonb) from public, anon, authenticated;
grant execute on function public.enquiry_options() to service_role;
grant execute on function public.submit_enquiry(jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- File storage: one private bucket for contracts, agreements, quotes,
-- invoices and brand files
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "Admins can read documents" on storage.objects
  for select to authenticated using (bucket_id = 'documents' and (select private.is_admin()));
create policy "Admins can upload documents" on storage.objects
  for insert to authenticated with check (bucket_id = 'documents' and (select private.is_admin()));
create policy "Admins can update documents" on storage.objects
  for update to authenticated using (bucket_id = 'documents' and (select private.is_admin()));
create policy "Admins can delete documents" on storage.objects
  for delete to authenticated using (bucket_id = 'documents' and (select private.is_admin()));
