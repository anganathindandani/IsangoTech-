-- Audit log, who may call and change what, and deleting old chats.

-- ---------------------------------------------------------------------------
-- Audit log: who changed bookings, prices, settings and the team
-- ---------------------------------------------------------------------------

-- Stores which fields changed, not their values, so personal information
-- deleted on request doesn't survive in the log.
create table public.audit_log (
  id bigint generated always as identity primary key,
  business_id uuid not null references public.businesses (id) on delete cascade,
  table_name text not null,
  record_id text,
  action text not null check (action in ('insert', 'update', 'delete')),
  changed_fields text[],
  -- Null when IsangoTech's systems made the change (the Assistant, onboarding).
  changed_by uuid,
  changed_at timestamptz not null default now()
);

create index audit_log_business_idx on public.audit_log (business_id, changed_at desc);

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
  bid uuid;
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

  bid := (coalesce(new_row, old_row) ->> coalesce(tg_argv[0], 'business_id'))::uuid;
  -- A business being deleted takes its log with it.
  if not exists (select 1 from public.businesses b where b.id = bid) then
    return null;
  end if;

  insert into public.audit_log (business_id, table_name, record_id, action, changed_fields, changed_by)
  values (
    bid,
    tg_table_name,
    coalesce(new_row ->> 'id', old_row ->> 'id', new_row ->> 'user_id', old_row ->> 'user_id', bid::text),
    lower(tg_op),
    fields,
    auth.uid()
  );
  return null;
end;
$$;

create trigger audit after insert or update or delete on public.businesses
  for each row execute function private.audit('id');

do $$
declare
  t text;
begin
  foreach t in array array[
    'business_members', 'business_settings', 'staff', 'services', 'service_staff',
    'knowledge_items', 'customers', 'bookings'
  ] loop
    execute format(
      'create trigger audit after insert or update or delete on public.%I '
      'for each row execute function private.audit()', t);
  end loop;
end;
$$;

alter table public.audit_log enable row level security;
create policy "Owners can read their audit log" on public.audit_log
  for select to authenticated using ((select private.is_owner(business_id)));

-- ---------------------------------------------------------------------------
-- Deleting old chats (POPIA: keep only what's needed)
-- ---------------------------------------------------------------------------

-- Deletes messages older than each business's retention setting. Run daily by
-- a scheduled job; returns how many messages were deleted.
create function private.delete_expired_messages()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  n bigint;
begin
  delete from public.messages m
  using public.business_settings s
  where s.business_id = m.business_id
    and m.created_at < now() - make_interval(months => s.message_retention_months);
  get diagnostics n = row_count;
  return n;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- Anonymous callers get nothing; customers only ever reach the platform
-- through WhatsApp and IsangoTech's edge functions.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon, public;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on functions from anon, public;

-- Signed-in people can change only these columns; the rest is IsangoTech's
-- (plans, products, WhatsApp numbers) or written by the system.
revoke insert, update, delete, truncate on public.businesses from authenticated;
grant update (name) on public.businesses to authenticated;

revoke update on public.business_members from authenticated;
grant update (full_name, role, active) on public.business_members to authenticated;

revoke insert, delete, truncate on public.business_settings from authenticated;

revoke insert, update, delete, truncate on public.conversations from authenticated;
grant update (handled_by) on public.conversations to authenticated;

revoke insert, update, delete, truncate on public.messages, public.usage_events from authenticated;

revoke insert, update, delete, truncate on public.unanswered_questions from authenticated;
grant update (status, knowledge_item_id) on public.unanswered_questions to authenticated;

-- Everywhere else: a row can't be moved to another business, and system
-- columns (ids, timestamps, who created it, when a reminder went) aren't editable.
do $$
declare
  t text;
  cols text;
begin
  foreach t in array array[
    'business_settings', 'staff', 'services', 'service_staff', 'knowledge_items', 'customers', 'bookings'
  ] loop
    select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols
    from information_schema.columns
    where table_schema = 'public' and table_name = t
      and column_name not in (
        'id', 'business_id', 'created_at', 'updated_at', 'created_by', 'reminder_sent_at', 'whatsapp_opt_in_at'
      );
    execute format('revoke update on public.%I from authenticated', t);
    execute format('grant update (%s) on public.%I to authenticated', cols, t);
  end loop;
end;
$$;

-- Nobody edits the audit log, not even the edge functions.
revoke insert, update, delete, truncate on public.audit_log from authenticated, service_role;

revoke all on all functions in schema private from public;
grant execute on function
  private.session_ok(), private.role_in(uuid), private.is_member(uuid), private.is_manager(uuid),
  private.is_owner(uuid), private.my_staff_id(uuid), private.is_my_customer(uuid, uuid)
  to authenticated, service_role;
grant execute on function private.delete_expired_messages() to service_role;
grant execute on function public.usage_this_month(uuid) to authenticated;
