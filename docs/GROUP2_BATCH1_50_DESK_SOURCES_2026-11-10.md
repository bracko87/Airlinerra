# Group 2 — Batch 1 airport research results (10 November 2026)

## Actual completion

- **Batch 1 case triage is complete:** all **50** airports assigned stable review numbers, initial priority, historic evidence/prohibition snapshot and actionable research requirements. This is NOT completion of 50 independent real-world verifications.
- **11 public primary-source findings**, covering **9 different airports**: seven runway-width findings, two independent source-document restriction corroborations (same previously recorded Austrian AIP restriction), and two Australian access/parking/distance findings.
- **41 cases do not yet have newly located public source documents** in this batch. They remain explicit research tasks.
- **Zero independently approved Group 2 airport gates; zero Group 2 airports ready for World 1 admission; zero Group 2 flights.**
- Source findings are **not** the independent `verified` evidence events from the protected group2 gate system. All new documents need final effective-date, identity, runway and permission checks; no live airport geometry is changed.

## Runway-width source candidates (NOT yet applied)

| Airport | Key | Game estimated width (m) | Public-source width (m) | Primary source / caveat |
|---|---|---:|---:|---|
| Coondewanna, AU / YCWA | OURAIRPORTS:29801 | 36.3 | **30.0** | [Airservices Australia ERSA FAC YCWA 28 Nov 2024](https://www.airservicesaustralia.com/aip/current/ersa/FAC_YCWA_28NOV2024.pdf). Restricted operations, PPR required |
| Onslow, AU / YOLW | OURAIRPORTS:27866 | 36.3 | **30.0** | [Airservices Australia ERSA FAC YOLW 4 Sep 2025](https://www.airservicesaustralia.com/aip/current/ersa/FAC_YOLW_04SEP2025.pdf). Security controlled, prior arrangement for >5,700 kg parking, aircraft/taxiway limits |
| Cecil, US / KVQQ | OURAIRPORTS:21335 | 36.3 | **60.96** | [Florida Aviation System Plan airport factsheet 2024](https://www.cfaspp.com/FASP/AirportPDFs/638615669868993308-VQQ_4_4_2024_.pdf); runway 18L/36R 12,503 × 200 feet |
| Grant County Intl, US / KMWH | OURAIRPORTS:20581 | 45.1 | **60.96** | [FAA March 2026 airport diagram](https://aeronav.faa.gov/afd/19MAR2026/NW_rear_19MAR2026.pdf); runway 14L/32R 13,503 × 200 feet, chart now outside validity window |
| Mobile Downtown, US / KBFM | OURAIRPORTS:3403 | 36.3 | **45.72** | [Mobile Airport Authority official infrastructure page](https://www.mobileairportauthority.com/aeroplex/infrastructure/); runway 14/32 9,618 × 150 feet |
| Southern California Logistics, US / KVCV | OURAIRPORTS:21315 | 36.3 | **45.72** | [City of Victorville official airport pilot information](https://www.victorvilleca.gov/Government/City-Departments/Airport/For-Pilots); runway 17/35 13,052 × 150 feet |
| Arkansas International, US / KBYH | OURAIRPORTS:3436 | 36.3 | **45.72** | [Arkansas state aviation airport directory](https://fly.arkansas.gov/uploads/7/5/7/7/75772239/blytheville-ar_international.pdf); runway 18/36 11,602 × 150 feet |

**These are public-source candidate dimensions, not current independent aviation/dispatch certificates.** The seven original game estimates have deliberately NOT been updated. A checked and dated runway review must confirm the actual current runway, declared distances, restrictions and aircraft compatibility before game model replacement or a source evidence gate is marked verified.

## Existing commercial-airfield prohibition holds

| Airport | Game key | Source |
|---|---|---|
| Brumowski Air Base, Tulln / LOXT | OURAIRPORTS:29484 | [Austro Control AIP amendment 335, AD 1.1 (27 Dec 2024)](https://www.austrocontrol.at/jart/prj3/ac/data/dokumente/LO_Amdt_2024_335_en_2024-12-10_1012477.pdf) |
| Hinterstoisser Air Base, Zeltweg / LOXZ | OURAIRPORTS:4436 | Same Austrian AIP source |

The published AIP amendment identifies the two military bases in its scope, states prior Ministry of Defence permission is required for civilian use and prohibits commercial aviation at the named military airfields. This corroborates the **existing** 2026 Group 2 historic prohibition findings, but the 2024 edition is **not** proof that the entire legal regime has remained unchanged in November 2026. Their existing `HARD_HOLD_DOCUMENTED_PROHIBITION` remains unchanged until authoritative, independently reviewed contrary evidence exists.

## Published Australian access details also found

- **Coondewanna YCWA:** [Runway Distance Supplement dated 27 Nov 2025](https://www.airservicesaustralia.com/aip/current/ersa/RDS_YCWA_27NOV2025.pdf) reports runway 08 TORA 1,950m, runway 26 TORA 1,930m, and LDA 1,800m for each. The FAC explicitly says **restricted operations, prior permission from airport operator (PPR)**.
- **Onslow YOLW:** The [ERSA FAC dated 4 Sep 2025](https://www.airservicesaustralia.com/aip/current/ersa/FAC_YOLW_04SEP2025.pdf) describes security-controlled airside access and parking by prior arrangement for aircraft above 5,700kg. There are also specific taxiway restrictions for aircraft size and gear width. These cannot be converted into a universal `unrestricted` flag.

## Exactly what was deployed

- `airport_group2_batch1_desk_cases_v1`: **50 immutable** case/priority snapshots, one per group2 airport in the initial batch.
- `airport_group2_batch1_public_source_findings_v1`: **11 immutable** source findings with URL, issuer, source date when available, limited fact type, candidate runway width and explicit freshness/permission warnings.
- `airport_group2_batch1_source_progress_v1`: summary of found-source coverage, still-unsourced research, previously prohibited cases and independent-review status.
- `airport_group2_batch1_desk_worklist_v1`: 50-case researched/not-yet-researched source worklist; immutable original batch membership despite any future reprioritization.
- Private by default: RLS enabled and no `anon`/`authenticated` read/write. Evidence events, source game profiles and operational admission tables are **not modified**.

## Verification

Both migrations and source/case data were checked in SQL `BEGIN; ... ROLLBACK;` before deployment. A separate **post-deploy rollback-only** acceptance checked:

- Exactly 50 case snapshots, 11 sources, nine sourced airports, 41 source-findings outstanding
- Exactly seven width candidates, two restrictions and two access-condition notes
- Exactly 2 + 20 + 28 initial triage priorities
- No source claims promoted to independently verified evidence or current runway width
- Current Group 1 roster still **3,141**, Group 2 **1,118**, World 1 still `planned`, flight events **zero**, preexisting airline ledger count unchanged
- Both case snapshots and source findings are immutable and private

## Follow-up

1. **Batch 1 — 41 unsourced cases:** seek direct authority/airport operator/AIP records. Some have military or private-use restrictions requiring special care.
2. **The seven width source findings:** confirm current effective-source cycle and exact airport/runway identity, reconcile discrepancies, then submit for independent evidence verification. Do not silently alter game runway data.
3. **Operating restrictions and passenger/cargo rights:** independently review per-airport curfews, PPR, carrier eligibility, physical handling and civil/commercial-use rules; a primary-source runway number alone cannot grant flight service.
4. **Only after completion of necessary independent gate reviews:** perform separate authorized Group 2 owner/game admission, with full engine integration and regressions. No Group 2 airports are authorized now.

**Progress interpretation:** Source research has started, and the initial 50 are triaged. **Batch 1 independent airport reviews are still open.** This distinction prevents the airport project from being repeatedly called 'complete' when a flight release is still blocked.
