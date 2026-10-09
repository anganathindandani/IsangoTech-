# IsangoTech

One system with two faces: a public website that wins clients, and a private team portal that runs the business from first enquiry to monthly support. Both share one Supabase database, so website enquiries land straight in the portal.

| Folder | What it is | Status |
| --- | --- | --- |
| `brand/` | Logo files, colours and usage rules | Done |
| `supabase/` | Database, security rules, website intake functions | Phase 1 done and tested |
| `website/` | Astro site for `isangotech.co.za` | Phase 1 pages built |
| `portal/` | Flutter Web app for `portal.isangotech.co.za` | Phase 1 screens built and tested |

## Database (`supabase/`)

`migrations/` holds every table from the spec, plus the business rules that keep the data honest:

- **Access:** only an active admin can reach any record. Two-step sign-in (an authenticator app code after the password) is optional and off by default; each person turns it on or off in the portal's Settings. Once someone has turned it on, their password alone gets them nothing, even through the API. Inactive staff and other roles see nothing. Anonymous visitors can't read or write any table.
- **Website intake:** the Get started form goes through the `submit-enquiry` edge function. It checks for spam (Cloudflare Turnstile and a hidden honeypot field), then creates the lead, its consent records and any assessment booking in one step.
- **Quotes:** quotes are numbered `Q-2026-0001`. Totals are worked out from the line items. A quote whose first-year value is above the approval amount can't be sent until an admin approves it, and editing it afterwards clears the approval. Sent quotes are locked. Accepting a quote makes the client active and marks the lead won; declining sends the lead back for follow-up.
- **Invoices:** an invoice gets its number (`INV-2026-0001`) when it's sent, so deleted drafts leave no gaps. Sent invoices are locked. Partial payments are supported and overpayments are refused. `invoice_summaries` shows the balance, paid/part-paid/unpaid and overdue.
- **History:** every change is written to the audit log by the database itself. It records who changed which fields and when, but not the values, so anonymised personal details don't survive there. Nobody can edit the audit log. Growth-stage changes are recorded per client.
- **POPIA:** consent records the privacy policy version each person agreed to. `private.apply_retention()` anonymises leads that never converted and lost prospects once their retention period has passed. It will be scheduled to run automatically in phase 2.

### Running the tests

The tests run on plain Postgres 16. A small stand-in for Supabase's `auth` and `storage` schemas lives in `supabase/tests/supabase_stub.sql`.

```sh
PGHOST=localhost PGUSER=postgres supabase/tests/run.sh       # database
cd supabase/functions && deno task test                      # edge functions
```

CI runs both, plus the website build and the portal's checks, on every push to `main` and on pull requests.

## Website (`website/`)

Home (with the stage picker), Solutions (salons, restaurants, caterers and other small businesses), Services and pricing, About, Get started, Contact, Privacy policy, Terms and a 404 page. Fonts are served from the site itself, and the Google map on the Contact page loads only when someone taps "Show map".

Most content lives in plain data files, so it can be edited without touching the page layouts:

| File | What's in it |
| --- | --- |
| `src/site.ts` | WhatsApp number, phone, email, registration number, social links, founder, Information Officer, VAT status. Anything left empty is hidden. |
| `src/data/packages.ts` | Packages and their "from" prices. A package with no price shows "Price on request". |
| `src/data/stages.ts` | The four growth stages. |
| `src/data/industries.ts` | Solutions pages: pains and what we offer at each stage. |
| `src/data/testimonials.ts` | Client quotes. The Home page hides this section while the list is empty. |

The Get started form talks to the Supabase edge functions. Build with:

```sh
cd website
PUBLIC_SUPABASE_FUNCTIONS_URL=https://<ref>.supabase.co/functions/v1 \
PUBLIC_TURNSTILE_SITE_KEY=<from Cloudflare Turnstile> npm run build
```

Without `PUBLIC_SUPABASE_FUNCTIONS_URL`, the form is replaced by a message pointing people to WhatsApp. The privacy policy and terms show a "Draft" notice until `legalReviewed` is set to `true` in `src/site.ts`.

## Portal (`portal/`)

Flutter Web app for staff. See [`portal/README.md`](portal/README.md) for what each screen does and how to run, test and build it.

## Going live: one-time setup

1. **Create the Supabase project** in the London (`eu-west-2`) or Frankfurt (`eu-central-1`) region.
2. **Apply the database:** `supabase link --project-ref <ref>`, then `supabase db push`.
3. **Deploy the edge functions:** `supabase functions deploy submit-enquiry enquiry-options --no-verify-jwt`.
4. **Set the function secrets:**
   ```sh
   supabase secrets set TURNSTILE_SECRET_KEY=<from Cloudflare Turnstile> \
     ALLOWED_ORIGINS=https://isangotech.co.za,https://www.isangotech.co.za
   ```
5. **Auth settings in the dashboard:** turn off "Allow new users to sign up", enable TOTP (authenticator app) multi-factor authentication, and set the minimum password length to 12.
6. **Create the first admin:** invite yourself under Authentication → Users, then run this in the SQL editor:
   ```sql
   insert into public.team_members (id, full_name, role, email)
   select id, 'Your Name', 'admin', email from auth.users where email = 'you@isangotech.co.za';
   ```
   Then sign in to the portal. Turning on two-step sign-in under Settings is recommended.
7. **Fill in Settings in the portal:** your bank details for invoices, and check the approval amount and retention periods.

## Settings to confirm

These are starting values in the `settings` table. An admin can change them at any time.

| Setting | Starting value |
| --- | --- |
| `quote_approval_amount` | R20 000 first-year value |
| `quote_valid_days` | 30 |
| `invoice_due_days` | 7 |
| `lead_retention_months` / `lost_prospect_retention_months` | 12 / 12 |
| `booking_min_notice_hours` / `booking_window_days` | 24 / 60 |
| `next_stage_review_months` | 3 |
| `vat_registered` | false |
| `invoice_payment_details` | Empty. Add your bank details so they print on invoices |

The price list is empty. Packages are added in the portal once names and prices are decided. `supabase/seed.sql` holds placeholder packages for local development only.
