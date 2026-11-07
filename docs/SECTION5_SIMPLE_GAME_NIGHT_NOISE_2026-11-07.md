# Section 5 — Simplified airport nighttime ban and noise game settings
**Date:** 7 November 2026
**World:** Airlinerra World 1 — 3,141 airports.

## User-approved rule
Use simple AirlineSim-style fields without mixing operational runway-specific exceptions into the public summary:
- **Nighttime ban:** Yes / No
- **Noise restrictions:** Yes / No and which ICAO chapters are **permitted** in the simplified comparison.
- If an airport has no checked source yet, display game defaults: **No / No**.

**Crucial:** No/None as a game fallback does not demonstrate that a source was checked or that actual airport restrictions do not exist. We retain source statuses to make this clear. No game default removes a documented mandatory hard rule.

## Applied database layer
`airlinerra_game.section5_airport_simplified_game_rules_v1` — private RLS table:
- 3,141/3,141 aircraft airports have `nighttime_ban`, `noise_restrictions`, and `permitted_noise_chapters` fields.
- 28 Swedish airport pages individually checked on AirlineSim Free1 on November 7, 2026.
- 2 screenshots supplied by user for Barcelona and Budapest (Stockholm Arlanda also independently checked from page).
- **3,111** airports have explicit `GAME_DEFAULT_NOT_CHECKED` status. They are **not** counted as verified AirlineSim pages or source absences.
- 2 positive nighttime bans in these observations: **Kiruna (KRN)** and **Budapest (BUD)**.
- 29 positive noise restrictions in these observations, typically AirlineSim wording "Restricted to Chapter III and IV aircraft". This is interpreted as permitted III and IV in AirlineSim's own simplified game system — not as a statement that Chapter III and IV are banned. Scandinavian Mountains (SCR) is "no noise restrictions".
- New read-only `airlinerra_game.section5_airport_simplified_game_progress_v1` summarizes source coverage.
- Pre-existing `section5_airport_time_restrictions_v1` remains at 91 rules across 66 airports. The **1,246** research-only cases remain untouched and separately pending rule normalization.
- The approved current aircraft noise fallback and official airport source-backed restrictions remain untouched.

## Example settings
| Airport | Nighttime ban | Noise restrictions | Permitted chapters | Source |
|---|---|---|---|---|
| ARN Stockholm Arlanda | No | Yes | III, IV | AirlineSim page |
| BCN Barcelona | No | Yes | III, IV | User screenshot |
| BUD Budapest | Yes | Yes | III, IV | User screenshot (01:01–05:59 shown) |
| KRN Kiruna | Yes | Yes | III, IV | AirlineSim page (00:01–05:59 shown) |
| SCR Scandinavian Mountains | No | No | — | AirlineSim page |

## App wiring
- `server/airport-profile-service.mjs` now joins the simplified table and adds `operations.simpleNightNoise` to the authenticated profile API response. It exposes value, source status and source URL; `dispatchApproval:false`.
- `website/airline-airports-office.mjs` displays Yes/No and Chapters in the airport profile, and a separate source status indicating page checked/screenshot/default.
- `website/airport-restriction-display.mjs` links checked simplified evidence alongside, but not instead of, existing official notes.
- Supabase Edge `airlinerra-airport-profile` updated to **v11**. The SQL query was independently executed successfully with BUD.
- GitHub route-planner and airport profile CI **#125 passed**, including new regression cases. SQL acceptance script also passed against the live database.

## Not yet completed
**It would be inaccurate to say all 1,246 research cases have been individually matched to AirlineSim.** Only 30 airports were explicitly source-observed in this run, and the source-state for every remaining default is visible. In addition, some observed airports were not among the 1,246 pending research cases.

We should not promote the 1,246 research-only normalization queue to "source verified" or full Section 5 operational completion based on defaults. Existing hard restrictions can still prevent an actual flight, regardless of the simplified No summary. Actual fleet, airport slots and flight activation are tracked in issue #10.

## Source and related work
- AirlineSim public country directory: https://free1.airlinesim.aero/action/info/countries
- Section 5 release issue: https://github.com/bracko87/Airlinerra/issues/9
- Fleet operations dependency: https://github.com/bracko87/Airlinerra/issues/10
- Migration: `supabase/migrations/20261107170500_section5_simplified_airport_night_noise_game_flags.sql`
- Acceptance: `tests/sql/section5_simplified_night_noise_game_flags_acceptance.sql`
