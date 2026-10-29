# World 1 (3,141 approved airports): ICAO code research, 29 October 2026

**Audit:** 3,125 ICAO codes already source-reported but not independently authoritative; 16 with no ICAO in source. Review all 16 below, but keep `icao_reported` NULL until authoritative proof. A local, national, GPS, FAA, four-character or historical identifier must NOT be automatically promoted to a current ICAO Doc 7910 location indicator.

## Database status after research
- New private `airlinerra_game.airport_identifier_resolution` table: exactly 16 ICAO research cases, with candidate/local/historical classification, source URLs and notes.
- Related records in `airlinerra_game.airport_identity_geography_audit` and `airport_data_work_queue` set to researching (only these 16). No profile code, approved roster, costs, flight permissions or public access changed.
- Resolution summary: 7 disputed/possible candidates, 4 documented local/national identifiers, 2 requiring additional research, 1 historical identifier, 1 reassigned identifier, 1 fictional owner-defined code.
- **Current source-reporting count is still 3,125/3,141**, not 3,141/3,141; not every airport should have a genuine ICAO code.

| Country | Airport | Current source/local ID or possible ICAO | State | Follow-up |
|---|---|---|---|---|
| AR | Aeródromo Estancia Don Panos | SA10 (GPS/source); PDP (local) | National/local only reported | Argentina AIS/ANAC AIP, no supported four-letter ICAO yet |
| CA | La Romaine | CTT5 (TC LID), ZGS (IATA) | Local only reported | NAV CANADA CFS/AIP to establish no Doc7910 ICAO |
| CA | Streatham Reef Hueston | CRHA | Need research | NAV CANADA aerodrome list and CFS status |
| CA | Trail Regional | CAD4 (TC LID), YZZ (IATA) | Local only reported | CAPA lists ICAO n/a; NAV CANADA CFS cross-check |
| ID | Old Nabire | WABI **reassigned to Douw Aturure** | Reassigned; must not reuse | Indonesian DGCA / AIP; old site's active status separately review |
| ID | Tabing | WIMG historical | Historical; do not assume current | Indonesia eAIP / military-only access confirmation |
| MX | Campo Cuatro Milpas | MM52 | Possible ICAO candidate | Current Mexico AFAC / AIP verification |
| MX | Cedros (Mazapil) | MX-0203, CED local | No ICAO candidate identified | Mexican official aerodrome register |
| RS | Aleksandrovo Airport (fictional) | LYAL owner-defined | Fictional, not ICAO-issued | Preserve fictional label and no fake allocation |
| RU | Kirovsk-Apatity | ULMK | **Disputed** | OurAirports expressly removed ULMK as an ICAO code; ICAO Doc7910 / Russian AIP needed |
| RU | Motygino | UNIM | Possible but unverified | Source lists GPS UNIM; current Russia AIP needed |
| RU | Nogliki | UHSN | **Disputed** | OurAirports removed 2026-07-24; some aviation directories still label ICAO |
| RU | Solovki | ULAS | Disputed | Airmate calls it ICAO, other sources do not; official allocation needed |
| RU | Srednekolymsk | UESK | Disputed | Aviation directories list ICAO, others list local/reference only |
| US | Lajitas International | FAA T89 (KT89 on FAA procedures) | Possible, not verified ICAO | FAA chart does not prove ICAO Doc7910 allocation |
| US | Roche Harbor land airport | FAA WA09 | Local only | WA09 from FAA/airport operator; IATA RCE may reference the separate seaplane base |

## Important evidence

- Official canonical source: [ICAO Location Indicators, Doc 7910 and ICAO Data Service](https://www.icao.int/operational-safety/Designators-and-indicators); [Doc7910 API](https://www.icao.int/api-data-service) requires appropriate access. The correct way to mark verified is to match exact airport to Doc7910, or authority's AIP.
- [NAV CANADA AIP](https://www.navcanada.ca/en/aeronautical-information/aip-canada.aspx) and [Canada Flight Supplement](https://products.navcanada.ca/shop-vfr/Canada-Flight-Supplement/) for Canadian national location IDs. [Trail industry profile](https://centreforaviation.com/data/profiles/airports/trail-regional-airport-yzz) ICAO n/a.
- [FAA Lajitas instrument procedures](https://www.faa.gov/AIR_TRAFFIC/FLIGHT_INFO/AERONAV/PROCEDURES/application/index.cfm?event=procedure.results&nasrId=T89) display T89 (KT89). [Roche Harbor operator](https://www.rocheharbor.com/airport/) confirms land airport WA09. Cross-check any RCE IATA claims against [IATA code directory](https://www.iata.org/en/publications/directories/code-search/?airport.search=rce) to avoid seaplane/base mix-up.
- [Indonesia Directorate General of Civil Aviation Douw Aturure](https://hubud.kemenhub.go.id/bandara/502) confirms WABI/NBX now belong to the new airport. [Old Nabire change history](https://ourairports.com/airports/ID-0339/changes.html) explicitly documents the move.
- [Tabing historical WIMG](https://www.faa.gov/air_traffic/publications/ifim/country_info/PDF/ID.pdf) is not current civilian access certification.
- [Campo Cuatro Milpas MM52 reference](https://en.wikipedia.org/wiki/Campo_Cuatro_Milpas_Airport) is secondary and needs AFAC/AIP confirmation.
- [Kirovsk ULMK data change](https://ourairports.com/airports/RU-10046/changes.html) and [Nogliki UHSN data change](https://ourairports.com/airports/UHSN/changes.html) explicitly record removal of those codes from the ICAO field. [Solovki ULAS Airmate](https://www.airmate.aero/?code=ULAS&lang=en&page=airport_page) and [Srednekolymsk alternative directory](https://bizjetjournal.com/airports/uesk) show conflicts.

## ICAO field acceptance criteria (GREEN)

Two independent checks:
1. **Source reporting audit**: a code value is present, or a credible authority expressly confirms there is no allocated ICAO indicator. A code appearing only in a game source is source-reported, not independently verified.
2. **Authority verification**: exact facility matched to current Doc7910 / official state AIP/registry; distinguish current, historical, local, reallocated and fictional identifiers. Only then update the canonical `icao_reported` and record verified source/date, or mark `authority_verified_unassigned` and keep ICAO NULL.

**Next missing field once these are dispositioned:** IATA (30 not reported). Do not mix IATA assignments of seaplane vs land airports. 
