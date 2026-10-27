# Airlinerra — Netlify account API staged safely (27 October 2026)

## Status

**Source implementation and CI checks only. NOT deployed.**

The permanent public Airlinerra homepage is `https://airlinerra.com/`; Netlify continuously publishes the static `website/` build from GitHub `main`. The new Netlify Function source lives at:

- `server/netlify-preview-template/airlinerra-accounts.mjs`

**It deliberately does NOT reside in `website/netlify/functions/` or `netlify/functions/`.** No `[functions]` directory has been added to `netlify.toml`; the current build script copies only explicit static website assets into `dist/`. Netlify will NOT discover or deploy this staged source under its current configuration. There are no live `/api/v1/...` account endpoints.

Netlify's own documentation states that every supported file in its configured functions directory is prepared and deployed automatically. Moving this file into the active functions directory is a separate release action: https://docs.netlify.com/build/functions/configuration/.

## Completed implementation

- A Netlify-standard default-export Web Request/Response adapter with **exactly three planned POST routes**:
  - `/api/v1/onboarding/context`
  - `/api/v1/legal/consents`
  - `/api/v1/airlines`
- Two independent server-side activation flags, `AIRLINERRA_HOSTED_BACKEND_ENABLED` and `AIRLINERRA_PRIVATE_PREVIEW_APPROVED`, are required to be precisely `true`. Otherwise every request returns a generic 503 without loading credentials, opening a pool or checking tokens.
- The adapter also checks `CONTEXT` for `deploy-preview` or `branch-deploy` on **each request**, including requests in a warm function container. Production is always refused even if flags are mistakenly set.
- A successful preview reuses a single in-memory app instance and bounded PostgreSQL pool; failed initialization hides internal errors.
- The previously staged `server/preview-account-app.mjs` uses a verified Supabase Auth user lookup, the existing protected game/consent services, strict origin validation, and at most two TLS-verified Postgres connections.
- **Important security fix:** `server/hosted-runtime-config.mjs` now validates but strips `sslmode=require` from the PostgreSQL URL before passing it to `pg`. The Node `pg` driver otherwise replaces the supplied `ssl` object and may ignore `rejectUnauthorized:true`, according to its upstream documentation: https://node-postgres.com/features/ssl.
- Preview config rejects `airlinerra.com`, `www.airlinerra.com` and `airlinerra.netlify.app` as origins. These are production/public website addresses, not isolated preview hostnames.
- `tests/test_staged_netlify_account_api.mjs` checks exact routes, disabled mode, two flags, parallel warm reuse, production-context rejection even after warmup, and secret-redacted failures.
- `tests/test_private_preview_account_app.mjs` additionally checks the normalized SSL URL. Account Node CI is subscribed to these tests.

## What still blocks live hosted integration

1. **Owner approval before installing a Netlify Function route**, even a test route, on the current GitHub-`main` connected public Netlify site. The website itself must remain public and registered game users are not yet enabled.
2. **Netlify runtime dependencies:** Pin and bundle `pg` (including a committed lockfile), ensure the source imports can be bundled from the site build base, and use function-scoped environment configuration. Current static website does not install `pg`; this step remains pending.
3. **Private testing access:** Netlify deploy previews may be publicly reachable by URL. Apply adequate preview access control and rate limiting before putting an enabled private API on an accessible hostname. Production URLs are deliberately ineligible with today's code.
4. **Credentials:** Secure, server-side host secret configuration for the existing Supabase project; no database passwords, publishable keys or session bearer tokens in the public repository or Netlify TOML. Never request or paste secrets in ChatGPT messages.
5. **Supabase Auth signup settings:** Provider-level signup restriction remains unverified. The public browser Auth flag is `false`; do not relax it without an approved release plan.
6. **Legal documents, hosted email and test accounts:** Approved public Terms/Privacy versions and compliant email sender/redirect configuration have not been installed. Full hosted sign-in-to-airline tests have not been run.
7. **Separate game launch authorization:** Release switch in `airlinerra_game.platform_release_gate` must remain false; game worlds must remain `planned`.

## Relevant safety invariants

- `website/auth-rules.mjs` must continue to set `PUBLIC_AUTH_ENABLED=false`.
- Do not introduce `website/netlify/functions/` or `netlify/functions/`, change Netlify functions config, or publish `server/` files as website assets without explicit authorization for that deployment.
- Do not enable player signup, commercial airport operations, payment collection, or unlock World 01 as part of this milestone.
- The 3,140 owner-approved World 01 entries reside in private game approval tables as simulation candidates only; no new airport import was performed.

## Validation

Non-deploying GitHub account workflow: https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-account-node-ci.yml

Current project milestone is **Netlify gateway source prepared, NOT deployed**. A green CI run must not be described as a live hosted account registration test.
