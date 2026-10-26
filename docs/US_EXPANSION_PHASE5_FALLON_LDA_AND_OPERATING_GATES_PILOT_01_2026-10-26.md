# Airlinerra — Phase 5 Operating-Eligibility Pilot 01 and Fallon LDA Clarification

**26 October 2026.** Completed in private Supabase project `hwllkabgzaynalahvkpz`, schema `airlinerra`; archived on GitHub `main`. The purpose is to develop **source-backed, strictly non-approving** operational evidence gates. This pilot does not introduce playable airports, grant commercial landing rights, or change Airlinerra's six airport categories.

## Independently audited completion

| Measure | Value |
| --- | ---: |
| Pilot airport research reviews saved | **6** |
| Distance-screen candidates among pilot | **5** |
| Partial declared-distance exception under review | **1: Fallon FLX** |
| Separate Fallon runway-direction clarification cases | **2: RW03 and RW21** |
| Pilot airport records with all operator/aircraft/permissions gates `NOT_VERIFIED` | **6 of 6** |
| Pilot/gameplay approvals | **0** |
| Entire Phase 5 cohort still `NOT_APPROVED` | **211 of 211** |
| Original runway-only airport cohort unchanged | **3,140** |
| World activations | **0** |

## Fallon Municipal (FLX) — no published LDA despite published takeoff distances

Fallon's FAA-derived record effective 01 October 2026 lists main RW03/21 **5,705 × 75ft GOOD asphalt**. Both RW03 and RW21 list **TORA 5,703ft and TODA 5,703ft**, while **source LDA remains NULL**. RW03 alone has a **102ft displaced threshold**. These fields are independently consistent with the FAA Chart Supplement page currently in effect, with publication date **03 September 2026, edition valid through 29 October 2026**. The separate RW13/31 is 3,581ft dirt and does not meet Airlinerra's paved-runway gate.

**Decision: keep `PARTIAL_DECLARED_DISTANCE_MANUAL_REVIEW`.** When *some* declared distances exist on the runway pair, the blanket no-declared-distance assumption is not applied under the existing conservative research rule. Neither 5,703ft TORA/TODA, 5,705ft gross nor calculated pavement may be entered as authenticated published LDA.

