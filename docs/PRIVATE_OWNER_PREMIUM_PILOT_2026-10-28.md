# Single-email, real-database private owner pilot

Owner-approved invited email: tvmejlza@gmail.com. Premium is complimentary, unlimited duration, payment-free and not a seven-day trial. There is no public signup, release gate, world opening, published legal approval, test environment, fake user, or pre-created airline.

## Production database changes
- 2026-10-28 migration `airlinerra_owner_single_email_unlimited_premium_on_activation_20261028`: private RLS table `airlinerra_game.owner_premium_email_reservations` with one exact normalized email. `start_account_trial_once` now awards `membership_state='active'` and NULL trial timestamps at first real airline activation for the verified matching email only; others retain the normal seven-day trial.
- 2026-10-28 migration `airlinerra_private_one_email_pilot_onboarding_20261028`: private RLS `owner_private_pilot_consents` stores explicit acceptance of the draft review process. `create_airline_once` recognizes the exact verified invited owner with a matching pilot consent as an exception to the PUBLIC legal, World 1 registration and release gates. Other users cannot bypass them. Approved real World 1 airports and atomic $5m credit remain mandatory.
- The pilot acknowledgement is NOT public legal approval. The signup provider remains invitation-only. No commercial billing is available.

## The only real Auth invitation step
Supabase Auth invitations cannot be sent via the current connected Supabase management tools. The operator must open Supabase Dashboard > Authentication > Users > Add user > Send invitation, address tvmejlza@gmail.com, with redirect URL http://localhost:5188/account.html?screen=verify after ensuring that URL is in Auth URL Configuration's redirect allowlist. The real confirmation email comes from Supabase. **Do not create Auth users by direct SQL INSERT.**

## Local integration
`npm run preview` uses the production website and verified Supabase Auth. The private server still requires a privately configured `AIRLINERRA_LOCAL_DATABASE_URL` to the actual Airlinerra Postgres database (never commit or paste it). The pilot flow returns eligible World 1 airports even while public registration remains closed; the manager acknowledges the visibly labelled draft policy, creates a real airline atomically and sees the persisted balance after login. The user can then review real dashboard pages; operational flights remain closed.
