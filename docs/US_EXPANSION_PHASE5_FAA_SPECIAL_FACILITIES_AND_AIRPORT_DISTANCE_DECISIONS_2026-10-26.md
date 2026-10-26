# Airlinerra — Phase 5 FAA Special-Facility Resolution & Airport Screening Decisions

**Date:** 26 October 2026. **Authoritative working research database:** private Supabase project `hwllkabgzaynalahvkpz`, schema `airlinerra`. **Version archive:** GitHub `main`.

## Verified outcome

This batch completes classification of **all 23 formerly unmatched runway-end records** and creates an initial, **research-only airport-level runway distance screening decision for all 211 US Phase 5 airports**. This is *not* authorization for commercial air transport or a change to world activation.

| Result | Count |
| --- | ---: |
| Previously unmatched FAA runway-end records classified | **23 / 23** |
| Helipad entries, excluded from fixed-wing game runway qualification | **15** |
| Water landing area ends, excluded from paved-runway qualification | **4** |
| Ultralight runway ends, excluded from airline runway qualification | **4** |
| Remaining unclassified missing physical-runway records | **0** |
| Total government-derived runway-end records preserved | **781** |
| Airport research decisions saved | **211 / 211** |
| Airport decisions: at least one *initial distance-screen* candidate | **208** |
| Airport decisions: no current distance-screen pass | **2** |
| Airport decisions: partial declared-distance manual review | **1** |
| Phase 5 airports admitted to gameplay | **0** |
| Original first-phase airport inventory preserved | **3,140** |
| World activation records | **0** |

The 23 records were not "ordinary paved runways missing a measurement." They were special-purpose identifier types that the FAA runway-end database includes but the government geospatial **Runways** layer does not show as normal physical runway pairs. The aviation records remain retained; exclusion affects *Airlinerra's paved fixed-wing airline runway requirement only* and does **not** assert closure of those facilities in real life.

## Official identifier semantics

