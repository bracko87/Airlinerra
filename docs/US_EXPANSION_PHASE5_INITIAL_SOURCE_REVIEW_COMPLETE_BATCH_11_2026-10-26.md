# Airlinerra — Phase 5 Initial Source Review Complete (Batch 11)

**26 October 2026 · Private Supabase `airlinerra` research schema · GitHub `main`**

## Verified closure

**All 211 of 211 Phase 5 airports have completed the INITIAL FAA-derived secondary-source review. Zero remain queued. This is NOT final airport eligibility approval.** Every one of the 211 remains `EVIDENCE_HOLD` and `NOT_APPROVED`; world activation remains empty.

| Metric | Verified |
| --- | ---: |
| Final Batch 11 reviews | 15 |
| Batch 11 runway-end source observations | 54 |
| Batch 11 direction LDA unverified | 32 |
| Batch 11 too-short/wrong-surface directions | 20 |
| Batch 11 pavement-condition holds | 2 |
| All Phase 5 airports initially source-reviewed | 211/211 |
| Whole runway-direction research ledger | 388 |
| Original first-phase airports preserved | 3,140 |
| Game-approved / activated airports | 0 / 0 |

These 15 source pages were independently retrieved from FAA-derived AirNav listings labeled FAA-effective **01 October 2026**. The original FAA NASR APT files and authoritative direction-specific Landing Distance Available were NOT independently authenticated. Do not infer FAA LDA from gross pavement, displaced thresholds, stopways, blast pads, EMAS or ILS. Secondary observations remain holds, not game approval.

## Fifteen individual airport findings

| FAA | Airport | Key source finding (full note stored in Supabase) |
| --- | --- | --- |
| TOC | Toccoa Airport - R.G. Letourneau Field | FAA-derived AirNav source now effective 01 Oct 2026 (earlier dossier was September). Toccoa primary RW03/21 GOOD asphalt 5008x100ft, secondary RW09/27 GOOD asphalt 2951x50ft underlength. RW21 tree only ~218ft a… |
| TOI | Troy Municipal Airport at N Kenneth Campbell Field | FAA-derived 01 Oct 2026 Troy primary RW07/25 GOOD asphalt 6197x100ft S24000/D80000/DT140000, ILS RW25; secondary RW14/32 5024x100ft POOR asphalt with extensive cracking, raveling, vegetation and faded markings;… |
| TQK | Scott City Municipal Airport | FAA-derived 01 Oct 2026 Scott City primary RW17/35 excellent CONCRETE 5002x75ft PCN11 R/C/X/U S30000/D45000lb, alternate RW08/26 ROUGH turf 2145x60ft with rodent holes and therefore physically ineligible. Road/… |
| TX0 | Shank N Bank Airport | FAA-derived 01 Oct 2026 privately owned Shank N Bank RW09/27 EXCELLENT asphalt 5002x75ft; owner documentation rounds length to 5001ft, and advertised pavement PCR45, tug 60000lb are NOT verified selected-airfra… |
| UAO | Aurora State Airport | FAA-derived 01 Oct 2026 Aurora State RW17/35 excellent grooved asphalt 5003x100ft, S30000/D45000, plus 150ft BLAST PAD at south end: blast pad NOT runway pavement/LDA and must never be added. FAA instrument LOC… |
| UGN | Waukegan National Airport | FAA-derived 01 Oct 2026 Waukegan National main RW05/23 good grooved asphalt 6001x150ft S95000/D120000/DT200000, ILS RW23; distinct short RW14/32 good asphalt 3750x75ft (RW14 threshold displaced 489ft), gross un… |
| UNI | Ohio University Airport | FAA-derived 01 Oct 2026 Ohio University RW07/25 good asphalt 5600x100ft PCN20 S56500/D82000, RW07 900ft displaced threshold leaves 4700ft NOMINAL pavement only, NOT source-published LDA. RW25 no displaced thres… |
| VPC | Cartersville Airport | FAA-derived 01 Oct 2026 Cartersville main RW01/19 excellent grooved asphalt 5760x100ft, displaced threshold RW01 740ft -> 5020ft nominal landing pavement only, NOT published LDA. Two runway-end EMAS areas are e… |
| VTN | Miller Field | FAA-derived direct source now 01 Oct 2026, unlike Phase4 September copy. Miller Field main RW14/32 excellent concrete 4705x75ft, RW14 384ft displaced threshold => 4321ft nominal; secondary concrete RW03/21 exce… |
| VUJ | Stanly County Airport | FAA-derived 01 Oct 2026 Stanly County main RW04R/22L excellent grooved asphalt 5499x100ft and ILS RW22L, separate parallel RW04L/22R excellent asphalt 3501x75ft but below min physical distance. Ramp PPR applies… |
| WLW | Willows Glenn County Airport | FAA-derived 01 Oct 2026 Willows Glenn County main RW16/34 good asphalt 4125x100ft, narrow ~58m gross above min; secondary RW13/31 POOR asphalt 3788x60ft with alligator cracking/faded markings and RW31 243ft dis… |
| X26 | Sebastian Municipal Airport | FAA-derived 01 Oct 2026 Sebastian Municipal main RW05/23 excellent asphalt 4023x75ft PCN6 F/B/Y/T S22000 single wheel, but municipal pilot page reports 4024x150ft: major **75ft vs 150ft width contradiction**, f… |
| X51 | Miami Homestead General Aviation Airport | FAA-derived 01 Oct 2026 Miami Homestead General Aviation RW18/36 good asphalt 4001x100ft PCN12, merely ~19m gross margin above min; separate RW10/28 excellent grooved asphalt 3000x75ft, and RW09U/27U turf 2500x… |
| Y70 | Ionia County Airport | FAA-derived 01 Oct 2026 Ionia County primary RW10/28 FAIR asphalt 4298x75ft S19000 single wheel, separate turf RW18/36 4261x340ft gross >1200m but SURFACE TURF means ineligible. County rounds dimensions to 4300… |
| ZPH | Zephyrhills Municipal Airport | FAA-derived 01 Oct 2026 Zephyrhills has TWO independently physically qualified runways: RW01/19 FAIR asphalt 6201x100ft PCN16 S47000/D69000 and RW05/23 GOOD grooved asphalt 5001x100ft PCN16 S53000/D75000; city … |

