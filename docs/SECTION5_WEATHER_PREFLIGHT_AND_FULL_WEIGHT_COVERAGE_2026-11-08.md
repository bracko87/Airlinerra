# Airlinerra Section 5 — Weather preflight and full-weight coverage checkpoint
Date: 2026-11-08. Supabase World 1: `hwllkabgzaynalahvkpz`.

## Implemented in this checkpoint

- GitHub PR #13 merged to `main` as `6fe38afa9b7ac02a077e027c3105cc1c52ed859b`.
- The authenticated read-only noise/curfew route preflight now also reads MET Norway airport weather *for the entered example UTC departure and arrival times only* using a 1-hour forecast matching window.
- The server response has `weatherPreview.origin` and `weatherPreview.destination`, with explicit statuses `FORECAST_REFERENCE_AVAILABLE`, `FORECAST_SOURCE_STALE`, `OUTSIDE_FORECAST_HORIZON`, `FORECAST_MISSING`, `NO_MATCHING_FORECAST_HOUR`, and `FORECAST_QUERY_UNAVAILABLE`.
- Route-planner UI displays the reference forecast and a clear note that it is **not** flight/weather clearance. The lookup is additive and failure-tolerant: it does not disable or bypass mandatory curfew, runway, verified noise, or slot restrictions.
- Production Supabase Edge `airlinerra-noise-curfew-check` upgraded from v7 to **ACTIVE v8**, retaining verified token handling and `verify_jwt=false` at the platform boundary because the function performs its own fresh authenticated session check. Deployed entrypoint matches GitHub `main`, with the new weather helper bundled.
- Focused route-planner Node tests and site build passed on the PR and `main` (main workflow run 42491812839); separate staged Netlify function bundle passed (42491812824).
- A direct read query verified both forecast-available and out-of-horizon results. Neither grants aviation dispatch clearance.

## Source-of-truth data coverage correction

A previous status screen counted **233** aircraft in the legacy `section5_full_weight_aircraft_reference_v2` table, suggesting 38 missing models. This is not missing runway screening in gameplay: all **271/271** currently cataloged models are present in `section5_full_weight_airport_aircraft_screen_v2`, with **851,211** airport/aircraft pair rows and **zero null takeoff or landing required lengths**. The other 38 catalog models are Group 3, which also has its own `section5_group3_airport_aircraft_readiness_v1` 119,358-row coverage. That Group 3 model is airport-specific; do not flatten it to a single made-up aircraft runway length or insert duplicate legacy records. The universal preflight was checked with Group 3 A340-500 and correctly hard-blocked an insufficient runway. Group 3 aircraft remain subject to their independent fleet release guard.

## Current weather data

- All **3,141/3,141** airport forecasts were valid/current at this checkpoint (the weather provider fetched them on 2026-11-08 around 01:00–04:16 UTC).
- Actual aviation visibility is absent in the feed, so the new weather preview cannot legitimately impose certified flight minima or authorize activation.
- The old static `section5_airport_operations_baseline_v1.weather_snapshot_status` still has historical 'first data pending' strings. The player-facing airport profile already uses the dynamic `section5_airport_weather_profile_v1.is_current`; a future status reporter should use dynamic validity rather than misleading static metadata.

## Still blocking actual flight activation

1. **Zero** production in-service owned/leased aircraft and **zero** saved server flight drafts at the checkpoint: real signed-in browser-to-server aircraft draft saving is untested with a true acquired plane.
2. No activation/flight-execution transactions. Aircraft position/rotations/real durations/turnarounds, crews, rights, full schedule horizon, operational weather minima/NOTAM policy, network conflicts and revenue accounting remain incomplete. See GitHub issue #10.
3. Airport-specific conditional research (including 1,246 unnormalized legacy condition records), 218 game-estimated aircraft noise Chapters, and source-dependent requirements remain separate from completed simplified Yes/No game airport flags. Do not falsely certify source-unknown research cases.
4. Production authenticated browser E2E not yet verified; no live flight or player financial records were changed.
5. Unrelated pre-existing global CI issues: fictional Aleksandrovo airport master-register mismatch; account-wide visual-polish test expects a removed `staff` menu entry. Neither was introduced by the Section 5 weather change.

Do not mark Section 5 as fully *operationally live* while the release guards remain closed.
