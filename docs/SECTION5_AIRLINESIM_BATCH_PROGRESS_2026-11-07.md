# Airlinerra Section 5 — AirlineSim simplified airport rules: batch progress
**Latest database verification:** 7 November 2026 · **World:** 1 · **Airport game database:** 3,141

## Current progress
- Original researched backlog: **1,246** airports. Of these, 30 had initial AirlineSim observations, leaving **1,216** for the tracked batch project.
- **450 / 1,216 cases processed** across Batches 1–9 (9 fully completed batches of 50).
- **431 directly observed AirlineSim airport pages** in batches, matching each airport to its AirlineSim IATA/ICAO detail.
- **19 airports not found** in the relevant complete country/region directory; each has the user-approved **No nighttime ban / No noise restrictions** *GAME fallback* and explicit `AIRLINESIM_NOT_FOUND` provenance.
- **766 remaining cases** in Batches 10–25 (Batches 10–24 each contain 50 airports, Batch 25 contains 16).
- In the full database: 459 AirlineSim detail pages checked (including 28 pre-batch checks), 2 user screenshots, 19 explicitly not found, and **2,661 other airports with unchecked neutral game defaults**.
- The Section 5 master status is **`partially_populated`**, not yet closed. Existing 91 individually sourced time rules and 1,246 original detailed research-normalization entries remain untouched.

## Batch status
| Batch | Confirmed AirlineSim source pages | Not listed — neutral game fallback | Pending | Notes |
|---|---:|---:|---:|---|
| 1 | 50 | 0 | 0 | Spain, Norway, Denmark, Italy |
| 2 | 50 | 0 | 0 | Italy, United Kingdom, Germany |
| 3 | 50 | 0 | 0 | Brazil |
| 4 | 40 | 10 | 0 | Brazil, France |
| 5 | 47 | 3 | 0 | Afghanistan, Anguilla, Armenia, Argentina, American Samoa, Austria, Australia, Azerbaijan, Bosnia, Bangladesh, Belgium, UAE |
| 6 | 47 | 3 | 0 | Belgium, Bulgaria, Burundi, Brunei, Bolivia, Caribbean Netherlands, Brazil, Bahamas, Bhutan, Botswana, Belarus, Canada |
| 7 | 49 | 1 | 0 | Canada, Cocos, DR Congo, Switzerland, Cook Islands, Chile, China |
| 8 | 49 | 1 | 0 | China, Colombia, Costa Rica, Cuba, Cape Verde, Curaçao, Christmas Island, Cyprus, Czech Republic, Germany |
| **9** | **49** | **1** | **0** | **Germany, Dominica, Dominican Republic, Algeria, Ecuador, Estonia, Egypt, Spain, Ethiopia, Finland** |
| 10–24 | 0 | 0 | 750 | Queued, 50 airports per batch |
| 25 | 0 | 0 | 16 | Queued |
| **Totals** | **431** | **19** | **766** | **450 completed of 1,216** |

### Batch 9 detailed result
- **50 processed; 49 direct source pages checked; 1 not found.**
- **10** airports have a simplified AirlineSim nighttime ban (SCN, GJL, TEE, FUE, GMZ, SPC, TFN, VDE, ABK, JIJ).
- **22** airports have noise restrictions, reported by AirlineSim as **“Restricted to Chapter III and IV aircraft”** (these are *permitted* Chapters III/IV, not banned chapters).
- **IBB (Isabela, Ecuador)** is not listed in AirlineSim Ecuador's complete 18-airport country directory as of check date. It received a clearly source-labelled **No / None neutral game default**, not a claim of actual legal permission.
- Estonia was checked through country `id=44` and identified by IATA and ICAO: KDL, TAY and URE. Country `id=42` was a different country and was **not** used for Estonia values.
- Melilla MLN was checked from Spain's Melilla regional directory; Åland MHQ was checked from Finland's Åland regional directory.
- Temporary source page timeouts for Ecuador CUE/SCY were retried and resolved before commit.

## Game rules and safety boundaries
- **Nighttime ban:** simple Yes or No. When the AirlineSim page shows a window (usually 00:01–05:59), keep it as the simplified window.
- **Noise restrictions:** No, or Yes with AirlineSim-permitted Chapters (typically III/IV).
- **Not found:** No nighttime ban / No noise restrictions **game** defaults. Status `AIRLINESIM_NOT_FOUND`.
- **Not yet checked:** same neutral **game** defaults, but status `GAME_DEFAULT_NOT_CHECKED`. Never count these as researched or sourced.
- This separate simplified game setting **does not remove or override primary-source hard curfews, aircraft restrictions, runway rules, NOTAMs or other official research**. A simplified “No” is not real-world legal approval.

## Database and GitHub references
- Private Supabase queue: `airlinerra_game.section5_airlinesim_review_batch_queue_v1`.
- Private game data: `airlinerra_game.section5_airport_simplified_game_rules_v1`.
- Progress: `airlinerra_game.section5_airport_simplified_game_progress_v1`.
- Batch 9 migration: `supabase/migrations/20261107221500_section5_airlinesim_batch09_50_airports.sql`.
- Batch 9 acceptance: `tests/sql/section5_airlinesim_batches01_to09_acceptance.sql` — **PASSED in live Supabase**. Assertions cover 450 decisions, 431 observed, 19 not found, 766 pending, 50/50 Batch 9, 10 night bans, 22 noise restrictions, all 3,141 game records, and preservation of all 91 historical source-backed time restrictions.
- Previous batch migrations 1–8 and historical acceptance tests remain in `supabase/migrations/` and `tests/sql/`. Those tests describe progress snapshots at their respective completion dates; use **the latest acceptance file** for the present live counts.
- Airport restrictions and normalization tracked in GitHub [issue #9](https://github.com/bracko87/Airlinerra/issues/9). True operational fleet, aircraft slots and flight activation separately tracked in [issue #10](https://github.com/bracko87/Airlinerra/issues/10).

**Next batch: 10.** Section 5 must not be reported as finished while its simplified AirportSim/ AirlineSim source review still has 766 pending items.
