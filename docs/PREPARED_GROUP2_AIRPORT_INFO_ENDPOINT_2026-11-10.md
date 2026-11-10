# Airlinerra — prepared Group 2 informational airport search (2026-11-10)

## Scope
The World 1 airport catalog contains **4,259** records with Sections 1–8 game data, while the approved/operational register still contains only **3,141 Group 1** airports. Group 2's **1,118** airports must not become bookable or dispatchable simply because a combined reference catalog exists.

## API change committed on main
In `server/player-read-service.mjs`, a new **authenticated read-only** POST endpoint is declared:
`/api/v1/player/prepared-airports`.

It returns **only** Group 2 prepared catalog entries, with a hard requirement for `source_group='GROUP_2'` and `commercial_access_scope='GROUP2_PREPARED_NOT_ADMITTED'`. Search is country-scoped or requires a minimum 2-character global query; input validation, 50-result page size, bounded offset, verified account, origin check, prepared-state validation and parameterized SQL match the existing protected player-read service.

Every returned item is explicitly marked:
- `sourceGroup: GROUP_2`
- `status: prepared_only`
- `commercialAccess: false`
- `bookable: false`
- `canActivateFlights: false`

The endpoint as a whole also returns `scope: prepared_information_only`, `bookable: false` and `canActivateFlights: false`.

`website/player-read-client.mjs` now exposes a matching `preparedAirports()` method while keeping `PLAYER_READ_API_ENABLED=false` and retaining the existing allowed host checks.

**Crucial:** The existing `/api/v1/player/airports` SQL, the existing airport profile endpoint, the route planner, airline home base selection and the approved country counts have **not** been modified. The booking/route search still uses `approved_game_airports` only. Prepared airports are therefore not selectable for routes, commercial flights or operational slot reservations by this change.

## Validation
The production database query against the same combined view returned exactly **1,118** prepared Group 2 records. Sample search for `Grant` in the US returned Group 2 Grant County International Airport with the expected `GROUP2_PREPARED_NOT_ADMITTED` status. Group 2 remains **0 operationally activated**; Group 1 approval remains **3,141**; combined data remains **4,259**.

`tests/test_player_read_api.mjs` has a new test for authentication, prepared status, a blocked forged approval, invalid offsets and proof the approved route-search SQL is unchanged.

**No live API deployment, browser UI rendering or passing CI run has been established.** The player read client is explicitly disabled by default, and this server endpoint must be added to the actual API gateway allowlist/deployment before it can be used by real visitors.

## Next tasks
1. Add the informational prepared-airports endpoint to the real server/gateway deployment only after backend access control and integration tests pass.
2. Keep airport-info browsing and the operational route planner separate. Any future Group 2 commercial admission requires independent Section 5/6 engine integration, permits, restrictions and slot checks.
3. Verify CI and end-to-end authenticated API behavior in deployment, without enabling live flights.
