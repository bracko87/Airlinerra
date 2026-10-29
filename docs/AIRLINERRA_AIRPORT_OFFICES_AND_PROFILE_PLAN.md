# Airlinerra - Headquarters, hubs, stations and airport profile

Implemented 29 October 2026. The owner wants company headquarters and operational airport presences treated as different entities, followed by a rich airport page for all catalog airports.

## Business meaning

- **Headquarters**: permanent company home airport chosen at airline creation and read from the verified owner airline. Its home airport may also serve as the airline's primary hub, but the headquarters record and its immutability must not be treated as a newly purchased extra hub. Panonian has Belgrade Nikola Tesla Airport (LYBE).
- **Hub**: airline base for connection flows, aircraft basing, ground handling and crew. Additional hubs have variable opening fees and recurring service / airport charges; future cost depends on the game's six canonical airport categories, real facilities, slot capacity and services. No fees are configured or deducted in the current implementation.
- **Station**: smaller airline representation at an airport where the airline is operating. Active station requires at least one actual station employee. Future activation will charge airport-specific desk fees plus the contracted employee salary. No employees or contracts are created by the current planner.
- Each airport may host multiple airlines, distinct headquarters, hubs, stations and scheduled services, but those must come from server-side verified owned-airline records, not local draft data.

## What is available NOW

- `website/airline-airports-office.mjs`: headquarters shown separately using the authenticated airline; independent proposed hubs/stations lists; country and approved-airport search; no duplicate proposed locations or headquarter proposals; 20 proposal limit; storage scoped by verified user ID and browser session; delete proposal action. Legacy hub drafts migrate for display until a new proposal is saved. No game transaction.
- A dedicated `#airport-profile` route, accessible from verified HQ, hub/station rows, and the approved airport directory search in Settings. It renders safely with text nodes.
- Verified airport info: approved airport key, name, catalog code, country code and municipality if the current authenticated directory returns them. World is Horizon. The HQ overview endpoint currently supplies its name, code and catalog key, but not municipality/country.
- Profile sections: identity, ICAO/IATA/time zone and geography, six-category classification, runways/stands/slots/terminals, passenger/cargo demand and traffic, airlines with headquarters/hubs/stations/operations, departure/arrival board, destinations and route frequencies. Unavailable fields explicitly say `Data pending` or `Not connected`. No fake counts or demand percentages.
- No Supabase migrations, Supabase Edge function deployments, fees, salary payments, bookings or public release changes.

## Required next-phase server implementation (NOT implemented yet)

1. **Airport master data enrichment** - a private normalized record keyed by (world_id, airport_key): IATA/ICAO, aliases, latitude/longitude, time zone IANA ID, type and the exact six canonical airport category names, verification timestamp and provenance per field. Airports need public real-world versus fictional attribution.
2. **Runways** - separate collection by airport/runway ID with length, width, operational status, surface, declared performance limits, airport restrictions, night curfews and aircraft capacity constraints. Null means unknown rather than zero. No non-operational/grass/gravel runways in the approved pool without explicit game rules.
3. **Capacity and slots** - scheduled arrival/departure slots by local time, runway/terminal/gate/stand and configured reserved capacity, with conflict checks, releases and transactional reservations. Slots are NOT a simple global 0-100% supply.
4. **Passenger and cargo demand** - sourced baseline daily/monthly volume per airport, seasonality, class, purpose (business/tourist), cargo, origin/destination matrices, market shares and route-level potential. An on-screen 0-100% value should identify the *reference* (percent of measured demand potential or utilization), not present arbitrary normalized numbers. Every number needs source date and update policy.
5. **Airline airport offices** - server-side table of `airline_id`, `airport_key`, role (headquarters/hub/station), activation timestamp, state, fees, minimum staffing and availability; RLS and ownership checks; unique (world, airline, airport) as appropriate. The headquarters must be derived from or linked to the existing verified owner airline. Roles must not be inferred from route stopovers.
6. **Activation costs and actual employment** - category/service/aircraft/staff-dependent price model with an explicit quote, owner confirmation, server-validated affordability and idempotent atomic ledger charge. Stations must check >=1 assigned active employee before opening. Charge recurring fees and staff salaries only through the game economy at scheduled game ticks.
7. **Airport traffic read model** - owner-authorized, privacy-safe multi-airline aggregate read service for airlines with HQ/hubs/stations, airlines actively operating, per-airport aircraft movements and route frequencies. Protect ownership data and prevent cross-world leaks.
8. **Live airport flight board** - bounded server-side departure/arrival data with scheduled and actual clock times, origin/destination codes, airline name/ICAO code, aircraft and operational state. Search/pagination/filters, and no fabricated data when flight engine is offline.
9. **Data quality** - null provenance, coverage dashboard, data-refresh cadence, airport category validation, airport-service eligibility, and fixture/authorization tests across all three worlds.

No direct client-side database writes should be introduced. Pilot work remains Github main -> local preview -> manual Netlify only after owner approval. Avoid deploying database migrations without verifying schema and authorization.
