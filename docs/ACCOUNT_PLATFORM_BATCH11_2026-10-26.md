# Airlinerra — Account Platform Batch 11: Disposable DB preflight and CI diagnostics

**Date:** 2026-10-26  
**Repository branch:** `main`, per `AGENTS.md`  
**Result:** Isolated PostgreSQL validation harness hardened, **not executed**  
**Live environment:** prelaunch, no game schema migration or airport world activation  
**Trello:** unchanged (owner-managed).

## Important evidence: workflow has not run

Queried the actual GitHub Actions workflow-runs collection through the connected GitHub API. The most recent visible runs were FAA/airport workflows dated 2026-10-23; none of the 100 returned runs had an account/PostgreSQL validation workflow name. This confirms there is no observed successful database test. The connected GitHub App provides read access to Actions history and file commits, but has no available `workflow_dispatch` action. The available local container has Node.js 22, but no `postgres`, `initdb`, `pg_ctl`, `psql` or Docker, and public GitHub cloning fails DNS resolution. We did **not** attempt SQL against the live Supabase research project or another game's production environment.

## Committed changes

1. **`tests/sql/disposable_database_preflight.sql`** — read-only PostgreSQL 17 preflight which fails before any Auth stubs or schema DDL unless:
   - The selected database is exactly `airlinerra_disposable`.
   - The server major version is PostgreSQL 17.
   - The active DB role is the isolated `postgres` test administrator.
   - No `airlinerra`, `airlinerra_game` or `auth` schemas already exist.
   - No existing Airlinerra public site/world/profile tables are present.
   
   These checks protect against accidentally running the synthetic database tests on a populated/reused project.

2. **`.github/workflows/airlinerra-postgres-isolated.yml`** — strict `PGHOST=127.0.0.1`, `PGPORT=5432`, `PGDATABASE=airlinerra_disposable` and `PGUSER=postgres` checks before calling the new SQL preflight. If any check fails, the job exits **before** the first schema creation.

3. **Error diagnostics** — a final `if: always()` step adds a GitHub Actions job summary. When the disposable localhost database is reachable, the summary also reports synthetic airline/ledger row counts. It never logs real database secrets or connects to the Airlinerra hosted Supabase project.

4. Workflow remains **manual-only** (`workflow_dispatch`). The Node regression suites, prelaunch static website build, synthetic Supabase Auth stubs, RLS checks, legal policy tests, two concurrent same-player activation calls and cross-world/ledger postconditions remain intact.

## Verification

- GitHub files re-fetched independently after the commits.
- **13/13 static structural checks passed** for the exact DB guard, PostgreSQL version guard, research/schema exclusion, order before DDL, localhost env guards, manual trigger, preserved concurrency/postcondition steps and summary diagnostics.
- A real `psql` execution of the preflight or PostgreSQL schema has **not** occurred, so there is no claim of successful PostgreSQL correctness or concurrent financial safety.
- No live production game-related Supabase DDL, Auth signups, money, player accounts, world admission or airport research changes were made.

## Required next step: one manual click in GitHub Actions

Open <https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml>, choose **Run workflow**, select `main`, and start the disposable PostgreSQL 17 test. Examine the actual run result and logs; repair any failing SQL/test logic *before* considering a production schema migration.

Unlike creating a separate Supabase test project, this workflow uses a disposable GitHub-hosted PostgreSQL container in a publicly accessible repo. It does not rely on Airlinerra's live Supabase project or touch its private research schema.

### Outstanding launch gates

A successful standalone PostgreSQL test is necessary but insufficient for launch. Dedicated, approved Supabase Auth integration, real email verification, sender/domain/legal approvals, anti-abuse controls, protected production server deployment and world-specific gameplay-airport approval must all be verified separately. Until authorized, the frontend `PUBLIC_AUTH_ENABLED` and both private API gates remain disabled. No public gameplay and no automated deploy from `main`.
