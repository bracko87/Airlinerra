# Airlinerra — Phase 5 October 2026 FAA NASR Runway-End Evidence Backfill

**Completed 26 October 2026. Research data only; no airport admission or world activation.**

## Summary

Phase 5's preliminary desk-source review of 211 airports previously finished. This backfill acquired FAA NASR `APT_RWY_END` runway-end records **as republished without modifications by the US Department of Transportation, Bureau of Transportation Statistics (BTS), National Transportation Atlas Database**. The table records the original `EFF_DATE`, `ARPT_ID`, `SITE_NO`, `RWY_ID`, `RWY_END_ID`, and `LNDG_DIST_AVBL` plus TORA/TODA/ASDA values. Every imported row shows the **2026-10-01 effective cycle**.

| Verified measure | Value |
| --- | ---: |
| Airport cohort identities reconciled | **211 / 211** |
| Exact FAA ARPT_ID matches | **210** |
| Official FAA ICAO-to-LID identity aliases resolved | **1** |
| Source runway-end entries imported | **781** |
| End records with non-blank source LDA | **91** |
| End records with blank source LDA | **690** |
| Airports with at least one numeric source LDA | **31** |
| Numeric source LDA >= 1,200m (3,938ft integer minimum) | **67 ends** |
| Numeric source LDA below 1,200m | **24 ends** |
| Matched prior Phase 5 secondary runway-end records | **388** |
| Previously unrecorded source runway ends | **393** |
| Conflicts in matching prior source-reported LDA | **0** |
| Airports approved for gameplay | **0** |
| Original airport cohort preserved | **3,140** |
| World activations | **0** |

**Important:** A source numeric LDA at least 1,200m is *not* a game-eligibility or flight-authorization decision. Some source rows concern short secondary surfaces or heliports. A blank LDA means the value was **not reported**, not zero and not an automatic airport failure. Airline operating rights, runway surfaces, aircraft suitability, live NOTAMs, weather, handling and rescue are different required checks.

## Public source provenance

