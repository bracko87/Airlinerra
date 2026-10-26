# Airlinerra — Phase 5 FAA AIM Blank-LDA Policy & Runway Physical Backfill

**Date:** 26 October 2026 · **Private database:** Supabase `hwllkabgzaynalahvkpz`, schema `airlinerra` · **GitHub:** `main`.

## Completed work

The 211-airport Phase 5 cohort now has a separate **research-only FAA AIM runway-distance screen**, retaining government-published LDA separately from an **assumed planning distance**. Runway width, length, surface, surface condition and individual displaced-threshold fields were imported from US DOT BTS's FAA-derived **01 October 2026** tables. All source identity matches were validated by FAA airport source identifier, `SITE_NO`, state and effective cycle. The existing 211 airport gate records, prior 388 direction reviews and original 3,140 airport cohort were not modified or activated.

| Verified metric | Result |
| --- | ---: |
| Airport identities matched | 211 / 211 |
| Government runway-end records evaluated | **781** |
| Physical runway pairs returned by government geospatial layer | **379** |
| Source runway ends matched to physical pairs | **758** |
| Source ends missing geospatial runway physical record | **23, held** |
| Runway-end displacement fields refreshed | **781 / 781** |
| End records with positive displaced-threshold length | **95** |
| Original published LDA numeric entries | **91** |
| Blank LDA entries | **690** |
| End records with all LDA/TORA/TODA/ASDA blank | **687** |
| End records with another declared-distance field but blank LDA | **3** |
| Individual runway ends with FAA-AIM conditional assumed landing distance computed | **662** |
| **Assumed-distance directions passing initial distance/surface/condition screen** | **435** |
| **Government-published LDA directions passing initial distance/surface/condition screen** | **67** |
| Airports with at least one direction passing initial distance-only research screen | **208 / 211** |
| Airports with no direction passing research screen | **3** |
| Airport gameplay approvals / world activations | **0 / 0** |

The **435 assumed-distance screening passes are NOT source-published FAA LDAs**, cannot be added to the 67 as airline operating permissions, and are not airport certifications. The 208 airports are those with one or more candidate research runway directions, not playable airports.

## FAA policy and evidence distinction

