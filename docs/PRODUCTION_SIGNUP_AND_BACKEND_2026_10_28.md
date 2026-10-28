# Airlinerra: production registration backend (resolved without Netlify database credentials)

The real game API has been moved to a **Supabase Edge Function** deployed at `https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-game`. This host is inside the existing Airlinerra Supabase project and uses the secure built-in `SUPABASE_DB_URL` environment. The endpoint has been tested live: readiness responds HTTP 200 with `privateOwnerPilotAvailable:true`.

`website/netlify/functions/airlinerra-game.mjs` is a same-origin, authenticated routing bridge to the Supabase Edge API. **Do not set or paste `AIRLINERRA_DATABASE_URL` or `AIRLINERRA_PRODUCTION_API_ENABLED` in Netlify. They are no longer required.** The public Supabase publishable key is safe to include in the browser. Bearer session tokens are forwarded only to the fixed Supabase domain and verified there via the live Auth user service. The actual database credentials are never in GitHub, the browser, or Netlify.

The single previously authorized owner premium account reservation remains in the database. The private pilot onboarding APIs enforce matching verified email, acknowledgement of the review-draft policy, approved real World 1 home airport, and atomic starting balance.

## Operator's exact remaining release steps
1. In Supabase Authentication > Hooks, enable **Before User Created** using `public.airlinerra_owner_signup_gate`. The SQL hook already exists; it restricts new signup to the single owner-approved email during closed public registration. Do this **before** enabling email signups.
2. In Supabase Authentication > Providers / Email, enable new email/password signups and keep **Confirm email** enabled. Supabase's server-side minimum password length must be 8 characters or lower to match the UI; keep reasonable provider security controls.
3. In Supabase Authentication > URL Configuration, set Site URL `https://airlinerra.com` and allow `https://airlinerra.com/account.html?screen=verify` for confirmation and `...screen=reset` for recovery.
4. Manually deploy latest GitHub main with existing `netlify.toml` build (not static dist only). No Netlify secret setup is needed.
5. Verify `https://airlinerra.com/api/v1/registration/readiness` responds HTTP 200 JSON including `privateOwnerPilotAvailable:true` before opening Register.
6. Register using `tvmejlza@gmail.com`, confirm the real email, sign in, acknowledge the labeled private-pilot legal drafts, select real World 1 home airport and create the first real airline. Returning login should show actual in-game $5m and Premium Unlimited.

No new account or airline is fabricated, no public legal drafts are marked approved, no public World 1 unlock or payment is performed.
