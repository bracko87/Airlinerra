# Airlinerra Group 3 — Step 5 backend integration (2026-11-06)

## What is genuinely implemented

Group 3 contains exactly **39** user-approved aircraft configurations. Every aircraft has structured research-planning data in Supabase project `hwllkabgzaynalahvkpz`. This is not an assertion of original type-certification for every field.

### Private market adapter

`airlinerra_game.group3_aircraft_market_catalog_v1` returns **39** rows, including configuration ID, manufacturer, model, passenger/cargo capacity, range, runway, fuel, noise classification, used/new equivalent reference prices, lease and hourly cost estimates, 1–6 passenger popularity, and production / future-model dates.

Prices and operating costs are **research game estimates**. Some real published aircraft benchmark prices are stored in the separate Group 3 economics table and must not be presented as exact transaction prices.

`airlinerra_game.group3_market_year_preview_v1(p_game_year)` calculates **provisional** new-build-year and used-aircraft research candidates. Its `can_purchase`, `can_lease` and `can_preorder` are all **false**, regardless of year. Never confuse year match with a release authorization.

Future display-only models are A350-1000ULR, 777-8F and D328eco. The unlaunched Dash 8-400 Cargo Combi retrofit is also locked. E195F has no confirmed first service year. Unverified conversion years remain labeled game-planning proxies.

### Loading and flight-rule integration

`airlinerra.aircraft_expansion_group3_check_loading_v1` checks 41 physical loading layouts (23 passenger-only models, 8 cargo-only and 8 combi/convertible models, with three choices for the Boeing 737-700C). It applies the configured passenger+bag mass, cargo mass and volume, MZFW, MTOW, MLW, fuel and distance. It is a **private research preview**, not a certified flight-release function.

`airlinerra_game.group3_flight_route_preview_v1` combines that loading check with the already-existing `airlinerra_game.section5_universal_route_restriction_gate_v1`. It returns preliminary origin and destination restrictions (runway/noise/time) plus loading and game-year reasons. **It always returns `gameHardBlocked=true`, `canScheduleNormalFlight=false` while Group 3 has no release.** Never use a preliminary pass from one sub-check to bypass the final game release gate.

`airlinerra_game.section5_group3_airport_aircraft_readiness_v1` joins 39 aircraft to **3,141** World 1 airport research records, totaling **122,499** aircraft/airport screening combinations. A runway-length PASS does not certify declared distances, runway operational availability, noise approvals, or any real-world dispatch.

### Real fleet-integrity guard

An enforced database trigger, `trg_group3_research_fleet_release_guard_v1` on `airlinerra_game.airline_aircraft_inventory`, calls `airlinerra_game.group3_airline_fleet_release_guard_v1()`.

It rejects INSERTs and relevant UPDATEs involving any Group 3 configuration with error `GROUP3_AIRCRAFT_NOT_RELEASED_FOR_FLEET`, for **both owned and leased** aircraft. Group 1 and Group 2 configurations remain outside this guard.

This is a narrow trigger function: a hardened database-owned function with fixed empty search path, no dynamic SQL, no external side effects, and no public EXECUTE grant. It only reads Group 3 configuration membership. It is not an endpoint for callers to bypass RLS or read private fleet data.

### Integration readiness

`airlinerra_game.group3_game_integration_status_v1` reports the 39 private backend adapters, model data, mode checks, exact image availability, and outstanding player-facing releases.

**Current blockers:**
- **0/39** approved, *exact-configuration* Group 3 hero images in `airlinerra.aircraft_configuration_media`. Ten variants happen to have approved images inherited from existing variants, but most depict DIFFERENT passenger/cargo configurations and must NOT be automatically assigned as Group 3 heroes.
- No playable React/Netlify game frontend is in this research archive; there is no working Group 3 player-facing purchase, lease, fleet or flight-scheduling interface to change.
- No production aircraft purchase/lease transaction engine connected to the new catalog. `airlinerra_game.airline_aircraft_inventory` has **0** real records as of this check; there is one development airline and a separate test fixture.
- No flight schedule persistence / dispatch creation system is connected to the Group 3 route preview. Do not create fake flights.
- Platform release gate is disabled; **no live activation is authorized**.
- The 737-200F and E195F cargo models still require exact conversion-weight evidence; all other unverified engine/noise/performance facts remain clearly marked. The single type/engine/mass Chapter 14 match for A340-541 does not authorize a registered airplane.
- **15** aircraft have planned mission-range derating at reference payload.

### How to integrate once a player app exists

1. Add a backend catalog endpoint using the exact configuration IDs and private market adapter; never expose private schemas or Supabase service-role keys to the client.
2. Add player-facing hero images keyed to each aircraft configuration **with the exact model/cargo/passenger configuration**, and approve those assets before enabling market display. Do not silently use a passenger image for a cargo conversion.
3. Build a *transactional* purchase/lease service (ownership, airline authorization, game calendar, pricing, cash, delivery, fleet capacity, registration) with server-side final validation. Research `can_purchase=false` should never be overridden in the browser.
4. Connect assigned flights to physical aircraft position, source/destination, schedule conflicts, turnaround, passenger/cargo layout and flight planning; recompute all route restrictions on the server at final flight creation. Apply the existing universal airport gate plus Group 3 loading/fuel checks, never preview booleans alone.
5. After completing source evidence, user-visible product checks, release permissions, regression tests and game deployment, introduce a separate **explicit owner-approved release mechanism**. Only then replace the temporary Group 3 inventory deny guard with a policy that authorizes eligible historic/used/new/future models. Do not automatically allow 2027/2029 forecast models based on dates alone.

## Verification

`scripts/verify_group3_game_backend_integration.sql` tests 39 market cards, 41 layouts, 122,499 airport screens, future and unlaunched status, invalid mixed-cargo combinations, route restrictions, and both fleet guard rejection and unaffected pre-existing model insertion. Fleet insert probes are performed in rolled-back PL/pgSQL subtransactions; no real aircraft is added.

Also rerun:
- `scripts/verify_group3_aircraft_planning.sql`
- `scripts/verify_group3_aircraft_history.sql`
- `scripts/verify_group3_aircraft_economics.sql`
- `scripts/verify_group3_aircraft_loading.sql`
- `scripts/verify_group3_aircraft_noise_performance.sql`

**Bottom line:** Group 3 is *database research complete and backend preview integrated*, **not fully playable or production launched**. Do not claim otherwise. The entire Airlinerra repository is public-development `main`, with production deployment explicitly separate in `docs/CONTROLLED_RELEASES.md`.
