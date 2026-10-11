-- What a business sells and who delivers it, its customers, and bookings.
-- Shared by both products: a booking the Assistant takes on WhatsApp is the
-- same row the Portal shows.
--
-- Child rows point at their parent through (business_id, id), so a row can
-- only ever reference a customer, service or staff member of its own business,
-- even if someone guesses another business's ids.

-- ---------------------------------------------------------------------------
-- Settings the Assistant follows (one row per business)
-- ---------------------------------------------------------------------------

create table public.business_settings (
  business_id uuid primary key references public.businesses (id) on delete cascade,
  -- {"mon": [["08:00", "17:00"]], "tue": ..., "sun": []}; a missing or empty day is closed.
  opening_hours jsonb not null default '{}' check (jsonb_typeof(opening_hours) = 'object'),
  -- Languages the Assistant may reply in.
  languages text[] not null default array['en'] check (languages <@ array['en', 'xh', 'af', 'zu'] and cardinality(languages) > 0),
  tone text not null default 'Friendly and professional',
  -- Cancellation, late-arrival, deposit and other policies, in the owner's words.
  policies text not null default '',
  -- Extra topics the Assistant must hand to a person (on top of the fixed safety rules).
  handover_topics text not null default '',
  min_booking_notice_hours int not null default 2 check (min_booking_notice_hours >= 0),
  change_notice_hours int not null default 24 check (change_notice_hours >= 0),
  deposit_required boolean not null default false,
  deposit_percent numeric(5, 2) not null default 0 check (deposit_percent between 0 and 100),
  privacy_notice_url text,
  -- Chats older than this are deleted (POPIA: keep only what's needed).
  message_retention_months int not null default 12 check (message_retention_months between 1 and 60),
  assistant_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Every business gets its settings row the moment it's created.
create function private.create_business_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.business_settings (business_id) values (new.id);
  return null;
end;
$$;

create trigger create_settings after insert on public.businesses
  for each row execute function private.create_business_settings();

create function private.touch_updated()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger touch before update on public.business_settings
  for each row execute function private.touch_updated();

-- ---------------------------------------------------------------------------
-- Staff: people who deliver services (not necessarily people who sign in)
-- ---------------------------------------------------------------------------

create table public.staff (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  full_name text not null check (length(trim(full_name)) > 0),
  -- Set when this person also signs in, so they can see their own bookings.
  user_id uuid,
  -- Same shape as opening_hours; empty means the business's opening hours.
  working_hours jsonb not null default '{}' check (jsonb_typeof(working_hours) = 'object'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, id),
  unique (business_id, user_id),
  foreign key (business_id, user_id) references public.business_members (business_id, user_id)
    on delete set null (user_id)
);

-- ---------------------------------------------------------------------------
-- Services: what the business sells
-- ---------------------------------------------------------------------------

create table public.services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  description text not null default '',
  -- In rand. Null means "price on request"; the Assistant then says so instead of guessing.
  price numeric(10, 2) check (price >= 0),
  -- True when price is a starting price ("from R450").
  price_from boolean not null default false,
  duration_minutes int check (duration_minutes > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, id)
);

-- Which staff can do which service. No rows for a service means anyone can.
create table public.service_staff (
  business_id uuid not null,
  service_id uuid not null,
  staff_id uuid not null,
  primary key (service_id, staff_id),
  foreign key (business_id, service_id) references public.services (business_id, id) on delete cascade,
  foreign key (business_id, staff_id) references public.staff (business_id, id) on delete cascade
);

-- ---------------------------------------------------------------------------
-- Knowledge items: facts the Assistant may quote
-- ---------------------------------------------------------------------------

create table public.knowledge_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  question text not null check (length(trim(question)) > 0),
  answer text not null check (length(trim(answer)) > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, id)
);

-- ---------------------------------------------------------------------------
-- Customers: the business's own customers (the business is the responsible
-- party under POPIA; IsangoTech is the operator)
-- ---------------------------------------------------------------------------

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  full_name text,
  -- International format without "+", e.g. 27821234567, as WhatsApp sends it.
  whatsapp_number text check (whatsapp_number ~ '^[1-9][0-9]{7,14}$'),
  email text,
  notes text not null default '',
  -- Agreed to reminders and updates on WhatsApp outside a conversation they started.
  whatsapp_opt_in boolean not null default false,
  whatsapp_opt_in_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, id),
  unique (business_id, whatsapp_number),
  check (full_name is not null or whatsapp_number is not null)
);

-- Records when someone opted in, and clears it when they opt out.
create function private.stamp_opt_in()
returns trigger
language plpgsql
as $$
begin
  if new.whatsapp_opt_in and (tg_op = 'INSERT' or not old.whatsapp_opt_in) then
    new.whatsapp_opt_in_at := now();
  elsif not new.whatsapp_opt_in then
    new.whatsapp_opt_in_at := null;
  end if;
  return new;
end;
$$;

create trigger stamp_opt_in before insert or update on public.customers
  for each row execute function private.stamp_opt_in();

