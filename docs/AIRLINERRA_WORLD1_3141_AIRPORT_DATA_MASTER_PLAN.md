# Airlinerra — Complete Airport Data Master Plan, World 1 (3,141 airports)

Date: 29 October 2026. **Airport master-data collection takes priority over further live route creation or flight-engine activation.**

## Non-negotiable rules

1. The World 1 approved pool `airlinerra_game.approved_game_airports` (3,141) is the **only eligible roster**; do not admit unapproved airports via new source imports.
2. Preserve the exact **six** canonical categories: **Local, Regional, Medium, Large, Major Hub, Mega Hub**. No four-category fallback. Existing categories are **provisional**, not signed-off final.
3. Distinguish **source-reported**, **verified factual**, **owner-approved simulation/model values**, and **unknown**. Never promote an old runway observation into a confirmed open runway; never imply a game-derived slot count is a published coordinator allocation.
4. A missing figure means `NULL` / data pending, **not zero**. Zero means a source explicitly establishes absence.
5. Every independently collected claim needs source identity, retrieval/effective date, license/terms, reviewer and revision history. Conflicts must be queued, not silently overwritten.
6. Airport key + world ID uniquely identify each airport; airport codes may change and are not primary keys. Do not confuse airport IATA/ICAO codes with airline/company codes.
7. A single fictional approved airport (Aleksandrovo LYAL) must carry an explicit `fictional` marker. Its coordinates, runways and capacity cannot be taken from a real airport or invented without an owner-approved game design.
8. Original game production finances, approvals, user profiles and public registration must remain unchanged by research imports.
9. Do not enable commercial routes, slot assignment, airline stations, hub fees or live flights during this research foundation stage.

## Complete per-airport field inventory

**A. Identity, geographic location, and locale (baseline, P0)**

| Field / family | Notes | Preferred evidence |
|---|---|---|
| World ID and stable approved airport key | Foreign key, non-reusable | Approved game roster |
| Official and display names, former names, local language names, aliases | Store original spelling where available | Airport operator / AIP / OurAirports |
| Source airport IDs and historical identifiers | Track stable OurAirports ID, registry ID, dataset version | OurAirports / existing registry |
| ICAO aerodrome location indicator | Not all airports have one; verify | AIP / authority / ICAO |
| IATA 3-letter location code | May legitimately be absent; IATA coding must not be invented | IATA / airport / source cross-check |
| GPS identifier and national/local/FAA location code | Distinguish from ICAO | Authority, OurAirports |
| Country ISO code, political grouping for game, region/province | ISO/approved game country mapping | Official / reference registry |
| Municipality where located, served city/catchment city | These are different; store both | Airport / municipality |
| Latitude, longitude, geographical datum | WGS84 decimal degrees, source uncertainty | Official AIP / OurAirports |
| Airport reference elevation (feet/metres) | Convert units with stated source | Official AIP / OurAirports |
| IANA time zone name, UTC offset derived by date, DST rule | Never hard-code today's UTC offset for future schedules | Trusted geographic time-zone boundary + IANA tzdb; verify |
| Geographic characteristics | City/region names, terrain/elevation restrictions where grounded | AIP / mapping source |
| Website and operator ownership | Airport operator, country agency, links | Official operator |
| Airport status | Open/closed/military-only/civilian access, date of restriction | AIP, NOT historical existence |
| **Six-class game category** | Provisional + approved final stored separately | Owner-approved classification and evidence |
| Real/fictional airport marker | Fictional airports cannot inherit real airport facts | Approved game roster |

**B. Physical runway inventory (one row per runway, P0)**

| Field / family | Notes |
|---|---|
| Stable source runway ID, airport key | Multiple runways for each airport |
| Runway pair/designators and both ends | e.g. 12L/30R, both thresholds |
| Surface length and width, metres | Preserve source units/precision |
| Surface material, raw and normalized | Asphalt, concrete, mixed, grass, gravel, etc.; **do not treat all as paved** |
| Runway end coordinates, bearings, magnetic heading | When source supports |
| Runway lights and approach lights | Distinguish yes/no/unknown |
| Runway declared distances by direction | TORA, TODA, ASDA, LDA; **not equal to physical length by default** |
| Runway/threshold displacement, slope, obstacle limits | Direction-specific constraints |
| Pavement strength, PCN/PCR and wheel/load restrictions | Only if authoritative |
| ILS/GNSS/VOR approach and CAT certification | Per runway direction, not generalized per airport |
| Runway operational status, closures, restrictions, civil/commercial use | Source effective dates and updates |
| Counts by surface and by operational availability | Derive only from sufficiently verified runway rows |
| Longest qualifying runway | Historical baseline can be displayed with clear status |

