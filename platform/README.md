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

Onboarding a business (creating it, its first owner and its WhatsApp number) will be an IsangoTech-only edge function, built with the Assistant.
