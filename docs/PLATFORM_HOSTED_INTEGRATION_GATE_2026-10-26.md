# Airlinerra — Hosted account integration readiness (26 October 2026)

**Scope:** Move the already-tested local account and airline-creation handlers toward a secure hosted environment. This document is an implementation handoff, **not a production launch authorization**.

## Current evidence

- Latest verified local Chromium onboarding passed ([GitHub Actions #40405209599](https://github.com/bracko87/Airlinerra/actions/runs/40405209599)): signup, email confirmation, profile persistence, approved airport display label, synthetic legal acceptance, exactly-once airline creation and recovery.
- The original 3,140 World 01 simulation airports already have a separate owner-authorized foundation release and source view. Their keys were reconciled against World 01 activation with no mismatches, then the real migration was validated on disposable PostgreSQL ([#40405017760](https://github.com/bracko87/Airlinerra/actions/runs/40405017760)).
- Read-only hosted Supabase audit: exactly **3,140** registration-source entries, **3,140** foundation-release members, **zero** `airlinerra_game` tables, and site `game_state=prelaunch`. Only the existing Airlinerra Supabase project (`hwllkabgzaynalahvkpz`) is the authorized research source.
- Supabase Security Advisors reported informational `rls_enabled_no_policy` on private research tables. This is consistent with their intentional default-deny access; do not add public read policies to dismiss an informational notice. The project has not been changed by this workstream.

## New source-code milestone

- `server/hosted-account-router.mjs`: a **default-disabled** Web Request/Response transport for exactly three same-origin HTTPS POST paths. Rejects other origins, methods, paths, oversized bodies and unsupported content types; never forwards upstream CORS/cookie headers or raw database errors.
- `server/hosted-account-stack.mjs`: reusable server-only composition of the existing verified Auth, legal consent, onboarding context and airline activation modules with *independent* gates. A real host must **inject** a trusted `verifyUserToken` function and a privileged **server-only** PostgreSQL connection pool. No credentials, network listeners, external route mapping, or live accounts are present in these files.
- `tests/test_hosted_account_router.mjs`: native Node tests cover default denial, explicit HTTPS origin, routing, header/body limits, exception sanitization and the private release-gate behavior. Registered in `website/package.json` and GitHub's account validation path filters.
- This is the **transport and composition stage**, not the complete Netlify deployment. In particular, there is **no deployed Netlify Function** and no hosted database connection.

## Required release work, in order

1. **Owner-authorized non-public database rollout.** Re-read live schema and migration history; audit the two review-only `docs/sql/airlinerra_game_*.sql` scripts, inspect RLS/client grants, and create/validate the `airlinerra_game` account schema using a controlled, authorized migration. Keep all game-world states `planned`, the platform release gate `false`, and public Auth UX `false`.
2. **World 01 game-roster transfer.** Run only `docs/sql/AIRLINERRA_WORLD1_3140_TO_GAME_ACCOUNT_AIRPORTS_PRELAUNCH_2026-10-26.sql` after installing the schema. Compare exactly 3,140 distinct `OURAIRPORTS:<source_id>` keys, names and country codes to the owner-authorized private source view; reject drift or unrelated World 02/03 approvals. The source release is for *simulation only* and does not assert commercial permits.
3. **Approved isolated hosted runtime.** Configure a dedicated HTTPS-origin host (Netlify is the selected static-site target but no production Functions route is registered here). Add a separate trusted serverless runtime with a pinned PostgreSQL driver, a trusted Supabase Auth verification client, a committed dependency lockfile, TLS, rate limiting, abuse prevention, bounded DB pools, timeouts and safe log redaction. Secrets must live in hosting's encrypted function-scoped environment settings — **never in the public repo, `netlify.toml`, static JS, or client responses**.
4. **Publish real legal materials.** Operator/legal approval required for actual Terms and Privacy URLs, version IDs, effective dates, GDPR/privacy handling, email use, data retention and deletion process. Synthetic CI legal pages are not player documents. Do not publish fabricated agreements or auto-accept on behalf of users.
5. **Hosted email and account tests.** Configure a validated sender/domain and SMTP/Auth redirect origins; verify registration confirmation, password recovery, JWT revalidation, a separate consenting manager, denied unapproved home airport, idempotent $5,000,000 ledger entry, a single seven-day account trial and browser refresh in a non-public hosted environment.
6. **Commercial launch separately approved.** Keep `PUBLIC_AUTH_ENABLED=false`, `platform_release_gate.enabled=false`, World 01 `planned`, and other worlds `planned` until a separate explicit launch decision. Billing/paid membership and live game feature readiness are separate deliverables; do not enable payment collection from this ticket.

## Operational status

| Milestone | Result |
| --- | --- |
| Local browser wizard | Passed |
| Authorized airport cohort and transfer logic | **3,140 authorized World 01 airports transferred to private game roster; keys and metadata reconciled** |
| Hosted HTTPS transport / service composition | Source prepared, default-disabled |
| Hosted runtime / Netlify Functions registration | Not yet built/deployed |
| Private game-account schema in live Supabase | **Installed 2026-10-27; 8 RLS-protected tables and all worlds planned** |
| Real legal documents and hosted SMTP | Not configured |
| Public registration and game worlds | Intentionally closed |

**Safety invariant:** A successful unit test, airport research activation or GitHub `main` commit must never automatically open registration or create a player/game airline in production.


## 2026-10-27 completion addendum — database milestone closed

The owner-directed private schema installation and World 01 airport handoff have now been applied to the existing Supabase project. Three versioned migrations appear in Supabase history; the private schema has **8 tables**, all RLS-enabled; the game approval roster contains **3,140 World 01** entries and no other-world approvals, with zero key or metadata mismatch. The platform release gate remains **false**, every world remains **planned**, legal publication and account records remain empty, and a direct activation attempt was refused as expected. See [verified live database release record](PLATFORM_PRELAUNCH_ACCOUNT_DB_INSTALLED_2026-10-27.md).

**Remaining tasks are hosted backend deployment, provider-level Auth signup restrictions, real legal/SMTP configuration, payment preparation and nonpublic hosted end-to-end verification. No public release was made.**
