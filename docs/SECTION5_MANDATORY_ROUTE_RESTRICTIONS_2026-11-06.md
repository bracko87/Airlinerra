# Airlinerra — mandatory aircraft/airport restriction checks in the route planner
Date: 2026-11-06
Project: Airlinerra World 1, Supabase `hwllkabgzaynalahvkpz`.

## Implemented

1. The main aircraft dropdown in the current route planner now includes **all aircraft from the real game catalog**, not just the non-operational test aircraft. Catalog selections are **planning previews only** and do not imply owned/leased inventory.
2. `website/route-aircraft-runway-screen.mjs` checks departure **takeoff** and destination **landing** runway requirements separately, using full-weight game reference distances when available. Its runway inventory screen uses available paved runways, omitting documented closed/abandoned runways.
3. A physically insufficient runway immediately raises a red **BLOCKED — This aircraft cannot be used on this route** message with exact needed and available lengths and missing metres, and disables **Apply route draft**.
4. The old optional "Check airport rules" button is removed. Exact UTC sample departure/arrival times and selected weekly local departures now trigger automatic read-only server screening.
5. The new `section5_weekly_route_restriction_gate_v1` computes up to 28 occurrences over **four weeks** using the origin airport's IANA time zone, converts weekdays from local time to UTC, rejects nonexistent DST times, and asks the universal time/runway/noise restriction gate to screen each occurrence. **It uses the player's entered sample duration**; a live scheduler must recalculate actual flights.
6. The protected `airlinerra-noise-curfew-check` Edge Function is now **v7 ACTIVE**, with input validation for up to seven unique weekly day/time selections and a single-flight compatibility path. This API remains read-only, explicitly returns `canActivateNormalFlight:false`, and performs explicit authenticated session verification inside the handler. It returns blocked individual weekly occurrences for the UI.
7. Saving a catalog-model route draft requires a fresh mandatory server restriction check. Confirmed hard restrictions prevent saving. Review-only restrictions remain warnings, not invented bans. All successfully saved routes remain **local drafts, not activated flights**.
8. `section5_aircraft_noise_game_fallback_v1`: **262 of 272** current configurations lack exact official configuration-matched noise certificates; these have **no additional game ICAO-Chapter ban** by default. This includes the **219** with no verified official chapter. A lack of certification is never misreported as an actual compliant certificate. Verified runway and curfew bans still apply.
9. Five public AirlineSim airport pages (AES, AAL, TRF, PED, JSI) compared to prior primary-source research in `section5_airlinesim_secondary_airport_audit_v1`. Simulator differences were documented but not allowed to override more detailed official airport evidence or falsely impose noise bans.

## Verification

- Pure browser-side helper passed direct test of **1,200m available vs 1,500m required**, with explicit 300m shortfall for origin; destination shortfall test passed.
- 3,141 airports and 272 current aircraft were screened through the universal engine, with zero unknown results and zero flight activation approvals (previous comprehensive sweep).
- SQL weekly test passed: Fukuoka weekly night curfew, 8 proposed occurrences checked; a separate example checks 12 occurrences without a hard game ban; duplicate weekdays rejected; invalid 02:30 local Berlin DST-gap time blocked.
- Regression file: `tests/sql/section5_weekly_schedule_gate_regressions.sql`.
- GitHub Actions route planner workflow previously failed due three outdated assertions, which were fixed. Run #108 completed successfully. A newer run for an additional weekly-request regression follows.
- Supabase Edge v7 deployed; no authenticated live-browser test of a player's real session or activated flight was performed.

## Still outstanding (do not call whole Section 5 100% complete)

- **1,246** airports with identified operational conditions still require source-specific normalization. This is not a count of proved full-airport curfews.
- The game still lacks an actual **flight schedule activation/write system**, owned operational fleet, validated flight duration and slot/traffic-rights engine. The server guard for future activation is present, but currently no production write calls it.
- The four-week check estimates arrival times using the supplied sample duration. Any longer-running or changed route must be rechecked when a transactional schedule engine exists.
- There is no proof of a live, authenticated, end-to-end production route booking/activation. No flights were activated or financial state altered.

Code and policy remain **game-specific**, never certified aviation dispatch permission.
