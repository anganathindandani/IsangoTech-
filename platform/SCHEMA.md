# Client platform: schema, flows and APIs

Reference for the WhatsApp Assistant and the Business Portal foundation, as built on 5 November 2026 (migrations up to `20261030090000_whatsapp_connect.sql`). The table section is generated from a database built from `platform/supabase/migrations`, so it matches the code exactly. Regenerate it after schema changes.

- **Supabase project:** `jsgdlmrwmjbeomfizcia` (separate from the website and ops portal project).
- **Code:** `platform/supabase/migrations` (schema), `platform/supabase/functions` (edge functions), `platform/app` (business app, app.isangotech.co.za).
- **Business Portal:** only its shared foundation exists (customers, services, staff, bookings, deposits). Quotes, invoices, payments and industry modules are not built.

## Authentication and access

- **Logins:** Supabase Auth, email and password. No public sign-up: IsangoTech admins create owners (`onboard-business`), owners create managers and staff (`team-member`). New people get a one-time password-setup link (a Supabase recovery link) shared on WhatsApp; no email is sent.
- **Two-step sign-in:** optional authenticator-app codes. Once a person turns it on, every database check requires an `aal2` session.
- **Roles, per business** (`business_members.role`): `owner` (everything, including usage, team and audit log), `manager` (chats, bookings, questions, settings), `staff` (only their own bookings and those customers; may change only a booking's `status` and `notes`).
- **IsangoTech admins:** rows in `platform_admins` (added in the SQL editor only). They onboard businesses and set plan fields but can't see any business's customers, chats or bookings unless they're also a member.
- **Enforcement:** row-level security on every table, via helpers in the `private` schema: `session_ok`, `is_member`, `is_manager`, `is_owner`, `role_in`, `my_staff_id`, `is_my_customer`, `is_platform_admin`. Child rows reference parents through `(business_id, id)`, so no row can point at another business's data. Column-level grants stop clients changing ids, timestamps, `created_by` and reminder bookkeeping.
- **Server-side callers:** edge functions use the service role, and only the `assistant_*` and other service-role functions below; they never query tables directly with it.
- **Secrets** (Supabase function secrets, never in the app): `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_APP_SECRET`, `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_GRAPH_VERSION`, `OPENROUTER_API_KEY`, `ASSISTANT_MODEL`, `USD_TO_ZAR`, `REMINDERS_SECRET`, `WHATSAPP_TEMPLATE_COST_ZAR`, `APP_ORIGINS`. Per-business Meta tokens live in `private.whatsapp_credentials`.

## Main user flows

### 1. Onboarding a business (IsangoTech admin)
1. Admin signs in to app.isangotech.co.za and opens **Businesses → Add**.
2. The app calls `onboard-business` with the business (name, industry, products, WhatsApp phone number id, allowance) and the owner (name, email).
3. The function checks the caller is a platform admin, finds or creates the owner's login, calls `onboard_business()` (creates `businesses`, the owner's `business_members` row, and `business_settings` via trigger) and returns a setup link.
4. Admin sends the link to the owner on WhatsApp; the owner chooses a password.

### 2. A customer messages the business (Assistant)
1. Meta POSTs to `whatsapp-webhook`. The function checks `X-Hub-Signature-256` with the app secret, answers `200` at once and continues in the background.
2. `assistant_receive()` finds the business by `phone_number_id`, ignores duplicates, upserts the `customers` and `conversations` rows, saves the `messages` row and counts a `usage_events` conversation when a new 24-hour window opens. It returns `reply` only if the Assistant is on and the chat isn't with a person.
3. `assistant_context()` gives the business details, settings, customer and chat history; the prompt (rules + business details cached) goes to OpenRouter with 8 tools.
4. Each tool call runs `assistant_tool(conversation, name, args)`, bound to that conversation's business and customer: `find_services`, `check_availability` (via `private.free_slots`), `create_booking`, `my_bookings`, `change_booking`, `cancel_booking`, `lookup_answer`, `hand_over`. At most 6 rounds.
5. The reply is sent with the business's token (or the platform's) and saved with `assistant_record_reply()`; each AI call is recorded with `assistant_record_ai_call()`.
6. On failure, or when unsure, `hand_over` sets `conversations.handled_by = 'person'` and logs an `unanswered_questions` row.

