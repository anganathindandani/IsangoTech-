-- Core business records. Growth stages are stored as numbers:
--   1 Get found · 2 Capture and respond · 3 Run operations · 4 Automate

-- ---------------------------------------------------------------------------
-- Lookups and price list
-- ---------------------------------------------------------------------------

create table public.industries (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  focus_status text not null default 'general' check (focus_status in ('focus', 'candidate', 'general')),
  active boolean not null default true,
  sort_order int not null default 100,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.industries (name, focus_status, sort_order) values
  ('Salons and beauty', 'focus', 10),
  ('Restaurants and food businesses', 'focus', 20),
  ('Caterers', 'focus', 30),
  ('Construction and trades', 'candidate', 40),
  ('Professional services', 'candidate', 50),
  ('Retail', 'candidate', 60),
  ('Accommodation', 'candidate', 70),
  ('Other small business', 'general', 999);

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  growth_stage smallint check (growth_stage between 1 and 4),
  description text,
  price numeric(12, 2) not null check (price >= 0),
  billing text not null check (billing in ('once_off', 'monthly')),
  active boolean not null default true,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.packages.growth_stage is 'Null for packages that apply at every stage, such as care plans.';

-- ---------------------------------------------------------------------------
-- Clients and contacts
-- ---------------------------------------------------------------------------

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  business_name text not null,
  industry_id uuid references public.industries (id),
  address text,
  growth_stage smallint check (growth_stage between 1 and 4),
  next_stage_review_date date,
  status text not null default 'prospect' check (status in ('prospect', 'lost', 'active', 'past')),
  start_date date,
  lost_at timestamptz,
  systems_used text,
  notes text,
  anonymised_at timestamptz,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index clients_status_idx on public.clients (status);
create index clients_review_idx on public.clients (next_stage_review_date) where status = 'active';

create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  full_name text not null,
  role text,
  phone text,
  email text,
  is_primary boolean not null default false,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index contacts_client_idx on public.contacts (client_id);

create table public.stage_changes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  from_stage smallint,
  to_stage smallint,
  changed_by uuid references public.team_members (id),
  changed_at timestamptz not null default now()
);

create index stage_changes_client_idx on public.stage_changes (client_id);

-- ---------------------------------------------------------------------------
-- Leads
-- ---------------------------------------------------------------------------

create table public.leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  business_name text,
  industry_id uuid references public.industries (id),
  phone text,
  email text,
  source text not null check (source in ('website_form', 'whatsapp', 'walk_in', 'phone', 'referral', 'other')),
  stage_needed smallint check (stage_needed between 1 and 4),
  biggest_pain text,
  pipeline_stage text not null default 'new'
    check (pipeline_stage in ('new', 'contacted', 'assessment', 'quoted', 'won', 'lost')),
  lost_reason text,
  owner_id uuid references public.team_members (id),
  next_follow_up date,
  client_id uuid references public.clients (id) on delete set null,
  anonymised_at timestamptz,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (phone is not null or email is not null or anonymised_at is not null)
);

comment on column public.leads.stage_needed is 'Growth stage the enquiry is about. Null when the person is not sure yet.';

create index leads_pipeline_idx on public.leads (pipeline_stage);
create index leads_follow_up_idx on public.leads (next_follow_up) where pipeline_stage not in ('won', 'lost');
create index leads_client_idx on public.leads (client_id);

create table public.lead_activities (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.leads (id) on delete cascade,
  client_id uuid references public.clients (id) on delete cascade,
  type text not null check (type in ('call', 'message', 'meeting', 'note')),
  summary text not null,
  occurred_at timestamptz not null default now(),
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(lead_id, client_id) >= 1)
);

create index lead_activities_lead_idx on public.lead_activities (lead_id);
create index lead_activities_client_idx on public.lead_activities (client_id);

