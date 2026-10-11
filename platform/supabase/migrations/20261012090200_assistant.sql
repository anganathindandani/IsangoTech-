-- The WhatsApp Assistant's records: chats, their messages, questions it
-- couldn't answer, and usage for allowances and billing.
--
-- Messages and usage are written only by IsangoTech's edge functions (service
-- role), never from the app, so the record of what was said can't be edited.

-- ---------------------------------------------------------------------------
-- Conversations: one ongoing WhatsApp chat per customer
-- ---------------------------------------------------------------------------

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  customer_id uuid not null,
  -- 'assistant' answers; 'person' means someone took over and the Assistant stays quiet.
  handled_by text not null default 'assistant' check (handled_by in ('assistant', 'person')),
  taken_over_by uuid,
  taken_over_at timestamptz,
  -- WhatsApp allows free replies for 24 hours after this; after that only approved templates.
  last_customer_message_at timestamptz,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  unique (business_id, id),
  unique (business_id, customer_id),
  foreign key (business_id, customer_id) references public.customers (business_id, id) on delete cascade
);

create index conversations_recent_idx on public.conversations (business_id, last_message_at desc);

-- Records who took over and when; handing back clears it.
create function private.stamp_takeover()
returns trigger
language plpgsql
as $$
begin
  if new.handled_by = 'person' and old.handled_by <> 'person' then
    new.taken_over_by := auth.uid();
    new.taken_over_at := now();
  elsif new.handled_by = 'assistant' then
    new.taken_over_by := null;
    new.taken_over_at := null;
  end if;
  return new;
end;
$$;

create trigger stamp_takeover before update on public.conversations
  for each row execute function private.stamp_takeover();

-- ---------------------------------------------------------------------------
-- Messages
-- ---------------------------------------------------------------------------

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  conversation_id uuid not null,
  direction text not null check (direction in ('inbound', 'outbound')),
  sender text not null check (sender in ('customer', 'assistant', 'person')),
  body text not null,
  -- WhatsApp's own id; unique so a webhook retry never saves a message twice.
  whatsapp_message_id text unique,
  -- The team member who wrote it, when sender = 'person'.
  sent_by uuid,
  created_at timestamptz not null default now(),
  foreign key (business_id, conversation_id) references public.conversations (business_id, id) on delete cascade,
  check ((direction = 'inbound') = (sender = 'customer')),
  check (sent_by is null or sender = 'person')
);

create index messages_conversation_idx on public.messages (conversation_id, created_at);
create index messages_age_idx on public.messages (business_id, created_at);

-- Keeps the conversation's timestamps current for the inbox and the 24-hour window.
create function private.bump_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations c
  set last_message_at = greatest(c.last_message_at, new.created_at),
      last_customer_message_at = case
        when new.direction = 'inbound' then greatest(c.last_customer_message_at, new.created_at)
        else c.last_customer_message_at
      end
  where c.id = new.conversation_id;
  return null;
end;
$$;

create trigger bump_conversation after insert on public.messages
  for each row execute function private.bump_conversation();

-- ---------------------------------------------------------------------------
-- Questions the Assistant handed over, so the owner can add an answer
-- ---------------------------------------------------------------------------

create table public.unanswered_questions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  conversation_id uuid,
  question text not null,
  status text not null default 'open' check (status in ('open', 'answered', 'dismissed')),
  -- The knowledge item added to answer it next time.
  knowledge_item_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (business_id, conversation_id) references public.conversations (business_id, id) on delete set null (conversation_id),
  foreign key (business_id, knowledge_item_id) references public.knowledge_items (business_id, id) on delete set null (knowledge_item_id)
);

create index unanswered_open_idx on public.unanswered_questions (business_id) where status = 'open';

create trigger touch before insert or update on public.unanswered_questions
  for each row execute function private.touch();

-- ---------------------------------------------------------------------------
-- Usage: each WhatsApp conversation, template message and AI call, with cost
-- ---------------------------------------------------------------------------

create table public.usage_events (
  id bigint generated always as identity primary key,
  business_id uuid not null references public.businesses (id) on delete cascade,
  -- whatsapp_conversation: a customer-started 24-hour window (counts against the allowance).
  kind text not null check (kind in ('whatsapp_conversation', 'whatsapp_template', 'ai_call')),
  conversation_id uuid,
  model text,
  input_tokens int check (input_tokens >= 0),
  cached_input_tokens int check (cached_input_tokens >= 0),
  output_tokens int check (output_tokens >= 0),
  cost_zar numeric(12, 4) not null default 0 check (cost_zar >= 0),
  created_at timestamptz not null default now(),
  foreign key (business_id, conversation_id) references public.conversations (business_id, id) on delete set null (conversation_id)
);

create index usage_events_month_idx on public.usage_events (business_id, created_at);

-- The dashboard's usage box: conversations and cost so far this month (in the
-- business's time zone) against the plan's allowance. Owners only.
create function public.usage_this_month(p_business uuid)
returns table (conversations bigint, allowance int, cost_zar numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  month_start timestamptz;
begin
  if not private.is_owner(p_business) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  select date_trunc('month', now() at time zone b.time_zone) at time zone b.time_zone
  into month_start
  from public.businesses b where b.id = p_business;

  return query
  select
    count(*) filter (where u.kind = 'whatsapp_conversation'),
    (select b.monthly_conversation_allowance from public.businesses b where b.id = p_business),
    coalesce(sum(u.cost_zar), 0)
  from public.usage_events u
  where u.business_id = p_business and u.created_at >= month_start;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.conversations enable row level security;
create policy "Managers can read chats" on public.conversations
  for select to authenticated using ((select private.is_manager(business_id)));
create policy "Managers take over and hand back chats" on public.conversations
  for update to authenticated
  using ((select private.is_manager(business_id))) with check ((select private.is_manager(business_id)));

alter table public.messages enable row level security;
create policy "Managers can read messages" on public.messages
  for select to authenticated using ((select private.is_manager(business_id)));

alter table public.unanswered_questions enable row level security;
create policy "Managers can read unanswered questions" on public.unanswered_questions
  for select to authenticated using ((select private.is_manager(business_id)));
create policy "Managers resolve unanswered questions" on public.unanswered_questions
  for update to authenticated
  using ((select private.is_manager(business_id))) with check ((select private.is_manager(business_id)));

alter table public.usage_events enable row level security;
create policy "Owners can read usage" on public.usage_events
  for select to authenticated using ((select private.is_owner(business_id)));