### 3. Booking with a deposit
1. If `business_settings.deposit_required`, `create_booking` saves the booking as `pending` with `deposit_status = 'requested'`, the amount (percent of the service price) and `deposit_due_by`.
2. The customer gets the amount, the business's payment link or EFT details, a reference (first 6 characters of the booking id) and the pay-by time.
3. A manager marks **Deposit received** (or **Waive**) in the app; the `settle_deposit` trigger confirms the booking.
4. If unpaid by `deposit_due_by`, `release_unpaid_bookings()` (called by `send-reminders`) cancels it and, inside the 24-hour window, messages the customer.

### 4. Reminders
`pg_cron` calls `send-reminders` every 15 minutes with `X-Cron-Secret`. `claim_due_reminders()` claims due bookings (template set, within the reminder window, more than an hour away, WhatsApp booking or opted-in customer, deposit not outstanding; claim held 10 minutes, at most 3 attempts). Each is sent as the business's approved template and recorded with `record_reminder()`.

### 5. Daily use by the business (business app)
- **Today:** `today_summary()` (bookings today, chats waiting, open questions, usage for owners).
- **Chats:** read `conversations`/`messages`; reply in person through `send-message` (`prepare_person_reply()` checks the 24-hour window, `record_person_reply()` saves it and takes the chat over).
- **Questions:** `answer_question()` adds a `knowledge_items` row and closes the question.
- **Bookings:** read and update `bookings` (status, deposit status).
- **Assistant settings:** update `business_settings`, `services`, `staff`, `service_staff`, `knowledge_items`.
- **Team (owners):** `team_members()` lists the team; `team-member` adds people or creates setup links (`add_team_member()`, `team_link_target()`).

## APIs already built

### Edge functions (`https://jsgdlmrwmjbeomfizcia.supabase.co/functions/v1/<name>`)

| Function | Called by | Auth | Input → output |
| --- | --- | --- | --- |
| `whatsapp-webhook` | Meta | `GET`: `hub.verify_token`. `POST`: `X-Hub-Signature-256` HMAC with the app secret. JWT check off. | Meta webhook payload → `200 ok`, then replies on WhatsApp |
| `send-message` | Business app | Signed-in user's JWT; database checks they're a manager or owner of that chat's business | `{conversation_id, body}` → `{ok: true, whatsapp_message_id}` or `{error}` |
| `onboard-business` | Business app | JWT of a platform admin | `{business:{name, industry, products[], whatsapp_phone_number_id?, whatsapp_display_number?, monthly_conversation_allowance?}, owner:{full_name, email}}` → `{business_id, new_login, setup_link}`; or `{action:"link", email}` → `{setup_link}` |
| `team-member` | Business app | JWT of the business's owner | `{business_id, email, full_name, role, staff_id?}` (role: manager or staff) → `{new_login, setup_link}` (`setup_link` is null when the login also belongs elsewhere); or `{action:"link", business_id, email}` → `{setup_link}` |
| `send-reminders` | `pg_cron` | `X-Cron-Secret` header. JWT check off. | `{}` → `{released, notified, due, sent, failed}` |

### Database functions (PostgREST RPC, `POST /rest/v1/rpc/<name>`)

| Function | Arguments | Returns | Who may call |
| --- | --- | --- | --- |
| `add_team_member` | `p_business uuid, p_user uuid, p_full_name text, p_role text, p_staff_id uuid` | void | edge functions only |
| `admin_businesses` | — | jsonb | signed-in users (checked inside) |
| `admin_update_business` | `p_business uuid, p_values jsonb` | void | signed-in users (checked inside) |
| `answer_question` | `p_question uuid, p_answer text` | uuid | signed-in users (checked inside) |
| `assistant_context` | `p_conversation uuid` | jsonb | edge functions only |
| `assistant_receive` | `p_phone_number_id text, p_from text, p_profile_name text, p_whatsapp_message_id text, p_body text` | jsonb | edge functions only |
| `assistant_record_ai_call` | `p_conversation uuid, p_model text, p_input_tokens integer, p_cached_input_tokens integer, p_output_tokens integer, p_cost_zar numeric` | void | edge functions only |
| `assistant_record_reply` | `p_conversation uuid, p_body text, p_whatsapp_message_id text` | void | edge functions only |
| `assistant_tool` | `p_conversation uuid, p_name text, p_args jsonb` | jsonb | edge functions only |
| `claim_due_reminders` | `p_limit integer` | jsonb | edge functions only |
| `connect_whatsapp` | `p_business uuid, p_phone_number_id text, p_display_number text, p_waba_id text, p_access_token text, p_coexistence boolean` | void | edge functions only |
| `is_business_owner` | `p_business uuid` | boolean | signed-in users (checked inside) |
| `is_platform_admin` | — | boolean | signed-in users (checked inside) |
| `onboard_business` | `p_business jsonb, p_owner_user uuid, p_owner_name text` | uuid | edge functions only |
| `prepare_person_reply` | `p_conversation uuid` | jsonb | signed-in users (checked inside) |
| `record_person_reply` | `p_conversation uuid, p_body text, p_whatsapp_message_id text` | void | signed-in users (checked inside) |
| `record_reminder` | `p_booking uuid, p_whatsapp_message_id text, p_body text, p_cost_zar numeric` | void | edge functions only |
| `release_unpaid_bookings` | `p_limit integer` | jsonb | edge functions only |
| `team_link_target` | `p_business uuid, p_email text` | uuid | edge functions only |
| `team_members` | `p_business uuid` | jsonb | signed-in users (checked inside) |
| `today_summary` | `p_business uuid` | jsonb | signed-in users (checked inside) |
| `usage_this_month` | `p_business uuid` | TABLE(conversations bigint, allowance integer, cost_zar numeric) | signed-in users (checked inside) |
| `user_id_by_email` | `p_email text` | uuid | edge functions only |
| `whatsapp_access_token` | `p_phone_number_id text` | text | edge functions only |

