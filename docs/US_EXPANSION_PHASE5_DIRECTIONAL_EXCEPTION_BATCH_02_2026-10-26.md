# Airlinerra — US Expansion Phase 5 Batch 2: Directional Landing Distance Exception Review
**Date:** 26 October 2026 · **Status:** Source research and Supabase recording complete (10/10); all cases remain blocked.

## Scope and disposition

Phase 5 Priority-2 reviewed the 10 airports that Phase 4 flagged because at least one runway landing direction cannot meet the game's **1,200-metre direction-specific usable landing-distance** threshold. An **individual landing-direction failure is not automatically an airport-wide exclusion**. Conversely, a physical asphalt runway longer than 1,200 metres is not proof its per-direction FAA published landing distance meets the requirement. Source checks used AirNav displays of FAA information effective **1 October 2026**; these are **secondary derived sources**, not flight-date FAA/NOTAM authorizations.

**Conclusions:** 9 airports have at least one runway direction with source-reported physical/nominal room above the threshold that still requires an authoritative per-direction LDA. **PHD** has no such currently documented paved landing direction; its RW15 and RW33 officially declared FAA-derived LDAs are both below threshold, and its second runway is turf and short. All 10 retain the Phase 5 review status `EVIDENCE_HOLD` **and** the separate gameplay status `NOT_APPROVED`.

| Metric | Verified |
| --- | ---: |
| Airport assessments | 10 of 10 |
| Individual landing-direction entries | 36 |
| Alternative unverified landing directions | 16 |
| Nominal displacement-derived landing length below 1,200m | 10 |
| Published direction-specific LDA below 1,200m | 4 |
| Physical length / non-permitted surface ineligible | 6 |
| Phase 5 airports approved to gameplay | 0 |
| World activation rows | 0 |
| Original airport cohort preserved | 3,140 |

## Airport-level conclusions

| FAA | Airport | Potential surviving landing directions | Blocked finding |
| --- | --- | --- | --- |
| 05C | Griffith-Merrillville Airport | 08 | RW26 nominal landing pavement 3779ft (<1200m); RW08 opposite 4899ft with no recorded displaced threshold is alternate pending official direction-specific LDA. Public-use airport, fuel listed, but 75ft width, tree obstacles, aircraft fit and owner/operator legal permissions remain unverified. |
| 3TR | Jerry Tyler Memorial Airport | 33 | RW15 nominal landing pavement 3800ft below cutoff. RW33 nominal 4100ft possible alternative pending official LDA (small margin); secondary 04/22 physically below minimum. Obstacles/PAPI, 25k lb single-wheel, owner/carrier/NOTAM unresolved. |
| AUO | Auburn University Regional Airport | 11, 18, 36 | RW29 nominal 3703ft below cutoff; RW11 nominal 4000ft and longer 18/36 5264ft are alternatives pending official per-direction LDA. University flight/event permission and aircraft load/operating restrictions not approved. |
| L65 | Perris Valley Airport | 33 | RW15 nominal 3200ft below cutoff after 1900ft displacement. RW33 nominal 4956ft possible but official LDA unresolved. Private owner paid use, 50ft pavement, parachutists/ultralights, emergency-only fuel, no published instrument procedures require hold. |
| ORE | Orange Municipal Airport | 01, 14 | RW19 nominal 3701ft and RW32 3510ft below minimum; RW01 nominal 5002ft and RW14 4800ft are possible alternates pending official LDA. April-Nov parachute activity, aircraft loads, owner authorization, current conditions require review. |
| OXD | Miami University Airport | 23 | RW05 nominal 3741ft below minimum; RW23 nominal 4011ft (~23m gross buffer) needs official current LDA. University-owner and current airport-manager paid commercial permissions, operator certificate, lighting/fuel service and gear limits pending. |
| PHD | Harry Clever Field | None shown | NO KNOWN QUALIFYING PAVED LANDING DIRECTION: FAA-derived published LDA RW15=3621ft and RW33=3634ft, both below 1200m, despite 3951ft physical paved runway; other RW12/30 is 1907ft turf. Airport remains blocked; verify any future runway project/current FAA declared distances before re-evaluation. Historical GlobalAir LDA for RW15 conflicts, use current FAA authoritative source. |
| PWK | Chicago Executive Airport | 16, 34 | Crosswind RW12 and RW30 PUBLISHED LDA 3785ft/3725ft both below cutoff, even though nominal post-threshold pavement 4120/3983ft appears above cutoff; published LDA governs. Main 16/34 5001ft nominal physical runway remains candidate pending official LDA. EMAS is not landing pavement; legal carrier/ATC/owner permission and aircraft strength pending. |
| SEE | Gillespie Field | 09L, 27R | RW17 nominal 3695ft and RW35 3460ft below cutoff; short 09R/27L 2738ft physically fails. Main 09L 5342ft / RW27R 4636ft nominal post-threshold are alternative candidates pending official LDA; terrain, skydive/training/ATCT, aircraft fit and County/Part135 authorization pending. |
| WVI | Watsonville Municipal Airport | 02, 09, 27 | RW20 nominal post-threshold 3913ft (about 7m below 1200m); RW02 4502ft and RW09/27 3998ft gross potential alternate landings pending official LDAs and limited margin. RW27 DEPARTURES prohibited by FAA remarks; do not mislabel all RW27 landings prohibited. Coastal fog, skydiving and city commercial permissions still unverified. |

