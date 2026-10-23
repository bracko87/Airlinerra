# Airlinerra — U.S. operator and aircraft eligibility gates, Phase 2 (2026-10-23)

## Verified starting position
All **50** exact FAA Part 139 crosswalk airports have a source URL, review timestamp and remain NOT_APPROVED in Supabase. This is desk-research coverage, **not 50 commercially cleared airports**. Existing six game categories and original 3,140 airports are unchanged.

## Operator registry
FAA official operator+aircraft register: https://www.faa.gov/about/officeorg/headquartersoffices/avs/faa-certificated-aircraft-operators-legal-part-135-holders
The FAA describes its spreadsheet and AVInfo operator search as weekly updated. Look up **specific named operator and aircraft registration**. If not listed or ambiguous, obtain operator certificate and contact FAA FSDO. An airport's promotional charter listing is not enough. NATA reported March 2026 data-integrity issues in the FAA source; preserve the snapshot date and verify independently: https://nata.aero/faas-part-135-operators-and-aircraft-list-temporarily-offline-for-data-corrections/.

## Specific Phase 2 prioritized airports (live Supabase first-pass runway data)

| FAA | Runway length m | Width m | Surface | Condition | Need |
|---|---:|---:|---|---|---|
| YIP | 2299.1 | 45.7 | Concrete | Good | Confirm Kalitta/USA Jet operator authority, actual cargo aircraft and load compatibility |
| GYH | 2438.4 | 45.7 | Concrete | Good | Identify particular charter/cargo AOC/Part135 operators and airport agreements |
| PTK | 1987.6 | 45.7 | Asphalt | Excellent | Validate specific active charter operators and aircraft |
| RDG | 1935.5 | 45.7 | Asphalt | Good | Validate Part135 charter and cargo-handling operations individually |
| GON | 1524.0 | 45.7 | Asphalt | Good | Validate Action Airlines Part135 legal operator, fleet N-numbers and runway constraints |
| CIC | 2049.5 | 45.7 | Asphalt | Good | Reconcile FAA inactive certificate with airport claims and specific charter certificate |

## Required approval gates
1. Airport physical status, runway operational/not closed, pavement and load rating as distinct facts.
2. Operator certificate and authority for the **service type**: Part 135 small charter, Part 121 scheduled passenger, cargo authority as applicable. Note Part 135 is not a general cargo approval.
3. Aircraft-specific operating authority, fleet tail number or model under valid operations specifications; aircraft performance including runway length/width/strength and local elevation/obstacles/weather.
4. Airport owner/operator permission, facilities, customs/security, passenger/cargo hours and local restrictions.
5. Document dated URLs, scope and confidence before marking service verified. Only after independent signoff may game admission change.

## Database action
On 2026-10-23, updated `next_action` for six prioritized expansion airports in private `airlinerra.airport_commercial_verification`. All six remain `game_admission_status=NOT_APPROVED` and `aircraft_compatibility_verification=NOT_CHECKED`. No activation or category changes.

## Open tasks
Obtain FAA Part135 weekly operator-aircraft data, match identified names for YIP, GYH, PTK, RDG, GON; check certification discrepancy at CIC. Add dedicated operator/airframe authorization evidence model only when a grounded operator-aircraft record is established; avoid implying authorization from airport-only evidence. Afterwards systematically process the other 44, and separately screen 1,879 airports not on Part139 roster.
