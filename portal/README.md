# Team portal

Flutter Web app for `portal.isangotech.co.za`. Staff sign in with Supabase Auth using their email and password. Two-step sign-in (a code from an authenticator app) is optional and off by default; each person turns it on or off under **Settings**, and once it's on, the code is required every time. The database's row-level security decides what each person can see, so the portal has no permission logic of its own. In Phase 1 that means an active admin sees everything and nobody else sees anything.

## What's in Phase 1

| Screen | What you can do |
| --- | --- |
| Today | Follow-ups due, new leads, this week's assessments, quotes waiting for approval, overdue invoices |
| Leads | Every enquiry, filtered by pipeline stage, with search. **Quick add** for WhatsApp, walk-in and phone enquiries, recording the person's consent. Each lead has an activity log, follow-up date, consents, assessments and **Create quote** |
| Clients | Prospects and clients, with growth stage and its history, next-stage review date, contacts, quotes, invoices and activity |
| Assessments | Upcoming and past AI Readiness Assessments (notes, findings, recommended package) and the booking slots the website offers |
| Quotes | Line items from the price list or custom. Quotes above the approval amount need **Approve** before **Mark as sent**. Then Accepted / Declined / Expired. Branded PDF download. **Create setup invoice** from an accepted quote |
| Invoices | Drafts get a number when marked as sent. Record full or partial payments, void unpaid invoices, branded PDF with your payment details |
| Price list | Packages by growth stage, once-off or monthly |
| Settings | Your two-step sign-in (on or off), approval amount, quote and invoice terms, VAT status, privacy policy version, retention periods, booking rules, payment details on invoices |
| Audit log | Who added, changed, deleted or exported what, and when |

Downloading a quote or invoice PDF is recorded in the audit log as an export.

## Running it

You need Flutter (stable) and a Supabase project, either the live one or a local one from `supabase start`.

```sh
cd portal
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLISHABLE-KEY
```

The publishable key (or the older "anon" key) is safe to put in the app. Never use the service role key here.

## Building for production

```sh
flutter build web --release --no-web-resources-cdn \
  --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLISHABLE-KEY
```

`--no-web-resources-cdn` bundles Flutter's rendering engine with the app, so it doesn't load it from Google's servers. Host `build/web` on any static host (Cloudflare Pages, Netlify) at `portal.isangotech.co.za`, with every path falling back to `index.html` so links like `/leads/…` work after a refresh. Add `https://portal.isangotech.co.za` to the Supabase project's allowed redirect URLs.

## Tests

```sh
flutter analyze
flutter test                      # PDF tests; the integration tests skip themselves
```

`test/integration/repository_test.dart` runs every database call the portal makes against a real Supabase API, with real sign-in and 2FA: two-step sign-in on and off, lead to client to quote to approval to invoice to payment, bookings, price list, contacts, settings and the audit log. It needs a **local or throwaway** project, never the live one:

```sh
SUPABASE_TEST_URL=http://127.0.0.1:54321 \
SUPABASE_TEST_ANON_KEY=... SUPABASE_TEST_SERVICE_KEY=... \
flutter test test/integration
```

## Code layout

| Path | What it is |
| --- | --- |
| `lib/data/repository.dart` | Every database call. Screens never build queries themselves |
| `lib/data/models.dart` | One class per record |
| `lib/auth/` | Sign-in, 2FA setup, 2FA code, no-access screens |
| `lib/app.dart` | Routes, sign-in gate (password, then 2FA, then team access) and the navigation shell |
| `lib/pages/` | One file per screen; `dialogs.dart` holds the shared edit dialogs |
| `lib/pdf/documents.dart` | Branded quote and invoice PDFs |
| `assets/` | Outfit and DM Sans fonts (SIL Open Font License) and the logo |

## Accessibility

Cards don't merge their contents into a single screen-reader element (`semanticContainer: false`), so lists and forms read item by item. The 2FA code field deliberately doesn't grab focus on its own, because in Flutter web that stops typing from reaching the field when a screen reader is on.
