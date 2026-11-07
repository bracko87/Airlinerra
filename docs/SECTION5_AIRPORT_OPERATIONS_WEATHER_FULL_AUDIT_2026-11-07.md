# Airlinerra Section 5 — Airport Operations & Weather — Full audit (2026-11-07)

**World:** 1. **Airports:** 3,141. **Aircraft configurations:** 272. **Master status:** `partially_populated`.  
**Purpose:** distinguish complete game defaults, sourced airport restrictions and genuine remaining work. This is a read-only audit; no user data or game rules have been changed.

## Current game baseline
- 3,141/3,141 operating-policy records; all have the `default_game_open_24_7=true` default **subject to more specific documented restrictions**. This is a GAME rule and not a claim that the real airport never closes.
- 3,141/3,141 IANA airport time zones and operations-baseline rows.
- Initial airport operating research: **1,312** airports with conditions found, **1,012** sourced/screened with no *general* curfew identified, **817** provisionally screened with H24 game default. These three groups total 3,141.
- **1,246** of the 1,312 condition airports remain in the normalization queue: research findings with source URLs have not been converted into individual schedule-enforceable rules. Another **66** airports have structured time rules, and even those can have additional unstructured conditions.
- **91** time-rule records, covering **66** airports; **55** hard prohibitions across **37** airports; **36** other rule records need review or have non-hard effects. One source-backed runway-specific rule currently exists.
- Database catalog: 3,141 airports classified, including 1,571 with some form of specific-restriction research still requiring review; not equivalent to 1,571 proven bans.
- **Airport local noise research:** 24 source-rule records covering **21** airports; **3,120** airports do not have individually sourced local Chapter-policy research. Countrywide baseline rules are separate from this count.
- **Aircraft noise:** 272 configurations; 10 exact configuration-matched certificates; 262 have the approved `NO_ADDITIONAL_GAME_NOISE_BAN_WITHOUT_MATCHED_CERTIFICATE` fallback. 219 have no source-verified Chapter at all; the larger 262 also includes less precise certificate evidence. Fallback is not a legal noise clearance. Five AirlineSim pages are stored as **secondary comparisons** and do not auto-block.
- Mandatory runway suitability, curfew, specific confirmed noise rules and weekly screening (up to four weeks, selected departure weekday and origin IANA time zone) are available for route drafts; each save of an owned-fleet server schedule draft rechecks inside its transaction. The signed-in player flow is not a live-flight execution/activation system.
- 0 real operational-fleet airframes, 0 server-saved operational schedules at latest verification. Activation remains deliberately blocked and tracked in [Issue #10](https://github.com/bracko87/Airlinerra/issues/10).

## Weather — current on 2026-11-07
- `MET_NORWAY_LOCATIONFORECAST_2_0_COMPACT` returns **3,141 current airport forecast records**, valid at time of audit. All 3,141 have hourly JSON (157,050 total hourly items), next-24h forecasts, temperature, wind, precipitation and weather symbol. Forecast data fetched between **01:00 and 04:16 UTC** on 7 November 2026, with validity extending at least to **9 November 03:00 UTC**.
- Provider health latest `SUCCESS` 2026-11-07 04:16 UTC; refresh log records 496 `COMPLETED` and 369 historical `PARTIAL` runs.
- **0/3,141** records have an aviation-visibility field; **0/3,141** have the separate `weather_code` field, although an alternate `weather_symbol` is populated for all. Snowfall numeric field also empty across all.
- **Weather is NOT an actual flight-dispatch gate.** Confirmed by inspecting the Section 5 route gate PostgreSQL function bodies; they do not query Section 5 weather data.
- The `section5_airport_operations_baseline_v1.weather_snapshot_status` text is stale for most records (3,137 still say initial data pending) despite the live forecast table being current. Update this metadata from authoritative provider state instead of reporting zero weather coverage.

## Operational constraints not yet connected
- Live NOTAMs: 34 observations cover 24 airports, but **3,141/3,141** operations-baseline rows say `NOT_CONNECTED_TO_SCHEDULER`; current route-gate functions do not enforce a live NOTAM update.
- Pavement structural strength: **3,141/3,141** operations-baseline rows say `UNVERIFIED` (different from runway length suitability).
- Stand/aircraft compatibility: all 3,141 use simplified `ALL_STANDS_ACCEPT_ALL_AIRCRAFT_SIMPLIFIED` game logic. Stand capacity and assignment belong to Section 6 / operational scheduling.
- Only 1 source-backed runway-specific restriction rule and 2 separate operational permission-evidence records have been structured; broader runway-specific permissions need to be considered in the remaining 1,246 normalizations if applicable.
- No full recurring flight-activation and execution engine; check ticket #10.

## Exactly what remains for a defensible *game-data* closure
1. **1,246 rule normalization decisions**: categorize each researched condition as (a) documented hard curfew/closure, with exact weekdays, local windows and source; (b) conditional/PPR/quota/review-only rule; or (c) informational, not a hard ban. Preserve current research and do not silently treat known conditions as genuinely unrestricted. If no enforceable specifics can be established, label the rule as **provisional game default/no additional restriction with review pending**.
2. Finish/review **local airport noise** evidence only when the game needs a specific restriction; apply existing user-approved no-extra-game-noise-ban fallback where no matching certificate or sufficient rule exists. Do not fabricate certificates.
3. Weather: update stale baseline availability flags; document provider refresh, cache validity and fallback on forecast expiry. Decide whether to add **visibility** and other aviation weather fields before operational gating. Do not fake aviation minima.
4. NOTAM: distinguish research-only snapshots from current safety signals; define default game behavior when real-time NOTAM data is unavailable. *Actual* closure enforcement on activated flights depends on a future transactional operations engine.
5. Pavement strength / operational permits / aircraft-specific stand limits: define game-specific fallbacks or warnings only within appropriate safety/release rules; do not assert certified real operations.
6. Consistency/acceptance tests: all 3,141 airports receive deterministic route decisions; known hard rules enforce correctly on origin/destination, midnight/DST, weekdays and recurring schedules; no unknown source becomes a fabricated hard ban; weather/provider metadata accurate.
7. Gameplay release dependency: real airframe ownership, scheduling/activation, crew, rights and slots remain under [Issue #10](https://github.com/bracko87/Airlinerra/issues/10), and capacity/stands under Section 6. These should not prevent an honest **game-data-ready** status if source-backed rules and defaults are represented properly, but they do prevent claiming full live operational readiness.

## Important definitions
- **Game data populated:** deterministic baseline or explicitly marked fallback exists.
- **Airport research normalized:** source-backed findings converted to precise, review-only or explicitly provisional game decisions, with provenance retained.
- **Certified real-world clearance:** **not provided by Airlinerra**; never infer from defaults.
- **Operationally live:** requires actual aircraft, flights, activated scheduling and enforcement; **not complete**.

## Read-only audit references
- `section5_airport_operating_policy_v1`
- `section5_airport_restriction_normalization_queue_v1`
- `section5_airport_time_restrictions_v1`
- `section5_airport_game_restriction_catalog_v1`
- `section5_airport_weather_profile_v1`
- `section5_airport_weather_forecast_v1`
- `section5_weather_provider_health_v1`
- `section5_airport_operations_baseline_v1`
- `section5_aircraft_noise_game_fallback_v1`
- `section5_database_readiness_summary_v1`
- GitHub issues [#9](https://github.com/bracko87/Airlinerra/issues/9) and [#10](https://github.com/bracko87/Airlinerra/issues/10)

**Conclusion:** Section 5 remains `partially_populated`: weather data and default airport policies are complete for game presentation, but 1,246 researched operating conditions need precise game disposition; real NOTAM/aviation weather dispatch and flight execution are not connected. This report does not change the database status.
