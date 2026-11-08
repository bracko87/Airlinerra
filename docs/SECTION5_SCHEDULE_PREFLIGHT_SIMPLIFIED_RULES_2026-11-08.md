# Airlinerra Section 5 — simplified nighttime/noise rules now in server flight preflight

Date: 2026-11-08. Project: Airlinerra World 1. The 1,895-airport research batch queue is complete. All 3,141 approved World 1 airport profiles have simplified game Yes/No values. Values without a matched source are explicitly marked game defaults, not claims of unrestricted real-world operation.

## Implemented and deployed in Supabase

- Migration: `supabase/migrations/20261108110500_section5_simplified_night_noise_live_preflight.sql`
- New private, SECURITY INVOKER, pinned-search-path function `airlinerra_game.section5_simplified_airport_leg_screen_v1` checks airport-local departure/arrival times against the simplified source-backed time windows and the permitted ICAO noise Chapters.
- Existing `section5_universal_route_restriction_gate_v1` merges the simplified restrictions **in addition to**, never instead of, its existing documented official airport/time/runway/noise restrictions. It retains standard top-level `gameHardBlocked`, `needsReview`, `canActivateNormalFlight=false`, and existing origin/destination fields while adding `simpleNightNoise`, `blockedBySimplifiedNighttimeBan` and `blockedBySimplifiedNoiseChapter` for each airport.
- Existing weekly route gate `section5_weekly_route_restriction_gate_v1` already calls that universal route gate for each flight occurrence. The atomic owned/leased server flight-draft save `section5_save_owned_aircraft_schedule_draft_v1` runs that weekly gate before committing; the Section 6 atomic slot+schedule writer invokes the same save. The nonmutating activation-readiness check runs the weekly gate again.
- Ordinary AirlineSim `0:01 and 5:59` plus precisely recorded `HH:MM-HH:MM` windows use airport IANA local timezone, with crossing-midnight handled correctly. Basel's origin-vs-destination scheduled limits retain their existing detailed official rules. Variable `sunset to sunrise` windows are review-only until date-sensitive times exist; no invented fixed time is enforced.
- Noise hard blocks require a configuration-matched **official certificate** showing a Chapter outside the simplified permitted set. An estimated/unknown game Chapter produces review, not a fabricated certified ban. Chapter 14 is accepted when the permitted rule includes Chapter 4, reflecting the newer, quieter standard.
- Any airport with `nighttime_ban=false` and `noise_restrictions=false` adds no new simplified hard prohibition. Existing official game-enforceable rules still apply, including where simplified game values were neutral defaults.
- No ownership/RLS grants, fleet purchases, airport capacity defaults, traffic rights, live flight activation, commercial flight execution or revenue writes changed.

## Live production database verification

Ran `tests/sql/section5_live_simplified_night_noise_route_regressions.sql` directly against production PostgreSQL in a fully rolled-back transaction; all assertions passed.

Also re-ran and passed:
- `tests/sql/section5_universal_restriction_gate_regressions.sql`
- `tests/sql/section5_weekly_schedule_gate_regressions.sql`
- `tests/sql/section5_server_flight_schedule_draft_acceptance.sql` (temporary owned-fleet/draft fixture rolled back)

Examples: Kiruna at 02:30 local blocked; daytime Kiruna permitted by simplified night rule; Billy Bishop nighttime still blocked; Fukuoka official mandatory rule still blocks; four recurring nighttime Kiruna occurrences all blocked. A temporary Chapter 3-only permitted list rejected matched Chapter 4; unverified certificate triggered review without a hard noise ban; Chapter 14 passed a Chapter 4-allowed rule.

## Remaining release work

1. Production has **zero in-service player aircraft** and **zero saved flight drafts** at this checkpoint. Thus a real authenticated user with a real owned fleet has not yet demonstrated the full browser-to-server save flow; database fixture and server tests passed, but no live production flight activation was attempted.
2. Full operational scheduling/activation remains disabled until aircraft position and rotations, crews, traffic rights, actual durations, recurring forecast horizon, stand slots, dispatcher, and revenue are connected and validated.
3. Airport-specific conditional/sunset time rules and certified noise values require further scope-sensitive normalization. The 218 estimated aircraft game noise Chapters remain playable classifications, not matched aviation certificates.
4. SQL-only commits do not themselves trigger the current route-planner Node CI push path filters. Run full application build/Node CI and an authenticated browser session before public release.

This checkpoint means **simplified airport restrictions are now enforced by the server route preflight and server-owned schedule-draft transaction**, not that fully operating flight scheduling is live.
