# IsangoTech Business app

The Flutter web app client businesses sign in to, at `app.isangotech.co.za`. It talks to the **client platform** Supabase project (`platform/supabase`), not IsangoTech's own.

Row-level security in the database decides what each person sees, so the app has no permission logic of its own. Owners see everything. Managers see everything except usage and cost. Staff see only their own bookings.

| Screen | What you can do |
| --- | --- |
| Today | Today's bookings, chats waiting for a person, questions to answer, and WhatsApp conversations this month against the plan (owners) |
| Chats | Every WhatsApp chat, newest first. Open one to read it, take it over from the Assistant, reply on WhatsApp (within WhatsApp's 24-hour window) and hand it back |
| Questions | What the Assistant couldn't answer. **Answer** adds it to the Assistant's answers, so it knows next time |
| Bookings | Two weeks at a time, by day. Mark completed, no-show or cancelled. See what deposit is due, by when and its reference; mark it received or waive it, which confirms the booking |
| Assistant | Switch it on or off, opening hours, languages, tone, policies, topics to always hand over, notice rules, deposits (percentage, how long to hold an unpaid booking, payment link and EFT details), privacy link, how long chats are kept, services and prices, staff, and answers |
| Team | Owners only: add managers and staff (each gets a setup link), change roles, remove or add back |
| Account | Your details, change password, sign out, and two-step sign-in (optional, off by default; once on, the database requires it) |
| Businesses | IsangoTech admins only: every client business, **Add a business** with its owner, edit the plan, and setup links |

New owners get a setup link from IsangoTech, shared on WhatsApp. It opens **Choose your password** (`/set-password`), and from then on they sign in with their email and that password.

Times always show in the business's own time (South African time), whatever the device is set to.

Replying in person goes through the `send-message` edge function. It checks, as the signed-in person, that they may reply and that WhatsApp's window is open; then it sends the message and records it. Replying takes the chat over, so the Assistant doesn't talk over you.

## Running it

```sh
cd platform/app
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://PLATFORM-REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=PLATFORM-PUBLISHABLE-KEY
```

The publishable key is safe to put in the app. Never use the service role key here.

## Building and hosting

```sh
flutter build web --release --no-web-resources-cdn \
  --dart-define=SUPABASE_URL=https://PLATFORM-REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=PLATFORM-PUBLISHABLE-KEY
npx wrangler deploy
```

`wrangler.jsonc` serves `build/web` on Cloudflare Workers at `app.isangotech.co.za`, with every path falling back to `index.html`. The **Deploy business app** GitHub workflow does the same on every push to `main` once its secrets and variables are set.

## Tests

```sh
flutter analyze
flutter test
```