Plain table reads and writes from the app go through PostgREST (`/rest/v1/<table>`) with the user's JWT, limited by the row-level security policies.

### Allowed values

| Column | Values |
| --- | --- |
| `businesses.status` | onboarding, active, paused, closed |
| `businesses.industry` | salon, guesthouse, restaurant, caterer, other |
| `businesses.products` | assistant, portal |
| `business_members.role` | owner, manager, staff |
| `bookings.status` | pending, confirmed, completed, cancelled, no_show |
| `bookings.source` | whatsapp, portal, walk_in |
| `bookings.deposit_status` | not_required, requested, paid, waived, refunded |
| `conversations.handled_by` | assistant, person |
| `messages.direction` / `sender` | inbound, outbound / customer, assistant, person |
| `unanswered_questions.status` | open, answered, dismissed |
| `usage_events.kind` | whatsapp_conversation, whatsapp_template, ai_call |

Note: `businesses.industry` doesn't yet include the business plan's phase 2 industries (auto repair, cleaning and security, tutoring, gyms); they'd be onboarded as `other` today.

## Tables

All tables are in `public` unless shown otherwise, and all have row-level security on.

### `private.whatsapp_credentials`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `business_id` | uuid | no |  |
| `access_token` | text | no |  |
| `updated_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (business_id)`

### `public.audit_log`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | bigint | no |  |
| `business_id` | uuid | no |  |
| `table_name` | text | no |  |
| `record_id` | text | yes |  |
| `action` | text | no |  |
| `changed_fields` | text[] | yes |  |
| `changed_by` | uuid | yes |  |
| `changed_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`

### `public.bookings`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `business_id` | uuid | no |  |
| `customer_id` | uuid | no |  |
| `service_id` | uuid | yes |  |
| `staff_id` | uuid | yes |  |
| `starts_at` | timestamptz | no |  |
| `ends_at` | timestamptz | no |  |
| `party_size` | int | yes |  |
| `status` | text | no | `confirmed` |
| `source` | text | no |  |
| `deposit_amount` | numeric | no | `0` |
| `deposit_status` | text | no | `not_required` |
| `notes` | text | no | `` |
| `reminder_sent_at` | timestamptz | yes |  |
| `created_by` | uuid | yes |  |
| `created_at` | timestamptz | no | `now()` |
| `updated_at` | timestamptz | no | `now()` |
| `reminder_attempts` | int | no | `0` |
| `reminder_claimed_at` | timestamptz | yes |  |
| `deposit_due_by` | timestamptz | yes |  |
| `deposit_paid_at` | timestamptz | yes |  |

- Foreign key: `FOREIGN KEY (business_id, service_id) REFERENCES services(business_id, id)`
- Foreign key: `FOREIGN KEY (business_id, staff_id) REFERENCES staff(business_id, id)`
- Foreign key: `FOREIGN KEY (business_id, customer_id) REFERENCES customers(business_id, id) ON DELETE CASCADE`
- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`
- Exclusion: staff member can't have overlapping pending/confirmed bookings (per business)

### `public.business_members`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `business_id` | uuid | no |  |
| `user_id` | uuid | no |  |
| `full_name` | text | no |  |
| `role` | text | no |  |
| `active` | bool | no | `true` |
| `created_at` | timestamptz | no | `now()` |
| `updated_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE`
- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (business_id, user_id)`