- [USDOT BTS Runway Ends Table metadata](https://www.arcgis.com/sharing/rest/content/items/77db9c3ab3bd4a02bd85e575992bbd3e/info/metadata/metadata.xml?format=default&output=html). The lineage explicitly says the Runway Ends Table is unmodified from `APT_RWY_END.csv` and is updated every 28 days.
- [Government-hosted October FAA-derived runway-end table](https://services.arcgis.com/xOi1kZaI0eWDREZv/arcgis/rest/services/Runway_Ends_Table/FeatureServer/1). Field `LNDG_DIST_AVBL` is stored exactly as published, including `NULL`.
- [FAA 28-Day NASR subscription source](https://www.faa.gov/air_traffic/flight_info/aeronav/aero_data/NASR_Subscription/). **The original October 2026 FAA ZIP was not independently downloaded/hash-verified**, due inaccessible download paths; `original_archive_verified=false` and `original_archive_sha256=NULL` are preserved in Supabase.
- [FAA Palmer identifier proof](https://www.faa.gov/air_traffic/flight_info/aeronav/procedures/application/index.cfm?event=procedure.results&nasrId=PAQ): FAA location ID `PAQ` is the same Alaska airport as ICAO `PAAQ`. Registry airport key remains unchanged `OURAIRPORTS:5336`, while evidence source ID is `PAQ`.

All 781 source rows and 211 airport coverage records are stored in private Supabase project `hwllkabgzaynalahvkpz`, schema `airlinerra`, with government source record ID, effective date, source URL, raw JSON attributes, and reconciliation state. All three backfill tables have row-level security and no `anon` or `authenticated` read/write privileges. The original Phase 5 211 airport gate records and 388 direction observations were **not** overwritten.

## Reconciliation findings

Matching was performed using the stable `airport_key`, FAA airport identifier (or explicitly verified alias), state code, effective date, and normalized runway-end identifier. All 388 existing source-runway directions were found in the government table, and all 388 agree on already reported LDA values or their absence; no values were silently overwritten. An additional 393 source runway ends were preserved independently as `NEW_DIRECTION_NOT_IN_PRIOR_LEDGER`, including nonqualified or non-runway entries.

**Palmer PAAQ / PAQ:** Government source `LNDG_DIST_AVBL` lists RW16 **5,506ft** and RW34 **6,006ft**. Runway 10/28 has blank published LDAs, and the source also includes helipad H1. Runway 16 and 34 remain unapproved until performance and legal gates are independently satisfied.

**Illinois Valley 3S4:** FAA-republished runway-end data lists RW18 and RW36 at **4,682ft LDA** each, matching prior secondary evidence.

**Little Falls LXL:** Source lists 2,856ft LDA for both ends of the physically short 18/36 runway, confirming those directions are below the threshold; the distinct main 13/31 runway has blank declared LDA and cannot inherit the 18/36 result.

**Red Oak RDK:** Both main RW05 and RW23 source LDA fields are blank; the nominal 4,100ft after RW05's displaced threshold must not be relabeled as an official LDA.

## Reproducible evidence archive

Schema and provenance controls: [private Supabase research schema SQL](./sql/AIRLINERRA_FAA_NASR_BTS_OCT2026_BACKFILL_SCHEMA_2026-10-26.sql). Eight CSV parts archive **all 781** imported end observations in deterministic order, including site identity, published LDA/TORA/TODA/ASDA, source object ID, and reconciliation classification:

- [FAA NASR October 2026 runway ends — Part 1](./data/faa_nasr_oct2026_airlinerra_phase5_ends_part_01.csv)
- [FAA NASR October 2026 runway ends — Part 2](./data/faa_nasr_oct2026_airlinerra_phase5_ends_part_02.csv)
- [FAA NASR October 2026 runway ends — Part 3](./data/faa_nasr_oct2026_airlinerra_phase5_ends_part_03.csv)
- [FAA NASR October 2026 runway ends — Part 4](./data/faa_nasr_oct2026_airlinerra_phase5_ends_part_04.csv)
- [FAA NASR October 2026 runway ends — Part 5](./data/faa_nasr_oct2026_airlinerra_phase5_ends_part_05.csv)
- [FAA NASR October 2026 runway ends — Part 6](./data/faa_nasr_oct2026_airlinerra_phase5_ends_part_06.csv)
- [FAA NASR October 2026 runway ends — Part 7](./data/faa_nasr_oct2026_airlinerra_phase5_ends_part_07.csv)
- [FAA NASR October 2026 runway ends — Part 8](./data/faa_nasr_oct2026_airlinerra_phase5_ends_part_08.csv)

The CSV fragments are a normalized audit copy. Supabase separately retains each row's complete original API attributes and source feature URL. The hosted source is a government republication, **not** proof that we acquired and hashed the original FAA ZIP.

## Next engineering work

1. **Original-archive provenance:** when the FAA cycle ZIP is accessible, download it, verify its SHA-256, parse `APT_RWY_END.csv`, reconcile row identity and all 781 published records, and update provenance only after verification.
2. **Resolve the 690 blank LDA fields:** a blank is not an explicit failed runway; define a conservative, documented fallback for runways without declared-distance values, based on authoritative physical runway and displaced-threshold records. Do not represent such an estimate as `FAA LDA`.
3. **Complete physical direction screening:** integrate FAA `APT_RWY` length, width, surface, condition and declared-distance status for all runway pairs. Preserve runway-specific restrictions, unsuitable short/turf surfaces, stopways/EMAS and directional exceptions.
4. **Final admission controls:** named certificated carrier, owner-paid-commercial-use rights, runway and airframe performance/loading/width, fuel/ARFF/handling, flight-date NOTAM/FICON/weather, and appropriate Customs permissions where needed. No airport can enter a game world without independent completion of mandatory gates.

**Result: 211/211 airport identities government-source matched; 781 direction-source records backfilled; zero game airports approved.**