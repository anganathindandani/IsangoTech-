# Team portal

Flutter Web app for `portal.isangotech.co.za`. Not started yet: it's step 4 of the build plan.

It will sign staff in with Supabase Auth (password plus authenticator-app 2FA) and work directly against the database in `../supabase`. Row-level security there decides what each person can see, so the portal never needs its own permission logic.

Phase 1 screens: sign-in and 2FA enrolment, Settings, Leads (with quick add and activity log), Assessments and booking slots, Clients, Price list, Quotes (with PDF and approval), Invoices and payments, and the audit log.
