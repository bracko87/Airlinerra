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
- Previously missing positive references: **139**. Now provided **provisional peer-model game estimates in a separate private planning view**, not as sourced manufacturer consumption.
- Private planning view: `airlinerra_game.aircraft_fuel_planning_profiles_v1` (271 rows: **132 existing provisional references + 139 derived estimates**; all positive). It references source model ID/name and confidence class for fallback cases.
- Fallback formula: nearest analogous donor by model family, speed class, MTOW and use type, scaled with `(target MTOW/donor MTOW)^0.82 × (target speed/donor speed)^0.20`. This is a *game design assumption* and can be wrong for less comparable aircraft. It is **not** flight certification or research completion.
- The live tables with existing research values were **not overwritten**; the planning view keeps source evidence and assumed values distinct.
- The private view is not exposed to anonymous/authenticated direct API roles and retains `approved_for_dispatch=false` and `approved_for_accounting=false` for every entry.
- Positive reference tank capacities: **270**.
- Distance rates from `airlinerra.aircraft_simple_fuel_per_100km_v1` are **provisional**; many cannot be dispatched.
- `airlinerra.aircraft_game_fuel_distance_rates` contains 119 entries, all with `gameplay_enabled=false`.
- Main `simple_fuel_gameplay_enabled` flags remain disabled; code does not flip them.
- The base game pricing is **$0.95/kg**, with airport-tier game factors: Mega Hub 0.95, Major Hub 0.98, Large 1.03, Medium 1.07, Regional 1.14, Local 1.22. All are **game-balancing assumptions**, not published fuel supplier prices.
- Read-only price module: `website/airport-fuel-price-preview.mjs`. A real airport category, when loaded, determines the provisional game price. Missing category retains the generic $0.95 baseline.
- External independent benchmark only: U.S. EIA/FRED DJFUELUSGULF, dated **2026-11-03**, **$4.198/US gallon** (approximately **$1.386/kg** using an assumed 0.80 kg/liter density). This is a **U.S. Gulf Coast spot price**, not an airport delivery contract, not globally applicable, and **not automatically used as the Airlinerra price**. Reference: https://fred.stlouisfed.org/series/DJFUELUSGULF
- Protected owner fleet API `airlinerra-fleet-acquisition` upgraded to **v10**, reads the private planning view and returns peer provenance for read-only flight estimates.

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
- Returns `UNAVAILABLE` and no monetary figure when relevant reference data is missing or invalid. Existing records without a usable source are now supplied **clearly labelled fallback game estimates** through the private view; unknown aircraft never silently receive a supposed real-world consumption rate.

## Next release gates
1. Research the 139 aircraft that currently use **provisional donor-model extrapolations**. Replace assumptions with documented per-model or per-engine consumption, storing source URLs and conditions.
2. Assign verified **fuel types** by engine/aircraft; currently the engine fuel class is expressly *unverified*, so Jet A-1 and AVGAS pricing is not yet applied separately.
3. Gather independently sourced **airport delivered fuel quotes** by geography, supplier and date. The current tier multipliers are balancing placeholders only; do not represent real contracts.
4. Validate short/long-sector phase fuel, cargo/occupancy assumptions, weather, reserve rules and tank screening against independent aircraft performance evidence.
5. Integrate a server-owned **idempotent flight fuel event**, only after actual trusted departure/arrival processing exists. Store actual tank/stock, burn and fuel transactions once per flight; never charge merely for drafting a route.
6. Verify the updated UI in a signed-in browser and deploy the frontend separately; passing CI tests is not production proof.
7. Address unrelated wider-build test failures separately from this fuel work; isolated fuel CI passes, but not every other Airlinerra suite currently passes.

Sources for phase-aware methodology: EUROCONTROL Standard Inputs for Economic Analyses,
ICAO engine emissions / LTO model; UNFCCC national inventories' five-plus-phase methodology.
For implementation we use simpler, explicitly disclosed balancing factors rather than claiming OEM fidelity.

## 2026-11-10 fuel-family follow-up — model-level completeness

- Private, read-only reference views:
  - `airlinerra_game.aircraft_fuel_family_reference_v1`: conservative fuel-family classification from catalog engine option.
  - `airlinerra_game.aircraft_fuel_family_reference_v2`: source-linked research for **18 aircraft with missing engine_option**.