## Direction-by-direction source ledger

Use the `PUBLISHED_LDA` value whenever supplied. `NOMINAL_FROM_THRESHOLD` is runway pavement length minus the source-reported displaced threshold, a **screening estimate only** and not a substitute for an FAA-declared LDA. `GROSS_ONLY` does not establish a direction's usable landing distance.

| FAA | Runway end | Paved length, ft | Threshold displaced, ft | Nominal ft | Published LDA ft | Finding |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 05C | 08 | 4899 | 0 | 4899 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| 05C | 26 | 4899 | 1120 | 3779 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| 3TR | 04 | 3316 | 898 | 2418 | — | PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE |
| 3TR | 22 | 3316 | 750 | 2566 | — | PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE |
| 3TR | 15 | 4100 | 300 | 3800 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| 3TR | 33 | 4100 | 0 | 4100 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| AUO | 11 | 4000 | 0 | 4000 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| AUO | 29 | 4000 | 297 | 3703 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| AUO | 18 | 5264 | — | — | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| AUO | 36 | 5264 | — | — | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| L65 | 15 | 5100 | 1900 | 3200 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| L65 | 33 | 5100 | 144 | 4956 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| ORE | 01 | 5002 | 0 | 5002 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| ORE | 19 | 5002 | 1301 | 3701 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| ORE | 14 | 4800 | 0 | 4800 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| ORE | 32 | 4800 | 1290 | 3510 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| OXD | 05 | 4011 | 270 | 3741 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| OXD | 23 | 4011 | 0 | 4011 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| PHD | 12 | 1907 | — | — | 1758 | PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE |
| PHD | 30 | 1907 | — | — | 1758 | PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE |
| PHD | 15 | 3951 | 330 | 3621 | 3621 | PUBLISHED_LDA_BELOW_1200M |
| PHD | 33 | 3951 | 0 | 3951 | 3634 | PUBLISHED_LDA_BELOW_1200M |
| PWK | 12 | 4415 | 295 | 4120 | 3785 | PUBLISHED_LDA_BELOW_1200M |
| PWK | 30 | 4415 | 432 | 3983 | 3725 | PUBLISHED_LDA_BELOW_1200M |
| PWK | 16 | 5001 | — | — | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| PWK | 34 | 5001 | — | — | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| SEE | 09L | 5342 | 0 | 5342 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| SEE | 27R | 5342 | 706 | 4636 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| SEE | 09R | 2738 | — | — | — | PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE |
| SEE | 27L | 2738 | — | — | — | PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE |
| SEE | 17 | 4145 | 450 | 3695 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| SEE | 35 | 4145 | 685 | 3460 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| WVI | 02 | 4502 | 0 | 4502 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| WVI | 20 | 4502 | 589 | 3913 | — | NOMINAL_PAVEMENT_BELOW_1200M |
| WVI | 09 | 3998 | 0 | 3998 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |
| WVI | 27 | 3998 | 0 | 3998 | — | ALTERNATE_DIRECTION_LDA_UNVERIFIED |

## Evidence, nuances and next action by direction

### 05C — Griffith-Merrillville Airport
- **RW 08:** RW08 has no displaced threshold reported; actual FAA direction-specific LDA, trees and selected aircraft/owner rights unverified. Source: https://www.airnav.com/airport/05C
- **RW 26:** RW26 threshold displaced 1,120ft; nominal available landing pavement 3,779ft below 1,200m; separate published FAA LDA still needs confirmation. Source: https://www.airnav.com/airport/05C