[FAA Advisory Circular 150/5200-35](https://www.faa.gov/documentLibrary/media/Advisory_Circular/150_5200_35.pdf) describes the runway/facility designation conventions: **H1/H2 etc.** for helipads, **W** for sealanes/waterways, and **U** for ultralight runways. The 23 entries are classified with these identifier rules:

- **15 helipad end records**, spread across 13 airports, with H1/H2 identifiers.
- **4 waterway ends** (two two-end records, across two airports), including 03W/21W.
- **4 ultralight ends** (two two-end records, across two airports), including 04U/22U and 09U/27U.

A database CHECK ensures the stored classification matches the associated FAA identifier pattern. All special-purpose ends are permanently **ineligible for this fixed-wing paved-runway screening**, retain `NOT_APPROVED`, and cannot be silently reintroduced as aircraft runways. This is an airport-runway *category* distinction, not a change to Airlinerra's six final airport-size categories.

## Airport-level research decisions

A new private table, `airlinerra.airport_faa_initial_distance_decisions`, stores one first-pass snapshot per airport and October 2026 evidence cycle. Fields include directions assessed, number of published- and assumed-distance passes, manual holds, special-purpose exclusions, prohibited landing directions, pavement-condition holds, source status, and all outstanding independent operational gates.

**208** airports have one or more directions passing an **initial length/surface/pavement condition screen** (67 directions with published LDA, 435 with FAA AIM conditional assumed length). This is **not** a finding that 208 airports are suitable for a commercial airline.

The remaining three are recorded explicitly:

| FAA ID | Airport | Research decision and reason |
| --- | --- | --- |
| **64S** | Prospect State Airport, OR | `NO_DISTANCE_SCREEN_PASS`: runway 02/20 physical length 3,986 ft, but its two displaced thresholds of 233/231 ft leave **3,753/3,755 ft**, under 1,200 m. |
| **PHD** | Harry Clever Field, OH | `NO_DISTANCE_SCREEN_PASS`: paved 15/33 published LDAs **3,621/3,634 ft**, below the minimum; grass alternative also fails. |
| **FLX** | Fallon Municipal Airport, NV | `PARTIAL_DECLARED_DISTANCE_MANUAL_REVIEW`: main 03/21 has FAA TORA/TODA values but blank LDA. Do **not** infer landing distance from gross pavement when partial declared distances exist. The alternate dirt runway fails Airlinerra's surface requirement. |

Published FAA LDA and FAA AIM **assumed** planning distance remain distinct. For the two no-pass airports, technical evidence must change or the eligibility criteria must be separately reconsidered; no automatic game rejection or activation is performed. Fallon needs targeted FAA/airport-operator clarification.

## FAA original archive provenance

The [FAA October 1, 2026 NASR subscription page](https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/) provides links to the full archive and airport-only CSV. The original files are hosted at `nfdc.faa.gov`. Two fresh direct-download tests of the complete ZIP and airport-only ZIP in this environment still failed because the download host does not resolve. No original archive bytes were acquired; consequently **no genuine SHA-256 checksum was produced**.

Supabase therefore continues to store `original_archive_verified=false` and a NULL SHA-256. The working runway evidence is explicitly labeled as an **FAA-derived government republication by US DOT BTS**, *not* independently hashed original FAA archive data.

The [2026 October runway-end backfill](./US_EXPANSION_PHASE5_FAA_NASR_BTS_LDA_BACKFILL_2026-10-26.md) and [FAA AIM screening policy](./US_EXPANSION_PHASE5_FAA_AIM_BLANK_LDA_SCREEN_AND_PHYSICAL_BACKFILL_2026-10-26.md) remain intact.

## Files and reproducible results

The following artifacts have been independently applied to the private research database and archived in this public source-control repository **without private credentials**:

- [Special facility classification SQL — 23 source runway ends](./sql/AIRLINERRA_PHASE5_FAA_SPECIAL_FACILITY_CLASSIFICATION_2026-10-26.sql)
- [211-airport preliminary decision ledger SQL](./sql/AIRLINERRA_PHASE5_FAA_INITIAL_AIRPORT_DISTANCE_DECISIONS_2026-10-26.sql)
- [Acceptance tests — previously executed successfully in Supabase](./sql/AIRLINERRA_PHASE5_FAA_SPECIAL_FACILITY_AND_AIRPORT_DECISION_TESTS_2026-10-26.sql)
- [Airport decision CSV — part 1, 100 airports](./data/airlinerra_phase5_faa_initial_airport_screen_decisions_part_01_2026-10-26.csv)
- [Airport decision CSV — part 2, 100 airports](./data/airlinerra_phase5_faa_initial_airport_screen_decisions_part_02_2026-10-26.csv)
- [Airport decision CSV — part 3, 11 airports](./data/airlinerra_phase5_faa_initial_airport_screen_decisions_part_03_2026-10-26.csv)

The new facility and decision tables have RLS enabled, no `anon` or `authenticated` read/write privileges, and `game_admission_status` constrained to `NOT_APPROVED`. The adjudicated view has `security_invoker=true` and public access is revoked. The acceptance suite returned **PASS** and verifies original-cohort protection and zero game-world admissions.

## Next priorities

1. **Fallback original FAA archive provenance:** find an accessible authenticated copy of the October NASR ZIP; hash it and independently compare with current government-derived records. Do not record an invented checksum.
2. **Investigate Fallon FLX partial declared distances**, and revalidate Prospect 64S and Harry Clever PHD against the correct declared-distance and threshold evidence. These are first-pass holds, not real-world closure declarations.
3. **Pilot full operating-gate assessments** for a small, explicitly selected sample of the 208 distance-screen candidates: aircraft landing/takeoff performance, runway width and bearing/load, airport-owner signed commercial rights, named certificated operator, fuel/rescue/handling and flight-date NOTAM/FICON/weather; international permissions when relevant. Record unverified fields as unverified rather than passing them.
4. Preserve six airport levels exactly: **Local, Regional, Medium, Large, Major Hub, Mega Hub**. Do not select or activate any live world or modify the existing original 3,140-airport cohort without specific approval.

**Final:** the FAA-special-facility evidence-gap queue is **0**, airport-level research decisions are **211/211**, and gameplay approvals remain **0/211**.
