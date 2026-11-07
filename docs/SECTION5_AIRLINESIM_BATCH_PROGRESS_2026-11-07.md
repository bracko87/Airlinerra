# Airlinerra Section 5 — AirlineSim batch tracking and game-rule results
**Run:** 7 November 2026 · **World:** 1 · **Target:** 1,216 originally unchecked airport restriction cases, from the original 1,246 backlog.

## Simplified user-approved game rules
For each airport, save:
- `nighttime_ban`: Yes / No, exact AirlineSim time window if shown.
- `noise_restrictions`: Yes / No, allowed Chapters (usually III and IV).
- If not listed in AirlineSim, use neutral **No nighttime ban / No noise restrictions**, explicitly labelled **`AIRLINESIM_NOT_FOUND`**. If *not yet checked*, `GAME_DEFAULT_NOT_CHECKED` remains clearly distinct. Neither category proves the real airport has no restrictions.

Existing primary-source curfews, runway conditions, noise laws and 91 time-rule records stay intact. The simplified summary **does not overwrite** their safety/flight-block checks.

## Audited progress

| Batch | Source airport pages checked | Not found on AirlineSim | Pending | Outcome |
|---|---:|---:|---:|---|
| #1 | 50 | 0 | 0 | Completed — Spain, Norway, Denmark, Italy |
| #2 | 50 | 0 | 0 | Completed — Italy, United Kingdom, Germany |
| #3 | 50 | 0 | 0 | Completed — Brazil |
| #4 | 40 | 10 | 0 | Completed — Brazil and France |
| #5–24 | 0 | 0 | 1,000 | Queued — 50 each |
| #25 | 0 | 0 | 16 | Queued |
| **TOTAL** | **190** | **10** | **1,016** | **200 / 1,216 processed** |

A further **30 initial airport observations** in the original list predate the batched review, bringing verified/explicitly not-found outcomes within the 1,246 list to **230**. Across all **3,141** airport game records, this corresponds to **218 source-checked AirlineSim pages, 2 user-screenshot cases, 10 not found in the directory, and 2,911 unchecked game defaults**.

### Important source examples
- AirlineSim Free1 public airport information pages were individually read and IATA codes verified before saving.
- Batch 1: 19 airports nighttime Yes, 29 airports noise Yes.
- Batch 2: 10 airports nighttime Yes, all but QSR have noise restricted to Chapters III/IV.
- Batch 3: 2 airports (MVF and SDU) have nighttime Yes; all 50 pages show no noise restrictions.
- Batch 4: 4 French airports (BIQ, BVE, DCM, SXB) have nighttime Yes; all 32 checked French pages permit Chapters III/IV. The 8 checked Brazil pages say no nighttime and no noise restrictions.
- Ten Brazil codes **BVS, CAU, CEL, CJZ, GGJ, JPE, MNX, OPP, SMT, TGQ** could not be found across AirlineSim Brazil's *North, Northeast, Center-West, Southeast and South* regional airport lists. These got the explicit not-found neutral default, not an invented checked source.

## Storage / code
- Queue: `airlinerra_game.section5_airlinesim_review_batch_queue_v1`, 1,216 rows spread over 25 batches; the next unprocessed batch number is **5**. Batch numbers 1–4 are completed; 5–24 have 50 each, 25 has 16.
- Game display/provenance: `airlinerra_game.section5_airport_simplified_game_rules_v1` and `section5_airport_simplified_game_progress_v1`.
- SQL migrations: `supabase/migrations/20261107172500_section5_airlinesim_batch01_50_airports.sql`, `20261107175000_section5_airlinesim_batch02_50_airports.sql`, `20261107184000_section5_airlinesim_batch03_50_brazil_airports.sql`, `20261107190000_section5_airlinesim_batch04_france_brazil_50.sql`.
- Acceptance: `tests/sql/section5_airlinesim_batches01_to04_acceptance.sql`. **Passed live.**
- Source notes are linked per checked airport, and a "Not listed on AirlineSim — neutral game default" provenance label has been added to the airport-profile website.

## Section 5 is NOT yet finished
- **1,016** items still require an individual page lookup or recorded not-found outcome in this specifically requested simplified review.
- Source-backed operational research queue still has **1,246** rows with detailed conditions; this remains separate from the simplified flags. Any precise hard restrictions still take priority over a simple No.
- Flight activation remains separately blocked pending true fleet + scheduling engine: [GitHub issue #10](https://github.com/bracko87/Airlinerra/issues/10).
- Section 5 master status remains `partially_populated`; **do not mark complete yet**.
