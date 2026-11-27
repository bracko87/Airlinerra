# Phase 1 storage operational review — 27 November 2026

Review evidence only. No production deployment, runway status changes, commercial rights changes or airport approval.

## Verified integrated baseline
- Private workflow 46066000877, commit 6ca40a133a8984b1a26229550206db2bef6acc02: 62 components, all four deferred candidate-data blocks, nine priced inactive facilities, six service proposals, 271 billing proposals; transaction rolled back and all seven schema fingerprint categories restored.
- Isolated regression 46065390936 passed on the same commit.

## Fresh read-only game preflight
All three return GAME_SOURCE_MATCHED_REVIEW_REQUIRED; approval_granted=false. The airport profiles, selected runway identities, game movement tariffs, fuel and remote stands matched the pinned preflight. All selected runway statuses remain unknown, verification historical_unverified.

| Airport | Selected source runway | Game runway length/width (m) | Storage proposed TORA/LDA cap (m) | Game landing/departure USD | Remote stands |
|---|---|---|---|---|---|
| ASP/YBAS | 233325, 12/30 | 2438.1/45.1 | 2438/2438 | 812/129.92 | 4 |
| LDE/LFBT | 235930, 02/20 | 3000.1/45.1 | 3000/2330 | 1000/160 | 1 |
| ROW/KROW | 244235, 17/35 | 3050.4/30.5 | 3050/3050 | 1875/337.50 | 5 |

All three have existing game fuel availability and one remote movement per direction per ten-minute slot. Game H24 default and noise rules are not real airport access clearance; no change proposed to commercial policies.

## Source verification
- Alice Springs: Airservices Australia RDS 04 September 2025, runway 12/30 TORA and LDA 2438 m at both ends; width 45 m. Full runway departure assumed in game; intersection distances are shorter. https://airservices.gov.au/aip/current/ersa/RDS_YBAS_04SEP2025.pdf
- Tarbes: French AIP 26 November 2026 cycle, AD 2 LFBT.13: runway 02 and 20 both TORA 3000 m; LDA 2330 and 3000 m respectively. The previous TORA cross-check is now satisfied by extracted AD2 text. AD 2.12 also describes missing regulatory runway shoulders for four-engine aircraft with span exceeding 36 m or any aircraft with span exceeding 52 m; aircraft exceeding pavement strength rating require operator contact. Do not infer that these aircraft are automatically prohibited in reality; for game storage admission propose a conservative exclusion pending explicit aircraft/airport compatibility and exception review. https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_26_NOV_2026/FRANCE/AIRAC-2026-11-26/pdf/FR-AD-2.LFBT-fr-FR.pdf
- Roswell: FAA-derived AirNav data effective 11 June 2026; runway 17/35 TORA and LDA 10008 ft in both directions, width 100 ft, published asphalt condition good at source date; separate 03/21 is longer and concrete. Preserve selected game runway rather than switching implicitly. Published attendance 0600–2100 is not an airport curfew; after-hours service and pavement suitability require review. https://airnav.com/airport/ROW

PDF extracted text was available for Australia and France; both screenshot requests returned cache misses. These static sources do not certify current runway status, airport access or actual flight clearance.

## Release decisions still required
1. Use the established airport evidence process to review runway status; precedent supabase/migrations/20261113204000_section5_belgrade_normal_runway_procedural_evidence.sql distinguishes reported use from operational status. Never turn unknown into operational solely from a storage facility listing.
2. Confirm storage-only game compatibility rules for Tarbes shoulder and pavement limitations and Roswell runway width/pavement; missing performance or compatibility evidence must not silently pass. Confirm operator coordination/fuel access assumptions.
3. Re-run the exact readiness snapshot after staging only explicitly reviewed records. Keep all release gates disabled until authorized.
4. Separate installation from individual facility activation. No live changes made in this review.

The schema and candidate data are verified; operational eligibility for phase 1 remains blocked.