**C. Terminals, gates, parking and ground infrastructure (P1)**

| Field / family | Notes |
|---|---|
| Passenger terminal count and identity | Some airports have no traditional terminal |
| Cargo terminals and cargo handling capability | Not inferred from size |
| Passenger boarding gate count | Physical passenger gates, not aircraft parking positions |
| Contact gates with jet bridges | Separate jet-bridge count |
| Remote boarding gates / bus boarding points | Separate from aircraft stands |
| Aircraft stands / parking positions by type | Narrowbody, widebody, turboprop, cargo, remote |
| Apron and taxiway limitations | Airport geometry and verified restrictions |
| Hangars and maintenance space | Capacity and maintenance capability |
| Ground handlers and available services | Contract/services vs physical capacity |
| Check-in, immigration, customs, border control, security | Attributes may be unknown, conditional or seasonal |
| Fuel availability and grades | Operator/source required |
| Catering, cargo refrigeration, dangerous-goods restrictions | Needed for future services |
| Fire/rescue (ARFF/RFFS) category | AIP/operator |
| Ground-side transport/road/rail access | Useful for passenger market model |

**D. Operating rules and true airport capacity (P0–P1)**

| Field / family | Notes |
|---|---|
| Official aerodrome operating hours | Day/season-specific; local + UTC time zones |
| Curfew, night restrictions and noise controls | Separate from airport opening hours |
| Weather approach minima and other restrictions | No universal assumptions |
| Civil/international/charter/cargo access permissions | Legally relevant, independently sourced |
| Slot coordination **Level 1, 2 or 3** | Industry coordination levels, **not** the game’s six airport classes |
| Source-declared movements per hour/day | Arrival, departure and combined limits separately |
| Published terminal/passenger/stand capacity | Must use named source + time period |
| Coordinator slots and seasonal slot windows | Not the same as current actual flights |
| Existing airport peak capacity constraints | Regulatory, runway, terminal, stand and ground limitations |
| Independent game capacity / slots per period | Future approved model; stored separately from official published numbers |
| Temporary closures and seasonal scheduling constraints | Start/end effective date |

**E. Historical passenger, cargo and aircraft traffic (P1–P2)**

| Field / family | Notes |
|---|---|
| Actual annual/monthly passengers | Total, domestic and international where reported |
| Cargo tonnage | Total, domestic/international, inbound/outbound as available |
| Airport aircraft movements | Total and commercial, avoid conflating flights with passengers |
| Scheduled vs charter traffic | Where official reporting distinguishes |
| Seasonal variability | Only if observed historically |
| Most recent reported year and older baseline years | Record year, publication date and scope |
| Existing route/destination traffic | May be confidential; use only legitimately available sources |
| Source coverage and reporting notes | Different authorities use different definitions |
| Game baseline demand per airport | Future model, **not** reported real traffic |
| Game origin-destination passenger/cargo demand by route | Requires named model version and inputs |
| Future demand drivers | Population, GDP, tourism, economic flows, competition, intermodal access |

**F. Airfield economics and service charges (P2)**

| Field / family | Notes |
|---|---|
| Landing charges per aircraft MTOW and aircraft class | Official tariffs / effective dates |
| Parking and stand usage / terminal charges | Duration and type |
| Passenger service charges, taxes and security charges | Country and airport-specific |
| Cargo/ground handling, fueling, de-icing, firefighting charges | Each separately |
| Currency, effective dates, tariff documents | No invented rates |
| Airlinerra hub/station opening and monthly fees | **Owner-approved game prices, separate from real tariffs** |
| Proposed operational handling/turnaround fees | Derived later from rules and verified game model |

**G. Source provenance and confidence (mandatory for all above)**

Every material field or dataset must retain source publisher/authority, title/URL, published/effective date, retrieved date, original unit, license, original reported value, normalized value, version/snapshot hash when available, reviewer, review status, conflicting alternative claims and notes. Use `airport_field_evidence`; it must not directly activate unverified values in the operational model.

## What existed before this migration

- 3,141 approved World 1 airports; names/countries/catalog codes for all.
- 3,140 source coordinates, longest qualifying runway summaries; one approved **fictional** airport lacks real coordinates.
- 3,141 **provisional** six-class game categories; **zero** final owner-approved category records.
- 3,089 municipalities reported, 52 absent.
- 3,125 ICAO, 3,111 IATA, 3,134 GPS reported code entries, all marked **UNVERIFIED** in the existing code register.
- 3,917 historical runway observations across 3,100 airports, all with unverified operational status; missing runway source observations must not be interpreted as zero real runways.
- No official airport slot allocations, verified time-zone IDs, terminal/gate inventory or comprehensive passenger/cargo demand coverage in the current private game roster.

## Database foundation now installed

