# Airlinerra — Netlify account API staged safely (27 October 2026)

## 27 October 2026 — Netlify native preview context and Free-plan edge protection

**This is a non-deployed security correction.** Netlify's current [Functions runtime environment documentation](https://docs.netlify.com/build/functions/environment-variables/) says only `URL`, `SITE_NAME` and `SITE_ID` are guaranteed read-only Netlify environment variables inside Functions; the build-time `CONTEXT` variable is not guaranteed there. The [Function context API](https://docs.netlify.com/build/functions/api/) provides the real context of the current deployment under `context.deploy.context`, whether it belongs to the published deployment under `context.deploy.published`, and trusted site identity under `context.site`.

The staged entrypoint now takes **both Request and Netlify Context**. Before reading the environment, it requires:

- Host-provided context is strictly `deploy-preview` or `branch-deploy` and `published === false`;
- Host-provided site name is `airlinerra` and canonical site URL is `https://airlinerra.com`;
- Both independent account preview flags remain true;
- Existing operator-secret, exact preview hostname, same-origin, POST, JSON and bounded-request checks still pass.

It then injects the **verified** deploy type into a copy of the environment for downstream guards and ignores any stale/forged `process.env.CONTEXT`. Every check is repeated for warm requests. Tests verify that absent or forged platform deployment metadata and production context are rejected *before reading secrets or initializing a DB pool*. Netlify's own archived Function ZIP is loaded and run with synthetic trusted and contradictory environment metadata as a smoke test.

### Free-plan native rate limiter

Netlify's [rate-limiting documentation](https://docs.netlify.com/manage/security/secure-access-to-sites/rate-limiting/) confirms that **two code-based rate-limiting rules are available on Free**. The single staged Function `config` now sets one IP-aggregated rule:

- `action: 'rate_limit'`
- `aggregateBy: 'ip'`
- `windowSize: 60` seconds
- `windowLimit: 30` requests

This adds provider-side protection across Function instances, in addition to the existing local capacity limit. It does not deploy a rule until the Function is separately deployed. Because the account API has three paths but one Function, this is one code-based rule, not three.

### Artifact

The isolated Netlify CI workflow archives the **tested secret-free Function ZIP and manifest** as a short-lived GitHub Actions artifact. This output is evidence and material for future owner-approved review; it is **not** an active Netlify Function, a site deployment, or a record of real hosted authentication. The production site remains static and public, with player registration disabled.

## 27 October 2026 — Real Netlify Function compilation AND offline runtime smoke passed

- **Non-deploying GitHub Actions [#40502453942](https://github.com/bracko87/Airlinerra/actions/runs/40502453942): SUCCESS.** The workflow `.github/workflows/airlinerra-netlify-function-bundle-ci.yml` uses the real Netlify CLI **27.14.2** and an isolated temporary output directory; it does not connect to the real Netlify project, publish a preview, configure a function route, or read provider secrets.
- Initial attempts showed an important difference between “Netlify produced a ZIP” and “Function works”: default function bundling from `server/` **left `pg` unresolvable**, causing the executable smoke to return HTTP 503. Simply changing to a static import from the `website/` dependency tree did not fix the default Netlify ZIP.
- **Validated solution:** The source-only CI workflow first bundles `server/netlify-preview-template/airlinerra-accounts.mjs` and the pinned `pg@8.23.1` driver using **esbuild 0.25.12** into `$RUNNER_TEMP/airlinerra-source/`, then has the **actual Netlify CLI** package that self-contained module into a ZIP outside the deploy directory. The 27 October successful build produced a roughly **220 KB** compiled ESM module inside a roughly **387 KB** Netlify ZIP.
- The workflow unpacks the real ZIP and imports the contained Function in Node 22 with **synthetic preview variables and no external network**. It verifies that the handler starts, the three intended API paths are present, the disabled default and production context both return HTTP **503**, and an enabled synthetic operator preview with a deliberately invalid player session returns HTTP **401**, demonstrating that the actual bundled `pg` driver and private handlers load correctly. This is **not a real Supabase Auth login, PostgreSQL connection, player registration or Netlify deployment**.
- Public production remains unchanged: `netlify.toml` still has no active Functions directory, `website/dev-scripts/build.mjs` copies only explicitly allowed static assets into `dist/`, and `PUBLIC_AUTH_ENABLED=false` remains enforced.
- **Future preview deployment must reuse the working prebundle procedure.** Moving the unbundled `server/netlify-preview-template/airlinerra-accounts.mjs` directly into a Netlify Functions folder would reintroduce the missing-driver bug, even if the Netlify CLI appears to build it. The isolated CI steps are the tested reference implementation; the future host-specific deployment is a separate approval-gated step.

## 27 October 2026 — Pinned database dependency completed

The `pg` runtime dependency is now **pinned to exact version `8.23.1`** in `website/package.json`, and its complete `website/package-lock.json` was generated using npm on a credential-free GitHub Actions runner. The lock includes package integrity hashes; it is committed so Netlify can reproduce the exact dependency tree using `npm ci`.

- `tests/test_pg_driver_contract.mjs` uses the **real installed** `pg` client and pool, with **no network connection**, to validate the sanitized configuration preserves `ssl.rejectUnauthorized=true` after the URL has been parsed by node-postgres.
- `.github/workflows/airlinerra-pg-lockfile-ci.yml` now runs **`npm ci` validation** (not a generator) and confirms the static website build excludes `server/`, `node_modules/` and server package metadata.
- The existing `airlinerra-account-node-ci.yml` now also runs `npm ci` before each account test job, including disposable PostgreSQL tests.
- **No Function was moved into a live functions directory.** The automatic Netlify production deployment still publishes only the disabled-registration static prelaunch website. The secure serverless runtime needs separate preview deployment authorization, configuration and live external integration testing.
- The lockfile contains no database password, service-role key or Netlify secret. The version is pinned, but hosted secrets, reviewed legal documents, rate limiting and Auth signup restrictions remain pending.

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