## Critical independent exceptions

- **Troy TOI**: RW14/32 is 5,024ft but badly cracked/vegetated and held `PAVEMENT_CONDITION_HOLD` in both directions. Separate good 6,197ft RW07/25 is not automatically closed. [FAA-derived source](https://www.airnav.com/airport/TOI).
- **Sebastian X26**: FAA-derived primary RW05/23 **4,023 × 75ft** differs materially from the city **4,024 × 150ft**. Use 75ft as conservative research assumption pending written reconciliation. [Source](https://www.airnav.com/airport/X26).
- **UNI / VPC / VTN**: displaced thresholds give nominal pavement UNI RW07 **4,700ft**, Cartersville RW01 **5,020ft**, Miller Field RW14 **4,321ft**. None is authenticated published FAA LDA. VPC's EMAS are not landing runway; UAO Aurora's 150ft blast pad is also excluded.
- **Shank N Bank TX0**: FAA-public-use privately owned airport still requires prior signed owner/operator landing waiver and permission. [Source](https://www.airnav.com/airport/TX0).
- **Ionia Y70**: secondary turf RW18/36 is physically long but disqualified by turf surface. **X51** Homestead runway 18/36 only 4,001ft, while shorter asphalt and turf runways cannot substitute. Weather-modification-specific PPR does not apply universally.
- **ZPH Zephyrhills**: 01/19 and 05/23 both physically long but have different pavement capacities, shared glider/skydiving traffic and both lack verified per-end FAA LDA.

## All 388 recorded runway-end research states

| Source-screening state | Records |
| --- | ---: |
| Physical length/surface plausible, official LDA unverified | 265 |
| Gross physical length/surface ineligible | 94 |
| Nominal pavement below 1,200m | 12 |
| Pavement-condition hold | 8 |
| Explicit landing-direction prohibition | 1 |
| Secondary-source LDA below 1,200m | 6 |
| Secondary-source LDA above 1,200m, pending revalidation | 2 |

These 388 records are a targeted direction-level evidence ledger and do not imply exhaustive directional coverage for all 211 airports.

## Version-controlled runnable SQL archives

- [Batch 11 direction evidence part 1, 18 records](./sql/AIRLINERRA_PHASE5_BATCH_11_RUNWAY_DIRECTIONS_PART_01_2026-10-26.sql)
- [Batch 11 direction evidence part 2, 18 records](./sql/AIRLINERRA_PHASE5_BATCH_11_RUNWAY_DIRECTIONS_PART_02_2026-10-26.sql)
- [Batch 11 direction evidence part 3, 18 records](./sql/AIRLINERRA_PHASE5_BATCH_11_RUNWAY_DIRECTIONS_PART_03_2026-10-26.sql)

## Next stage — primary evidence and operational gates

1. Obtain and import genuine current FAA NASR airport/runway records with URL, effective cycle, original file hash and per-direction declared LDA; preserve unknown/blank values.
2. Apply direction-specific landing clearance, declared LDA, surface and selected-aircraft bearing, landing/takeoff performance and width. Maintain LAM's explicitly prohibited landing direction.
3. Independently secure written commercial owner/airport permission, named certificated air operator, fuel/handling/rescue service and flight-class/customs authorization as needed.
4. Revalidate temporary restrictions on the intended date with live NOTAM/FICON/weather. **No airport, category or world activation until all required gates pass.**

**Final result: initial source-review phase complete 211/211; airport-operational certification 0/211 approved.**
