# Prepared Group 2 airport API: hosted deployment boundary (2026-11-10)

## Code committed on main
- `server/player-read-service.mjs`: authenticated, parameterized, bounded and fail-closed `/api/v1/player/prepared-airports` endpoint, returning only non-bookable Group 2 prepared airports.
- `server/canonical-game-api.mjs`: adds route to private canonical API routing.
- `website/player-read-client.mjs`: explicit browser client method; the default player-read feature flag remains disabled.
- `tests/test_player_read_api.mjs`: prepared-only status, non-bookable contract, validation, authentication and forged-admission rejection.
- `tests/test_real_local_player_gateway.mjs`: private route membership and fail-closed proxy behavior. The ordinary localhost-to-Edge proxy intentionally does not forward a route that the deployed Edge service does not yet implement.

## Production database verified
- Combined game-data catalog: 4,259.
- Group 1 approved airport register: 3,141.
- Group 2 prepared airport profiles: 1,118.
- Group 2 live commercial activation: 0.
- Sample query for Grant County International Airport `OURAIRPORTS:20581` returned prepared-only scope; the SQL is valid against production game data.

## Important deployment finding (actual active Edge function inspected)
Supabase `airlinerra-game` is ACTIVE **version 14**, and its deployed bundled `server/canonical-game-api.mjs` and `server/player-read-service.mjs` differ from GitHub `main`. The live bundle includes dedicated airport-office draft handling and a smaller read endpoint list; it does **not** contain the new `/api/v1/player/prepared-airports` route. The current repo canonical API lacks some of the deployed airport-office implementation. Consequently, redeploying the repository code as-is risks removing existing airport-office behavior. **No production Edge function redeployment was performed.**

## Deployment path
Reconcile the current deployed Edge bundle with the latest repository source before publishing. Preserve all existing hosted routes and airport-office handling; add the prepared-only read endpoint to the merged server module; test regression cases; deploy an explicitly versioned Edge bundle, then verify real authenticated 200/401/403 and prepared-only response, and only afterward enable the informational UI.

Do not add prepared Group 2 airports to the operational search, onboarding home-airport selection or slot engine. Never treat estimated Section 1–8 game data as legal airspace permissions or activate flights without independent release gates.

CI/test execution and browser-side deployment are **not verified** by the work on this day.
