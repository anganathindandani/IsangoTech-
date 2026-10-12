-- Owners add and manage their own team: managers and staff, each with their
-- own login. The team-member edge function creates logins and setup links;
-- these functions hold the rules.

-- For the app and the edge function: is the signed-in person an owner here?
create function public.is_business_owner(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_owner(p_business);
$$;

-- The team with emails (which live in auth.users), for owners only.
create function public.team_members(p_business uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_owner(p_business) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'user_id', m.user_id,
      'full_name', m.full_name,
      'email', u.email,
      'role', m.role,
      'active', m.active,
      'signed_in', u.last_sign_in_at is not null,
      'staff_id', st.id,
      'staff_name', st.full_name
    ) order by m.active desc, case m.role when 'owner' then 0 when 'manager' then 1 else 2 end, m.full_name)
    from public.business_members m
    join auth.users u on u.id = m.user_id
    left join public.staff st on st.business_id = m.business_id and st.user_id = m.user_id
    where m.business_id = p_business
  ), '[]'::jsonb);
end;
$$;

-- Adds someone to the team (or brings back someone who left). Staff are
-- linked to a staff record so they see their own bookings: an existing one
-- without a login, or a new one in their name. Called by the edge function
-- (service role) after it has checked the caller owns the business.
create function public.add_team_member(
  p_business uuid,
  p_user uuid,
  p_full_name text,
  p_role text,
  p_staff_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_role not in ('manager', 'staff') then
    raise exception 'Owners can add managers and staff' using errcode = '22023';
  end if;
  insert into public.business_members (business_id, user_id, full_name, role)
  values (p_business, p_user, trim(p_full_name), p_role)
  on conflict (business_id, user_id) do update
    set full_name = excluded.full_name, role = excluded.role, active = true;

  if p_role = 'staff' and not exists (
    select 1 from public.staff where business_id = p_business and user_id = p_user
  ) then
    if p_staff_id is not null then
      update public.staff set user_id = p_user
      where id = p_staff_id and business_id = p_business and user_id is null;
      if not found then
        raise exception 'That staff member already has a login' using errcode = '22023';
      end if;
    else
      insert into public.staff (business_id, full_name, user_id) values (p_business, trim(p_full_name), p_user);
    end if;
  end if;
end;
$$;

-- An owner may get a setup link (which lets whoever opens it set the
-- password) only for a manager or staff member whose login belongs to this
-- business alone. Never for another owner, someone in another business, or an
-- IsangoTech admin: otherwise adding someone's email would hand over their account.
create function public.team_link_target(p_business uuid, p_email text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from auth.users u
  join public.business_members m on m.user_id = u.id and m.business_id = p_business
  where lower(u.email) = lower(trim(p_email))
    and m.role in ('manager', 'staff')
    and not exists (select 1 from public.business_members o where o.user_id = u.id and o.business_id <> p_business)
    and not exists (select 1 from public.platform_admins a where a.user_id = u.id);
$$;

revoke all on function
  public.is_business_owner(uuid), public.team_members(uuid),
  public.add_team_member(uuid, uuid, text, text, uuid), public.team_link_target(uuid, text)
  from public, anon;
grant execute on function public.is_business_owner(uuid), public.team_members(uuid) to authenticated;
revoke all on function public.add_team_member(uuid, uuid, text, text, uuid), public.team_link_target(uuid, text)
  from authenticated;
grant execute on function public.add_team_member(uuid, uuid, text, text, uuid), public.team_link_target(uuid, text)
  to service_role;