### `public.business_settings`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `business_id` | uuid | no |  |
| `opening_hours` | jsonb | no | `{}` |
| `languages` | text[] | no | `ARRAY['en']` |
| `tone` | text | no | `Friendly and professional` |
| `policies` | text | no | `` |
| `handover_topics` | text | no | `` |
| `min_booking_notice_hours` | int | no | `2` |
| `change_notice_hours` | int | no | `24` |
| `deposit_required` | bool | no | `false` |
| `deposit_percent` | numeric | no | `0` |
| `privacy_notice_url` | text | yes |  |
| `message_retention_months` | int | no | `12` |
| `assistant_enabled` | bool | no | `false` |
| `updated_at` | timestamptz | no | `now()` |
| `reminders_enabled` | bool | no | `false` |
| `reminder_hours_before` | int | no | `24` |
| `reminder_template` | text | yes |  |
| `reminder_template_language` | text | no | `en` |
| `deposit_payment_link` | text | yes |  |
| `deposit_payment_instructions` | text | no | `` |
| `deposit_hold_hours` | int | no | `24` |

- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (business_id)`

### `public.businesses`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `name` | text | no |  |
| `industry` | text | no |  |
| `products` | text[] | no | `{}[]` |
| `modules` | text[] | no | `{}[]` |
| `status` | text | no | `onboarding` |
| `time_zone` | text | no | `Africa/Johannesburg` |
| `whatsapp_phone_number_id` | text | yes |  |
| `whatsapp_display_number` | text | yes |  |
| `monthly_conversation_allowance` | int | no | `300` |
| `created_at` | timestamptz | no | `now()` |
| `updated_at` | timestamptz | no | `now()` |
| `whatsapp_waba_id` | text | yes |  |
| `whatsapp_connected_at` | timestamptz | yes |  |
| `whatsapp_coexistence` | bool | no | `false` |

- Primary key: `PRIMARY KEY (id)`
- Unique: `UNIQUE (whatsapp_phone_number_id)`

### `public.conversations`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `business_id` | uuid | no |  |
| `customer_id` | uuid | no |  |
| `handled_by` | text | no | `assistant` |
| `taken_over_by` | uuid | yes |  |
| `taken_over_at` | timestamptz | yes |  |
| `last_customer_message_at` | timestamptz | yes |  |
| `last_message_at` | timestamptz | yes |  |
| `created_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id, customer_id) REFERENCES customers(business_id, id) ON DELETE CASCADE`
- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`
- Unique: `UNIQUE (business_id, id)`
- Unique: `UNIQUE (business_id, customer_id)`

### `public.customers`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `business_id` | uuid | no |  |
| `full_name` | text | yes |  |
| `whatsapp_number` | text | yes |  |
| `email` | text | yes |  |
| `notes` | text | no | `` |
| `whatsapp_opt_in` | bool | no | `false` |
| `whatsapp_opt_in_at` | timestamptz | yes |  |
| `created_at` | timestamptz | no | `now()` |
| `updated_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`
- Unique: `UNIQUE (business_id, whatsapp_number)`
- Unique: `UNIQUE (business_id, id)`

### `public.knowledge_items`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `business_id` | uuid | no |  |
| `question` | text | no |  |
| `answer` | text | no |  |
| `active` | bool | no | `true` |
| `created_at` | timestamptz | no | `now()` |
| `updated_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`
- Unique: `UNIQUE (business_id, id)`

### `public.messages`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `business_id` | uuid | no |  |
| `conversation_id` | uuid | no |  |
| `direction` | text | no |  |
| `sender` | text | no |  |
| `body` | text | no |  |
| `whatsapp_message_id` | text | yes |  |
| `sent_by` | uuid | yes |  |
| `created_at` | timestamptz | no | `clock_timestamp()` |

- Foreign key: `FOREIGN KEY (business_id, conversation_id) REFERENCES conversations(business_id, id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`
- Unique: `UNIQUE (whatsapp_message_id)`

### `public.platform_admins`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `user_id` | uuid | no |  |
| `full_name` | text | no |  |
| `created_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (user_id)`

### `public.service_staff`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `business_id` | uuid | no |  |
| `service_id` | uuid | no |  |
| `staff_id` | uuid | no |  |

- Foreign key: `FOREIGN KEY (business_id, service_id) REFERENCES services(business_id, id) ON DELETE CASCADE`
- Foreign key: `FOREIGN KEY (business_id, staff_id) REFERENCES staff(business_id, id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (service_id, staff_id)`

