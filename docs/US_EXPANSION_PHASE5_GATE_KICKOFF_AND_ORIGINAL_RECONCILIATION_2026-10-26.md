# Airlinerra — Phase 5 evidence-gate kickoff and original-airport reconciliation — 26 October 2026

## Scope and safety
This report records changes made in Supabase Airlinerra private schema `airlinerra`, and the independent post-write audit. **It does not admit airports into gameplay, certify actual flight operations, or validate a named carrier.** No original airport was modified. GitHub `main` is the current single development branch per `AGENTS.md`.

## Original 3,140: reconciliation completed, no mutation
- `airport_cohorts`: **3,140** `ORIGINAL_3140` entries.
- `airport_access_reviews`: all **3,140** remain `HOLD` and `NOT_APPROVED`.
- `airport_game_profiles`: **3,140** preliminary categories are present and **zero** final approved categories.
- The outcome matches the intentional runway-only data collection policy documented in `AGENTS.md` and `docs/AIRLINERRA_SUPABASE_CENTRAL_DATABASE_2026-10-23.md`: `RUNWAY_QUALIFIED` means technical source screening, not permission, capacity, operator qualification, playable-world activation, or permission for real flights.
- **Decision:** Do not bulk-convert `HOLD` into `APPROVED`; do not reimport or overwrite the original 3,140 as a supposed fix.

## Phase 5 Supabase changes
Created `airlinerra.airport_expansion_phase5_gate_reviews` with a primary key/FK to the **211 distinct Phase 4 airports**. Source evidence and Phase 4 classifications are carried forward without overwriting source records. One Phase 5 row per airport; an idempotent `ON CONFLICT DO NOTHING` seeding procedure loaded **211 of 211**.

Evidence gates are individually tracked: direction-specific LDA, selected aircraft/pavement, airport-owner written commercial permission, current certificated operator, date-valid NOTAM/weather, and fuel/handling/rescue. Each of the last five starts `NOT_VERIFIED`. `game_admission_status` has a database CHECK forcing `NOT_APPROVED`. Phase 5 research cannot silently grant game access.

| Phase 5 selection | Airport rows | State |
| --- | ---: | --- |
| Published LDA above threshold in Phase 4 | 26 | Priority 1; source requires cycle/current FAA revalidation |
| Direction flagged below 1,200m | 10 | Priority 2; assess alternate qualifying direction/runway |
| Official direction-specific LDA not yet established | 175 | Priority 3; authoritative source collection needed |
| **Total** | **211** | **0 gameplay approvals** |

Batch identifier for all 26 Priority-1 cases: `US_EXPANSION_PHASE5_LDA_REVALIDATION_BATCH_01_2026_10_26`. **Assigned to Batch 1 means queued, NOT a completed Phase 5 assessment.** The other 185 currently have no assigned Phase 5 batch identifier.

## Phase 5 initial source cross-checks: four airport cases
Four records were independently revisited against public October 2026 cycle-oriented source pages, with their URLs and findings stored in `verification_notes` and `source_evidence_urls`. The `phase5_review_status` is **EVIDENCE_HOLD** (not approved); `lda_evidence_status` remains `SOURCE_PUBLISHED_PENDING_REVALIDATION` because this desk check is not a refreshed authoritative FAA Chart Supplement / ADIP or flight-date clearance.

| FAA code | Airport | Phase 4 LDA evidence | Phase 5 desk-check result |
| --- | --- | --- | --- |
| C35 | Reedsburg Municipal | RW18/36 each 4,100ft | AirNav and FlightAware match; small margin above 1,200m; 75ft width, wheel load and approach constraints still matter |
| SFF | Felts Field | RW04L/22R each 4,499ft | AirNav and FlightAware match; water/short secondary runway not eligible |
| BNW | Boone Municipal | RW15 4,667ft; RW33 4,807ft | FAA-derived AirNav shows compatible numbers; PCN6 and 75ft runway require aircraft-specific fit |
| PAAQ | Palmer Municipal | RW16 5,506ft; RW34 6,006ft | AirNav and FlightAware match Phase 4; **GlobalAir displays RW16 LDA 6,006ft** despite displaced threshold. Resolve the secondary-source disagreement from current authoritative FAA declared distances before marking validated |

Source references:
- C35: https://www.airnav.com/airport/C35 ; https://www.flightaware.com/resources/airport/C35/runway/18/36
- SFF: https://airnav.com/airport/KSFF ; https://www.flightaware.com/resources/airport/KSFF/runway/04L/22R
- BNW: https://airnav.com/airport/BNW
- PAAQ: https://www.airnav.com/airport/PAQ ; https://www.flightaware.com/resources/airport/PAAQ/runway/16/34 ; https://www.globalair.com/airport/apt.runway.aspx?aptcode=paaq

FAA policy for use of declared distances: https://www.faa.gov/air_traffic/publications/atpubs/aip_html/part2_enr_section_1.1.html . A physical runway's gross length is not automatically the declared LDA, and a published LDA must not have a threshold subtraction applied a second time.

## Supabase post-write verification
- **211** rows, **211** distinct keys.
- **26** in first Phase 5 batch: **4** source-cross-checked and held; **22** awaiting source cross-check.
- **185** remaining Phase 5 rows queued (10 below-minimum-direction reviews + 175 missing officially established LDAs).
- **0** unexpected gameplay approvals; **0** falsely verified owner/operator/aircraft/NOTAM/fuel gates.
- All original **3,140** remained `HOLD`, `NOT_APPROVED`, with `final_category IS NULL`.
- New ledger is private, RLS-enabled, with **no SELECT or INSERT permission for `anon` or `authenticated`**. Security Advisor's informational "RLS enabled no policy" finding is intentional for a private research table.

## Next actions
1. Obtain latest authoritative FAA per-direction declared distance records for the 22 remaining Priority-1 cases, and resolve PAAQ's secondary-source discrepancy.
2. Record aircraft type/gear-specific compatibility and current restrictions separately; do not substitute PCN or generic wheel bearing for a type-specific approval.
3. Collect written owner permission and evidence for a named certificated operator; verify date-valid NOTAM/FICON/weather, fuel, servicing and rescue.
4. Progress the 10 directional exceptions and 175 missing official LDA cases after Batch 1. Keep the 622 Phase 3 operational holds and the other 1,096 Phase 3 candidates in separate queues.
5. Do not change `ORIGINAL_3140`, preliminary six-level categories, or `airport_world_activation` until explicitly authorized and independently supported by evidence.
