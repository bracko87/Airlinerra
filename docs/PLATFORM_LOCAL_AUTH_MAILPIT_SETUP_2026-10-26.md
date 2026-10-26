# Airlinerra — Local-only Auth setup and email test plan (2026-10-26)

**Original task:** Player registration, email verification, login and password recovery.  
**Status:** Local-development configuration and browser preview **implemented in code**; real Supabase local-stack email delivery **not yet run end to end**.  
**Data safety:** This setup **does not** connect to the central Airlinerra airport-research database.

## Why local first

The connected Supabase account currently contains **three** established projects: Airlinerra (research), Tennis Legacy and ProPeloton Manager. It has **no independent Airlinerra development project**. We must not use the research project for test signups or create a potentially billable new hosted project without agreeing to its cost. The local Supabase CLI runs on a developer's own computer/Docker installation, with email captured by local Mailpit rather than sent externally.

Official Supabase references:
- [Test Auth flows using Mailpit](https://supabase.com/docs/guides/auth/testing-auth-flows)
- [Local email template configuration](https://supabase.com/docs/guides/local-development/customizing-email-templates)
- [Auth email templates](https://supabase.com/docs/guides/auth/auth-email-templates)

## Committed local-only files

- `supabase/config.toml`: a distinct `airlinerra-local-auth` project, `http://localhost:5187` callback URL and **`enable_confirmations=true`**. No cloud project ID, production database URL, migration deployment or hosted credentials.
- `supabase/templates/confirmation.html`: direct `{{ .TokenHash }}` browser callback with `screen=verify&type=email`.
- `supabase/templates/recovery.html`: direct `{{ .TokenHash }}` browser callback with `screen=reset&type=recovery`. This matters because ordinary PKCE `code` exchange is **not** accepted as proof of recovery by the browser service.
- `website/dev-scripts/dev-local-auth.mjs`: an **explicitly opt-in localhost HTTP server**. It only binds `127.0.0.1`, only targets local Supabase Auth `http://127.0.0.1:54321` (or the localhost equivalent), requires a local public key, and overlays the account page's Auth release switch **in memory**. The committed source and the published static site retain `PUBLIC_AUTH_ENABLED=false`. The preview displays a clear disclaimer that test credentials are submitted to **local** Supabase, not to Airlinerra production.
- `tests/test_supabase_dev_email_contract.mjs`: five native tests that parse the two templated links through the actual Auth callback code and check recovery-only, one-use authorization.
- `tests/test_local_auth_preview.mjs`: four native HTTP tests for explicit opt-in, loopback host checks, no production/airport targets, safe headers, and disabled private game API routes.
- `website/package.json`: `npm run dev:auth:local` starts the new server and the test suite includes these nine new checks.

## Developer setup (local computer only)

1. Install Docker and the Supabase CLI using the latest official instructions. **Do not** run `supabase link`, `supabase db push`, `supabase config push`, or connect this setup to an existing hosted project.
2. At the **Airlinerra repository root**, start the local test stack:

   ```bash
   supabase --version
   supabase start
   supabase status
   ```

3. Read `supabase status` and copy the **local `sb_publishable_...` key**. The local Auth API should be `http://127.0.0.1:54321`; Mailpit is normally at `http://127.0.0.1:54324`. Do **not** copy any `service_role`, `sb_secret_` or hosted project key.

4. In another terminal:

   ```bash
   cd website
   export AIRLINERRA_LOCAL_AUTH_TEST=1
   export AIRLINERRA_LOCAL_PUBLISHABLE_KEY='sb_publishable_YOUR_LOCAL_KEY_FROM_SUPABASE_STATUS'
   npm run dev:auth:local
   ```

5. Open **http://localhost:5187/account.html** (not the production domain). Use a synthetic test email and a unique password unrelated to real accounts.
6. Sign up and open the **local Mailpit** message for the confirmation link. Confirm the email, then sign in. Request password recovery, open the second Mailpit email and verify the recovery-only link. Complete one password change; reused or wrong-purpose links should be refused.
7. Stop the browser preview with Ctrl+C and the local Supabase stack with `supabase stop`. No emails should leave Mailpit and no hosted project is required.

**Important limits:** The local Auth preview is **not** a complete working airline game. The private `airlinerra_game` account tables are not installed in the local Supabase CLI stack by this config, and `/api/v1/airlines` and `/api/v1/legal/consents` are intentionally **not exposed by the preview**. Profile saving and airline creation therefore remain nonoperational there. In particular, merely adding airport activation records in the airport research schema never grants gameplay approval.

## Release status and next milestone

- **Implemented:** local Auth configuration, correct OTP email callbacks, explicit development browser preview, protection against accidentally targeting the airport-research project.
- **Native CI:** Node/browser tests and disposable PostgreSQL test are run in the existing non-deploying GitHub workflow. **CI does not start the full Supabase Auth/Mailpit stack**, so it cannot by itself certify email delivery.
- **Still blocked:** first genuine local Supabase/Mailpit registration-login-recovery run; a separate owner-approved dev hosting environment if remote testing is needed; published legal documents; secure player-account database deployment; real account API deployment; public SMTP/domain; payments.

Do not enable public registration, use actual customer information, or claim the entire onboarding journey works until those steps have been verified.
