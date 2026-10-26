# Airlinerra platform — First green native Node + disposable PostgreSQL 17 validation

**Date:** 2026-10-26  
**Branch:** `main`  
**Verified CI run:** https://github.com/bracko87/Airlinerra/actions/runs/40358806119  
**CI tested commit:** `1a7001c0fbce90ae9380aedc4bf196f014889ca3`  
**Status:** **Isolated PostgreSQL and native Node tests PASSED**. Live database deployment and real Supabase Auth/email remain **NOT done**.

## Why this milestone matters

The team was previously relying on JavaScript mocks and source-level tests because the original disposable PostgreSQL Actions workflow required a manual run and could not be dispatched through the connected GitHub tools. This work created a **separate non-deploying GitHub Actions validation workflow**, triggered only by changes to Airlinerra platform files on `main`, with two jobs:

1. **Native Node 22 + website build** with public Auth launch gates asserted disabled.
2. **PostgreSQL 17 disposable service** with explicit `PGDATABASE=airlinerra_disposable`, local-only database connection, no Supabase credentials, mandatory preflight guard, synthetic Supabase Auth stubs, review-only game schema drafts, independent legal and RLS tests, eight-way concurrent airline activation, and financial/trial postconditions.

**The original manual-only PostgreSQL workflow has been left manual-only.** Neither workflow accesses the actual Airlinerra project database or deploys any code to the public website.

## Bugs found by real test execution and corrected

- `tests/sql/legal_consent_isolated.sql` still passed airport ID `101` instead of `'OURAIRPORTS:101'`.
- `tests/sql/player_profile_rls_isolated.sql` referenced the obsolete `create_airline_once(uuid,smallint,text,bigint)` function signature rather than the current `text` airport-key variant.
- An older native player-lifecycle test still asserted the obsolete numeric airport foreign key; first real Node run returned **108/109** with exactly one failure. This assertion was updated to the stable `airport_key` FK.
- The first real PostgreSQL run applied both drafts and passed preflight but exposed **implicit integer world IDs** in test calls. PostgreSQL does not automatically resolve `integer` constants as `smallint` function arguments. The SQL fixtures and both workflows now use explicit `1::smallint`, `2::smallint`, or `3::smallint`.
- `tests/test_sql_contract_drift.mjs` adds six native regression cases covering the shared text-key SQL contract, a single schema definition, legal/permissions signatures, fictional airport fixture, manual preflight and explicit `smallint` casts. The last test's regular-expression escaping was corrected before the final successful run.

## Verified, grounded CI results (run #40358806119)

### Native Node job: completed SUCCESS

- **110 tests / 110 passed / 0 failed** on the GitHub-hosted Node 22 runner.
- The prelaunch static website build completed successfully.
- Checks confirmed public authentication and the private handlers remain disabled.

### Disposable PostgreSQL 17 job: completed SUCCESS

- Native Node test suite **110/110** and site build both passed again.
- Disposable test database preflight succeeded and verified the PostgreSQL 17 database was `airlinerra_disposable`, empty of project/research schemas, with no external project connection.
- Synthetic Auth stubs and **both draft game-account schema files applied successfully**.
- Private schema, default-closed worlds and release switch, permission checks and RLS tests succeeded.
- Legal acceptance idempotency and rotated policy rejection succeeded.
- Invalid user, expired trial, suspended membership and unauthorized-airport negative paths rejected as expected.
- **Eight parallel activation attempts:** **exactly one `newly_created=true` and seven `false` idempotent retries**.
- Postconditions confirmed exactly one starting credit, **$5,000,000** balance per created airline, one **168-hour account-wide trial**, second-world independent airline, stable trial timestamp, and paid-without-trial scenario.

Evidence, from the GitHub Actions job logs:
- `Created: 1; idempotent retries: 7`
- `Concurrent startup credit, replay, paid plan and two-world invariants passed`
- `# tests 110` / `# pass 110` / `# fail 0`

## Live production project — read-only verification

Read-only query of Supabase project `hwllkabgzaynalahvkpz` after the test run:

| State | Value |
|---|---|
| Deployed game-account tables under `airlinerra_game` | **0** |
| World 01 active airport activation records in `airlinerra` | **3,140** |
| Website game state | `prelaunch` |

All CI account rows, airline cash balances, trials, legal consents and World 02 fictional fixtures existed **only inside disposable PostgreSQL**.

## Status vs original user tasks

- **Task 14 / isolated Node, SQL migration, concurrency and RLS validation:** **COMPLETE and independently verified**.
- **Tasks 6–12 / real registration, verified email, account profiles, legal consent, airline creation, starting balance and trial:** source code implemented and tested in isolation, **not operational** on live Supabase.
- **Domain, sender email/SMTP, published legal text, paid pricing/payment, public deployment:** **not completed**. No external DNS/SMTP/payments were changed.
- **World 01 airports:** activation rows 3,140 but approval/final six-category reconciliation is handled exclusively in **Airport Database Overview**; this workflow did **not** approve or modify airports.

## Recommended next platform milestone

Prepare an owner-approved **separate development Supabase environment** for end-to-end registration, email confirmation, current legal consent, profile creation, World 01 airline creation and password recovery. Before any development migration, review permissions, deployment controls and safe rollback. **Do not deploy the game-account schema into the existing airport-research Supabase project or enable public signup without owner approval.**

All application code remains nonpublic/disabled for account operations, and no production data has been touched.