Migration: `supabase/migrations/20261029181500_airlinerra_airport_data_foundation.sql`.

Eight server-owned tables under private schema `airlinerra_game`:
1. `airport_reference_profiles`: one source-backed approved profile per airport; reported codes, location, provisional category, absent facts nullable.
2. `airport_runway_inventory`: one historical runway observation per source runway ID, explicit `historical_unverified` and `unknown` operational status.
3. `airport_facilities`: one blank/unknown infrastructure placeholder per approved airport.
4. `airport_capacity_observations`: future published/declared coordination, seasonal capacity and research estimates, with source/review.
5. `airport_traffic_observations`: separately sourced actual annual/monthly passenger/cargo/movement counts.
6. `airport_market_demand_models`: future versioned *simulated* origin-destination demand, never labelled measured.
7. `airport_field_evidence`: per-field source citations and review history.
8. `airport_data_work_queue`: seven source verification workstreams per airport.

Backfill: **3,141 profile rows; 3,917 historical runway rows; 3,141 facilities placeholders; 21,987 tracking work items**. Capacity, traffic and OD model tables intentionally empty pending real collection.

All new tables have RLS enabled and no direct `anon`/`authenticated` data access. None of the existing approval, airline, balance or ledger records were edited.

## Collection workflow

**Stage 1: audit / reconcile** (current). Stable approved pool, reported codes and coordinates, provisional categories, historical runways stored; map missing facts and conflicts. Do not collapse `unknown` to zero.

**Stage 2: reference enrichment, for all airports**. Pull current OurAirports airport and runway snapshots using stable source ID, geospatial/timezone data with checked license, and authority sources for code/airport operating status. Reconcile codes, municipality, time zone, elevation, real/fictional classification; capture license + snapshots. Explicitly flag records without legitimate ICAO/IATA codes.

**Stage 3: runway validation**. Recheck all 3,100 airports with observations plus the 41 without them; identify runway count/surfaces, actual open runway directions, aircraft eligibility, source evidence. Refresh coordinates and condition dates. Historical rows remain research until verified.

**Stage 4: airports' infrastructure and legal limits**. Research gates, stands, terminals, aprons, fire/rescue, operating hours, night restrictions, cargo availability and declared hourly capacity. Use national aeronautical information publications, airport operators and slot coordinators where possible. Where global official data is unavailable, explicitly mark `not published` and defer to an **owner-reviewed game modelling policy**; do not manufacture a real-world number.

**Stage 5: real traffic and demand inputs**. Import separately sourced annual/monthly official passenger, cargo and aircraft movement statistics; record definitions and year. Derive game-specific seasonality and O/D demand only after the modelling rules are approved, always identifying simulation outputs.

**Stage 6: category approval and operating-model gate**. Review all six canonical categories, finish owner-approved capacity model and representative operating constraints. Produce a comprehensive airport data readiness matrix; only then begin operational routes, traffic, scheduling and slot allocation.

### Minimum acceptance before the *real route engine*

- 3,141 / 3,141 reference profiles, with explicitly resolved identity and location/time-zone status, or justified fictional/no-code exceptions.
- Approved six-category mapping for all 3,141; no implicit promotion of the provisional classification.
- A clearly sourced or owner-approved simulation policy for runways, eligibility and operating windows (including unknowns).
- A source-backed declared-capacity value **or** separately labelled approved game capacity model for eligible airports. Demand cannot equal capacity by assumption.
- A versioned model for passenger/cargo demand, with actual measured traffic kept distinct.
- No route or airport office enabled solely because a draft or an unverified source row exists.
- UI reads private, bounded owner-authorized profile data; no raw research tables or privileged keys in browser.

## Research source starting points

- OurAirports public-domain airports/runways/regions/navaids: https://ourairports.com/data/ and https://ourairports.com/help/data-dictionary.html . **Source reports are not aeronautical operating authorization**.
- National AIP/official aeronautical authorities for runways, restrictions, operating status and airspace.
- IATA slot coordination: https://www.iata.org/en/programs/ops-infra/slots/ and coordinated-airport levels https://www.iata.org/en/programs/ops-infra/slots/coordinated-airports/ .
- Airport operators, slot coordinators, transport regulators, FAA data and national statistics offices for gate/stand/capacity and passenger/cargo totals. Respect licensing and refresh terms.
- Geographic time zone boundary sources with a reviewed redistribution license; IANA zone IDs for schedule calculations.
- Mapping evidence such as OSM may supplement infrastructure research, but incomplete OSM gate tags are **not** proof of a 0-gate airport. Check ODbL obligations before commercial reuse.

**This foundation does not mean all facts have been collected or verified.** It prepares the research, provenance and validation framework to complete that work safely.
