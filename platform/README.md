# Client platform

The database behind the two products IsangoTech sells to client businesses: the **WhatsApp Assistant** and the **Business Portal**. It is a separate Supabase project from IsangoTech's own records (`../supabase`), so client data and internal data never mix.

Both products share one set of tables. A booking the Assistant takes on WhatsApp is the same row the Portal shows, so a business can start with either product and add the other without moving data.

## What's here

| Table | Holds |
| --- | --- |
| `businesses` | Each client business: industry, products and modules switched on, WhatsApp number, time zone, monthly conversation allowance |
| `business_members` | Who signs in to which business, as owner, manager or staff |
| `business_settings` | Opening hours, languages, tone, policies, hand-over topics, deposit and notice rules, chat retention. Created with the business; the Assistant starts switched off |
| `staff`, `services`, `service_staff` | Who delivers what, at what price and for how long |
| `knowledge_items` | Facts the Assistant may quote |
| `customers` | The business's customers, with their WhatsApp opt-in |
| `bookings` | Customer, service, staff, times, status, deposit, source (WhatsApp, portal, walk-in) |
| `conversations`, `messages` | One WhatsApp chat per customer, who took over, and the 24-hour reply window |
| `unanswered_questions` | Questions the Assistant handed over, for the owner to answer |
| `usage_events` | WhatsApp conversations, template messages and AI calls, with their cost |
| `audit_log` | Who changed bookings, prices, settings, customers and the team (field names only, never values) |

## The WhatsApp Assistant

A customer messages a business's WhatsApp number. Meta sends the message to the `whatsapp-webhook` edge function, which:

1. Checks Meta's signature on the delivery, then answers Meta straight away and does the rest in the background.
2. Saves the message (`assistant_receive`). It stops there if a WhatsApp retry already delivered the message, if someone on the team has taken over the chat, or if the business hasn't switched the Assistant on.
3. Asks the AI model, through OpenRouter, with the business's details and the last week of the chat.
4. Runs the tools the model asks for (`assistant_tool`), until it has an answer. It allows at most six rounds.
5. Sends the reply on WhatsApp and records it, along with what each AI call cost.

The tools are `find_services`, `check_availability`, `create_booking`, `my_bookings`, `change_booking`, `cancel_booking`, `lookup_answer` and `hand_over`. They run in the database and take only the conversation id, working out the business and customer from it. Whatever the model asks for, it can only see that business's services and free times, and change that customer's own bookings.

Free times respect:
- opening hours;
- each staff member's own hours and which services they do;
- the minimum notice;
- existing bookings.

Changes and cancellations inside the business's notice period go to a person.

Safety nets:
- If the AI fails or never settles on an answer, the chat is handed to a person and the customer is told someone will reply.
- If the customer writes again while a reply is being worked out, only the newest message gets an answer.
- A new customer's first reply links to the business's privacy notice, if one is set.

## Rules the database enforces

- **One business never sees another's data.** Every table carries `business_id`, and row-level security lets a person reach a row only through an active membership of that business. Child rows point at their customer, service or staff member through `(business_id, id)`, so they can't reference another business's records even with a guessed id. Even the double-booking check is scoped to one business, so its error can't reveal another business's bookings.
- **Roles.**
  - **Owner:** everything, including usage, the audit log and the team.
  - **Manager:** daily work (bookings, customers, chats, services, settings), but not billing or the team.
  - **Staff:** see only their own bookings and those customers, and can change only a booking's status and notes.
- **Always an owner.** A business always keeps at least one active owner. Setting someone inactive locks them out at once.
- **Two-step sign-in.** It's optional. Once someone turns it on, their password alone gets them nothing, even through the API.
- **What only IsangoTech changes.** Plans, products, modules, WhatsApp numbers and allowances are IsangoTech's to change; owners can only rename their business.
- **Written only by IsangoTech's edge functions.** Messages and usage are recorded by the edge functions (service role) and can't be edited from the app. A WhatsApp retry never saves a message twice.
- **POPIA.**
  - `private.delete_expired_messages()` deletes chats older than each business's retention period (12 months by default).
  - Deleting a customer removes their bookings and chats.
  - Deleting a business removes everything it had.

## Running the tests

The tests run on plain Postgres 16. `tests/supabase_stub.sql` stands in for Supabase's `auth` schema.

```sh
PGHOST=localhost PGUSER=postgres platform/supabase/tests/run.sh
```

- `01_isolation.sql`: signs in as each role of one business and proves it can't read, change or delete anything in another, for every table.
- `02_roles.sql`: what each role can and can't do inside a business.
- `03_records.sql`: bookings, chats and the POPIA rules.
- `04_assistant.sql`: recording messages, free times and every tool, including that a conversation can't reach another business's services or another customer's bookings.
- `05_dashboard.sql`: the business app's summary for each role, answering questions, and replying in person only within WhatsApp's 24-hour window.

