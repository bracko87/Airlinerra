# Airlinerra — German expansion specialist decisions, Batch 11

**Executed 26 October 2026 · Central private Supabase** `hwllkabgzaynalahvkpz` / schema `airlinerra` · **GitHub** `bracko87/Airlinerra` `main`.

## Executive result

The three remaining specialist runway cases from Germany's **44 existing expansion candidates** have now received explicit, independently grounded runway-only collection decisions in the private research database. This **does not** mean all German airports can be released to gameplay or used commercially.

| Measure | After Batch 11 |
|---|---:|
| German airports technically source-reviewed | **44** |
| Main central `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING` | **35** |
| Main central `INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING` | **7** |
| Main central provisional short-runway hold | **1 — EDMB** |
| Main central temporary airport-closure hold | **1 — EDCP** |
| Separate specialist direction restrictions still preserved | **EDXJ civil LDA 1,140m, plus earlier cases** |
| German generic independent-verification queue | **0** |
| Worldwide expansion generic independent-verification queue | **1,783** |
| Original active World 1 airports and home-airport picker | **3,140 / 3,140** |
| New expansion airport activations | **0** |

### Specialist airport verdicts

**EDMB — Biberach an der Riß — provisional basic runway-eligibility failure.** The [current airport operator](https://www.edmb.de/fur-piloten/an-abflug/) gives **RW04/22 asphalt 980 × 23m**, RW04 LDA **780m**, RW22 LDA **980m**. The airport's [2025 AERO visitor information](https://www.edmb.de/fur-piloten/aero/) independently repeats 980m. [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=1366) also reports 980m, while historical [OurAirports](https://ourairports.com/airports/EDMB/runways.html) and [TPM](https://tpm-mediashop.com/pages/edmb-biberach-a-d-riss) incorrectly or inconsistently report **1,315m** as the original runway physical figure. Because the original Airlinerra catalog inherited **1,314.9m**, this is a material **334.9m registry versus current operator discrepancy**. The current operator does not identify a second qualifying paved runway. The case is now documented as **`PROVISIONAL_BELOW_1200_OPERATOR_RUNWAY_AIP_RECONCILIATION`**. It **fails the basic ≥1,200m current operator-runway evidence screen** and should **not** enter an expansion release without authoritative counterevidence. The central status remains **`HOLD_OPERATOR_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT`**, not a permanent exclusion, until effective AIP/physical-source reconciliation is completed. Original source runway data has not been overwritten.

**EDXJ — Husum-Schwesing — physical paved-runway screening passes, both civil landing directions restricted.** The [airport operator's current runway specification](https://www.flughafen-husum.de/de/flughafen/daten/startbahn.php) documents **RW03/21 asphalt 1,450 × 30m** (with concrete RW03 threshold), corroborated by the [resident flying group](https://www.sfg-husum.de/flugplatz1-sfg.html). The same original operator plainly states **1,140m between civil thresholds and only 1,140m TORA/LDA**, with the former NATO portion no longer available for civil use. The current Airlinerra `AGENTS.md` runway-only **airport-collection** criterion requires a qualifying physical paved runway ≥1,200m and explicitly **does not require civilian access, aircraft permissions or other future operating suitability at this stage**. Thus EDXJ's **physical runway evidence** has advanced to **`INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`**, while the existing private `airport_expansion_german_civil_runway_end_holds` record preserves **both 1,140m civil LDA limits** and denies game/commercial operating permissions. Under a future 1,200m **direction-specific** landing screen, **both directions currently fail**. Do not interpret the 1,450m gross pavement as available landing distance for either end.

**EDCP — Peenemünde — physically paved runway corroborated but temporarily closed during specified periods.** [IVAO's AIRAC 2106 aeronautical reference](https://de.ivao.aero/prozeduren/edww/e/edcp/) confirms **RW13/31 concrete 2,400 × 48m**, while [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071) independently records **2,400 × 60m** concrete. The sources agree on the basic physical paved runway length/surface above 1,200m but **disagree on width**; this must be resolved for aircraft suitability. Separately, [EAD-derived NOTAM briefing](https://www.notaminfo.com/latest?country=Germany) reports **NOTAM E4380/26**, an aerodrome closure **October 26–31, 2026**, **daily 07:00–11:00 and 12:15–17:00 UTC**, for test and research flights. An [official DFS notice](https://www.dfs.de/homepage/de/medien/ifr-vfr-informationen/vfr-informationen/gebiet-mit-flugbeschraenkungen-vom-08-januar-2026-bis-31-dezember-2028-forschungsprojekt-polaris/) separately documents the **Peenemünde ED-R restricted-airspace program through December 31, 2028**; this does *not* declare EDCP continuously closed for two years. EDCP's physical collection screen is recorded **`true`** in the specialist decisions table, but its central status remains **`HOLD_TEMPORARY_EDCP_AERODROME_CLOSURE_NOTAM_E4380_26`** and `paved_runway_status='UNVERIFIED'`, because the temporary closure and width reconciliation are still unresolved. **November 1, 2026** is the recorded manual **source-recheck date**, *not* an automatic clearance/activation or scheduled user notification. Check authoritative AIS NOTAM, replacements and official runway status before changing this hold.

### Database changes made

1. Added the private, RLS-protected `airlinerra.airport_expansion_de_specialist_batch11_decisions` with **three audited airport-keyed evidence records**, explicit distinct verdicts, runway dimensions, original source lengths, landing distances, provenance URLs and required next source actions. Constraints forbid real aircraft operating approval, effective 2026 AIP certification without evidence, gameplay admission or game-world activation.
2. Updated **only EDXJ** in `airport_access_reviews` to **operator-backed basic physical runway evidence verified**, preserving the *separate* special civil-use hold row that blocks both published 1,140m civil landing directions. No automatic airline permission was created.
3. Preserved **EDMB** on the provisional runway-length dispute hold and **EDCP** on its dated temporary-closure hold. Peenemünde’s existing separate `airport_expansion_de_temp_airfield_closure_watch` retains **NOTAM E4380/26** and a **2026-11-01** source recheck; it was not automatically cleared.
4. No change to original `airport_registry` source identifiers or source runway lengths, founding first-world airport activations, registration picker, aircraft model data, game worlds 2/3, the six airport category definitions or any live production/registration/payment settings.

### Source and test archive

- [Batch 11 reproducible SQL: private evidence ledger and safeguarded Husum runway status](./sql/AIRLINERRA_DE_SPECIALIST_BATCH_11_2026-10-26.sql)
- [Batch 11 Supabase regression suite — executed PASS](./sql/AIRLINERRA_DE_SPECIALIST_BATCH_11_TESTS_2026-10-26.sql)

The acceptance suite confirms **3 cases**, **Biberach 980m provisional under-threshold**, **Husum 1,450m gross physically passes with two separately held 1,140m civil landing distances**, and **Peenemünde E4380/26 closure held until source review**, plus **35 operator-evidence and 7 multi-source-evidence** German records, two remaining special central holds, zero newly approved/activated game airports, row-level security and preserved **3,140 World 1** records.

## Outstanding work after the completed specialist batch

**Germany's generic physical runway screening is accounted for, but this is not final unrestricted airport admission.** The next technical actions are: (1) obtain effective official German AIP for Biberach and resolve its **980m vs 1,314.9m** source discrepancy; (2) fetch current civil LDA and usable physical-runway details for Husum and retain 1,140m aircraft-distance limits; (3) recheck Peenemünde's active NOTAM **after October 31** and authoritative physical runway width. All 42 evidence-advanced German airports also retain applicable source freshness, runway-end declared-distance, runway operational state or permission checks before any future airline/simulation release.

**International expansion:** resume new country batches among the **3,906** total unactivated expansion airports, starting from the **1,783** that remain on the generic independent verification hold, while keeping other cohort-specific workflow statuses separate.

**End result: three German specialist cases classified, one new operator-backed runway evidence advance, one provisional runway-length failure held and one dated NOTAM hold retained, no newly playable airports.**
