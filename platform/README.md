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
| `bookings` | Customer, service, staff, times, status, deposit (amount, status, pay-by time), source (WhatsApp, portal, walk-in) |
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
- `06_onboarding.sql`: only admins onboard, a new business starts switched off, and admins never see customers or chats.
- `07_team.sql`: owners add managers and staff, staff are linked to their bookings, and setup links only for logins that belong to the business alone.
- `08_reminders.sql`: which bookings are due, each claimed once, retries, and a moved booking re-armed.

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

## Onboarding a business

IsangoTech's admins add businesses from the business app's **Businesses** screen. The form takes the business's name, kind, products, conversation allowance and WhatsApp number, and the owner's name and email. One step creates:
- the owner's login, or reuses theirs if they already have one;
- the business, which starts in **Onboarding** with the Assistant switched off;
- their owner membership.

You then get a **setup link** to send the owner on WhatsApp. It signs them in once so they choose their own password. No email is sent, so no email service is needed. **New setup link** on any owner makes a fresh one, for example if they forget their password.

Admins see each business's plan and owners, and can change its status, products, allowance and WhatsApp number. They can't see any business's customers, chats or bookings.

One-time setup:
1. `npx supabase db push --workdir platform`, then deploy the function:
   ```sh
   npx supabase functions deploy onboard-business --workdir platform
   ```
2. **Make yourself an admin** in the SQL editor, after adding yourself under Authentication → Users:
   ```sql
   insert into public.platform_admins (user_id, full_name)
   select id, 'Anganathi Ndandani' from auth.users where email = 'you@isangotech.co.za';
   ```
3. **Let the setup link open the app:** in Authentication → URL Configuration, set the Site URL to `https://app.isangotech.co.za` and add `https://app.isangotech.co.za/set-password` to the Redirect URLs.
4. **Optional: give owners longer to open the link.** By default a setup link works for an hour. Raise the expiry under Authentication → Providers → Email (up to 24 hours), so owners have time to open it.

## Owners' teams

Owners add managers and staff themselves on the business app's **Team** page:
- Each person gets their own login and a setup link, which the owner shares on WhatsApp.
- Staff are linked to a staff record, so they see their own bookings. That's either an existing one or a new one in their name.
- Owners can change someone's role, remove them (they're locked out at once) or add them back.

A setup link lets whoever opens it set the password. So owners only get links for managers and staff whose login belongs to their business alone: never for another owner, an IsangoTech admin, or someone who's also in another business. If an owner adds the email of someone who already has a login, that person gets access to the business and keeps their own password.

Deploy the function once:

```sh
npx supabase functions deploy team-member --workdir platform
```

## Booking reminders

Outside WhatsApp's 24-hour window, a business may only send message templates Meta has approved. Reminders work like this:

1. **The owner switches them on** under Assistant → Reminders. They set how many hours before (24 by default) and the name of their approved template. The page shows the exact template text to submit to Meta: category **Utility**, name `booking_reminder`, with `{{1}}` first name, `{{2}}` service, `{{3}}` business, `{{4}}` day and `{{5}}` time.
2. **Every 15 minutes**, `send-reminders` claims the reminders due and sends them. Due means:
   - a pending or confirmed booking;
   - starting within the window, and more than an hour away;
   - for a customer who booked on WhatsApp or agreed to WhatsApp updates.
3. **Each reminder is recorded** in the customer's chat, and counted as a template message in usage.
4. **Each booking is reminded once.**
   - A claim holds for 10 minutes, so runs never send the same one twice.
   - A failed send is retried after 10 minutes, at most three times.
   - Moving a booking re-arms its reminder.

One-time setup:
1. `npx supabase db push --workdir platform`.
2. Make up a long random secret: `openssl rand -hex 32`.
3. Deploy the function with that secret:
   ```sh
   npx supabase secrets set --workdir platform REMINDERS_SECRET=<the secret>
   npx supabase functions deploy send-reminders --workdir platform --no-verify-jwt
   ```
4. **Schedule it** in the SQL editor. First switch on the `pg_net` extension under Database → Extensions; `pg_cron` is already on. Then run:
   ```sql
   select cron.schedule('send-reminders', '*/15 * * * *', $$
     select net.http_post(
       url := 'https://<platform ref>.supabase.co/functions/v1/send-reminders',
       headers := jsonb_build_object('Content-Type', 'application/json', 'X-Cron-Secret', '<the secret>'),
       body := '{}'::jsonb
     )
   $$);
   ```
5. **Optional:** set `WHATSAPP_TEMPLATE_COST_ZAR` to what Meta charges per template message, so usage shows the cost. Check Meta's current rate card for South Africa.
6. **For each business,** create the template in that business's WhatsApp Manager. Once Meta approves it, switch reminders on in the app.

## Deposits

A business can ask for a deposit to secure WhatsApp bookings. The money goes straight to the business, through its own payment link or EFT; IsangoTech never holds it.

1. **The owner sets it up** under Assistant → Bookings → Ask for a deposit:
   - the percentage of the price;
   - how long to hold an unpaid booking (1 to 72 hours, 24 by default);
   - their payment link (Yoco, SnapScan, PayFast, Zapper or their bank; `https://` only);
   - other ways to pay, such as EFT details (optional).
2. **When the Assistant books,** the booking is **pending** and the customer gets:
   - the amount and how to pay;
   - a reference: the first six characters of the booking's id, also shown in the app;
   - the pay-by time.

   The slot stays taken, and no reminder is sent while the deposit is due.
3. **When the money arrives,** a manager or owner marks it **Deposit received** in Bookings, which confirms the booking. They can also **waive** it, which confirms it too. Staff can't change deposits.
4. **If it isn't paid by the pay-by time,** `send-reminders` releases the booking within 15 minutes and the time is free again. If the customer's 24-hour window is still open, they get a message saying so; otherwise the release is silent.
5. **A paid deposit is never cancelled by the Assistant:** it hands the chat to a person, who deals with the money under the business's own policy.

The pay-by time is the hold period from booking, but always at least an hour before the appointment and never less than 30 minutes away.

Setup: `npx supabase db push --workdir platform`, then redeploy `whatsapp-webhook` and `send-reminders`. Releasing unpaid bookings rides on the `send-reminders` schedule above, so nothing else needs scheduling.

Coming next:
- confirming deposits automatically when a Yoco payment comes in (needs each business's Yoco account connected), instead of marking them by hand.