-- ---------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  customer_id uuid not null,
  -- Optional: a restaurant table booking has no service or staff member.
  service_id uuid,
  staff_id uuid,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  party_size int check (party_size > 0),
  status text not null default 'confirmed'
    check (status in ('pending', 'confirmed', 'completed', 'cancelled', 'no_show')),
  source text not null check (source in ('whatsapp', 'portal', 'walk_in')),
  deposit_amount numeric(10, 2) not null default 0 check (deposit_amount >= 0),
  deposit_status text not null default 'not_required'
    check (deposit_status in ('not_required', 'requested', 'paid', 'refunded')),
  notes text not null default '',
  reminder_sent_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  foreign key (business_id, customer_id) references public.customers (business_id, id) on delete cascade,
  foreign key (business_id, service_id) references public.services (business_id, id),
  foreign key (business_id, staff_id) references public.staff (business_id, id),
  -- A staff member can't be double-booked. Scoped to the business so the check
  -- never reveals anything about another business's bookings.
  constraint no_double_booking exclude using gist (
    business_id with =,
    staff_id with =,
    tstzrange(starts_at, ends_at) with &&
  ) where (staff_id is not null and status in ('pending', 'confirmed'))
);

create index bookings_business_start_idx on public.bookings (business_id, starts_at);
create index bookings_customer_idx on public.bookings (customer_id);

-- created_by can't be spoofed from the API.
create function private.stamp_booking()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  else
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;

create trigger stamp_booking before insert or update on public.bookings
  for each row execute function private.stamp_booking();

do $$
declare
  t text;
begin
  foreach t in array array['staff', 'services', 'knowledge_items', 'customers', 'bookings'] loop
    execute format(
      'create trigger touch before insert or update on public.%I for each row execute function private.touch()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Staff who sign in see only their own bookings, and only those customers
-- ---------------------------------------------------------------------------

create function private.my_staff_id(p_business uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id from public.staff s
  where s.business_id = p_business and s.user_id = auth.uid() and s.active
    and private.is_member(p_business);
$$;

create function private.is_my_customer(p_business uuid, p_customer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bookings b
    where b.business_id = p_business and b.customer_id = p_customer
      and b.staff_id = private.my_staff_id(p_business)
  );
$$;

-- Staff may only move their own booking along (status) and add notes.
create function private.check_staff_booking_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.role_in(old.business_id) = 'staff'
     and (to_jsonb(new) - array['status', 'notes', 'updated_at'])
         is distinct from (to_jsonb(old) - array['status', 'notes', 'updated_at']) then
    raise exception 'Staff can only change a booking''s status and notes' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger check_staff_update before update on public.bookings
  for each row execute function private.check_staff_booking_update();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.business_settings enable row level security;
create policy "Members can read their settings" on public.business_settings
  for select to authenticated using ((select private.is_member(business_id)));
create policy "Managers change their settings" on public.business_settings
  for update to authenticated
  using ((select private.is_manager(business_id))) with check ((select private.is_manager(business_id)));

-- Catalogue: every member can read it, owners and managers keep it up to date.
do $$
declare
  t text;
begin
  foreach t in array array['staff', 'services', 'service_staff', 'knowledge_items'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "Members can read" on public.%I for select to authenticated '
      'using ((select private.is_member(business_id)))', t);
    execute format(
      'create policy "Managers can change" on public.%I for all to authenticated '
      'using ((select private.is_manager(business_id))) with check ((select private.is_manager(business_id)))', t);
  end loop;
end;
$$;

alter table public.customers enable row level security;
create policy "Managers can read customers" on public.customers
  for select to authenticated using ((select private.is_manager(business_id)));
create policy "Staff can read their own customers" on public.customers
  for select to authenticated using ((select private.is_my_customer(business_id, id)));
create policy "Managers add customers" on public.customers
  for insert to authenticated with check ((select private.is_manager(business_id)));
create policy "Managers change customers" on public.customers
  for update to authenticated
  using ((select private.is_manager(business_id))) with check ((select private.is_manager(business_id)));
-- Deleting a customer (a POPIA request) removes their bookings and chats too; owners only.
create policy "Owners delete customers" on public.customers
  for delete to authenticated using ((select private.is_owner(business_id)));

alter table public.bookings enable row level security;
create policy "Managers can read bookings" on public.bookings
  for select to authenticated using ((select private.is_manager(business_id)));
create policy "Staff can read their own bookings" on public.bookings
  for select to authenticated using (staff_id = (select private.my_staff_id(business_id)));
create policy "Managers add bookings" on public.bookings
  for insert to authenticated with check ((select private.is_manager(business_id)));
create policy "Managers change bookings" on public.bookings
  for update to authenticated
  using ((select private.is_manager(business_id))) with check ((select private.is_manager(business_id)));
create policy "Staff change their own bookings" on public.bookings
  for update to authenticated
  using (staff_id = (select private.my_staff_id(business_id)))
  with check (staff_id = (select private.my_staff_id(business_id)));
create policy "Owners delete bookings" on public.bookings
  for delete to authenticated using ((select private.is_owner(business_id)));
