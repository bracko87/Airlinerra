# Airlinerra mixed-use passenger/cargo capacity — 2026-11-06

## Problem and decision

The read-only Aircraft Library previously showed the *catalog passenger seats* and
the *maximum reported cargo payload* as if both maxima could always be loaded together.
That is false for quick-change and other combi variants. Conversely, commercial
passenger aircraft commonly carry freight in lower-deck holds after accounting for
passenger luggage, available mass, the equipment carried and airport handling.

The production project now has `airlinerra.aircraft_service_payload_game_v1`, a
separate, RLS-protected, **game-planning** data table keyed to every catalog
configuration. Source/certification values in
`airlinerra.aircraft_configurations` and the airport flight-eligibility screening
tables were **not rewritten**.

There are 235 raw configurations (231 active at time of research), including 11
combis, 140 passenger, and 84 dedicated cargo configurations. The new records
explicitly separate:
- `simultaneous_passenger_seats` — current gameplay mixed-mode seats for combis,
  unchanged catalog passenger seating for passenger-only aircraft, zero for freighters.
- `simultaneous_freight_kg` — supported cargo reference *for the same mixed layout*
  when evidence exists; NULL means not verified, **not zero**.
- `belly_hold_reference_kg` and `belly_hold_reference_type` — a lower-hold
  reference for passenger aircraft, never an unconditional freight offer.
- `seat_basis`, `capacity_note`, `evidence_url` — distinguish operator layouts
  from provisional game estimates.

## Active mixed-service passenger seats

| Config ID | Model/role | Game simultaneous seats | Mixed cargo reference (kg) | Basis |
|---|---|---:|---:|---|
| 125 | Antonov An-26B-100 Combi | 32 | unverified | game plan |
| 170 | Antonov An-74TK-100 Combi | 20 | 4,500 | historical mixed-mode reference, check before live use |
| 30 | Boeing 737-200C | 70 | unverified | game estimate; 112 full passenger seats cannot coincide with cargo-only ceiling |
| 31 | Boeing 737-300C | 80 | unverified | game estimate; 130 full passenger seats cannot coincide with cargo-only ceiling |
| 86 | Boeing 737-800 Combi | 90 | unverified | Air Inuit operator layout (5 main-deck pallets, total payload not guaranteed) |
| 196 | Boeing 757-200 Combi | 123 | unverified | provisional research |
| 188 | Boeing 737-400 Combi | 72 | unverified | provisional research |
| 59 | De Havilland Dash 8-100 Combi | 29 | 1,814 | Air Inuit 29-seat/4,000 lb layout; 21-seat mode can take more cargo |
| 89 | De Havilland Dash 8-300 Combi | 45 | 1,814 | Air Inuit 45-seat/4,000 lb separate aft cargo compartment |
| 180 | Saab 340A Quick Change/Combi | **24** | **unverified** | **game estimate**; 34 seats are passenger-only, not 34 seats + added main-deck freight |

Hidden catalog configuration #60 retains research reference 45 seats/1,814 kg
for preservation; it stays excluded from players via the catalog exclusions.

## Passenger aircraft belly freight

- Most commercial passenger jets and some turboprops can take cargo with checked
  bags in a lower/bulk hold. Availability depends on the installation, weight
  balance, fuel, operating route, security and handling. Do not interpret missing
  DB cargo kg as zero or assume freight capacity is unlimited.
- The following reference figures are operator-specific and **are not type limits**:
  Airbus A319-100 (#16) **500 kg**, A320-200 (#3) **1,000 kg**, A321XLR
  (#19) **1,134 kg**, from Qantas Freight's published full-passenger-load
  cargo equipment page.
- Saab 340A passenger (#172): **950 kg rear cargo hold structural limit
  including passenger baggage**, from EASA.A.068. It is not a 950 kg *extra*
  commercial freight allowance.
- Remaining passenger aircraft have belly eligibility/capacity **not yet
  verified**; none has a fabricated capacity inserted.
- In the UI, referenced kg are suffixed `*` with an explicit caveat.
  Unverified cases show `Hold unverified`, not zero or 'no cargo'.

Sources:
- https://www.airinuit.com/en/charter/fleet/de-havilland-dash-8-combi-100
- https://www.airinuit.com/en/charter/fleet/de-havilland-dash-8-combi-300
- https://www.airinuit.com/en/charter/fleet/boeing-737-800ng-combi
- https://freight.qantas.com/en-us/fleet/freight-fleet
- https://www.easa.europa.eu/en/downloads/7388/en
- https://www.faa.gov/lessons_learned/transport_airplane/accidents/ZS-SAS

## Future live-flight acceptance: NOT ENABLED

The aircraft library is a read-only planning screen, not an operational dispatch
permit or freight-sale endpoint. Before any route scheduling toggle for
'Accept freight' can be enabled, implement and test:

1. Select an aircraft's *actual installed configuration* and validate it on the
   date of the flight. Quick-change requires downtime/cost to reconfigure.
2. Passenger count × passenger+baggage weight; subtract booked checked baggage,
   fuel mass, crew and equipment when calculating remaining payload/weight.
3. Enforce aircraft type-specific main-deck and lower-hold compartment limits,
   center-of-gravity and gross weight (MTOW/MZFW/MLW) **at the same time**.
4. Enforce cargo dimensions, volume, loading equipment, dangerous goods/security
   rules, and airports' handling/service restrictions.
5. Ensure passenger fare and belly-freight revenue share the same airplane
   inventory and route economics without counting cargo as a free, separate load.
6. Treat provisional estimates as non-bookable until validated per airframe/flight,
   or explicitly authorize a fully fictional simulation rule.

Do not convert a sourced cargo-only maximum into a mixed-layout allowance.
Do not overwrite original manufacturer/certification information with planning
numbers. No changes to existing engine route, runway, safety release or economy
functions were authorized by this catalog correction.