- [FAA-derived AirNav Oct 2026 airport entry](https://www.airnav.com/airport/FLX)
- [Current FAA Chart Supplement publication schedule](https://www.faa.gov/air_traffic/flight_info/aeronav/digital_products/dafd/)
- [Verbatim FAA Chart Supplement Southwest page 396](https://tallyaero.com/atlas/chart-supplement/SW_396/)
- [City of Fallon — official municipal airport ownership and contact](https://www.fallonnevada.gov/fallon-municipal-airport-flx/)

Two independent runway-end clarification rows are now stored, each requiring a **written FAA/airport-owner answer** before the ambiguity can be resolved. The municipality is identified for follow-up, but **no email, phone call or formal permission request has been sent and no response has been received**. The original FAA October NASR ZIP remains neither downloaded nor hash authenticated.

## Pilot candidates and the operational restrictions discovered

| FAA | Research runway | Type of distance evidence | Independent operations issue | Required next step |
| --- | --- | --- | --- | --- |
| **PRO** Perry Municipal, Iowa | RW14/32 5,500 × 100ft concrete | FAA AIM *assumed*, not published LDA | [Iowa DOT](https://opmapps.iowadot.gov/aviation/airports/PRO) says 5,500ft, while [City of Perry](https://www.perryia.org/perry-municipal-airport.html) still says 4,000ft; city advertises charter services but **does not identify a certified carrier for Airlinerra's hypothetical service** | Written city runway dimension reconciliation, owner approval, selected aircraft/operator, NOTAM and support |
| **RDK** Red Oak Municipal, Iowa | RW05/23 5,100 × 75ft concrete | RW05 *assumed* landing length 4,100ft after 1,000ft displaced threshold | [Iowa DOT](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=RDK) advertises Jet A/100LL. Winter closing of short turf 13/31 does not close main concrete 05/23 | Confirm permitted paid carrier usage, runway load and aircraft landing performance, fuel/ARFF, date NOTAM |
| **GWR** Gwinner/Roger Melroe Field, North Dakota | RW16/34 5,000 × 75ft concrete | AIM *assumed* only | [FAA Chart Supplement NC page 338](https://tallyaero.com/atlas/chart-supplement/NC_338/) describes airport as unattended with self-service fuel, wildlife and winter snow-removal confirmation. Only short turf RW06/24 has seasonal closure | Written operator/owner rules, named certified carrier, 75ft airframe/weight performance, flight-date snow/FICON and ground response |
| **HND** Henderson Executive, Nevada | RW17R/35L 6,501 × 100ft asphalt | AIM *assumed* only | [Airport official site](https://www.hnd.aero/) states airport 24h but FBO **05:00–22:30** and full-service Jet A **05:30–22:00**. Special-event PPR **Nov 17–23 and Dec 2–13, 2026**; Oct 16–23 PPR already expired by Oct26 | Nominate operator/aircraft/arrival date, obtain airport commercial access, ramp/Jet A agreement and valid event-specific PPR/NOTAM |
| **PAAQ** Palmer Municipal, Alaska (FAA `PAQ`) | RW16/34 6,006 × 100ft asphalt | **Published LDA:** RW16 5,506ft, RW34 6,006ft | [City of Palmer](https://www.palmerak.org/airport) advertises cargo/flightseeing charters, 24h fuel and ground support by arrangement, but no *specified Airlinerra carrier, operator certificate or written commercial approval*; source city physical 6,008ft differs from FAA 6,006ft | Certificated carrier/aircraft, signed city permission, winter operating assessment, confirmed fuel/rescue and flight-date clearance |

All five pilot candidates currently pass **only their initial distance research screen**. Relevant published fuel, FBO, city and DOT statements are retained as service observations, **not verified contracts**. In particular, a public-use designation, available charter service, a landing fee, or availability of Jet A does not substitute for rights to operate a specific passenger or cargo airline.

FAA [14 CFR Part 135 certification guidance](https://www.faa.gov/licenses_certificates/airline_certification/135_certification) and [DOT carrier-authority requirements](https://www.transportation.gov/policy/aviation-policy/licensing/US-carriers) distinguish appropriate air-carrier safety/operations authorization and economic authority from airport-owner permission. Applicable legal requirements depend on operation type, but none is evidenced for a named hypothetical operator in this pilot.

## Database controls

Two new **private, RLS-enabled** Supabase tables:

1. `airport_faa_declared_distance_clarifications`: two Fallon end records; LDA remains NULL; named authority response `false`; game admission constrained to `NOT_APPROVED`.
2. `airport_faa_operational_pilot_reviews`: six source-linked assessment rows, with distinct notes for runway evidence, owner rules, fuel/support, operational restrictions and next checks. Every one of six certificate/consent/aircraft/handling/flight-date/commercial gates is `NOT_VERIFIED`; **no operator, aircraft, flight date or permission agreement was invented**.

Both research tables deny `anon` and `authenticated` read and write rights. The existing 211 Phase 5 airport gate rows, 781 government runway-end records, initial decisions, and world activation remain unchanged.

## Reproducibility

- [Schema / restrictive admission safeguards](./sql/AIRLINERRA_PHASE5_FALLON_CLARIFICATION_AND_OPERATING_PILOT_01_SCHEMA_2026-10-26.sql)
- [All six operating review evidence records — SQL replay](./sql/AIRLINERRA_PHASE5_OPERATING_PILOT_01_SIX_AIRPORT_EVIDENCE_2026-10-26.sql)
- [Both Fallon declared-distance clarification end records — SQL replay](./sql/AIRLINERRA_PHASE5_FALLON_RUNWAY_03_21_LDA_CLARIFICATION_2026-10-26.sql)

## Next pilot engineering step

Create a reusable workflow for **named aircraft + named commercial operating entity + intended date**: evaluate the selected airplane's landing/takeoff performance and load/width against each airport runway; verify appropriate operator and route authorization and the owner's signed paid-use rights; validate airport-specific NOTAM/FICON/weather and service capacity on the operating date. Expand the pilot only when those input records and verifiable authority exist; leave unknowns unknown.

**Status: six evidence-grounded pilot reviews completed, Fallon LDA unresolved, all 211 airports still blocked from gameplay.**