### `public.services`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `business_id` | uuid | no |  |
| `name` | text | no |  |
| `description` | text | no | `` |
| `price` | numeric | yes |  |
| `price_from` | bool | no | `false` |
| `duration_minutes` | int | yes |  |
| `active` | bool | no | `true` |
| `created_at` | timestamptz | no | `now()` |
| `updated_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`
- Unique: `UNIQUE (business_id, id)`

### `public.staff`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `business_id` | uuid | no |  |
| `full_name` | text | no |  |
| `user_id` | uuid | yes |  |
| `working_hours` | jsonb | no | `{}` |
| `active` | bool | no | `true` |
| `created_at` | timestamptz | no | `now()` |
| `updated_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id, user_id) REFERENCES business_members(business_id, user_id) ON DELETE SET NULL (user_id)`
- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`
- Unique: `UNIQUE (business_id, id)`
- Unique: `UNIQUE (business_id, user_id)`

### `public.unanswered_questions`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | uuid | no | `gen_random_uuid()` |
| `business_id` | uuid | no |  |
| `conversation_id` | uuid | yes |  |
| `question` | text | no |  |
| `status` | text | no | `open` |
| `knowledge_item_id` | uuid | yes |  |
| `created_at` | timestamptz | no | `now()` |
| `updated_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id, conversation_id) REFERENCES conversations(business_id, id) ON DELETE SET NULL (conversation_id)`
- Foreign key: `FOREIGN KEY (business_id, knowledge_item_id) REFERENCES knowledge_items(business_id, id) ON DELETE SET NULL (knowledge_item_id)`
- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Primary key: `PRIMARY KEY (id)`

### `public.usage_events`

| Column | Type | Null | Default |
| --- | --- | --- | --- |
| `id` | bigint | no |  |
| `business_id` | uuid | no |  |
| `kind` | text | no |  |
| `conversation_id` | uuid | yes |  |
| `model` | text | yes |  |
| `input_tokens` | int | yes |  |
| `cached_input_tokens` | int | yes |  |
| `output_tokens` | int | yes |  |
| `cost_zar` | numeric | no | `0` |
| `created_at` | timestamptz | no | `now()` |

- Foreign key: `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- Foreign key: `FOREIGN KEY (business_id, conversation_id) REFERENCES conversations(business_id, id) ON DELETE SET NULL (conversation_id)`
- Primary key: `PRIMARY KEY (id)`
## Connecting to the internal ops portal later

The ops portal (portal.isangotech.co.za, code in `portal/`, database in `supabase/`) runs on a **different Supabase project**. It holds IsangoTech's own records: `leads`, `clients`, `contacts`, `assessments`, `quotes`, `quote_line_items`, `invoices`, `payments`, `care_plans`, `projects`, `tasks`, `tickets`, `packages`, `team_members`, `settings`, `audit_log`. There is no link to the platform today.

What a link would need:

1. **A shared key between a client and a business.** Add `platform_business_id uuid unique` to the ops portal's `clients` (or `ops_client_id uuid` to the platform's `businesses`). Neither exists yet. Set it when a client is onboarded.
2. **Onboarding from the ops portal.** A "Set up on platform" action on a client that calls the platform's `onboard-business` function. That needs a server-to-server credential: a dedicated platform admin login for the ops portal, or a new function guarded by a shared secret (like `X-Cron-Secret`). The ops portal's users are a different Auth user pool, so their JWTs aren't valid on the platform.
3. **Usage for billing.** A platform function (service role, secret-protected) that returns per business per month: conversations (`usage_events.kind = 'whatsapp_conversation'`), template messages, AI cost in rand (`cost_zar`), and the allowance. The ops portal would pull it monthly (a scheduled function) to add usage lines or check fair-use limits on invoices. Today `usage_this_month()` covers one business for its own owner only.
4. **Status sync.** When a client is paused or closed in the ops portal (unpaid invoices, cancellation), set `businesses.status` on the platform through `admin_update_business()` (or a secret-protected equivalent). The Assistant and reminders only run for `onboarding` and `active` businesses.
5. **Support and health signals (optional).** Counts of open hand-overs and unanswered questions per business, so the ops portal's `tickets` can show which clients need help.
6. **Keep personal data where it is.** Customers' chats and bookings belong to each client business (IsangoTech is their operator under POPIA). Sync only business-level ids, status and usage totals into the ops portal, never customer names, numbers or messages.
7. **Matching vocabulary.** The ops portal's `industries` table (now including the plan's phase 2 industries) and `packages` don't match the platform's `businesses.industry` check and `products` values; map them, or widen the platform's list, before syncing.
