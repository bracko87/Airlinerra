# Airlinerra — Airport Office Phase 4: verified rollout readiness

Date: 29 October 2026. **Source-only on draft PR #2. Not deployed.**

## Verified environment boundary

Connected Supabase projects include one Airlinerra production project:
`hwllkabgzaynalahvkpz`. At verification, `list_branches` returned zero development
branches, and there is **no separate Airlinerra staging project**. Therefore this
work must NOT interpret the live Airlinerra project as staging, execute a production
DDL migration there, or enable the office API/client on production.

Read-only live checks: `airlinerra_game.airport_offices` was absent; existing
`airlinerra_game.airlines` and `airlinerra_game.airline_ledger` were unchanged.
The current deployed `airlinerra-game` Edge Function is v9. This branch adds a
canonical API route in source, **not** a deployed Edge Function route.

## Actual PostgreSQL end-to-end test

CI workflow `.github/workflows/airport-office-drafts-ci.yml` provisions an
ephemeral PostgreSQL 17 database named `airlinerra_office_disposable` on
`127.0.0.1` and verifies this exact target before any test starts.

`tests/e2e/airport-office-disposable.mjs` executes the real
`createCanonicalGameApi` -> `createAirportOfficeHttpHandler` ->
`createAirportOfficePersistence` -> real PostgreSQL queries with a trusted
test-only Auth identity verifier. Tests seed three airlines across two verified
owners and two distinct worlds; airports are **only synthetic CI fixtures**.
Assertions include:

- owner-scoped list/save/remove, no cross-user visibility or deletion
- world-isolated airport authorization and absence of cross-world draft leakage
- rejected headquarters, unapproved airports, invalid operations and forged Auth
- idempotent replay and concurrent same-airline inserts serialized safely
- database constraint rejection for `active` status, wrong-world foreign key,
  and forbidden headquarters insertion
- RLS + no direct browser-role SELECT grants
- zero changes to each airline's $5,000,000 fixture cash and zero ledger rows
- idempotent migration applied twice before test

Successful run: https://github.com/bracko87/Airlinerra/actions/runs/40907976359
Prior focused Node tests (20/20) and website build also passed.

## Production release conditions — still NOT met

1. Owner-controlled non-production Supabase project or preview database must exist;
   do not create a potentially billable Supabase branch without explicit approval.
2. Re-verify its actual schema and migration history; apply the private draft-only
   migration to that **non-production target** and run the same negative tests.
3. Deploy an authenticated office route to the **non-production** game Edge Function
   and route it through the proper same-origin Netlify adapter. Production v9
   is not modified by this PR.
4. Verify with actual invited-test accounts in the correct game worlds. Auth
   must be independently verified on each call; no client-supplied airline ID.
5. Enable `airportOfficeDraftsEnabled` on that backend, then
   `AIRPORT_OFFICE_DRAFT_API_ENABLED` in the preview client. Both remain false
   in the current source defaults.
6. Test reload, multiple browsers, unrelated local drafts, 401/403/409/503
   failure paths, and that local drafts are not silently migrated or discarded.
7. Require owner-reviewed PR and passing relevant gates before any production
   migration or deploy. Existing unrelated airport-register and account/navigation
   CI failures remain separately tracked; do not claim full-repository green.

Real staff assignments, quotes, opening and recurring fees, active offices,
aircraft schedules, flight boards, slots, and passenger/cargo metrics are still
separate features. No production mutation was performed in Phase 4.