**Source:** [FAA Aeronautical Information Manual, Section 4-3-6](https://www.faa.gov/air_traffic/publications/aim_html/chap4_section_3.html). For runways without published declared distances, FAA guidance permits the declared distances to be assumed to equal physical runway length, except landing distances are reduced by a displaced threshold. Published declared distances supersede physical-length assumptions.

Airlinerra preserves two separate fields:

- `published_lda_ft`: a numeric landing distance explicitly present in the FAA-derived US DOT source, or `NULL` where unreported.
- `aim_assumed_landing_ft`: only a **conditional planning/screening assumption** when **no LDA/TORA/TODA/ASDA is published anywhere on the runway pair**, physical length has been sourced, and the displaced-threshold field has been retrieved. Missing declared values are never converted to *published* LDA.

When a retrieved `DISPLACED_THR_LEN` is blank, only this conditional screening model treats it as no displacement reported. That does not certify field conditions or rule out owner, NOTAM or Chart Supplement restrictions. The model never adds a stopway, blast pad, clearway or EMAS to landing pavement.

Runway surfaces are limited to government codes `ASPH`, `CONC`, `ASPH-CONC`, `CONC-ASPH`. Turf, dirt, gravel or mixed asphalt/gravel are not silently accepted. `POOR` and `FAILED` pavements remain held. A previous explicit `LANDING_DIRECTION_PROHIBITED` or `PAVEMENT_CONDITION_HOLD` is also preserved. Runways missing the geospatial physical row remain a separate hold.

A blank LDA with **some other published declared-distance field** is not treated as a runway with no declared distances. This keeps partial declarations on manual review, including FLX runway 03/21 and ARR runway 09; five direction records are affected by a partial-declaration runway pair.

## Critical validation samples

| Airport and runway end | Source physical length | Displaced threshold | Research outcome |
| --- | ---: | ---: | --- |
| RDK RW05 | 5,100ft | 1,000ft | 4,100ft **assumed**, not published LDA |
| MQI RW05 / RW23 | 4,306ft | 305 / 301ft | 4,001 / 4,005ft **assumed** |
| THV RW17 | 5,188ft | 794ft | 4,394ft **assumed** |
| 3S4 RW18 | 4,807ft | 125ft | 4,682ft **published** LDA, not assumed |
| LAM RW09 | 6,000ft | none reported | Landing direction remains **prohibited** |
| FLX RW03 | 5,705ft | 102ft | Published TORA/TODA but blank LDA: **manual review** |
| TOI RW14 | 5,024ft | none reported | **Pavement-condition hold** |
| Y70 RW18 | 4,261ft | none reported | **Turf surface ineligible** |

### Three airports without an initial runway-distance research pass

- **64S Prospect State Airport:** the 3,986ft physical 02/20 runway has 233/231ft displaced thresholds; conditional assumed lengths **3,753/3,755ft** are below 1,200m.
- **FLX Fallon Municipal Airport:** the qualifying 03/21 asphalt runway has published TORA/TODA but **blank LDA**, so it is held pending declared-distance clarification; dirt 13/31 does not qualify.
- **PHD Harry Clever Field:** source explicitly publishes **3,621/3,634ft** LDA on asphalt 15/33, both below 1,200m; its short turf runway is also ineligible.

This is a research screen as of the October source cycle, not a permanent airport closure, formal rejection, or substitute for live FAA flight information.

## Source integrity and uncompleted original archive verification

The FAA [1 October 2026 NASR subscription page](https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/) identifies the original archive. Direct downloads from `nfdc.faa.gov` could not be completed in this tool environment because of DNS/network failures. Consequently **no SHA-256 hash of the original FAA archive has been calculated**, and database `original_archive_verified` remains `false`. FAA-derived physical, width and runway end data came from the [USDOT Runways geospatial layer](https://services.arcgis.com/xOi1kZaI0eWDREZv/arcgis/rest/services/Runways_View/FeatureServer/0) and [USDOT Runway Ends Table](https://services.arcgis.com/xOi1kZaI0eWDREZv/arcgis/rest/services/Runway_Ends_Table/FeatureServer/1). Each imported row was validated for October effective date and FAA/site/state identity.

## Version-controlled artifacts

- [Research-only schema and screening view](./sql/AIRLINERRA_PHASE5_FAA_AIM_BLANK_LDA_SCREEN_POLICY_2026-10-26.sql)
- [Runnable acceptance and fail-closed assertions](./sql/AIRLINERRA_PHASE5_FAA_AIM_BLANK_LDA_TESTS_2026-10-26.sql)

**Physical runway sources, all 379 rows:**
- [FAA physical runways — Part 1](./data/faa_nasr_oct2026_phase5_runway_physical_part_01.csv)
- [FAA physical runways — Part 2](./data/faa_nasr_oct2026_phase5_runway_physical_part_02.csv)
- [FAA physical runways — Part 3](./data/faa_nasr_oct2026_phase5_runway_physical_part_03.csv)
- [FAA physical runways — Part 4](./data/faa_nasr_oct2026_phase5_runway_physical_part_04.csv)

**FAA runway-end threshold source attributes, all 781 rows:**
- [FAA runway-end threshold fields — Part 1](./data/faa_nasr_oct2026_phase5_end_thresholds_part_01.csv)
- [FAA runway-end threshold fields — Part 2](./data/faa_nasr_oct2026_phase5_end_thresholds_part_02.csv)
- [FAA runway-end threshold fields — Part 3](./data/faa_nasr_oct2026_phase5_end_thresholds_part_03.csv)
- [FAA runway-end threshold fields — Part 4](./data/faa_nasr_oct2026_phase5_end_thresholds_part_04.csv)
- [FAA runway-end threshold fields — Part 5](./data/faa_nasr_oct2026_phase5_end_thresholds_part_05.csv)
- [FAA runway-end threshold fields — Part 6](./data/faa_nasr_oct2026_phase5_end_thresholds_part_06.csv)
- [FAA runway-end threshold fields — Part 7](./data/faa_nasr_oct2026_phase5_end_thresholds_part_07.csv)
- [FAA runway-end threshold fields — Part 8](./data/faa_nasr_oct2026_phase5_end_thresholds_part_08.csv)

The earlier [government-sourced declared-distance backfill report](./US_EXPANSION_PHASE5_FAA_NASR_BTS_LDA_BACKFILL_2026-10-26.md) and its eight source-LDA CSV parts remain preserved.

## Test and security results

The acceptance script was executed successfully (`PASS`) against live Supabase source research data. It asserts correct cardinality, no published/assumed LDA double-use, no fallback when any declared distance exists on that runway pair, case-specific displaced-threshold calculations, restricted landing directions, runway surface and pavement holds, 211/211 unapproved airport gates and zero world activation.

New physical data table has RLS enabled and no `anon` or `authenticated` read permissions. The derived view runs with `security_invoker=true` and also denies public/authenticated SELECT. No six-category airport classification, live game world, original 3,140-airport research cohort or commercial operating gate was changed.

## Next

1. **Original FAA ZIP verification:** Acquire exact 2026-10-01 FAA NASR APT data from a functioning external network, hash the bytes, compare original rows against current government republication, and store provenance only upon successful validation.
2. **23 missing geospatial direction rows:** obtain non-geospatial FAA runway-pair physical records rather than assuming a size. These include entries such as heliports that may not be eligible runways.
3. **Airport-level evidence adjudication:** review the three airport exceptions first; check direction-specific Chart Supplement/operator restrictions and disputed local dimensions. Do not equate a government research screen with commercial operating permission.
4. **Required operational gates:** aircraft landing/takeoff performance, runway width and pavement limits, named owner-commercial permission and certificated air operator, live flight-date NOTAM/FICON/weather, and necessary fuel, rescue, handling and customs.

**Result:** FAA AIM assumption policy is coded, tested, secured and versioned. The original FAA ZIP checksum and all operational admissions remain outstanding; **0 of 211** Phase 5 airports are approved for gameplay.