-- What the owner's dashboard needs beyond plain table reads: today's summary,
-- answering a question the Assistant couldn't, and replying to a customer
-- in person on WhatsApp.

-- ---------------------------------------------------------------------------
-- Today at a glance
-- ---------------------------------------------------------------------------

-- Runs as the signed-in person, so row-level security applies: staff see only
-- their own bookings, managers don't see usage.
create function public.today_summary(p_business uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with b as (
    select bz.id, bz.time_zone, bz.monthly_conversation_allowance,
           (date_trunc('day', now() at time zone bz.time_zone)) at time zone bz.time_zone as day_start,
           (date_trunc('month', now() at time zone bz.time_zone)) at time zone bz.time_zone as month_start
    from public.businesses bz where bz.id = p_business
  )
  select jsonb_build_object(
    'bookings_today', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', bk.id,
        'starts_at', bk.starts_at,
        'ends_at', bk.ends_at,
        'status', bk.status,
        'customer', coalesce(cu.full_name, cu.whatsapp_number),
        'service', sv.name,
        'staff', st.full_name
      ) order by bk.starts_at)
      from public.bookings bk
      left join public.customers cu on cu.id = bk.customer_id
      left join public.services sv on sv.id = bk.service_id
      left join public.staff st on st.id = bk.staff_id
      where bk.business_id = b.id and bk.status <> 'cancelled'
        and bk.starts_at >= b.day_start and bk.starts_at < b.day_start + interval '1 day'
    ), '[]'::jsonb),
    'chats_waiting', (select count(*) from public.conversations c where c.business_id = b.id and c.handled_by = 'person'),
    'open_questions', (select count(*) from public.unanswered_questions q where q.business_id = b.id and q.status = 'open'),
    -- Null for anyone who isn't an owner (they can't read usage).
    'usage', case when private.is_owner(b.id) then jsonb_build_object(
      'conversations', (select count(*) from public.usage_events u
                        where u.business_id = b.id and u.kind = 'whatsapp_conversation' and u.created_at >= b.month_start),
      'allowance', b.monthly_conversation_allowance,
      'cost_zar', (select coalesce(sum(u.cost_zar), 0) from public.usage_events u
                   where u.business_id = b.id and u.created_at >= b.month_start)
    ) end
  )
  from b;
$$;

-- ---------------------------------------------------------------------------
-- Answering a question the Assistant couldn't
-- ---------------------------------------------------------------------------

-- Adds the answer to the business's knowledge, so the Assistant can use it
-- next time, and marks the question answered. Runs as the signed-in person.
create function public.answer_question(p_question uuid, p_answer text)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  q public.unanswered_questions;
  item_id uuid;
begin
  select * into q from public.unanswered_questions where id = p_question and status = 'open';
  if not found then
    raise exception 'That question is no longer open' using errcode = 'P0002';
  end if;
  if length(trim(coalesce(p_answer, ''))) = 0 then
    raise exception 'Please write an answer' using errcode = '22023';
  end if;
  insert into public.knowledge_items (business_id, question, answer)
  values (q.business_id, q.question, trim(p_answer))
  returning id into item_id;
  update public.unanswered_questions set status = 'answered', knowledge_item_id = item_id where id = q.id;
  return item_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Replying in person
-- ---------------------------------------------------------------------------

-- The send-message edge function calls these as the signed-in person. The
-- first checks they may reply and that WhatsApp still allows a free reply,
-- and gives the numbers to send from and to. The second records the message
-- once WhatsApp has accepted it.
create function public.prepare_person_reply(p_conversation uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  conv public.conversations;
  from_id text;
  to_number text;
begin
  select * into conv from public.conversations where id = p_conversation;
  if not found or not private.is_manager(conv.business_id) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  if conv.last_customer_message_at is null or conv.last_customer_message_at < now() - interval '24 hours' then
    raise exception 'WhatsApp only allows replies within 24 hours of the customer''s last message'
      using errcode = 'P0001';
  end if;
  select b.whatsapp_phone_number_id into from_id from public.businesses b where b.id = conv.business_id;
  select c.whatsapp_number into to_number from public.customers c where c.id = conv.customer_id;
  if from_id is null or to_number is null then
    raise exception 'This chat has no WhatsApp number to reply to' using errcode = 'P0001';
  end if;
  return jsonb_build_object('phone_number_id', from_id, 'to', to_number);
end;
$$;

create function public.record_person_reply(p_conversation uuid, p_body text, p_whatsapp_message_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  conv public.conversations;
begin
  select * into conv from public.conversations where id = p_conversation;
  if not found or not private.is_manager(conv.business_id) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  insert into public.messages (business_id, conversation_id, direction, sender, body, whatsapp_message_id, sent_by)
  values (conv.business_id, conv.id, 'outbound', 'person', p_body, nullif(p_whatsapp_message_id, ''), auth.uid());
  -- Replying in person takes the chat over, so the Assistant doesn't talk over them.
  if conv.handled_by <> 'person' then
    update public.conversations set handled_by = 'person' where id = conv.id;
  end if;
end;
$$;

revoke all on function
  public.today_summary(uuid),
  public.answer_question(uuid, text),
  public.prepare_person_reply(uuid),
  public.record_person_reply(uuid, text, text)
  from public, anon;
grant execute on function
  public.today_summary(uuid),
  public.answer_question(uuid, text),
  public.prepare_person_reply(uuid),
  public.record_person_reply(uuid, text, text)
  to authenticated;
