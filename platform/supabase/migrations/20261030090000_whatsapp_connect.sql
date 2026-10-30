-- Connecting a business's own WhatsApp number from the app (Meta's Embedded
-- Signup), instead of an IsangoTech admin typing in its phone number id.
--
-- Each connected business gets its own Meta access token, kept where only the
-- edge functions can read it. A business without one (one set up by hand)
-- keeps using the platform's own token.

alter table public.businesses
  -- The WhatsApp Business Account the number belongs to.
  add column whatsapp_waba_id text,
  add column whatsapp_connected_at timestamptz,
  -- The number also stays in the WhatsApp Business app on the owner's phone.
  add column whatsapp_coexistence boolean not null default false;

create table private.whatsapp_credentials (
  business_id uuid primary key references public.businesses (id) on delete cascade,
  access_token text not null check (length(access_token) between 20 and 4000),
  updated_at timestamptz not null default now()
);

comment on table private.whatsapp_credentials is
  'Meta access tokens for connected businesses. Read only by the edge functions, through whatsapp_access_token().';

alter table private.whatsapp_credentials enable row level security;
revoke all on private.whatsapp_credentials from public, anon, authenticated, service_role;

-- Saves a connection once the connect-whatsapp function has exchanged the
-- signup code with Meta and checked the number belongs to the account.
create function public.connect_whatsapp(
  p_business uuid,
  p_phone_number_id text,
  p_display_number text,
  p_waba_id text,
  p_access_token text,
  p_coexistence boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.businesses b
             where b.whatsapp_phone_number_id = trim(p_phone_number_id) and b.id <> p_business) then
    raise exception 'That WhatsApp number is already connected to another business' using errcode = '23505';
  end if;
  update public.businesses set
    whatsapp_phone_number_id = trim(p_phone_number_id),
    whatsapp_display_number = nullif(trim(p_display_number), ''),
    whatsapp_waba_id = trim(p_waba_id),
    whatsapp_connected_at = now(),
    whatsapp_coexistence = coalesce(p_coexistence, false)
  where id = p_business;
  if not found then
    raise exception 'No such business' using errcode = 'P0002';
  end if;
  insert into private.whatsapp_credentials (business_id, access_token)
  values (p_business, p_access_token)
  on conflict (business_id) do update set access_token = excluded.access_token, updated_at = now();
end;
$$;

-- The token to send from a number with: the business's own, or null for the
-- platform's.
create function public.whatsapp_access_token(p_phone_number_id text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select c.access_token
  from public.businesses b
  join private.whatsapp_credentials c on c.business_id = b.id
  where b.whatsapp_phone_number_id = p_phone_number_id;
$$;

revoke all on function public.connect_whatsapp(uuid, text, text, text, text, boolean),
  public.whatsapp_access_token(text) from public, anon, authenticated;
grant execute on function public.connect_whatsapp(uuid, text, text, text, text, boolean),
  public.whatsapp_access_token(text) to service_role;
