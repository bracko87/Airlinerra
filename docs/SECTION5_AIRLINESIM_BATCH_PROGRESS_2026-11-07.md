# Airlinerra Section 5 — AirlineSim simplified game-rule batch progress
**Updated:** 7 November 2026 · **World:** 1 · **Original simplified review backlog:** 1,216 airports (from the original 1,246 researched cases, 30 initially checked).

## Current confirmed progress
- **Batches 1–8 complete:** 400/1,216 airport cases processed.
- **AirlineSim airport pages individually checked:** 382 across those eight batches.
- **Not found on AirlineSim:** 18 cases with user-approved neutral No/None *game* defaults, explicitly tagged `AIRLINESIM_NOT_FOUND`. Not-found is not a claim of no real restriction.
- **Still pending individual comparison:** 816 cases, queued as Batches 9–25 (16×50 + last batch 16).
- **Across all 3,141 airports:** 410 AirlineSim public airport pages checked (including 28 initial checks); 2 original user-screenshot cases; 18 recorded not-found directory lookups; **2,711 general game defaults not individually source checked**.
- Section 5 database master remains `partially_populated`. Existing **91** precise official-source time rules and the original **1,246** detailed research-normalization items are retained without modification.

## Batch-by-batch status
| Batch | AirlineSim pages | Not found, neutral game default | Pending | Country groups |
|---|---:|---:|---:|---|
| 1 | 50 | 0 | 0 | Spain, Norway, Denmark, Italy |
| 2 | 50 | 0 | 0 | Italy, UK, Germany |
| 3 | 50 | 0 | 0 | Brazil |
| 4 | 40 | 10 | 0 | France, Brazil |
| 5 | 47 | 3 | 0 | Afghanistan, Anguilla, Armenia, Argentina, American Samoa, Austria, Australia, Azerbaijan, Bosnia, Bangladesh, Belgium, UAE |
| 6 | 47 | 3 | 0 | Belgium, Bulgaria, Burundi, Brunei, Bolivia, Caribbean Netherlands, Brazil, Bahamas, Bhutan, Botswana, Belarus, Canada |
| 7 | 49 | 1 | 0 | Canada, Cocos Islands, DR Congo, Switzerland, Cook Islands, Chile, China |
| 8 | 49 | 1 | 0 | China, Colombia, Costa Rica, Cuba, Cape Verde, Curaçao, Christmas Island, Cyprus, Czech Republic, Germany |
| 9–24 | 0 | 0 | **800** | Queued, 50 per batch |
| 25 | 0 | 0 | **16** | Queued |
| **Total** | **382** | **18** | **816** | **400 completed** |

## User-approved simplified output contract
For each airport:
- Nighttime ban: **Yes** or **No**. Store the AirlineSim displayed time range when Yes.
- Noise restrictions: **None** or **Yes, Chapters III/IV permitted** (according to the wording of the specific AirlineSim page). No Chapter ban is inferred from a permitted-Chapter entry.
- If **not listed after checking the applicable country and regional directories**, save **No nighttime ban / No noise restrictions** as a neutral GAME fallback, explicitly tagged **`AIRLINESIM_NOT_FOUND`**.
- If **not yet checked**, retain **`GAME_DEFAULT_NOT_CHECKED`** and never describe it as sourced.
- Keep official documented airport rules in separate protected tables; do not permit a simplified No to override an existing hard rule.

## Examples and special cases
- Batch 5: 47 source checks; 3 not-found entries **ZDY (UAE), EDP (Argentina), KQR (Australia)**. A Vienna airport listed internally as `LOWW` was correctly matched to AirlineSim IATA `VIE` using ICAO.
- Batch 6: 47 source checks; 3 not-found entries **CCA (Bolivia), SWX (Botswana), UMU (Brazil)**. Canada was checked via 13 provincial and territorial directories. AirlineSim entries for BQT, YHU and YUL have a game nighttime ban.
- Batch 7: 49 source checks; 1 not-found **LMF (Chile)**; checked China provinces and Canadian provinces. AirlineSim game nighttime bans include ACH, BRN, LUG, DLC and SHA.
- Batch 8: 49 source checks; 1 not-found **JCL (Czech Republic)**; exact source airport codes were confirmed for China, Colombia, Costa Rica, Cuba, Cape Verde, Curaçao, Christmas Island, Cyprus, Czech Republic and Germany.
- No unverified location or incomplete page fetch was marked source-observed. Temporary timeouts were retried and source-code identity verified before batch commit.

## Storage and acceptance
- `airlinerra_game.section5_airlinesim_review_batch_queue_v1`: 1,216 rows, 25 planned batches, 400 rows completed.
- `airlinerra_game.section5_airport_simplified_game_rules_v1`: game Yes/No values, permitted Chapters, original source URL, source-status provenance, capture date.
- `airlinerra_game.section5_airport_simplified_game_progress_v1`: read-only global progress.
- Migration files:
  - `supabase/migrations/20261107172500_section5_airlinesim_batch01_50_airports.sql`
  - `supabase/migrations/20261107175000_section5_airlinesim_batch02_50_airports.sql`
  - `supabase/migrations/20261107184000_section5_airlinesim_batch03_50_brazil_airports.sql`
  - `supabase/migrations/20261107190000_section5_airlinesim_batch04_france_brazil_50.sql`
  - `supabase/migrations/20261107201000_section5_airlinesim_batch05_50_airports.sql`
  - `supabase/migrations/20261107203000_section5_airlinesim_batch06_50_airports.sql`
  - `supabase/migrations/20261107210500_section5_airlinesim_batch07_50_airports.sql`
  - `supabase/migrations/20261107213000_section5_airlinesim_batch08_50_airports.sql`
- SQL acceptance: `tests/sql/section5_airlinesim_batches01_to08_acceptance.sql` — **PASSED against the live Supabase project**: exact batch counts and source statuses, all 3,141 game records, 91 old precise rules and 1,246 historical research cases preserved.
- GitHub issue [#9](https://github.com/bracko87/Airlinerra/issues/9) tracks airport research/normalization; [#10](https://github.com/bracko87/Airlinerra/issues/10) tracks actual operational fleet, aircraft scheduling, slots and flight execution.

**Next:** Begin Batch **9**, not Batch 1 or 5. Complete the remaining 816 airport lookups or document not-found outcomes with neutral game defaults. Only after source coverage and other game-data checks pass should Section 5's game-data completion be considered; this is not legal or regulatory validation of airports.
