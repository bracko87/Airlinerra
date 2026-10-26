# Airlinerra — Phase 5 Batch 3: 20 Missing-LDA Airport Source Reviews
**Date:** 26 October 2026. **Database:** Airlinerra Supabase project hwllkabgzaynalahvkpz, private airlinerra schema.

## Verified result
The first **20 of 175** Priority-3 airports were individually researched against available FAA-derived airport records and their own Phase 4 evidence, recorded in Supabase, and audited. **155 remain queued.** All 20 are `EVIDENCE_HOLD` and `NOT_APPROVED`. All 211 Phase 5 airports stay `NOT_APPROVED`. No six-category final approvals or world activations were made; the original 3,140 were preserved.

This is a **source-review completion milestone, not 20 official FAA LDA confirmations**. The full original FAA NASR APT export was not obtainable in this review. The consulted AirNav pages are FAA-derived secondary sources; flight-date NOTAM/weather, owner signed commercial access and actual licensed operator remain unverified.

## Results by airport
| FAA | Airport | LDA outcome |
| --- | --- | --- |
| 0E0 | Moriarty Municipal | Unverified; high-altitude/PCN3 constraint |
| 16G | Seneca County | Unverified; 4000ft physical length, narrow margin |
| 1QK | Gove County | Unverified; 4000ft physical length and 60ft width |
| 2G9 | Somerset County | Unverified; primary paved runway; turf secondary excluded |
| 3F3 | C E Rusty Williams | Unverified; AirNav remarks say Jet A currently inoperative |
| 3LF | Litchfield Municipal | Unverified; primary 4002ft gross, short secondary |
| 3R4 | Hart | Unverified; 6000lb single-wheel limit |
| 3S4 | Illinois Valley | **Source-published LDA 4682ft both RW18 and RW36**, pending original FAA confirmation |
| 48S | Harlem | Unverified; consulted directory still on September cycle |
| 4A4 | Polk County/Cornelius Moore | Unverified; parachuting and runway loading checks |
| 5B2 | Saratoga County | Unverified; physical 4699ft, separate commercial permission |
| 64S | Prospect State | **Nominal RW02 3753ft, RW20 3755ft BELOW 1200m**; official LDA still unverified |
| 79J | South Alabama Regional | Unverified; military-contract fuel distinction |
| 8S1 | Polson | Unverified; 4194ft gross and runway-end obstacles |
| 9S5 | Three Forks | Unverified; 60ft width, 12000lb single-wheel limit |
| AAF | Apalachicola Regional | Unverified; consulted directory still on September cycle |
| ACZ | Wallace-Pender / legacy Henderson Field | Unverified; name reconciliation, marginal nominal pavement |
| ADG | Lenawee County | Unverified; older source cycle |
| ADT | Atwood/Rawlins County | Unverified; 12500lb wheel limit, no Jet A confirmed |
| AKO | Colorado Plains Regional | Unverified; worn threshold markings and high elevation |

## Four individual direction records added
| Airport | Landing direction | Gross ft | Displaced threshold ft | Nominal ft | Source-published LDA ft | Status |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 3S4 | RW18 | 4807 | 125 | 4682 | 4682 | Above minimum, primary revalidation pending |
| 3S4 | RW36 | 4807 | — | — | 4682 | Above minimum, primary revalidation pending |
| 64S | RW02 | 3986 | 233 | 3753 | Not verified | Below minimum nominal pavement |
| 64S | RW20 | 3986 | 231 | 3755 | Not verified | Below minimum nominal pavement |

The Phase 5 runway-direction table now supports `PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION` in addition to its prior screening statuses. A database CHECK still enforces `NOT_APPROVED`, and no prior runway evidence was overwritten. The 64S physical runway differs from Oregon's rounded 4000ft description; nominal landing pavement would still fail even using 4000ft.

## Sources and follow-up
- FAA NASR 01 Oct 2026 source catalog: https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/
- 3S4 FAA-derived airport source: https://www.airnav.com/airport/3S4
- 64S FAA-derived source: https://www.airnav.com/airport/64S
- Prospect Oregon state agency: https://www.oregon.gov/aviation/airports/Pages/prospect-64S.aspx
- 3F3 Jet A service remark: https://www.airnav.com/airport/3F3
- ACZ current name: https://www.airnav.com/airport/ACZ

For the other airports, corresponding official-cycle FAA-derived AirNav entries were checked at `https://www.airnav.com/airport/<FAA identifier>`; each specific full source URL and evidence note is saved in the Supabase record.

Next: Phase 5 Batch 4 should review the remaining 155 in small batches, pursuing official LDA evidence and preserving separate aircraft, permission, certification, NOTAM/weather and rescue gates. No airport may advance to gameplay on this report alone.
