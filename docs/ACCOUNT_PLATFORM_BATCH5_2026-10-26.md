# Airlinerra — Account foundation Batch 5: Disposable PostgreSQL integration harness

**Date:** 2026-10-26  
**Branch:** `main`  
**Release status:** Prelaunch, no database migrations or game activation  
**Trello:** Owned and managed independently by project owner

## What was completed

This batch corrects the review-only activation function and adds a real PostgreSQL integration test *workflow* that can be run without altering the live Supabase research project.

- Corrected a paid-account edge case in `docs/sql/airlinerra_game_activation_prelaunch.sql`: a legitimately paid subscriber with no previous free-trial timestamps can create an airline; the account must remain paid without starting an unwanted trial.
- Added `.github/workflows/airlinerra-postgres-isolated.yml`. It is **workflow_dispatch only** and creates a disposable **PostgreSQL 17** service container. It runs all existing Node account tests, the website build, two SQL draft files and the SQL integration tests. It does NOT use the Supabase production project's credentials.
- Added `tests/sql/bootstrap_auth_stubs.sql`: minimal disposable-only `auth.users`, `auth.uid()`, `auth.jwt()` and roles. These stubs are only for compiling/testing SQL on vanilla Postgres; they are not an Auth implementation.
- Added `tests/sql/airline_activation_disposable_fixtures.sql`: synthetic users, consent versions, paid and expired memberships, and synthetic airports 101/202; world 01 and 02 are temporarily opened **inside the disposable test DB only**.
- Added `tests/sql/airline_activation_negative_cases.sql`: must reject closed world, wrong-world airport, expired trial, banned account, suspended membership, and missing terms consent.
- Added `tests/sql/player_profile_rls_isolated.sql`: role-level owner-only profile reads/writes, immutable timestamps, denied impersonation, and anonymous JWT isolation.
- Added `tests/sql/airline_activation_postconditions.sql`: exactly one airline and one starting ledger entry after two simultaneous activations of the same player/world; identical replay is read-only, changed-name replay denied, second-world creation cannot restart the global seven-day trial, and paid-without-trial remains valid.
- Strengthened `tests/sql/airline_activation_isolated_assertions.sql`: even an actual invocation of the SQL function must fail before the platform release gate is enabled.

## How the manual integration run works

```text
GitHub Actions → Airlinerra isolated PostgreSQL account validation → Run workflow
     |
PostgreSQL 17 disposable service (NO external or live Supabase project)
     |
Node account regression suites + npm run build
     |
Create synthetic Supabase Auth roles/functions + install both SQL drafts
     |
Verify closed worlds, zero airports, locked launch gate and RLS
     |
Load synthetic accounts, approvals and test-only release gate
     |
Reject invalid operations and unauthorized player-profile changes
     |
Launch two concurrent PostgreSQL sessions for identical airline activation
     |
Require EXACTLY ONE created airline, startup credit and global trial
     |
Verify replay, paid account, and another world cannot reset trial
```

**Workflow:** https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml

## Verification levels — do not confuse them

1. **Committed to GitHub and fetched back:** yes. Test assets are present on `main`.
2. **Source/static checks:** 17 of 17 checks completed against ten independently re-fetched GitHub files, confirming manual-only dispatch, PostgreSQL 17 isolation, workflow references, paired dollar quotes, identity/consent gates, concurrency assertions, RLS test coverage, and the paid-account SQL fix. These checks do **not** establish SQL execution correctness.
3. **Node test suite:** configured to execute on the runner; not yet reported green.
4. **Real PostgreSQL DDL, role/RLS and two-connection concurrency test:** the workflow is ready, but **not executed yet**. No claim of actual database-level pass or race-proof operation may be made before the manual run finishes green.
5. **Real Supabase Auth and email tests:** not covered by the minimal Auth stub. Require an independently approved development Supabase setup, SMTP and configured redirects.

## Environment limitation and next action

The current execution environment has Node.js but **no PostgreSQL server, psql client or Docker**, and direct GitHub cloning cannot resolve the public GitHub host. The available browser profile is not signed into GitHub, and the connected GitHub actions do not expose a workflow dispatch capability. Thus this session **cannot launch** the manually triggered test workflow or truthfully claim it passed. No billable Supabase project has been provisioned without approval.

The practical next step is to run the new **manual GitHub Actions workflow** on `main`. Fix any actual failing SQL or tests shown by its logs. Only after real PostgreSQL validation should the team prepare versioned migrations and test the real Supabase Auth integration in an isolated authorized environment.

## Production safeguards still intact

- Public account signup disabled in frontend; verify server-side Auth settings separately before launch.
- No domain acquired or SMTP sending domain verified in this batch.
- `airlinerra_game` game tables **not migrated** into the existing live Supabase project.
- `airlinerra.airport_world_activation` in the research database remains separate from approved in-game airports.
- Worlds 01, 02, 03 not opened on production; no real airline, funds, subscription or trial activated.
- Trello board unchanged.
