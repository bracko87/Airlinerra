# Airlinerra — Batch 30 Airport Source Research (2026-10-23)

**COMPLETED AND VERIFIED: 50 / 50 individual airport-source reviews saved to Supabase.**

The Batch 30 selection contains **50 previously unreviewed FAA-matched expansion candidates**. An individual airport-specific public owner, airport operator, state aviation, or FAA-derived source was checked for each. This is a first source research pass, not verification of scheduled airline or licensed charter/cargo operating rights.

## Database recovery checkpoint
- Prior aggregate verified after Batch 29: **643/1929** individually source-reviewed.
- **50** distinct airport codes saved using conditional updates to `airlinerra.airport_commercial_verification` (project `hwllkabgzaynalahvkpz`).
- The **30 records previously marked PENDING** were subsequently saved in three batches of 10. Supabase independently confirmed `batch30=50`.
- Verified aggregate read-back confirms **693/1,929** reviewed and **1,236** still unreviewed; **0** game admissions have changed.
- Identifiers must be matched using BOTH FAA code and FAA state, with `independent_review_at IS NULL`; do not duplicate source rows on recovery.

## Material findings requiring consideration
- **1M4 Posey Field**: FAA says weekend fuel unavailable except by prior approval; cracks and vegetation on ramp. https://www.airnav.com/airport/1M4
- **L08 Borrego Valley**: Oct19–25 2026 aerobatic-airspace NOTAM and parachute operations; no on-field airframe repair. https://www.iflightplanner.com/Airports/L08
- **E14 Ohkay Owingeh**: Tribal council-owned public airfield at about 5760ft elevation, unattended, main gate locked; specific commercial access not established. https://www.airnav.com/airport/E14
- **SXU Santa Rosa Route 66**: unattended at ~4792ft, 5013ft asphalt, reported 12.5k single wheel load; berm near runway end. https://www.airnav.com/airport/SXU
- **K24 Russell County**: 5010ft paved runway and 24h fuel; notice says RWY17 PAPI unserviceable into 2027. https://www.iflightplanner.com/Airports/K24
- **AFJ Washington County PA**: PennDOT lists on-field **Air Charter Services** among FBOs; named charter qualification remains pending. https://www.pa.gov/agencies/penndot/traveling-in-pa/airports/washington-county-airport
- **TRL Terrell**: City explicitly counts **air taxi** among airport flight activity. This does not prove a specific scheduled airline. https://www.terrelltx.gov/753/Terrell-Municipal-Airport
- **VGT North Las Vegas**: operator requires special-event **prior permission** on Oct16–23, 2026 and later listed major events; controlled Class D beneath Las Vegas Class B. https://vgt.aero/
- **CTY Cross City**: primary runway rated excellent; secondary runway fair with poor/faded markings, not interchangeable for aircraft performance. https://www.airnav.com/airport/CTY
- **VNW Van Wert County**: FAA reports only **8.0 single-wheel bearing** at 5005ft runway; must account for aircraft weight. https://www.airnav.com/airport/VNW
- **EBA Elbert County**: 100LL only, no repairs, nearby trees and rising terrain. https://www.airnav.com/airport/EBA
- **GDK Greene County/Lewis A Jackson**: FAA identifier now GDK, **formerly I19**, so avoid creating duplicate airports. https://www.airnav.com/airport/GDK

