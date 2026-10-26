# Airlinerra — Account Foundation Batch 6 (2026-10-26)

**Branch:** main (repository policy)  
**Trello:** owner-managed; not changed  
**Production:** still prelaunch; no database migrations, auth enablement, domains or payment actions

## Progress and concrete defect fixes

The previously committed 3-file JavaScript account test suite was fetched, together with its actual source modules and referenced HTML/CSS/SQL files. An independent in-memory JavaScript compatibility runner executed **27 committed test bodies** using injected Node-like test assertions and local file fixtures.

The first run: **24 passed, 3 failed**. Two were genuine test expectation errors: the validators correctly throw `Display name...` with uppercase `D`, while the tests required case-sensitive `/display name/`. The test regex patterns were corrected to `/display name/i` in:
- `tests/test_account_foundation.mjs`
- `tests/test_player_lifecycle.mjs`

The third initial failure was due only to the test harness lacking `URLSearchParams` (available in real Node.js and browsers). An equivalent URLSearchParams test shim was added to the one-off runner, **not** to production source.

Second independent in-memory execution: **27/27 committed test bodies passed**. This included:
- locked prelaunch account/world gates and callback origin checks
- PKCE + OTP callback validation and rejected mismatched tokens
- mocked Supabase account service, password recovery and safe sign-out
- profile ownership, rejected unverified/anonymous users
- seven real 24-hour days, fixed starting funds, cross-world trial expiry
- trusted backend identity, parameterized private SQL, transaction rollback
- static SQL draft security-contract assertions

**Important limitation:** This was a V8 compatibility test harness with mocked `node:assert/strict`, `node:test` and filesystem access, **not a native `npm test` execution** and **not a PostgreSQL test**. Native Node and the disposable PostgreSQL Actions workflow must still run and turn green before production migration approval.

## Infrastructure availability checked

The current working container has Node.js 22 but no PostgreSQL server, psql, Docker or Supabase CLI. Git cannot resolve the GitHub hostname from the container. The GitHub connector can fetch/edit files but offers no `workflow_dispatch` action; the available browser profile contains no recorded authenticated GitHub session.

The connected Supabase projects were inspected. They include Airlinerra's **live research project** and production/work projects for other games; **no dedicated disposable Airlinerra test project** exists. Do NOT repurpose Tennis Legacy, ProPeloton Manager or Airlinerra's live research database for destructive SQL/DDL/concurrency testing. Provisioning an extra billable Supabase project must be an explicitly authorized owner decision.

## Testing gate still outstanding

The manual-only workflow already exists:
https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml

It starts its **own disposable PostgreSQL 17 service on GitHub-hosted runners** (it does not need a paid Supabase project), creates minimal Supabase Auth role/function stubs for SQL compilation, installs both prelaunch SQL drafts, verifies private grants/RLS/world gates, runs real concurrent activation attempts and checks exactly-once starting capital and global trial stability.

Execute **Run workflow** on `main`; do not state that PostgreSQL concurrency was verified until the workflow has actually finished green. Failure logs must be used to repair the SQL. The official Supabase Auth integration remains a separate phase because simulated Auth stubs do not validate actual email/password, SMTP or session behavior.

## Repository and production safeguards

- Both test regex changes were committed to `main` and the files were refetched for the second in-memory run.
- World 01, World 02 and World 03 all remain planned, with public account forms disabled (`PUBLIC_AUTH_ENABLED=false`).
- No SQL draft was executed against Airlinerra's live Supabase project.
- The game launch switch still defaults `false` in the unapplied draft and the approved-airport roster defaults empty.
- The account-wide seven-day trial is still a proposed policy until finally approved.
- No Trello, billing, email-domain or production deployment changes were made in this batch.

**Next responsible engineering action:** run the disposable PostgreSQL workflow and repair any actual SQL/PG errors, then set up a real *approved* prelaunch Auth integration environment and sender domain before enabling registrations.
