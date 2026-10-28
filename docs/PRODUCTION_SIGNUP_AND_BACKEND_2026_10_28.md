# Airlinerra production account release — owner performs final manual deploy

The SAME website build contains a real Netlify Function at `website/netlify/functions/airlinerra-game.mjs`. It handles all canonical `/api/v1/*` player, onboarding and readiness paths, hosted under https://airlinerra.com. The frontend and backend both use the **real Supabase Auth project** and **real Airlinerra database**. No separate test server or invitation is necessary for a normal email signup.

Before owner manually deploys, configure Netlify **site-scoped secret environment variables** (Functions scope, not public browser or GitHub): `AIRLINERRA_PRODUCTION_API_ENABLED=true`; `AIRLINERRA_DATABASE_URL` = a legitimate **Airlinerra Supabase PostgreSQL Session Pooler URL**, with password, from Dashboard Connect; `AIRLINERRA_PUBLIC_SUPABASE_KEY` = the project's existing sb_publishable key. The server rejects another project's DB URL, validates live access tokens via Supabase Auth, uses parameterized owner-scoped queries and a bounded 2-connection PostgreSQL pool. These values must never be committed or pasted in chat.

The owner performs exactly one manual Netlify release from GitHub main, then verifies https://airlinerra.com/api/v1/registration/readiness does **not** return 404 or static HTML (200 JSON if connected, 503 JSON if missing configuration).

To allow actual **standard email/password signup** after deployment, use Supabase Auth > Settings / Providers > Allow new users to sign up = ON; Confirm Email = ON; Anonymous = OFF, Site URL=https://airlinerra.com, allowlist https://airlinerra.com/account.html?screen=verify. This is a **public provider-wide change**, not a user-specific invitation. Registration and airline activation remain different gates.

Owner email tvmejlza@gmail.com is already reserved privately. If that address signs up through the standard form and confirms the email, the private owner pilot can use the closed World 1 and receive permanent complimentary premium **only when the real airline is activated**, with its $5m in-game credit and zero aircraft. No fake account or airplane is created.

The Terms and Privacy pages remain clearly marked review drafts, not final public agreements; the owner pilot separately acknowledges them. Do not mark the global legal policy approved, open World 1 publicly, or enable paid billing merely to test this one owner account. Other accounts remain blocked from game activation until approved published legal documents and the ordinary world release gates exist.
