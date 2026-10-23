# Airlinerra: US commercial suitability review (23 October 2026)

This is a **second-stage triage** of all 2,077 US Local/Regional candidates from the successful FAA NASR October 1, 2026 audit. It does not approve airline service or activate airports.

| FAA evidence / stage | Candidates |
| --- | ---: |
| FAA open/public-use and >=1,200m asphalt/concrete — small-aircraft commercial **research candidates** | 1,929 |
| Nonpublic/private-use access hold | 115 |
| FAA no qualifying paved 1,200m runway | 13 |
| Airport not open | 1 |
| FAA identity match unresolved | 19 |
| **Total** | **2,077** |

Within the 1,929 physical/public-use candidates: **1,407 Local** and **522 Regional** by their *old provisional* categories.

## Commercial model: not all aircraft are equivalent

- Public general-aviation airports can support **small charter operations**; Part 139 does not universally apply to these operations. This is not a claim that a particular airport has approved a particular operator.
- Under 14 CFR 139.1, scheduled air-carrier passenger operations with **more than 9 seats** generally invoke Part 139 airport certification; unscheduled air-carrier passenger aircraft with **at least 31 seats** generally also invoke it, subject to legal exceptions such as Alaska.
- Scheduled ATR 42 flights are therefore **not automatically allowed** at the 1,929 sites. Class I Part 139 review, certified aircraft performance, operational permissions and the actual transport plan are necessary. No flight frequency or revenue is assumed.
- Low-volume small-aircraft charter / tourist air taxi or light cargo may be a realistic design case but **operator permission is still unverified**.
- All 2,077 remain **NOT ACTIVE / owner approval NOT GRANTED**.

Official context: [FAA Part 139 airports affected](https://www.faa.gov/airports/airport_safety/part139_cert/airports-affected), [FAA classes](https://www.faa.gov/airports/airport_safety/part139_cert/classes-of-airports), [FAA NASR](https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/).

## Findings requiring targeted correction

- **17** physical/public-use candidates have a different preliminary runway-length tier under current FAA data versus the old source tier. Do **not** automatically reclassify them; some master values represent a different runway than the FAA longest runway, or the source airport type may be a higher tier.
- **38** FAA-passing candidates differ by at least 100m in recorded runway length; 26 differ by >=250m. Verify physical runway, dates and what runway each record represents. Source discrepancy is not proof of incorrect airport identity.
- **2** FAA-vs-source state/geographic-code discrepancies need review; border-area airport jurisdictions may legitimately differ.
- **2058** sites have a matched *official FAA local location identifier*, including **69** with no source GPS/ICAO/IATA code in the earlier dataset. These codes should be stored as `verified_faa_local_identifier`, never backfilled as official IATA/ICAO identifiers.
- FAA source-verified runway width is present for **1929** of the physical-pass airports (reference longest qualifying FAA runway), which can support later **game planning** but is not an aircraft-specific takeoff/landing approval.

## Outputs and next research

- [us_commercial_suitability_2077.csv](us_commercial_suitability_2077.csv): one row per candidate, all aircraft-service review tracks.
- [us_commercial_hold_cases_148.csv](us_commercial_hold_cases_148.csv): the 148 blocked airport exceptions for case-by-case access/runway/identity investigation.
- [us_commercial_suitability_summary.json](us_commercial_suitability_summary.json): automated counts and regulatory assumptions.

**Next:** Independently check Part 139 certificate class for any proposed scheduled service with >=10 passenger seats, airport operator-specific commercial permissions, access/operating hours and aircraft performance. In particular, do not treat occasional small aircraft charter as equivalent to ATR 42 scheduled flights. Resolve 148 held cases separately before moving them to the physical-pass pool.

Six-tier hierarchy, 3,140 original airports, 8,153 master and gameplay states remain unchanged.
