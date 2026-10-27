# Airlinerra — Private hosted preview backend prepared (27 October 2026)

## Verified outcome

**Source milestone complete, external hosted deployment NOT complete.** The code below lives on GitHub `main`, not in a deployed Netlify Function or browser build. This work neither enables Supabase Auth signup nor alters airport research, World 01, player accounts, SMTP, billing or legal documents.

The private Airlinerra Supabase project `hwllkabgzaynalahvkpz` previously received 8 RLS-protected account tables and 3,140 authorized World 01 game-airport rows. A fresh 2026-10-27 **read-only** query verified:

- `airlinerra_game.approved_game_airports`: 3,140 in World 01, 0 in Worlds 02/03.
- `platform_release_gate.enabled`: **false**.
- Worlds not in `planned` state: **zero**.
- Actual `airlinerra_game.airlines` and `auth.users`: **zero**.
- Website `game_state`: **prelaunch**.

This is already deployed *database foundation*, **not** an approved public game.

## Newly implemented source modules

- `server/hosted-runtime-config.mjs`: opt-in hosting configuration, **two separate closed-by-default switches** (`AIRLINERRA_HOSTED_BACKEND_ENABLED` and `AIRLINERRA_PRIVATE_PREVIEW_APPROVED`), refused `production` Netlify context, exact pinned Supabase project and publishable-key validation, HTTPS origin allowlist, private PostgreSQL URL verification, and two separate reviewed HTML policy paths. Disabled configuration does not even read database secrets.
- `server/hosted-auth-verifier.mjs`: server-side GET to the exact Airlinerra Supabase Auth `/auth/v1/user` service for each passed access token, with bounded network timeout and no locally trusted JWT claims. Denied, unconfirmed, anonymous, or unavailable verification fails closed. Uses a *publishable* API key; neither service-role nor other secret keys are bundled in browser scripts.
- `server/preview-account-app.mjs`: lazily assembles the existing secure HTTP/router and legal/airline services with a bounded (max 2 connections) PostgreSQL TLS pool. It imports the `pg` driver **only after** both release flags and the host context have passed. `pg` driver must be packaged and version-locked in the actual future hosted build; it is not installed/deployed by this source change.
- `tests/test_private_preview_account_app.mjs`: tests invalid keys, origins, database targets, forbidden production context, denied users, Auth errors, private DB release gating, TLS configuration, and no connections or fetches while disabled.
- `tests/test_prelaunch_release_invariants.mjs`: static regression guard ensures the public Auth switch remains false, website build does not include backend secrets, and neither the root nor `website/` has an autodiscovered Netlify Functions directory or custom account redirect.

The existing `server/hosted-account-router.mjs` and `server/hosted-account-stack.mjs` compose the Auth, consent, onboarding-context and airline-activation handlers. All existing DB/world/legal/airport gates remain independent.

## Explicit remaining release blockers

1. **Actual Netlify deployment is NOT connected.** The site uses `[build] base="website"` and static `../dist`. No `[functions]` directory, serverless bundle, route mapping, or custom account redirect was added, because the public `main` branch may be connected to production deployment. Netlify documents that functions are automatically deployed from a configured folder and that runtime variables must be set in the UI/CLI/API with Functions scope, not `netlify.toml`. See https://docs.netlify.com/build/functions/configuration/ and https://docs.netlify.com/build/functions/environment-variables/.
2. **Dependency lock and serverless packaging:** The trusted host must ship an exact pinned `pg` dependency with its committed lockfile, bundle existing `server/` ESM modules, and configure TLS/DB connection pooling. Only a private approval-gated deploy preview should initially be used. No secret database connection URL belongs in GitHub.
3. **Hosted Netlify Function runtime and URL mapping:** Still needs integration with a concrete host/site, configuration of `/api/v1/onboarding/context`, `/api/v1/legal/consents`, and `/api/v1/airlines`, and verification of same-origin HTTPS/CSRF protections. Add edge/host rate limits, secret redaction, monitoring, and protection for nonpublic preview before enabling the two flags.
4. **Supabase Auth provider-level signup:** **Not independently verified** in hosted Supabase settings. The browser source currently refuses to use the existing research project `hwllkabgzaynalahvkpz` as its Auth target, and `PUBLIC_AUTH_ENABLED=false`. These browser development restrictions must not be silently removed. Before any public onboarding, verify in Supabase Auth provider settings that unsolicited registrations are prohibited or explicitly authorized, then reconcile the intended Auth project and only enable public Auth on a separately approved release.
5. **Real legal policy and SMTP:** Actual Terms/Privacy must be written, reviewed, versioned, hosted, and approved before publication and consent gating. Configure verified sending domain, rate limits, callback origin allowlist, recovery and confirmation emails. CI-only synthetic legal texts are not valid public documents.
6. **Full private-hosted E2E:** The existing **local** Mailpit/Chromium wizard test was successful, but this **new hosted runtime** has only mock/injected dependency tests. Do not claim a real Netlify browser flow, hosted PG connection, actual Auth request, or SMTP delivery until those are observed on an approved preview.
7. **Payment, world opening and production go-live:** Separate owner approval required; current target is prelaunch backend preparation only.

## Validation record

- Earlier local full signup-to-airline Chromium E2E: https://github.com/bracko87/Airlinerra/actions/runs/40405209599
- New prelaunch preview runtime and tests: tracked in the account Node validation workflow at https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-account-node-ci.yml
- Live private schema installation record: [PLATFORM_PRELAUNCH_ACCOUNT_DB_INSTALLED_2026-10-27.md](PLATFORM_PRELAUNCH_ACCOUNT_DB_INSTALLED_2026-10-27.md)

**Never conflate "private account database installed" or "hosted runtime source prepared" with "players can register or play now."**
