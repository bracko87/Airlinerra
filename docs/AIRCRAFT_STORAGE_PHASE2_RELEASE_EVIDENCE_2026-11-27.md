# Phase 2 storage-only operational evidence — 2026-11-27

Review only. No production activation. The Phase 1 read-only preflight returned GAME_SOURCE_MATCHED_REVIEW_REQUIRED for ASP, LDE and ROW, with approval_granted=false in every row.

## Current game registry audit

| Airport | Registry key | ICAO ident / GPS code | Commercial operational authorization | Game reference profile |
|---|---|---|---|---|
| Teruel | OURAIRPORTS:316427 | LETL / LETL | false | Not installed |
| Victorville | OURAIRPORTS:21315 | KVCV / KVCV | false | Not installed |

Both unified rows have dispatch_eligible_by_airport_admission=true but operationally_authorized=false. The former flag alone does not authorize commercial operation. Do not alter either field in a storage-only release. Reuse the existing registry keys.

## Teruel

Primary source: ENAIRE AD 2-LETL, effective 6 August 2026, https://aip.enaire.es/AIP/contenido_AIP/AD/AD2/LETL/LE_AD_2_LETL_en.html

- Field elevation 1026 m; asphalt runway width 45 m. Declared takeoff distances differ by direction (2539 and 2825 m); both landing distances are 2539 m. Adopt the conservative existing candidate length of 2539 m for game review.
- Public-use operating schedule is weekdays excluding regional holidays, 0630–1630 UTC summer and 0800–1600 UTC winter. Outside normal periods prior coordination is required. Restricted-use hours differ. Fuel and handling are tied to operating hours.
- Airport publishes Jet A-1 service: https://aeropuertodeteruel.com/en/flight-operations/charges-and-handling
- Published access coordination: https://aeropuertodeteruel.com/en/flight-operations/technical-information
- Storage operator: https://tarmacaerosave.aero/our-sites/

Block final profile approval until the game can represent the reviewed service schedule and permission exceptions, or a narrower explicit game-only operating policy is accepted and enforced. The existing daily curfew boolean alone does not model weekdays, seasonal hours, holidays or prior permission. Do not encode known restrictions as unknown/no restrictions. Elevation multiplier and aircraft width policy require explicit game review.

## Victorville

Primary source: https://www.victorvilleca.gov/Government/City-Departments/Airport/For-Pilots

- Runway 17/35: 3978 m, 150 ft (45.72 m), mixed asphalt/concrete. Equal declared distances in each direction. Retain candidate length/width. Runway-end elevation around 2822–2885 ft.
- Public-use airport, around-the-clock operations contact and baseline rescue service. Enhanced rescue service requires advance coordination; published FBO hours 0600–2200 local. International arrivals may need landing rights/customs coordination. Do not infer unrestricted fuel service from the airport contact hours.
- Jet A listed: https://www.airnav.com/airport/KVCV
- Storage operator reference: https://www.comav.com/facilities/

Block final profile approval until service-hour limitations and known access conditions are represented by an explicitly reviewed game policy. Elevation multiplier and aircraft-specific width policy require review. Mixed asphalt/concrete, not synthetic concrete-only test data.

## Shared game rules and next action

Rates USD 4000/8000/15000 monthly; storage occupancy and duration unlimited. Existing proposed per-direction movement limits are game scheduling limits, not real measured throughput. No commercial rights, passenger demand, or route access. Do not seed synthetic evidence from acceptance tests into production. Preserve safety of already-departed flights when admission changes.

Next: add storage-only service availability/permission policy acceptance coverage, with missing/changed policy blocking new bookings and departures. Final profile approval must compare that policy to the reviewed evidence. Use an explicit game-only policy for simplifying real airport restrictions, never claim real flight clearance.
