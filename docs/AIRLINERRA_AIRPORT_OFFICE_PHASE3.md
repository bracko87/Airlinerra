# Airlinerra Airport Operations Phase 3 — private draft API and UI integration

Implementation date: 29 October 2026.
Review: draft PR #2 on `feature/airport-office-persistence-foundation` (base `main`).
CI: [isolated airport-office validation run](https://github.com/bracko87/Airlinerra/actions/runs/40907105207) passed 20 focused Node tests and disposable PostgreSQL migration checks.
This is NOT deployed to the actual game.

## Implemented in source

- `server/airport-office-http-handler.mjs`: POST `/api/v1/player/airport-offices` operations `list`, `save`, `remove`; strict body contract, capped size, approved origin, bearer token, redacted errors, default off. No `activate`, fee, charge or staff mutation operation.
- `server/canonical-game-api.mjs`: dispatches this one new route only to the guarded handler, otherwise retains existing account routes. New constructor option `airportOfficeDraftsEnabled=false` independently controls backend availability.
- `website/airport-office-client.mjs`: owner-authenticated, same-origin client. Export `AIRPORT_OFFICE_DRAFT_API_ENABLED=false`. The only network calls are through the protected route with an in-memory Auth access token. No private table is exposed directly.
- `website/player-app.mjs`: forwards the office client to Operations when explicitly enabled. It is NOT currently enabled.
- `website/airline-airports-office.mjs`: if the enabled client is present, server-owned draft list/save/remove is used. On unavailable API, it fails closed and does not silently write to browser storage. When disabled, existing browser-only planning continues.
- Browser-only drafts are never auto-migrated, overwritten, claimed as verified, or silently charged; the interface labels the separation.
- `website/dev-scripts/invited-overlay.mjs`: adds the gated browser client to the preview build bundle.
- `tests/test_airport_office_http.mjs` and `tests/test_airport_office_browser.mjs` exercise server-disabled behavior, strict HTTP inputs, owner token transport, API response validation and local-data isolation.
- The package's normal `npm test` includes the new feature tests; the isolated PR workflow validates new functionality separately from older failing account/navigation and airport data checks.

## Important deployment ordering — do not skip

1. Fix/review pre-existing failing repository checks separately; do not claim full-repository green from the isolated feature run.
2. Review the private migration and its RLS/privilege posture; apply only to an approved non-production/staging database first. Verify using real approved airports and a controlled test account.
3. Deploy the authenticated canonical HTTP route through the actual backend and verify deployment, origin checks and owner isolation end-to-end.
4. ONLY THEN opt in the backend `airportOfficeDraftsEnabled` and browser `AIRPORT_OFFICE_DRAFT_API_ENABLED` flags in a controlled build. Never turn on one side without verifying the other.
5. Preserve local proposals until the user explicitly selects any migration action. Do not auto-import browser drafts into the private database.
6. Verify server save/list/remove across browser sessions with two different users and across game worlds; test 401/403/409/503 and billing invariants.
7. Do not enable active hub/station status until real personnel assignments, verified fees, idempotent ledger transactions and recurring-charge service are separately designed and tested.

## Unimplemented features

Activation and airport opening payments, station employees, salary/airport fee schedules, verified infrastructure/demand and live airport flight statistics remain future work. The `airport_offices` table only permits `draft`. No Supabase migration or Edge Function has been run against production, no Netlify deploy, no balances/ledger/aircraft/flights changed.
