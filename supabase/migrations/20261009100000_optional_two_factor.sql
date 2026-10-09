-- Two-step sign-in becomes optional (off by default), chosen per person in the
-- portal's Settings.
--
-- Someone who has turned it on (has a verified authenticator factor) still
-- needs a session that completed the second step (aal2): their password alone
-- isn't enough, even when calling the API directly. Someone who hasn't turned
-- it on gets in with their password (aal1).

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (
      coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or not exists (
        select 1
        from auth.mfa_factors f
        where f.user_id = auth.uid() and f.status = 'verified'
      )
    )
    and exists (
      select 1
      from public.team_members m
      where m.id = auth.uid() and m.role = 'admin' and m.active
    );
$$;
