# Airlinerra Account Batch 4 — atomic activation foundation

**Date:** 2026-10-26  
**Branch:** `main` (Airlinerra's required development branch)  
**Status:** CODE + SQL REVIEW DRAFTS; not deployed, not a production launch  
**Trello:** owner-managed; no edits

## Implemented and committed

1. **Fixed invalid PL/pgSQL function dollar quotes** in `docs/sql/airlinerra_game_identity_schema_prelaunch.sql`. The prior draft had four malformed `AS $`/`$;` function bodies; all now use matched tagged delimiters.
2. **New atomic private activation function**, `airlinerra_game.create_airline_once(uuid,smallint,text,bigint)`, in `docs/sql/airlinerra_game_activation_prelaunch.sql`. It is `SECURITY INVOKER` in the **private unexposed schema**, with EXECUTE revoked from PUBLIC/anon/authenticated. It must be invoked only by a trusted DB connection. It is NOT exposed through the public browser API.
3. **Fail-closed gates**: platform release gate defaults disabled, published terms policy initially absent, no verified account consent, three worlds still planned, separately approved game airports table empty. The new function checks all of these before any airline creation.
4. **Verified Auth owner check**: validates `auth.users` confirmed, non-anonymous, non-deleted, not currently banned; serializes concurrent player activations with `FOR UPDATE` on the Auth user row. Does not accept `raw_user_meta_data` as authorization.
5. **Idempotent creation**: one airline per player per world; identical retry reads the existing airline and does not re-issue starting funds. Changing airline name or home airport on a retry fails. World-level active memberships may be resumed but suspended memberships remain blocked.
6. **Cash and trial**: newly created airline receives one USD 5,000,000 ledger entry and a matching exact decimal balance. The seven-day account trial starts only at first activation, exactly **168 hours**, and cannot restart on a new world. New airline creation after an expired trial requires active subscription. The trial implementation is a **proposed account-wide policy** awaiting owner final confirmation.
7. **Server-only adapter** `server/airline-activation.mjs`: derives player ID from a trusted Supabase Auth server verification result, validates game inputs, invokes private SQL with bound parameters inside a transaction, rolls back on error and releases the connection. Nothing imports this adapter into the website and **no HTTP endpoint is registered**.
8. **Financial precision**: cash balances from PostgreSQL are returned as **decimal strings**, never JavaScript floats.
9. **Regression suite** `tests/test_airline_activation.mjs`: mocked server/client checks for disabled gate, invalid Auth, parameter binding, rollback, monetary response and SQL security invariants. Existing `npm test` and the **manual-only** account-foundation workflow include it.
10. **Isolated PostgreSQL smoke assertions**: `tests/sql/airline_activation_isolated_assertions.sql` checks actual database metadata, private grants, RLS, locked worlds, no activated airports, zero airlines/ledger/trials, and uniqueness constraints.

## Correct transaction sequence

```text
Trusted server receives verified player access token
    |
Server calls Supabase Auth getUser(token); playerId comes ONLY from Auth
    |
Validate world ID 1–3, airline name, airport source ID
    |
BEGIN PostgreSQL transaction on PRIVILEGED backend connection
    |
SELECT airlinerra_game.create_airline_once(playerId, worldId, name, airportId)
    |--> platform gate enabled? (DEFAULT FALSE => rejects now)
    |--> verified unbanned user? lock auth user row
    |--> official published terms & per-user consent?
    |--> world open? lock world row
    |--> approved airport FOR THIS world? lock approval
    |--> identical existing airline? return existing, no money/trial restart
    |--> else lock existing entitlement / require active trial or subscription
    |--> create/resume membership
    |--> create airline with DB enforced uniqueness
    |--> create exactly one startup ledger entry and add $5m
    |--> start one-time global trial if never activated
    |
COMMIT; any error ROLLBACK
```

**No airline can be created from this code today:** there is no server route; the operator release gate is unconfigured and disabled; terms/consent/airport approval sets are empty; the SQL drafts have not been applied.

## Verification performed

- The committed files were fetched again from GitHub and reviewed, including the syntax correction.
- Independent source/mock validation: 18 of 18 checks passed, including mocked verified-user SQL binding, success/rollback, disabled activation, currency precision, matched SQL function quoting and closed-world permissions.
- Existing automated Node tests and manual Actions workflow are committed, but the complete `npm test` suite has **not** been run against a full checkout during this session; no green GitHub Actions run is claimed.
- A real PostgreSQL schema apply/transaction and two-session concurrency test was **not performed**. No isolated PostgreSQL or disposable Supabase test project is accessible in this session. Do not claim database-level SQL validation, financial race safety or successful RLS tests until these are exercised against PostgreSQL.
- Current live project must remain prelaunch. Do not execute these drafts against the shared production/research database without explicit migration/launch authorization.

## How to test safely in isolation

Use a **disposable non-production Supabase stack** or independently provisioned local PostgreSQL with Supabase's Auth schema and roles configured. Do not point credentials at the existing Airlinerra research project.

1. Create a disposable project with matching PostgreSQL major version; ensure `auth.users`, `auth.uid()`, `auth.jwt()`, `anon` and `authenticated` exist.
2. Execute `docs/sql/airlinerra_game_identity_schema_prelaunch.sql` and then `docs/sql/airlinerra_game_activation_prelaunch.sql`. Stop on **any** SQL parse/DDL error.
3. Execute `tests/sql/airline_activation_isolated_assertions.sql` with psql `ON_ERROR_STOP=1`; expect a passing notice and **no rows** in playable airline, ledger, membership or entitlement tables.
4. On the **disposable instance only**, configure a synthetic verified Auth account, synthetic legal acceptance, a synthetic approved airport ID and a manually opened test world + release gate. In two concurrent database sessions call `create_airline_once` for the *same user and world*; assert one airline, one ledger STARTING_CAPITAL entry, total balance exactly 5,000,000 and a single unmodified trial clock. Also test distinct worlds: no second trial.
5. Test invalid, suspended and banned users; different-airline retry; closed worlds; wrong-world airport; terms version rotation; trial expiry. On error, verify no partial memberships, ledger entries or entitlement changes.
6. Leave the real Airlinerra Supabase project unmodified. After successful isolation tests, review Supabase security advisor output and obtain explicit owner approval before any actual game schema migration.

**Remaining blockers:** confirmed domain purchase, verified SMTP, privacy/terms publication, server-side signup controls, production build of pinned Supabase SDK (not CDN), legal-acceptance endpoint, user/session authorization middleware, audited admission/airport operator workflow, deployment review, and a separately approved World 01 opening.

See previous reports for the account UI, world model, profile repository and seven-day trial design. None of this changes airport research classification, the 8,153 technical catalog, or any gameplay approval.