The edge function's tests use a fake database, AI and WhatsApp, so they cost nothing:

```sh
cd platform/supabase/functions && deno task test
```

CI runs them on every push to `main` and on pull requests.

## Going live: one-time setup

1. **Create a second Supabase project** for the platform, in the same region as the main one. Before the first paying client, move it to the Pro plan for daily backups.
2. **Apply the database:**
   ```sh
   supabase link --workdir platform --project-ref <platform ref>
   supabase db push --workdir platform
   ```
3. **Auth settings in the dashboard:** turn off "Allow new users to sign up", enable TOTP multi-factor authentication, and set the minimum password length to 12.
4. **Schedule the chat clean-up** (runs nightly at 02:15 UTC) in the SQL editor:
   ```sql
   create extension if not exists pg_cron;
   select cron.schedule('delete-expired-messages', '15 2 * * *', 'select private.delete_expired_messages()');
   ```

## Switching on the Assistant

1. **Apply the new migrations:** `npx supabase db push --workdir platform`.
2. **Meta app:**
   1. At developers.facebook.com, create a Business app and add the WhatsApp product. The test number it gives you is enough to start.
   2. Note the **Phone number ID** (WhatsApp → API Setup).
   3. Note the **App secret** (App settings → Basic).
   4. Create a permanent access token: Business settings → System users, add a system user, give it the app with `whatsapp_business_messaging`, then generate a token.
3. **Secrets.** These go in Supabase, never in the code:
   ```sh
   npx supabase secrets set --workdir platform \
     WHATSAPP_VERIFY_TOKEN=<any long random string you make up> \
     WHATSAPP_APP_SECRET=<app secret> \
     WHATSAPP_ACCESS_TOKEN=<system user token> \
     OPENROUTER_API_KEY=<OpenRouter key> \
     ASSISTANT_MODEL=anthropic/claude-haiku-5.5
   ```
   Optional settings:
   - `WHATSAPP_GRAPH_VERSION`: default `v23.0`. Use the version Meta's dashboard shows.
   - `USD_TO_ZAR`: default `18`, used to record AI costs in rand.
4. **Deploy:** `npx supabase functions deploy whatsapp-webhook --workdir platform --no-verify-jwt`.
5. **Connect Meta to it:** WhatsApp → Configuration → Webhook.
   1. Set the callback URL to `https://<platform ref>.supabase.co/functions/v1/whatsapp-webhook`.
   2. Use the same verify token as in step 3.
   3. Subscribe to `messages`.
6. **Add a business** in the SQL editor. Until the onboarding screen exists, this is how a business is set up. The demo salon on the test number looks like this:
   ```sql
   with b as (
     insert into public.businesses (name, industry, products, status, whatsapp_phone_number_id)
     values ('Demo Salon', 'salon', '{assistant}', 'active', '<phone number id>')
     returning id
   ), s as (
     insert into public.services (business_id, name, price, price_from, duration_minutes)
     select id, x.name, x.price, x.price_from, x.minutes from b,
       (values ('Box braids', 450, true, 180), ('Wash and blow-dry', 180, false, 60)) as x(name, price, price_from, minutes)
   )
   insert into public.staff (business_id, full_name) select id, 'Ayanda' from b;

   update public.business_settings
   set opening_hours = '{"tue": [["08:00", "17:00"]], "wed": [["08:00", "17:00"]], "thu": [["08:00", "17:00"]],
                         "fri": [["08:00", "18:00"]], "sat": [["07:00", "15:00"]]}',
       languages = '{en,xh}',
       assistant_enabled = true
   where business_id = (select id from public.businesses where name = 'Demo Salon');
   ```
   Then message the test number from your phone. On Meta's test number, your phone must first be added as a recipient under WhatsApp → API Setup.

## The business app

Owners, managers and staff use the Flutter web app in `app/` (see [`app/README.md`](app/README.md)). They can:
- see today's bookings;
- read chats, take them over and reply on WhatsApp;
- answer the questions the Assistant couldn't;
- run the Assistant's settings, services, staff and answers.

Replies go through the `send-message` edge function. Deploy it alongside the webhook:

```sh
npx supabase functions deploy send-message --workdir platform
npx supabase secrets set --workdir platform APP_ORIGINS=https://app.isangotech.co.za
```

To give a business owner a login:
1. Add them under Authentication → Users → **Add user** in the platform project. Tick "auto confirm" and set a password to give them.
2. Run this in the SQL editor:

   ```sql
   insert into public.business_members (business_id, user_id, full_name, role)
   select b.id, u.id, 'Their Name', 'owner'
   from public.businesses b, auth.users u
   where b.name = 'Demo Salon' and u.email = 'owner@example.co.za';
   ```

Coming next:
- an IsangoTech-only onboarding screen that creates the business, its owner and their login in one step;
- owners adding their own team;
- booking reminders, which need message templates Meta has approved.
