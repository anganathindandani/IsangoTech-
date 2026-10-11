-- Client platform foundation: businesses, the people who sign in to them, and
-- the access helpers every other table's rules go through.
--
-- Every client table carries business_id. A signed-in person reaches a row only
-- when they are an active member of that business, so one business can never
-- see or change another's data. IsangoTech onboards businesses and their first
-- owner through the service role (edge functions or the dashboard); nobody can
-- create a business from the app.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

create extension if not exists btree_gist with schema extensions;

-- ---------------------------------------------------------------------------
-- Businesses
-- ---------------------------------------------------------------------------

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  industry text not null check (industry in ('salon', 'guesthouse', 'restaurant', 'caterer', 'other')),
  -- Which products the business pays for. Adding one later switches it on; no data moves.
  products text[] not null default '{}' check (products <@ array['assistant', 'portal']),
  -- Extra Portal modules switched on for this business.
  modules text[] not null default '{}' check (modules <@ array['events', 'rooms', 'stock', 'rosters', 'job_cards']),
  status text not null default 'onboarding' check (status in ('onboarding', 'active', 'paused', 'closed')),
  time_zone text not null default 'Africa/Johannesburg',
  -- Meta's id for the business's WhatsApp number; the webhook finds the business by it.
  whatsapp_phone_number_id text unique,
  whatsapp_display_number text,
  -- Conversations a month included in the plan before usage is billed at cost.
  monthly_conversation_allowance int not null default 300 check (monthly_conversation_allowance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.businesses is
  'One row per client business. Created and switched between plans by IsangoTech only; owners can rename their business.';

-- ---------------------------------------------------------------------------
-- Members: which login belongs to which business, with a role
-- ---------------------------------------------------------------------------

create table public.business_members (
  business_id uuid not null references public.businesses (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  full_name text not null check (length(trim(full_name)) > 0),
  -- owner: everything, including billing and team. manager: daily work, no
  -- billing. staff: their own bookings.
  role text not null check (role in ('owner', 'manager', 'staff')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create index business_members_user_idx on public.business_members (user_id);

comment on table public.business_members is
  'Set active = false the day someone leaves; that removes their access at once. A business always keeps at least one active owner.';

-- ---------------------------------------------------------------------------
-- Access helpers
-- ---------------------------------------------------------------------------

-- True when this session may act as a member: someone who has turned on
-- two-step sign-in must have completed it (aal2); everyone else gets in with
-- their password. Same rule as IsangoTech's own portal.
create function private.session_ok()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or not exists (
        select 1 from auth.mfa_factors f
        where f.user_id = auth.uid() and f.status = 'verified'
      );
$$;

-- The signed-in person's role in a business, or null if they aren't an active member.
create function private.role_in(p_business uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role
  from public.business_members m
  where m.business_id = p_business and m.user_id = auth.uid() and m.active
    and private.session_ok();
$$;

create function private.is_member(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.role_in(p_business) is not null;
$$;

-- Owners and managers run the daily work.
create function private.is_manager(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.role_in(p_business) in ('owner', 'manager'), false);
$$;

create function private.is_owner(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.role_in(p_business) = 'owner', false);
$$;

-- ---------------------------------------------------------------------------
-- Timestamps
-- ---------------------------------------------------------------------------

create function private.touch()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
  else
    new.created_at := now();
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger touch before insert or update on public.businesses
  for each row execute function private.touch();
create trigger touch before insert or update on public.business_members
  for each row execute function private.touch();

-- ---------------------------------------------------------------------------
-- Member rules
-- ---------------------------------------------------------------------------

-- Members can't be moved between businesses or logins, and a business always
-- keeps an active owner (so nobody can lock everyone out by mistake).
create function private.check_members()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  bid uuid := coalesce(old.business_id, new.business_id);
begin
  if tg_op = 'UPDATE' and (new.business_id <> old.business_id or new.user_id <> old.user_id) then
    raise exception 'A member can''t be moved to another business or login; add a new member instead'
      using errcode = '23514';
  end if;

  if exists (select 1 from public.businesses b where b.id = bid)
     and not exists (
       select 1 from public.business_members m
       where m.business_id = bid and m.role = 'owner' and m.active
     ) then
    raise exception 'A business needs at least one active owner' using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger keep_an_owner after update or delete on public.business_members
  deferrable initially immediate
  for each row execute function private.check_members();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.businesses enable row level security;
alter table public.business_members enable row level security;

create policy "Members can see their business" on public.businesses
  for select to authenticated using ((select private.is_member(id)));
create policy "Owners can rename their business" on public.businesses
  for update to authenticated
  using ((select private.is_owner(id))) with check ((select private.is_owner(id)));

create policy "Members can see their team" on public.business_members
  for select to authenticated using ((select private.is_member(business_id)));
create policy "Owners add team members" on public.business_members
  for insert to authenticated with check ((select private.is_owner(business_id)));
create policy "Owners change team members" on public.business_members
  for update to authenticated
  using ((select private.is_owner(business_id))) with check ((select private.is_owner(business_id)));
create policy "Owners remove team members" on public.business_members
  for delete to authenticated using ((select private.is_owner(business_id)));