### 3TR — Jerry Tyler Memorial Airport
- **RW 04:** Secondary poor broken asphalt 3,316ft total; physically below minimum regardless of threshold. Source: https://www.airnav.com/airport/3TR
- **RW 22:** Secondary poor broken asphalt 3,316ft total; physically below minimum regardless of threshold. Source: https://www.airnav.com/airport/3TR
- **RW 15:** RW15 threshold displaced 300ft; nominal landing pavement 3,800ft below cutoff; obstacles and limited PAPI usable sector. Source: https://www.airnav.com/airport/3TR
- **RW 33:** RW33 has no displaced threshold reported; physical length only ~50m above minimum; official LDA and 25,000lb S gear fit pending. Source: https://www.airnav.com/airport/3TR

### AUO — Auburn University Regional Airport
- **RW 11:** No displaced threshold listed on RW11; nominal margin ~19m above 1,200m, official LDA still unverified. Source: https://www.airnav.com/airport/AUO
- **RW 29:** RW29 displaced 297ft; nominal landing pavement 3,703ft below minimum; runway is not presumed closed. Source: https://www.airnav.com/airport/AUO
- **RW 18:** Longer grooved main asphalt 5,264ft; airport event PPR/tower hours and direction-specific official LDA to verify. Source: https://www.airnav.com/airport/AUO
- **RW 36:** Longer grooved main asphalt 5,264ft; university permission, aircraft performance and direction-specific official LDA to verify. Source: https://www.airnav.com/airport/AUO

### L65 — Perris Valley Airport
- **RW 15:** RW15 displaced 1,900ft, nominal available 3,200ft. Daily skydiving/ultralights and 50ft paved width. Source: https://www.airnav.com/airport/L65
- **RW 33:** RW33 nominal 4,956ft; actual officially published LDA not established. Private owner permission, skydive restrictions, and emergency-only fuel unresolved. Source: https://www.airnav.com/airport/L65

### ORE — Orange Municipal Airport
- **RW 01:** RW01 no threshold displacement listed; official LDA unverified; parachuting near airport April-November. Source: https://www.airnav.com/airport/ORE
- **RW 19:** RW19 displaced threshold 1,301ft, nominal available 3,701ft below minimum; published LDA unverified. Source: https://www.airnav.com/airport/ORE
- **RW 14:** RW14 no displacement listed; official LDA still unverified; separate pavement/aircraft load. Source: https://www.airnav.com/airport/ORE
- **RW 32:** RW32 displaced threshold 1,290ft, nominal available 3,510ft below minimum; published LDA unverified. Source: https://www.airnav.com/airport/ORE

### OXD — Miami University Airport
- **RW 05:** RW05 displacement 270ft: nominal available 3,741ft below minimum; approach obstacles. Source: https://www.airnav.com/airport/OXD
- **RW 23:** RW23 no threshold displacement; gross nominal available 4,011ft, only ~23m above minimum; official LDA pending. Jet A by request, owner/manager written use rights pending. Source: https://www.airnav.com/airport/OXD

### PHD — Harry Clever Field
- **RW 12:** Turf runway below minimum in length and surface; published LDA only 1,758ft. Source: https://www.airnav.com/airport/PHD
- **RW 30:** Turf runway below minimum in length and surface; published LDA only 1,758ft. Source: https://www.airnav.com/airport/PHD
- **RW 15:** FAA-derived published RW15 LDA 3,621ft; threshold displaced 330ft. Fails 1,200m even though runway length 3,951ft. Source: https://www.airnav.com/airport/PHD
- **RW 33:** FAA-derived published RW33 LDA 3,634ft, which is below 1,200m EVEN THOUGH no displaced threshold and full pavement length 3,951ft; do not use nominal. Source: https://www.airnav.com/airport/PHD

### PWK — Chicago Executive Airport
- **RW 12:** FAA-derived published RW12 LDA 3,785ft BELOW minimum even though 4,120ft nominal pavement after displacement. Use official LDA, not 4,120. Source: https://www.airnav.com/airport/PWK
- **RW 30:** FAA-derived published RW30 LDA 3,725ft BELOW minimum even though 3,983ft nominal pavement after displacement. Use official LDA, not 3,983. Source: https://www.airnav.com/airport/PWK
- **RW 16:** Primary grooved asphalt 5,001ft with ILS, EMAS beyond ends; official RW16 LDA not in consulted extracted record. Source: https://www.airnav.com/airport/PWK
- **RW 34:** Primary grooved asphalt 5,001ft with ILS, EMAS beyond ends; official RW34 LDA not in consulted extracted record. Source: https://www.airnav.com/airport/PWK

