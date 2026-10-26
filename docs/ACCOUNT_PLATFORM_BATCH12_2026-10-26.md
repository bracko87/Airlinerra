# Airlinerra — Account Platform Batch 12: Entitlement Integrity

**Date:** 2026-10-26  
**Development branch:** `main` (required by `AGENTS.md`)  
**Release status:** Prelaunch. SQL drafts are review-only, **not applied**.  
**Trello:** Owner-managed, no changes.

## Bug discovered and repaired

The first-activation function previously checked that a nonpaid entitlement had both trial timestamps, but did not require `membership_state='trial'` or an unexpired, exact 168-hour interval. An inconsistent record with `membership_state='none'` and populated dates could therefore potentially slip through the final success check.

Batch 12 adds **two layers of protection**:

1. `docs/sql/airlinerra_game_identity_schema_prelaunch.sql` — a `CHECK` constraint named `entitlement_state_clock_consistent`:
   - `membership_state='none'` requires **both** trial timestamps to be NULL.
   - `membership_state='trial'` requires **both** trial timestamps to be populated.
   - `trial_interval_exact` continues to enforce `trial_ends_at = trial_started_at + interval '168 hours'`.
   - Paid/expired/suspended/past-due account states retain support for either a prior trial clock or no clock as applicable.
2. `docs/sql/airlinerra_game_activation_prelaunch.sql` — after the private `start_account_trial_once` routine, only an **active paid membership** or an actual **trial** membership with a complete **unexpired 168-hour** period can complete new airline activation. Otherwise the operation raises `check_violation` and rolls back airline, membership, ledger, and trial writes together.

## Tests amended

- `tests/sql/airline_activation_negative_cases.sql`: in the disposable PostgreSQL fixtures, attempt to insert an invalid `none` account with trial dates and a `trial` account with no dates. Both must fail with `check_violation`, and no synthetic entitlement may persist.
- `tests/test_player_lifecycle.mjs`: add structural assertions for the new SQL constraint.
- `tests/test_airline_activation.mjs`: assert the returned entitlement must be `trial` or `active`, and nonpaid trial must be exactly 168 hours and unexpired.

## Verification performed, with limits

- Re-fetched the committed SQL and test files on GitHub `main`.
- **14/14** targeted source checks passed, covering membership-state invariants, cash/trial independence, the fail-closed SQL operator gate and the new negative fixtures.
- Evaluated **all 18 existing activation SQL static assertions** against the current committed activation SQL; **18/18 passed**.
- Independently ran the existing native Node.js profile smoke suite: **7/7 passed**. These tests cover profile storage, not PostgreSQL activation logic.
- **Did not execute PostgreSQL** locally: the environment has no `postgres`, `initdb`, `pg_ctl`, `psql` or Docker. GitHub workflow dispatch is not provided by the connected GitHub integration. Neither local native Node tests nor static assertions prove SQL DDL, RLS behavior or concurrent financial safety.

## Required next action

Run the existing, hardened **manual-only disposable PostgreSQL 17 GitHub Actions workflow**, then use real failing job logs (if any) to correct the SQL:

https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml

This workflow must complete successfully before applying game-account migrations to Airlinerra's actual Supabase project.

## Safety

No game-account tables or account-related SQL were deployed to the live project, no airport was activated, no world was opened and no player funds were created. The frontend `PUBLIC_AUTH_ENABLED` and private onboarding handlers stay disabled. No changes to research data, payment setup, domain/SMTP or Trello.
