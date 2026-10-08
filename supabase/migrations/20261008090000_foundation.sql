-- Foundation: private helpers, team members, settings and the audit log.
--
-- Phase 1 ships admin-only access. Every policy goes through private.is_admin(),
-- which also requires a session that signed in with two-factor authentication
-- (aal2), so 2FA can't be skipped by calling the API directly.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Team members (one row per staff login)
-- ---------------------------------------------------------------------------

create table public.team_members (
  id uuid primary key references auth.users (id) on delete restrict,
  full_name text not null,
  role text not null check (role in ('admin', 'developer', 'sales_support', 'finance')),
  email text not null unique,
  phone text,
  active boolean not null default true,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.team_members is
  'Staff who can sign in to the portal. Set active = false the day someone leaves; that removes access immediately. Rows are never deleted, so history keeps its authors.';

create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
     and exists (
       select 1
       from public.team_members m
       where m.id = auth.uid() and m.role = 'admin' and m.active
     );
$$;

-- ---------------------------------------------------------------------------
-- Record stamps: created_by / created_at / updated_at
-- ---------------------------------------------------------------------------

-- Set by trigger rather than column defaults so they can't be spoofed from the API.
create function private.stamp()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.created_at := now();
  else
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger stamp before insert or update on public.team_members
  for each row execute function private.stamp();

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

create table public.settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_by uuid references public.team_members (id),
  updated_at timestamptz not null default now()
);

create function private.stamp_setting()
returns trigger
language plpgsql
as $$
begin
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end;
$$;

create trigger stamp before insert or update on public.settings
  for each row execute function private.stamp_setting();

create function private.setting(p_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select value from public.settings where key = p_key;
$$;

insert into public.settings (key, value, description) values
  ('quote_approval_amount', '20000', 'Quotes whose first-year value (once-off total plus 12 months of monthly items) is above this amount in rand need admin approval before they are sent.'),
  ('quote_valid_days', '30', 'Default number of days a quote stays valid.'),
  ('invoice_due_days', '7', 'Default number of days between issuing an invoice and its due date.'),
  ('currency', '"ZAR"', 'Currency for prices, quotes and invoices.'),
  ('vat_registered', 'false', 'Whether IsangoTech is a registered VAT vendor. Show the VAT note and charge VAT only once this is true.'),
  ('vat_rate', '0.15', 'South African VAT rate, used once vat_registered is true.'),
  ('privacy_policy_version', '"1"', 'Current privacy policy version. Recorded on every consent so we know which version each person agreed to.'),
  ('lead_retention_months', '12', 'Months after the last update before a lead that never became a client is anonymised.'),
  ('lost_prospect_retention_months', '12', 'Months after a prospect is marked lost before their personal details are anonymised.'),
  ('booking_min_notice_hours', '24', 'How far ahead a website visitor must book an assessment slot.'),
  ('booking_window_days', '60', 'How many days ahead the website shows open assessment slots.'),
  ('next_stage_review_months', '3', 'Months after a go-live before the client is due a next-stage conversation.');

-- ---------------------------------------------------------------------------
-- Audit log
-- ---------------------------------------------------------------------------

-- Stores which fields changed, not their values, so personal information that
-- is later anonymised under the retention rules doesn't survive in the log.
create table public.audit_log (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id text,
  action text not null check (action in ('insert', 'update', 'delete', 'export')),
  changed_fields text[],
  changed_by uuid references public.team_members (id),
  changed_at timestamptz not null default now()
);

create index audit_log_record_idx on public.audit_log (table_name, record_id);
create index audit_log_changed_at_idx on public.audit_log (changed_at);

create function private.audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_row jsonb;
  new_row jsonb;
  fields text[];
begin
  if tg_op in ('UPDATE', 'DELETE') then old_row := to_jsonb(old); end if;
  if tg_op in ('INSERT', 'UPDATE') then new_row := to_jsonb(new); end if;

  if tg_op = 'UPDATE' then
    select array_agg(k order by k) into fields
    from jsonb_object_keys(new_row) as k
    where k not in ('updated_at')
      and new_row -> k is distinct from old_row -> k;
    if fields is null then
      return null;
    end if;
  end if;

  insert into public.audit_log (table_name, record_id, action, changed_fields, changed_by)
  values (
    tg_table_name,
    coalesce(new_row, old_row) ->> coalesce(tg_argv[0], 'id'),
    lower(tg_op),
    fields,
    auth.uid()
  );
  return null;
end;
$$;

create trigger audit after insert or update or delete on public.team_members
  for each row execute function private.audit();
create trigger audit after insert or update or delete on public.settings
  for each row execute function private.audit('key');

-- Portal calls this whenever someone exports records (CSV, PDF and so on).
create function public.log_export(p_table text, p_record_ids text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  insert into public.audit_log (table_name, record_id, action, changed_by)
  select p_table, rid, 'export', auth.uid()
  from unnest(p_record_ids) as rid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Document numbers (Q-2026-0001, INV-2026-0001)
-- ---------------------------------------------------------------------------

create table private.counters (
  prefix text not null,
  year int not null,
  last_value int not null,
  primary key (prefix, year)
);

-- Gap-free: the row lock holds until the calling transaction commits or rolls back.
create function private.next_number(p_prefix text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  y int := extract(year from now() at time zone 'Africa/Johannesburg');
  n int;
begin
  insert into private.counters as c (prefix, year, last_value)
  values (p_prefix, y, 1)
  on conflict (prefix, year) do update set last_value = c.last_value + 1
  returning last_value into n;
  return format('%s-%s-%s', p_prefix, y, lpad(n::text, 4, '0'));
end;
$$;