### SEE — Gillespie Field
- **RW 09L:** Main good asphalt no threshold displacement on RW09L, nominal 5,342ft; official direction-specific LDA and aircraft/approach suitability pending. Source: https://www.airnav.com/airport/SEE
- **RW 27R:** RW27R threshold displaced 706ft, nominal 4,636ft; official LDA, terrain/PAPI and carrier rights pending. Source: https://www.airnav.com/airport/SEE
- **RW 09R:** Shorter runway 2,738ft, ineligible by physical length, with additional nighttime closure. Source: https://www.airnav.com/airport/SEE
- **RW 27L:** Shorter runway 2,738ft, ineligible by physical length, with additional nighttime closure. Source: https://www.airnav.com/airport/SEE
- **RW 17:** RW17 displaced 450ft, nominal available 3,695ft below minimum; other runway may be usable. Source: https://www.airnav.com/airport/SEE
- **RW 35:** RW35 displaced 685ft, nominal available 3,460ft below minimum; other runway may be usable. Source: https://www.airnav.com/airport/SEE

### WVI — Watsonville Municipal Airport
- **RW 02:** RW02 no displaced threshold reported, nominal 4,502ft; official LDA, trees/fog and availability pending. Source: https://www.airnav.com/airport/WVI
- **RW 20:** RW20 displaced 589ft, nominal landing pavement 3,913ft, only ~7m below cutoff; official LDA and weather/straight-in approach pending. Source: https://www.airnav.com/airport/WVI
- **RW 09:** RW09 gross and nominal 3,998ft, only ~19m above minimum; published LDA and trees/aircraft fit unresolved. Source: https://www.airnav.com/airport/WVI
- **RW 27:** RW27 landing LDA remains unverified; separately, FAA-derived airport remarks PROHIBIT ALL RW27 DEPARTURES due to obstructed visibility. Do not confuse departure ban with landing restriction. Source: https://www.airnav.com/airport/WVI

## Critical interpretation notes

- **PHD (Harry Clever Field):** RW15 officially FAA-derived reported LDA 3,621ft and RW33 3,634ft, both below 1,200m; 3,951ft gross runway is NOT a qualifying LDA. Historical third-party databases may disagree with current FAA-derived information. Keep as airport-wide evidence hold, reopen only on a changed authoritative airport/runway record.
- **PWK (Chicago Executive):** RW12/30 nominal post-threshold pavement 4,120/3,983ft is **larger** than the actual FAA-derived published LDAs 3,785/3,725ft. Both landing ends fail the stated LDA rule. Potential RW16/RW34 remains pending. EMAS is not extra usable landing pavement.
- **WVI (Watsonville):** FAA-derived remarks prohibit **departures** from runway 27; this is a different operational constraint from landing distance or a blanket RW27 landing ban. RW20 nominal pavement 3,913ft is slightly below 1,200m.
- **L65 (Perris Valley):** 50ft runway width, extensive parachuting and FAA listing of fuel for emergency use only must be preserved even if RW33 meets the final LDA screen. This airport is a poor candidate for unsupported commercial operations.
- **AUO, ORE, SEE:** Their failed crosswind/secondary landing directions must not invalidate longer primary runways without independently examining official LDA on those separate directions.
- **No game admission or six-tier category change** is authorized by this research ledger. Owner permission, operator certification, selected aircraft type/pavement, flight-date weather/NOTAM and handling/rescue remain NOT_VERIFIED.

## Supabase records and backlog

- Canonical research project: `hwllkabgzaynalahvkpz`, private `airlinerra` schema.
- `airport_expansion_phase5_gate_reviews`: 10 Priority-2 rows now `EVIDENCE_HOLD`, batch `US_EXPANSION_PHASE5_DIRECTIONAL_EXCEPTION_BATCH_02_2026_10_26`.
- `airport_expansion_phase5_runway_directions`: 36 direction rows keyed by stable airport key and runway end, with source URL, source-effective date, pavement, threshold, nominal estimate, optional published LDA, and non-approval check constraints. Row-level security enabled; no anon/authenticated access.
- Phase 5 after Batch 2: **26** previous Batch-1 source reviews held + **10** Batch-2 direction reviews held + **175** Priority-3 airports queued without validated official usable LDA. **211/211 still NOT_APPROVED**.

**Next action:** Phase 5 Batch 3 begins official LDA evidence collection for the 175 Priority-3 airports in manageable review batches. Continue separate follow-up for 9 airports with possible surviving directions and PHD's blocked runway issue. Do not automatically activate any airport.
