# Airlinerra — Current World 1 airport catalog (27 October 2026)

**This file supersedes older airport counts and CSV snapshot lists from 27 October 2026.**

## Database-verified counts

| Cohort | Count |
|---|---:|
| Original game cohort (untouched) | 3,140 |
| Added under source-reported ICAO + historic hard-paved >1,200 m rule | 2,392 |
| Added using historical runway and identifier evidence (not all independently validated) | 2,607 |
| **Active and approved in World 1** | **8,139** |
| **Rejected / not active** | **14** |
| All registry candidates | 8,153 |

## Current downloads

- [Active accepted airport register — 8,139](airlinerra_world1_accepted_8139_2026-10-27.csv)
- [Confirmed exclusions — 14](airlinerra_world1_rejected_14_2026-10-27.csv)
- [Detailed independently sourced runway checks — 14 cases](airlinerra_independent_runway_checks_14_2026-10-27.csv)
- [Earlier 524 high-priority historical review items](airlinerra_historical_high_priority_review_524_2026-10-27.csv) — historical audit snapshot; some records have since been rejected, so cross-check against the current accepted register.

## Data and limits

- The database source of truth is Airlinerra Supabase project `hwllkabgzaynalahvkpz`, `airlinerra.airport_world1_review_20261027`; membership is `airlinerra.airport_world_activation` and `airlinerra_game.approved_game_airports`.
- Explicit four-letter ICAO codes in the registry are **source-reported**, not guaranteed to be independently verified. National/local IDs are not fabricated as ICAO codes.
- The **2,607 historical admissions** remain eligible under the owner's historical-runway simulation rule; they **have not all received independent checks for a current eligible paved runway**.
- Newly identified failures include asphalt runways under 1,200 m, mixed dirt/asphalt runway lengths incorrectly counted as wholly paved, a turf runway mistakenly recorded as asphalt, and an airport marked closed indefinitely.
- High-priority flags are documented separately in `airlinerra.airport_quality_audit_flags`; past acceptance is not an assertion of current airline service or commercial permission.
- Six category labels remain exactly Local, Regional, Medium, Large, Major Hub, Mega Hub; provisional assignments may require later refinement.
- This is a **simulation game airport catalog**, not a flight-planning authority.

**Prior snapshot with 8,148 active is outdated.** The present numbers are 8,139 accepted, 14 rejected.
