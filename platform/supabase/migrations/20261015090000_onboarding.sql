-- Onboarding: IsangoTech's own admins add businesses and their owners from
-- the business app, instead of the SQL editor.
--
-- A platform admin can see and set up every business, but has no access to
-- any business's customers, chats or bookings unless they're also a member.

create table public.platform_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  created_at timestamptz not null default now()
);

comment on table public.platform_admins is
  'IsangoTech staff who onboard client businesses. Added in the SQL editor only.';

alter table public.platform_admins enable row level security;
revoke all on public.platform_admins from anon, authenticated;

-- Same two-step rule as everyone else: once turned on, it's required.
create function private.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.session_ok()
     and exists (select 1 from public.platform_admins a where a.user_id = auth.uid());
$$;

-- For the app: is the signed-in person an IsangoTech admin?
create function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin();
$$;

-- ---------------------------------------------------------------------------
-- What admins see and change
-- ---------------------------------------------------------------------------

create function public.admin_businesses()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_platform_admin() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id,
      'name', b.name,
      'industry', b.industry,
      'status', b.status,
      'products', b.products,
      'whatsapp_phone_number_id', b.whatsapp_phone_number_id,
      'whatsapp_display_number', b.whatsapp_display_number,
      'monthly_conversation_allowance', b.monthly_conversation_allowance,
      'assistant_enabled', s.assistant_enabled,
      'created_at', b.created_at,
      'owners', (
        select coalesce(jsonb_agg(jsonb_build_object('name', m.full_name, 'email', u.email) order by m.created_at), '[]')
        from public.business_members m join auth.users u on u.id = m.user_id
        where m.business_id = b.id and m.role = 'owner' and m.active
      )
    ) order by b.created_at desc, b.name)
    from public.businesses b join public.business_settings s on s.business_id = b.id
  ), '[]'::jsonb);
end;
$$;

-- Plan, products, status and WhatsApp number: the fields owners can't change.
create function public.admin_update_business(p_business uuid, p_values jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_platform_admin() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  update public.businesses set
    name = coalesce(nullif(trim(p_values ->> 'name'), ''), name),
    industry = coalesce(p_values ->> 'industry', industry),
    status = coalesce(p_values ->> 'status', status),
    products = case when p_values ? 'products'
      then array(select jsonb_array_elements_text(p_values -> 'products')) else products end,
    whatsapp_phone_number_id = case when p_values ? 'whatsapp_phone_number_id'
      then nullif(trim(p_values ->> 'whatsapp_phone_number_id'), '') else whatsapp_phone_number_id end,
    whatsapp_display_number = case when p_values ? 'whatsapp_display_number'
      then nullif(trim(p_values ->> 'whatsapp_display_number'), '') else whatsapp_display_number end,
    monthly_conversation_allowance = coalesce((p_values ->> 'monthly_conversation_allowance')::int,
                                              monthly_conversation_allowance)
  where id = p_business;
  if not found then
    raise exception 'No such business' using errcode = 'P0002';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Used by the onboard-business edge function (service role), after it has
-- checked the caller is a platform admin and created the owner's login.
-- ---------------------------------------------------------------------------

create function public.onboard_business(p_business jsonb, p_owner_user uuid, p_owner_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  bid uuid;
begin
  insert into public.businesses (name, industry, products, status, whatsapp_phone_number_id,
                                 whatsapp_display_number, monthly_conversation_allowance)
  values (
    trim(p_business ->> 'name'),
    p_business ->> 'industry',
    coalesce(array(select jsonb_array_elements_text(p_business -> 'products')), '{}'),
    'onboarding',
    nullif(trim(p_business ->> 'whatsapp_phone_number_id'), ''),
    nullif(trim(p_business ->> 'whatsapp_display_number'), ''),
    coalesce((p_business ->> 'monthly_conversation_allowance')::int, 300)
  )
  returning id into bid;
  insert into public.business_members (business_id, user_id, full_name, role)
  values (bid, p_owner_user, trim(p_owner_name), 'owner');
  return bid;
end;
$$;

-- An existing login's id by email, so a person who already has one (say, an
-- owner of two businesses) isn't given a second.
create function public.user_id_by_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id from auth.users u where lower(u.email) = lower(trim(p_email)) limit 1;
$$;

revoke all on function
  public.is_platform_admin(), public.admin_businesses(), public.admin_update_business(uuid, jsonb),
  public.onboard_business(jsonb, uuid, text), public.user_id_by_email(text)
  from public, anon;
revoke all on function private.is_platform_admin() from public;
grant execute on function private.is_platform_admin() to authenticated, service_role;
grant execute on function public.is_platform_admin(), public.admin_businesses(), public.admin_update_business(uuid, jsonb)
  to authenticated;
revoke all on function public.onboard_business(jsonb, uuid, text), public.user_id_by_email(text) from authenticated;
grant execute on function public.onboard_business(jsonb, uuid, text), public.user_id_by_email(text) to service_role;
