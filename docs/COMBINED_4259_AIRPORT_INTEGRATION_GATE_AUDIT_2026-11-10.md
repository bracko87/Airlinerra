# Airlinerra — combined 4,259-airport integration audit (2026-11-10)

## Scope
The combined Section 1–8 catalog is not equivalent to commercial admission. Existing World 1 game/route scheduling functions are tied to the previously approved Group 1 airport set. This document records a production, read-only integration audit and new optional private preview, **not** a switch-over.

## Verified production coverage
| Area | Group 1 | Group 2 |
| --- | ---: | ---: |
| Combined game-data catalog | 3,141 | 1,118 |
| Positive game runway | 3,141 | 1,118 |
| Game stand/slot capacity values | 3,141 | 1,118 |
| Game nighttime/noise flags | 3,141 | 1,118 |
| Existing Section 6 slot-capacity engine rows | 3,141 | 0 |
| Existing Section 5 operating-policy engine rows | 3,141 | 0 |
| Existing approved airport registry | 3,141 | 0 |

New objects:
- `airlinerra_game.airport_sections1_8_integration_status_v1` — a restricted, security-invoker view of source-group operational system coverage.
- `airlinerra_game.airport_sections1_8_preview_aircraft_v1(airport_key, configuration_id, operation)` — a private **read-only** inspection function. Shows catalog runway length, aircraft model reference requirement, stand-type game per-10-min capacity, stored game curfew/noise flags, source-group / admission status. **Always** returns `canActivateNormalFlight=false` and `canBookSlots=false`; does not verify actual slot reservations, full-weight performance, official aircraft noise Chapter matching, curfew-hour applicability, licenses, weather, real-world dispatch permissions or trusted movements.
- Direct anon/authenticated function execution and view access are revoked.

## Confirmed test cases
1. Existing Group 1 Narsarsuaq (OURAIRPORTS:113) vs B737-800 (configuration 1, departure): catalog runway **1,830 m**, catalog aircraft takeoff reference **2,230 m**, therefore returns `BLOCKED_CATALOG_RUNWAY_LENGTH`. The original Section 5 universal gate separately returned `BLOCKED_GAME_RUNWAY_LENGTH` after using its full-weight performance reference of 2,248 m.
2. Group 2 Grant County International (OURAIRPORTS:20581) vs the same 737-800: game runway 4,115.7 m, catalog length enough, terminal/remote/cargo per-10-min game capacities 3/1/1. Preview returns `PREPARED_NOT_ADMITTED`, `canActivateNormalFlight=false`, `canBookSlots=false`.
3. Existing Section 5 universal leg restriction gate directly rejects Group 2 Grant County as `BLOCKED_UNKNOWN_AIRPORT_OR_AIRCRAFT` (rather than accidentally authorizing it).
4. Attempting the existing Section 6 weekly slot preflight using a Group 2 origin raised `SECTION6_AIRPORT_TIMEZONE_MISSING`; Group 2 has no existing slot-engine rows. This is a current integration gap, not a successful availability check.

## Safety checks
Production readback:
- Combined catalog still **4,259**, approved registry **3,141**, Group 2 commercially enabled **0**, World 1 `planned`.
- No airline/flight/schedule/ledger writes from this migration.
- Existing live-facing airport search/route planner API still requires separate integration and testing. Do not change approved-airport admission simply to surface a new airport in informational searches.
- Group 2 operational access cannot be inferred from estimated game fields, especially at military bases and airports under airspace restrictions.

## Next engineering actions
1. Inspect authenticated player airport-read endpoint. If informational catalog visibility is wanted, add a distinct `prepared` scope for Group 2 that the route planner cannot select as an operational endpoint until approval.
2. Design a deliberate, source-safe promotion path into Section 5 and 6 engine data structures; include current operational restrictions, full-weight runway validation, local-time curfews/Chapter rules, reservations and permission gates. Do not silently overwrite Group 1 records.
3. Validate backend and UI tests, then separately review any authorization for commercial admission. A successful read-only preview is not operational signoff.
