# Airlinerra — five-phase fuel engine (2026-11-10)

## Implementation state
- Branch: `main` only.
- Pure calculator: `website/flight-fuel-phase-engine.mjs`.
- Protected owner fleet reads: `server/fleet-acquisition-service.mjs`.
- Preview: route planner (`website/route-planner.mjs`), plus Aircraft Profile reference values.
- Production financial settlement: **NOT connected**, no direct fuel charges, no refuelling, no dispatch authorization, no inventory movement.
- Test suite: `tests/test_five_phase_fuel_preview.mjs`.
- Existing financial dashboard explicitly excludes unimplemented estimated fuel expenses.

## Existing data inspected in World 1 (2026-11-10)
- Aircraft configurations: **271**.
- Positive distance or hourly fuel references: **132**.
- Missing usable positive consumption references: **139** (do NOT silently assign an invented generic rate).
- Positive reference tank capacities: **270**.
- Distance rates from `airlinerra.aircraft_simple_fuel_per_100km_v1` are **provisional**; many cannot be dispatched.
- `airlinerra.aircraft_game_fuel_distance_rates` contains 119 entries, all with `gameplay_enabled=false`.
- Main `simple_fuel_gameplay_enabled` flags remain disabled; code does not flip them.
- Group 3 economics uses a **$0.95/kg game-balancing price**. This is NOT an airport quote or a verified current market price.

## Phase model
1. Taxi out: fixed 15 minutes.
2. Takeoff and climb: up to 20 minutes; shorter flights shorten the phase.
3. Cruise: calculated from airfield distance *after subtracting climb and descent distances*.
4. Descent and landing: up to 20 minutes, adjusted on short flights.
5. Taxi in: fixed 10 minutes.

Factors relative to model cruise flow: 0.25, 1.35, 1.00, 0.52, 0.22.
All five factors are explicit **game-balancing assumptions**; not OEM figures or flight clearance.

The existing whole-mission kg/100km reference is calibrated on a 1000-km benchmark.
Its whole-flight fuel is split into phases. It is **not added** a second time.
A catalog hourly reference is used only if a positive distance reference is unavailable.
For payload, use empty/half/full interpolation where available. Occupancy in route UI
is an assumed planning input, not a verified aircraft weight or payload manifest.

## Outputs
- Individual phase durations and estimated fuel burned (kg).
- Block time estimate; modeled trip fuel and cost (USD).
- Screening reserve = 5% of trip plus 30-minute hold at 50% model cruise flow.
- Tentative load (burn + reserve) and reference tank screening when a tank value exists.
- No final alternate-airport fuel, weather/wind, actual route track, ATC/airspace,
  current fuel price, takeoff weight/CG or equipment verification.
- Returns `UNAVAILABLE` and no monetary figure when relevant reference data is missing.

## Next release gates
1. Source-link or label the **139 missing aircraft burn profiles** (do not enable dispatch by a guessed source).
2. Assign aircraft **fuel types** from sourced engine/aircraft data before differentiating Jet A-1/AVGAS.
3. Research airport-fuel-pricing, source and date; add guarded pricing reference, not a hard-coded universal quote.
4. Verify short-/long-sector tests against real aircraft references, reserve and tank constraints.
5. Connect verified, server-owned flight events to fuel use and one-time idempotent settlement **only after flight activation passes**.
6. Test signed-in browser appearance and deploy the website separately; a GitHub CI pass is not a production browser check.

Sources for phase-aware methodology: EUROCONTROL Standard Inputs for Economic Analyses,
ICAO engine emissions / LTO model; UNFCCC national inventories' five-plus-phase methodology.
For implementation we use simpler, explicitly disclosed balancing factors rather than claiming OEM fidelity.