## Individual ledger
| FAA | State | First-pass evidence category | Public airport-specific source | Supabase |
|---|---|---|---|---|
| SXU | NM | HIGH_ALTITUDE_UNATTENDED | [Source](https://www.airnav.com/airport/SXU) | SAVED |
| AZE | GA | GA_FUEL_WEIGHT_LIMIT | [Source](https://www.hazlehurstga.gov/hazlehurst-municipal-airport) | SAVED |
| MNZ | TX | CITY_GA_FUEL | [Source](https://www.hamiltontexas.com/149/Airport) | SAVED |
| L08 | CA | AEROBATIC_PARACHUTE | [Source](https://www.iflightplanner.com/Airports/L08) | SAVED |
| JCA | GA | GA_COUNTY | [Source](https://jacksoncountygov.com/149/Airport) | SAVED |
| CRT | AR | STATE_GA | [Source](https://fly.arkansas.gov/crossett.html) | SAVED |
| DLL | WI | FBO_LISTED | [Source](https://www.lakedeltonwi.gov/166/Baraboo-Dells-Airport) | SAVED |
| EMV | VA | REGIONAL_BUSINESS_GA | [Source](https://www.flyemv.net/airport-info) | SAVED |
| K24 | KY | RUNWAY_PAPI_UNSERVICEABLE | [Source](https://www.iflightplanner.com/Airports/K24) | SAVED |
| MAW | MO | JET_A_CALL_AHEAD | [Source](https://airnav.com/airport/maw) | SAVED |
| OSX | MS | UNATTENDED_AIRPORT | [Source](https://www.airnav.com/airport/OSX) | SAVED |
| 1M4 | AL | FUEL_WEEKEND_RAMP_LIMIT | [Source](https://www.airnav.com/airport/1M4) | SAVED |
| CTZ | NC | AVGAS_GA | [Source](https://www.sampsoncountync.gov/Business/Clinton-Sampson-County-Airport) | SAVED |
| POF | MO | CITY_GENERAL_AVIATION | [Source](https://www.poplarbluff-mo.gov/150/Municipal-Airport) | SAVED |
| TOC | GA | OBSTRUCTIONS_MAIN_RUNWAY | [Source](https://www.airnav.com/airport/TOC) | SAVED |
| AGO | AR | STATE_GENERAL_AVIATION | [Source](https://fly.arkansas.gov/magnolia.html) | SAVED |
| E14 | NM | TRIBAL_GATE_HIGH_ALTITUDE | [Source](https://www.airnav.com/airport/E14) | SAVED |
| SFQ | VA | BUSINESS_GA_SKYDIVE | [Source](https://www.suffolkva.us/149/Airport) | SAVED |
| EYF | NC | GA_MAJOR_MAINTENANCE | [Source](https://elizabethtownnc.org/airport/) | SAVED |
| HMZ | PA | COUNTY_GA_24H | [Source](https://flybedfordpa.com/administration/contact-airport-authority/) | SAVED |
| JSO | TX | GA_FUEL_WEEKDAY_FBO | [Source](https://www.cherokeecountyairport.com/) | SAVED |
| MGJ | NY | MULTIPLE_TRAFFIC_PATTERNS | [Source](https://www.airnav.com/airport/MGJ) | SAVED |
| OEO | WI | COUNTY_GA_FUEL | [Source](https://www.gcr1.com/5010ReportRouter/default.aspx?airportID=OEO) | SAVED |
| TRL | TX | AIR_TAXI_ACTIVITY | [Source](https://www.terrelltx.gov/753/Terrell-Municipal-Airport) | SAVED |
| 06A | AL | WILDLIFE_PAPI_OUT | [Source](https://www.airnav.com/airport/06A) | SAVED |
| 3F3 | LA | GA_CROP_DUSTING | [Source](https://www.flightaware.com/resources/airport/3F3) | SAVED |
| 8A1 | AL | CORPORATE_GA_SEAPLANE | [Source](https://guntersvilleal.org/departments/guntersville-municipal-airport-joe-starnes-field/) | SAVED |
| CTY | FL | PAVEMENT_SECONDARY_FAIR | [Source](https://www.airnav.com/airport/CTY) | SAVED |
| EMP | KS | CITY_CORPORATE_GA | [Source](https://www.emporiaks.gov/1301/Emporia-Municipal-Airport) | SAVED |
| GZH | AL | CITY_FBO_FUEL | [Source](https://www.evergreenal.org/middleton-field.html) | SAVED |
| HRJ | NC | GA_FBO_DAILY | [Source](https://www.airnav.com/airport/HRJ) | SAVED |
| MHL | MO | GA_JET_SELF_FUEL | [Source](https://www.airnav.com/airport/MHL) | SAVED |
| PSN | TX | CITY_GA_FUEL | [Source](https://www.cityofpalestinetx.com/210/Airport) | SAVED |
| RNV | MS | UNIVERSITY_GA_TRAINING | [Source](https://www.cityofclevelandms.com/163/Municipal-Airport) | SAVED |
| SBX | MT | NO_REPAIRS_AFTER_HOURS_FUEL | [Source](https://www.airnav.com/airport/KSBX) | SAVED |
| SHN | WA | STATE_AIRPORT_ID | [Source](https://wsdot.wa.gov/travel/aviation/airports-list/sanderson-field) | SAVED |
| UTS | TX | CITY_PUBLIC_GA | [Source](https://www.huntsvilletx.gov/1059/Huntsville-Municipal-Airport) | SAVED |
| VGT | NV | SPECIAL_EVENT_PPR | [Source](https://vgt.aero/) | SAVED |
| VNW | OH | LOW_PAVEMENT_LOAD | [Source](https://www.airnav.com/airport/VNW) | SAVED |
| EBA | GA | AVGAS_ONLY_TERRAIN | [Source](https://www.airnav.com/airport/EBA) | SAVED |
| AAS | KY | GA_WEIGHT_LIMIT | [Source](https://taylorcountyky.gov/airport) | SAVED |
| AFJ | PA | AIR_CHARTER_LISTED | [Source](https://www.pa.gov/agencies/penndot/traveling-in-pa/airports/washington-county-airport) | SAVED |
| AMN | MI | GA_FBO_HOURS | [Source](https://www.airnav.com/airport/AMN) | SAVED |
| CRS | TX | CITY_GA_FUEL | [Source](https://cityofcorsicana.com/577/Airport) | SAVED |
| EXX | NC | AFTER_HOURS_UNATTENDED_HOLIDAYS | [Source](https://www.airnav.com/airport/EXX) | SAVED |
| MNE | LA | CITY_GA_FBO_FUEL | [Source](https://mindenla.org/business/minden-airport/) | SAVED |
| GTU | TX | TOWERED_CORPORATE_GA | [Source](https://www.airnav.com/airport/GTU) | SAVED |
| HHF | TX | GA_FUEL | [Source](https://www.airnav.com/airport/HHF) | SAVED |
| GDK | OH | FORMERLY_I19 | [Source](https://www.airnav.com/airport/GDK) | SAVED |
| JFX | AL | GA_COUNTY_AIRPORT | [Source](https://www.walkercountyal.us/home/services-dept/airport/) | SAVED |

## Recovery and controls
Recovery complete: the additional 30 source records were written and separate SQL read-back confirmed `Batch30=50`, `reviewed=693/1929`, `remaining=1236`, and zero gameplay approvals. Keep the original 3140 unaffected and exactly six game tiers: Local, Regional, Medium, Large, Major Hub, Mega Hub. Technical runway acceptability, commercial-use verification, relevant charter/cargo certificate and aircraft compatibility are separate decisions and **not approved** by this research.
