# Group 2 combined 54-week route gate and planning gateway audit — 2026-11-10

## Deployed database work
Applied two production Supabase migrations on the `airlinerra_game` schema:
- `20261110185000_group2_combined_54week_route_safety_preview.sql`
- `20261110190500_group2_route_safety_timetable_hardening.sql`

The private `group2_combined_route_safety_preview_v1` now checks the **origin and destination for each occurrence of a 54-week weekly schedule**, combining:
- full-weight elevation-adjusted runway model (existing game reference, missing references blocked)
- per-stand, per-ten-minute capacity and reservation snapshot
- stored conditional nighttime restrictions and noise-Chapter evidence
- weekly DST/timezone/aggregate slot-capacity model
- strict rejection of duplicate weekly departures and distinct departures overlapping the same 10-minute bucket

The gate prioritizes blockers over review outcomes and is explicitly **preview only** (`canBook=false`, `canDispatch=false`, `canActivateHqOrOffice=false`, `commercialAdmission=false`). No schedules, slots, HQ, office or movements are created.

## Production tests
- Grant County → Ciudad Real, Boeing 737-800, one flight weekly: **54 actual occurrences checked**. The destination has an unresolved sourced-noise-Chapter issue for this aircraft, so overall verdict is `REVIEW_REQUIRED_OCCURRENCE_RESTRICTION`.
- Paris–Le Bourget → Ciudad Real, ATR 72-200, terminal stands: **54 actual occurrences checked** and **54 blocked** due to unavailable terminal capacity.
- Two flights on the same local weekday at 06:00 and 06:05 now return `BLOCKED_OVERLAPPING_TEN_MINUTE_DEPARTURES`, rather than being silently collapsed into one slot.
- Invalid weekdays, exact duplicate schedule entries and Group 1 airport keys fail closed.
- Production postcheck counts: combined catalog 4,259, approved registry 3,141, prepared Group 2 1,118, commercially activated Group 2 0, saved Group 2 location plans 0, Group 2 slot reservations 0.

## Local frontend-to-backend integration
`website/dev-scripts/real-player-read-gateway.mjs` now recognizes the existing authenticated `/api/v1/player/group2-location-plans` route and validates exact requests for owner-only planned future HQ, hub and station list/save/remove operations. Invalid fields, forged IDs, invalid airport keys and active-state requests are rejected before any proxy call. Protected Edge routing retains server-side ownership verification and non-operational storage.
`tests/test_group2_local_gateway.mjs` was committed and added to `.github/workflows/airports-integration-check.yml`.

## Not completed — essential release boundary
These new tests and safe previews are NOT integrated into the authorized schedule save transaction, Section 9 aircraft movement, licences/traffic rights, live airport activation, or the live operational Section 5/6 approval roster. HQ/hub/station plans are not active locations. The user's static website deployment and a real authenticated live browser test remain unverified. GitHub Actions returned no completed workflow runs for the latest commit, so do not claim passing Node/CI tests. Do not promote Group 2 to the `approved_game_airports` table until all live operational gates are wired and tested.