-- The single source of truth for opt-ins, including WhatsApp permission.
create table public.consents (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.leads (id) on delete cascade,
  contact_id uuid references public.contacts (id) on delete cascade,
  purpose text not null check (purpose in ('enquiry', 'whatsapp', 'marketing')),
  given_at timestamptz not null default now(),
  privacy_policy_version text not null,
  source text not null check (source in ('form', 'whatsapp', 'in_person')),
  withdrawn_at timestamptz,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(lead_id, contact_id) = 1)
);

comment on column public.consents.purpose is
  'enquiry: use their details to respond to the enquiry. whatsapp: message them on WhatsApp. marketing: send news and offers.';

create index consents_lead_idx on public.consents (lead_id);
create index consents_contact_idx on public.consents (contact_id);

-- ---------------------------------------------------------------------------
-- Assessments and booking slots
-- ---------------------------------------------------------------------------

create table public.booking_slots (
  id uuid primary key default gen_random_uuid(),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  mode text not null default 'in_person' check (mode in ('in_person', 'online')),
  location text,
  status text not null default 'open' check (status in ('open', 'booked', 'cancelled')),
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  constraint booking_slots_no_overlap
    exclude using gist (tstzrange(starts_at, ends_at) with &&) where (status <> 'cancelled')
);

create index booking_slots_open_idx on public.booking_slots (starts_at) where status = 'open';

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.leads (id) on delete set null,
  client_id uuid references public.clients (id) on delete set null,
  booking_slot_id uuid references public.booking_slots (id),
  scheduled_at timestamptz,
  location text,
  status text not null default 'booked' check (status in ('booked', 'completed', 'cancelled', 'no_show')),
  notes text,
  findings text,
  recommended_package_id uuid references public.packages (id),
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(lead_id, client_id) >= 1)
);

-- A slot holds one booked assessment; cancelled ones release it for rebooking.
create unique index assessments_booked_slot_idx on public.assessments (booking_slot_id) where status = 'booked';
create index assessments_lead_idx on public.assessments (lead_id);
create index assessments_client_idx on public.assessments (client_id);

-- ---------------------------------------------------------------------------
-- Quotes
-- ---------------------------------------------------------------------------

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  number text not null unique,
  client_id uuid not null references public.clients (id) on delete restrict,
  lead_id uuid references public.leads (id) on delete set null,
  status text not null default 'draft'
    check (status in ('draft', 'pending_approval', 'sent', 'accepted', 'declined', 'expired')),
  total numeric(12, 2) not null default 0,
  monthly_total numeric(12, 2) not null default 0,
  valid_until date,
  notes text,
  approved_by uuid references public.team_members (id),
  approved_at timestamptz,
  sent_at timestamptz,
  decided_at timestamptz,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.quotes.total is 'Sum of once-off line items. Kept up to date by trigger.';
comment on column public.quotes.monthly_total is 'Sum of monthly line items. Kept up to date by trigger.';

create index quotes_client_idx on public.quotes (client_id);
create index quotes_status_idx on public.quotes (status);

create table public.quote_line_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes (id) on delete cascade,
  package_id uuid references public.packages (id),
  description text not null,
  quantity numeric(10, 2) not null default 1 check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  billing text not null default 'once_off' check (billing in ('once_off', 'monthly')),
  line_total numeric(12, 2) generated always as (round(quantity * unit_price, 2)) stored,
  sort_order int not null default 0,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index quote_line_items_quote_idx on public.quote_line_items (quote_id);

-- ---------------------------------------------------------------------------
-- Projects and tasks
-- ---------------------------------------------------------------------------

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete restrict,
  quote_id uuid references public.quotes (id) on delete set null,
  name text not null,
  type text not null check (type in ('website', 'enquiry_capture', 'operations_portal', 'automation')),
  package_id uuid references public.packages (id),
  start_date date,
  go_live_date date,
  status text not null default 'planned' check (status in ('planned', 'in_progress', 'live', 'cancelled')),
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index projects_client_idx on public.projects (client_id);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  title text not null,
  owner_id uuid references public.team_members (id),
  due_date date,
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'done')),
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high')),
  go_live_checklist boolean not null default false,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_project_idx on public.tasks (project_id);