- Verified DB result: **271 total configurations**, **270 turbine/kerosene-family model assumptions**, **1 piston/aviation gasoline family** (DC-6 with R-2800), **0 unknown model fuel families**.
- The 18 researched aircraft include A220, E195/E195-E2, A340-600, 767/777/787, Dash 8-300, EMB-120, Dornier 328-110, Beechcraft 1900C, A300-600R and A310-300.
- Model family data and source URLs are NOT confirmation of any individual aircraft's installed engine or approved fuel grade. **0 exact installed fuel grades verified**. `refuelling_approved` and `fuel_financial_settlement_approved` remain FALSE for every model.
- Aviation gasoline must NOT use the generic Jet A game price. `previewAirportFuelPrice` returns no USD value for `AVGAS_PISTON` or `UNKNOWN_ENGINE`. The five-phase calculator still shows trip kilograms, reserve and tank screening with `estimatedBurnCostUsd=null`, not a fabricated $0 or wrong-fuel price.
- Source guidance: FAA https://www.faa.gov/newsroom/leaded-aviation-fuel-and-environment; manufacturer's model-level source links are in `supabase/migrations/20261110235900_source_linked_aircraft_fuel_family_models_v2.sql`.
- Fuel rates are **still provisional**: 132 legacy distance/hourly references and 139 comparison-derived peer estimates, not OEM-confirmed fuel flow.
- Protected airline fleet API deployed at `airlinerra-fleet-acquisition` **v12** and includes `fuelFamily`, `fuelFamilyEvidence`, `fuelFamilySourceUrl`, `fuelModelWithoutEngine`; both fuel views are private (not directly SELECT-granted to anon or authenticated).
- Isolated fuel CI and protected website build passed. No authenticated browser or production frontend deployment verification has been performed for this update.
- Database gates checked: 0 catalog `simple_fuel_gameplay_enabled` flags, 0 fuel family records approved for refuelling/accounting, 0 settled flight financials.

### Remaining operational release gates

1. Source-check manufacturer/engine-specific fuel burn against the 132 provisional references and improve the 139 peer estimates. Record measurement conditions and uncertainty.
2. Confirm each physical aircraft's installed engine and fuel grade (where the game models such specificity).
3. Obtain fuel price/availability evidence at airports by fuel family, supplier, date, and local taxes. Six airport game-tier multipliers remain deliberately **non-quoted game estimates**.
4. Make the future server-owned aircraft fuel stock/tank, per-phase burn, reserve/alternate policy, airport uplift and accounting processor idempotent; do not activate until real trusted movements and safety gates pass.
5. Visually verify signed-in routes, edge-function authentication and the deployed frontend before claiming game-readiness.

## 2026-11-10 universal gameplay fuel decision (supersedes fuel-family split **for game calculations**)

The player approved **one fuel type for every Airlinerra aircraft**:

- Gameplay label: **Turbine/kerosene — model-level game assumption**.
- Private read-only gameplay view: `airlinerra_game.aircraft_game_fuel_family_v1`.
- SQL verified: **271/271** catalog configurations in this view report `TURBINE_KEROSENE_ASSUMED` and `UNIVERSAL_GAMEPLAY_ASSUMPTION`.
- The airline-owned fleet API reads this gameplay view (v13). Route fuel-price estimates now work with the universal kerosene tier assumptions for every aircraft with the normal pricing input.
- **Different aircraft still have different consumption rates**; the common fuel type does not unify fuel burn, tank capacity or flight time.
- The separate source-research views `aircraft_fuel_family_reference_v1`/`v2` are **unchanged**. For example, the DC-6's real piston/AVGAS evidence remains stored as `research_fuel_family`. This is deliberate: the game simplification must never falsify aircraft research.
- No claim of a certified installed engine, approved fuel grade or actual airport supply. Every gameplay row keeps `refuelling_approved=false` and `fuel_financial_settlement_approved=false`.
- Existing provisional fuel rates and estimated airport-tier prices remain game estimates, not actual invoices.
- The isolated fuel CI passed, including browser build; signed-in frontend visual verification remains outstanding.
