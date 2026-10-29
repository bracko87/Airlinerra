# Airlinerra Airport Operations — Phase 5: complete gated transport (29 October 2026)

**Status:** Feature branch + draft PR #2 only; no production or staging deployment.

## Work completed

- Registered `/api/v1/player/airport-offices` in Netlify's game function route list. This does not authorize writes.
- Added `airportOfficeDraftsEnabled=false` to the production Netlify proxy. The route answers HTTP 503 **without contacting Supabase Edge** unless a separate, explicit backend opt-in is provided. Existing game endpoints are unaffected.
- Explicitly set `airportOfficeDraftsEnabled:false` in the Supabase Edge entrypoint to preserve its current fail-closed behavior.
- Enforced a 512-byte request limit at the new Netlify route. Server-side office request parser now uses standard `TextEncoder` to work in Node and Deno.
- Added `tests/test_airport_office_release_gate.mjs`: tests disabled-by-default no-upstream, explicit opt-in forwarding, bearer/origin/body restrictions, route registration, and disabled Edge entrypoint.
- Extended `tests/e2e/airport-office-disposable.mjs` to exercise Netlify proxy -> **in-process** Edge handler -> authenticated canonical API -> private service -> real disposable PostgreSQL, with two owners and two worlds. The emulated Edge transport does not contact external Supabase or Netlify. Test-only Auth verifier is used; real hosted Supabase Auth has not been end-to-end exercised.
- Updated isolated GitHub Actions and normal npm tests for the release-gate coverage.

## Results

Isolated CI: https://github.com/bracko87/Airlinerra/actions/runs/40909478110
- 24/24 airport-office Node checks passed.
- Website build passed.
- Disposable PostgreSQL migration and real database integration passed.
- Real database security and balance/ledger invariant checks passed.

These checks do not override unrelated failures in the airport-register test workflow and older account/navigation regressions.

## Independent deployment prerequisites

The current connected Supabase project `hwllkabgzaynalahvkpz` is the only Airlinerra project; it reports no development branches. It remains production and must not be treated as a disposable staging target. Current production `airlinerra_game.airport_offices` does not exist.

Before a real web user can persist drafts across sessions:
1. Provision/approve a separate staging Supabase project/branch and staging origin with an explicit cost decision.
2. Apply the draft-only migration to staging, verify grants/RLS/FKs.
3. Deploy the **new** canonical API with its added office modules to the staging Supabase Edge Function. The currently deployed production v9 cannot serve this new endpoint.
4. Test with real hosted Supabase Auth and two distinct user accounts, and verify Netlify's API routing and the browser's Hubs/Stations interface.
5. Set the server and web feature flags to true **only in staging**, with verified target URLs and fail-closed default elsewhere.
6. Review all failing repository-wide CI checks before promoting anything to production.
7. Never enable active hubs, stations, billing or employees until the separate staffing/pricing/ledger system exists.

**No production changes** were made in this phase. Save/list/delete are still draft-only by design; existing browser-only plans stay separate without automatic upload.