create index tasks_owner_due_idx on public.tasks (owner_id, due_date) where status <> 'done';

-- ---------------------------------------------------------------------------
-- Care plans, invoices and payments
-- ---------------------------------------------------------------------------

create table public.care_plans (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete restrict,
  package_id uuid references public.packages (id),
  monthly_fee numeric(12, 2) not null check (monthly_fee >= 0),
  billing_day smallint not null default 1 check (billing_day between 1 and 28),
  start_date date not null,
  renewal_date date,
  status text not null default 'active' check (status in ('active', 'paused', 'cancelled')),
  usage_notes text,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index care_plans_client_idx on public.care_plans (client_id);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  number text unique,
  client_id uuid not null references public.clients (id) on delete restrict,
  project_id uuid references public.projects (id) on delete set null,
  care_plan_id uuid references public.care_plans (id) on delete set null,
  quote_id uuid references public.quotes (id) on delete set null,
  type text not null check (type in ('setup', 'monthly', 'custom')),
  description text,
  amount numeric(12, 2) not null check (amount >= 0),
  issue_date date,
  due_date date,
  period_start date,
  status text not null default 'draft' check (status in ('draft', 'sent', 'void')),
  sent_at timestamptz,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Stops the monthly job from billing a care plan twice for the same month.
  unique (care_plan_id, period_start)
);

comment on column public.invoices.number is 'Assigned when the invoice is sent, so deleted drafts leave no gaps.';

create index invoices_client_idx on public.invoices (client_id);
create index invoices_due_idx on public.invoices (due_date) where status = 'sent';

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices (id) on delete restrict,
  amount numeric(12, 2) not null check (amount > 0),
  paid_on date not null default current_date,
  method text not null check (method in ('eft', 'card', 'cash', 'payment_link', 'other')),
  reference text,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index payments_invoice_idx on public.payments (invoice_id);

-- ---------------------------------------------------------------------------
-- Support tickets and documents
-- ---------------------------------------------------------------------------

create table public.tickets (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete restrict,
  subject text not null,
  description text,
  channel text not null check (channel in ('whatsapp', 'email', 'phone', 'other')),
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  owner_id uuid references public.team_members (id),
  status text not null default 'open' check (status in ('open', 'in_progress', 'waiting_on_client', 'closed')),
  opened_at timestamptz not null default now(),
  first_response_at timestamptz,
  closed_at timestamptz,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tickets_client_idx on public.tickets (client_id);
create index tickets_open_idx on public.tickets (status) where status <> 'closed';

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients (id) on delete restrict,
  title text not null,
  type text not null check (type in ('contract', 'operator_agreement', 'nda', 'template', 'brand', 'other')),
  file_path text not null,
  signed_on date,
  created_by uuid references public.team_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.documents.client_id is 'Null for company documents such as templates and brand files.';
comment on column public.documents.file_path is 'Path of the file in the private "documents" storage bucket.';

create index documents_client_idx on public.documents (client_id);

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------

-- security_invoker so the view obeys the caller's row-level security.
create view public.invoice_summaries with (security_invoker = true) as
select
  i.*,
  coalesce(p.paid, 0) as paid,
  i.amount - coalesce(p.paid, 0) as balance,
  case
    when i.status <> 'sent' then i.status
    when coalesce(p.paid, 0) >= i.amount then 'paid'
    when coalesce(p.paid, 0) > 0 then 'part_paid'
    else 'unpaid'
  end as payment_status,
  (i.status = 'sent' and coalesce(p.paid, 0) < i.amount and i.due_date < current_date) as is_overdue
from public.invoices i
left join (
  select invoice_id, sum(amount) as paid from public.payments group by invoice_id
) p on p.invoice_id = i.id;
