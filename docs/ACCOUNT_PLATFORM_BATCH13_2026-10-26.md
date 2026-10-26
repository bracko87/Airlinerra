# Airlinerra — Account Platform Batch 13: Deeper Auth and concurrent activation tests

**Date:** 2026-10-26  
**Branch:** `main` per `AGENTS.md`  
**Status:** Integration test coverage extended, **NOT executed against PostgreSQL yet**  
**Production and Trello:** unchanged.

## GitHub Actions status observed

Read the GitHub repository's actual Actions run history through the connected API (121 historical runs). No account/PostgreSQL validation run appears in the returned recent 100, and the isolated PostgreSQL workflow remains manual-only. The connected GitHub integration has no workflow-dispatch action and the available local container has no PostgreSQL server, client or Docker. **No live Supabase or other game database was used for SQL/DDL.** This batch does NOT claim native PostgreSQL integration, actual concurrent writes or a green workflow.

## Completed and committed

### 1. Additional invalid Auth fixtures

Extended `tests/sql/airline_activation_disposable_fixtures.sql` with three synthetic accounts, inserted **after** the five valid synthetic consent rows were recorded:

- `77777777-...`: email not verified.
- `88888888-...`: explicitly anonymous Auth identity, even though email is populated.
- `99999999-...`: deleted player account.

These users deliberately have no accepted legal policy. The tests ensure the **Auth gate** rejects them before the legal-consent stage.

### 2. Reject invalid Auth identities for the right reason

Extended `tests/sql/airline_activation_negative_cases.sql`. Each of the three new accounts attempts a new airline in World 01. A passing test must reject the request using `check_violation` **and** the explicit `Verified, active player account required` message. A different failure reason (such as legal consent) or a successful activation fails the test.

This is a stronger check of the verified-account requirement than merely asserting that no airline was created.

### 3. Test legal-policy rotation through the actual activation function

Extended `tests/sql/legal_consent_isolated.sql`. In a transaction scoped to the throwaway database, the test temporarily updates the published Terms version to `test-v2`. It now invokes `airlinerra_game.create_airline_once` for a previously consenting synthetic player and requires the actual database function to reject old consent with `Published terms and verified player consent required`. The transaction rolls back, restoring the test policy to `test-v1`. This tests the public-policy change against the *function*, not only a JOIN query.

### 4. Eight-way concurrent activation burst

Strengthened `.github/workflows/airlinerra-postgres-isolated.yml`. It previously attempted two concurrent sessions; it now launches **eight independent PostgreSQL clients**, all activating the same account/world/airline. The job requires **exactly one `newly_created=true` and seven `false` idempotent retries**, and still runs the financial ledger and trial assertions afterwards.

- PostgreSQL requests have `statement_timeout=30000` and `lock_timeout=20000` to avoid silent hanging.
- The step waits for all eight worker processes and prints their outputs before asserting success.
- SQL error/worker failure causes the job to fail. No live production data is involved.

## Validation performed

1. Re-fetched all six affected/source SQL and workflow files from GitHub `main`.
2. **17 of 17 static checks passed**, including new fixtures, rejection reasons, policy-rotation function call, timed concurrent workers, idempotency counts, existing disposable database preflight and private function grants.
3. Locally executed a **Bash harness smoke check** of the new worker-output aggregation with synthetic responses: one `true` and seven `false` returned the required `1 / 7` totals; `bash -n` passed.
4. No PostgreSQL execution was possible in the current runtime. A passing Bash aggregation smoke test does not establish transaction isolation, RLS correctness or exactly-once funds.

## Required next action

Open the [manual GitHub Actions isolated PostgreSQL workflow](https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml) and select **Run workflow** on `main`. The workflow must complete green using a disposable PostgreSQL 17 service before approving the real game-account schema migration. Any failing SQL error should be corrected from the actual job logs.

No live account signup, paid subscription, playable world, airline starting capital, or gameplay airport was activated. The launch gate remains hard-off.
