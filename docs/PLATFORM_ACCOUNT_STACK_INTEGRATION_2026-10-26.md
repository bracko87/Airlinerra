# Airlinerra — Platform Account Stack Integration, 26 October 2026

**Original task:** 14 — Backend integration and database validation.
**Status:** PARTIALLY COMPLETED. The private account stack is assembled in code and exercised with synthetic data; the isolated PostgreSQL workflow and real Supabase Auth test remain pending.
**Branch:** `main` as directed by `AGENTS.md`.
**Scope boundary:** No airport research review, runway classification, airport approvals, airport imports, world openings, Trello edits, domain, live email or payment work.

## What was implemented

1. `server/local-account-stack.mjs` — a dedicated local-only prelaunch composition function `startLocalAccountStack({verifyUserToken,database,enabled=false,port=0})`. Uses **the real existing modules**:
   - `startLocalAccountGateway` — loopback-only HTTP transport
   - `createAirlineHttpHandler` and `createAirlineActivationService`
   - `createLegalConsentHttpHandler` and `createLegalConsentService`

   Both the local gateway and each private handler/service have **independent** release switches set to disabled by default. The factory requires an explicit trusted Auth verifier and a database pool interface; it does not inject credentials, expose service-role keys, run any migration, open a world, or approve airports. No production server is installed.

2. `tests/test_local_account_stack.mjs` — 11 new native Node.js test cases that **will be run by the existing `npm test` command** on a real Node runner. Cases cover:
   - Default disabled gateway: no authentication or DB calls.
   - Real legal-consent HTTP adapter → freshly verified account → BEGIN → private policy-read SQL → consent-insert SQL → COMMIT.
   - Real airline HTTP adapter → verified account → BEGIN → private airline-activation SQL → exact $5 million string and seven-day trial timestamp → COMMIT.
   - Idempotent creation replay: one airline and one synthetic starting-capital grant in the same world.
   - Separate World 02 airline using `FICTIONAL:fictional:RS:LYAL`, a different airline ID but the unchanged account-wide trial timestamp.
   - Published legal version rotation rejected with 409 and ROLLBACK.
   - Unverified account denied 401 before DB access.
   - Old client-supplied numeric airport/owner fields and bad legal consent denied 400.
   - Synthetic DB refusal of airport activation rolls back and discloses no SQL details.
   - Rejected cross-origin and malformed Bearer requests before Auth/DB.
   - Database-connection error returns generic 503 without secrets.
   - Invalid dependency injection cannot start a listener.

   All SQL transactions and paid/trial state in these tests are **synthetic assertions in a fake database adapter**, not observed PostgreSQL behavior.

3. `website/package.json` — includes `../tests/test_local_account_stack.mjs` in `npm test`. The existing manual-only isolated PostgreSQL GitHub Action already executes `npm test` on Node 22 before starting disposable PostgreSQL validation, so the new suite is included automatically when the workflow is triggered.

## Validation actually performed

- Re-fetched the exact committed modules and test file from GitHub `main`.
- Executed all **11 of 11 committed test bodies successfully** in the V8 test-compatibility harness against the **actual current JavaScript implementations** of the account service, legal service and HTTP handlers. The harness supplied a synthetic `fetch`/local gateway adapter and fake transactional database pool. This is a **mock integration test**, **not** a native Node 22 HTTP test and **not** the full repository `npm test`.
- Passed **7 of 7** accompanying source/integration checks: scenario count, pass results, stable `homeAirportKey`, local port default, independent gates, native test inclusion and distinct World 02 airline IDs.
- The prior nine localhost transport smoke cases were committed before this work; they are separate from this new service-stack test and should be run together by `npm test`.

## Work not completed

- Live `airlinerra_game` migrations are **not deployed**.
- No actual `auth.getUser(token)` request, legal consent insert, airline transaction or concurrent $5 million credit was performed in PostgreSQL.
- A recorded green manual GitHub Action on disposable PostgreSQL 17 is **still missing**. The GitHub connection has no workflow-dispatch capability; its available Actions tools only inspect or rerun existing runs. The browser profile has no verified GitHub login, and this local container has no PostgreSQL server.
- No public signup or airline registration is authorized. The player portal remains a closed prelaunch preview.
- Airport eligibility, category finalization and operator-approved airport roster remain exclusively the responsibility of **Airport Database Overview**. An `airport_world_activation.active` row must never grant `airlinerra_game.approved_game_airports` membership by itself.

## Current original-task outcome

| User-requested capability | Status |
|---|---|
| Local API transport and real handler composition | **Source code complete**; mock-verified; not deployed |
| Correct server-side owner verification and legal consent | **Source code complete**; fake-DB tests; not live |
| World-specific airline creation, idempotency, $5m and global trial | **Source code complete**; fake-DB tests; real database validation outstanding |
| Public registration, live email and game-account database | **Not deployed / not operational** |
| Domain, subscription payment and playable worlds | **Not complete** |

**Next blocker:** [Run the manual isolated PostgreSQL workflow on `main`](https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml), then repair any real failures before approving a development migration. This step does not require changing any airport review/approval data.
