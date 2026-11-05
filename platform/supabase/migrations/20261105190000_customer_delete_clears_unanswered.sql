-- POPIA: when a customer is deleted their chats cascade away; unanswered
-- questions from those chats must go too, so no question text is left behind.
-- The old foreign key used ON DELETE SET NULL, which kept the question row.

-- Orphans left by the old SET NULL behaviour (no live conversation).
delete from public.unanswered_questions where conversation_id is null;

alter table public.unanswered_questions
  drop constraint unanswered_questions_business_id_conversation_id_fkey;

alter table public.unanswered_questions
  add constraint unanswered_questions_business_id_conversation_id_fkey
  foreign key (business_id, conversation_id)
  references public.conversations (business_id, id)
  on delete cascade;
