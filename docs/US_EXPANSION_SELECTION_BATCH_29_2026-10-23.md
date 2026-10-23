# Airlinerra — Batch 29 U.S. Expansion Airport Source Ledger
_Research date 2026-10-23. **Partial Supabase write status: 46 saved / 50 researched; 4 pending.**_

## Verified database state
- Starting checkpoint from Batch 28: **593 / 1,929** individual first-pass airport source reviews saved.
- Batch 29 source lookup and airport-specific research completed for the **50 selected codes**.
- Conditional Supabase writes succeeded for **46 distinct airport records**; a separate SQL read enumerated all 46 and their evidence URLs. Therefore **639** records are expected to be individually reviewed (593+46), but an independent aggregate total should be checked when the final four records are written.
- Four researched airport records **MIO, DTN, HUL and 1F0** remain unwritten after multiple SQL writes were blocked. DO NOT count them as first-pass database reviewed until verified.
- No `game_admission_status` values modified by these updates, and none of the 50 was granted final commercial admission.

## High-priority qualifications
- **D60 Tioga ND**: its former Tioga Aero Center operator expressly says fixed-base services suspended August 29, 2024. Current availability must be separately established: https://www.tiogaaero.com/news.html
- **PHG Phillipsburg KS**: current October 2026 FAA airport report says **5,101ft concrete**, matching the pinned 1,554.8m; older city and county websites show 4,500ft. Source: https://www.airnav.com/airport/phg
- **3K7** is Mark Hoard Memorial at **Leoti KS**, NOT Syracuse-Hamilton County (3K3). Source: https://www.iflightplanner.com/Airports/3K7
- **M46 Colstrip MT**: Rosebud County operator specifically lists **no fuel, no repairs**. Source: https://rosebudcountymt.gov/departments/airport/
- **BKE Baker City OR**: on-field Baker Aircraft FBO explicitly offers **charter** as a service, along with fuel and maintenance. https://www.bakeraircraft.com/fbo-airport
- **LNN Willoughby-Lost Nation OH**: Classic Jet Center advertises **air charter** and publishes FAA Air Carrier Certificate number 8CLA151N. Check FAA certificate status and permitted fleet before game admission. https://www.classicjetcenter.com/
- **S52 Methow Valley State WA**: WSDOT warns state airport operation is at users' risk, winter snow clearing limited and some taxiways restricted. https://wsdot.wa.gov/travel/aviation/airports-list/methow-valley-state
- **E41 Reagan County TX**: paved 5,035ft main runway is only 50ft wide; runway 16 displaced threshold 1,005ft; loose stones on main runway and poor pavement on secondary 9/27. https://airnav.com/airport/E41
- **FFZ Falcon Field AZ**: busy Class D beneath Phoenix Class B, closely spaced runways and wrong-surface landing risk. https://www.faa.gov/flight_deck/ffz
- **4A4 Polk County GA**: extensive parachute activity weekends, airport runway ends not mutually visible; announce carefully on CTAF. https://www.airnav.com/airport/4A4
- **LRJ Le Mars IA**: runway 18 and 36 thresholds each displaced 300ft, reduce relevant landing distance. https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=LRJ
- **1L7 Escalante UT**: high elevation GA source is dated 2017, needs current-source refresh before final decision.

## Complete source and saved-status ledger
| FAA | State | First-pass finding category | Airport-specific source finding | Source URL | Supabase status |
|---|---|---|---|---|---|
| EDN | AL | GA_SMALL_JET_OPERATIONS | Enterprise Municipal official economic-development description says public 5100ft runway supports light corporate jets, Jet A/100LL and passenger terminal; charter operator unverified. | [Source](https://www.enterprisealabama.com/enterprise-municipal-airport) | SAVED |
| LLQ | AR | GENERAL_AVIATION | Arkansas Aeronautics identifies Monticello Ellis Field as municipal GA airport. | [Source](https://fly.arkansas.gov/monticello.html) | SAVED |
| VBT | AR | CITY_GA | Arkansas aeronautics identifies city-owned Bentonville Municipal Louise M Thaden Field general aviation runway 18/36; current charter carrier unverified. | [Source](https://fly.arkansas.gov/bentonville.html) | SAVED |
| FFZ | AZ | BUSINESS_GA_BUSY_AIRSPACE | FAA flags parallel runways, wrong-surface risk and busy VFR corridor in Mesa Class D beneath Phoenix Class B; GA/business field. | [Source](https://www.faa.gov/flight_deck/ffz) | SAVED |
| 4A4 | GA | SKYDIVE_NO_LINE_OF_SIGHT | FAA Polk County Cornelius Moore Field reports 5041ft asphalt, extensive weekend parachuting and no runway-end line-of-sight; requires frequent CTAF broadcasts. | [Source](https://www.airnav.com/airport/4A4) | SAVED |
| IIY | GA | GA_FBO_ONLY | Washington-Wilkes County public airport offers Jet A and 100LL self-service and county-operated ground handling; charter operator not confirmed. | [Source](https://www.airnav.com/airport/KIIY) | SAVED |
| LRJ | IA | DISPLACED_THRESHOLDS | Iowa DOT Le Mars Municipal 5056ft concrete, fuel and Ultra Flight FBO; both runway 18 and 36 thresholds displaced 300ft. | [Source](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=LRJ) | SAVED |
| RDK | IA | GA_GRASS_CLOSURE | Iowa DOT Red Oak municipal records 5100ft concrete paved 05/23 plus seasonal closed winter turf runway; Jet A/avgas. | [Source](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=RDK) | SAVED |
| GIC | ID | COUNTY_GA | Idaho County Grangeville airport manager and runway confirmed, charter operator unverified. | [Source](https://www.idahocounty.org/tmp/airport/idaho-county-airport/) | SAVED |
| HFY | IN | GA_FBO_ONLY | individual source review: October FAA identifies Indy South Greenwood public airport, Jet A/100LL and major maintenance; charter unconfirmed. | [Source](https://www.airnav.com/airport/HFY) | SAVED |
| 3K7 | KS | LEOTI_IDENT | 3K7 is Mark Hoard Memorial at Leoti, not Syracuse 3K3; FAA public runway 5100ft. | [Source](https://www.iflightplanner.com/Airports/3K7) | SAVED |
| PHG | KS | RUNWAY_RECONCILED | October 2026 FAA lists Phillipsburg 5101ft concrete, older city page 4500ft; current matches existing database. | [Source](https://www.airnav.com/airport/phg) | SAVED |
| TOP | KS | TOWERED_BUSINESS_GA | FAA October Philip Billard public Topeka airport has staffed tower and 5100ft paved runway, migratory bird warning; carrier unverified. | [Source](https://airnav.com/airport/TOP) | SAVED |
| SJS | KY | GA_FBO_ONLY | Big Sandy Regional operator confirms 5051ft paved public runway, Cox Aviation 100LL and Jet A, 0800-dusk, no charter carrier identified. | [Source](https://bigsandyregional.com/) | SAVED |
| DET | MI | GA_AIR_CARRIER_TERMINAL | Detroit city describes Coleman A Young air carrier terminal and FBO, but scheduled service not proven. | [Source](https://detroitmi.gov/departments/airport-coleman-young-international) | SAVED |
| AXN | MN | MEDICAL_HELI_WARNINGS | Alexandria Regional FAA says med-helicopter ramp area and ultralight/waterfowl hazards, 5099ft runway, Jet A/100LL, no scheduled carrier established. | [Source](https://www.airnav.com/airport/KAXN) | SAVED |
| UNO | MO | GA_FBO_ONLY | West Plains Regional public paved airport has Jet A/100LL; airline unconfirmed. | [Source](https://www.flightaware.com/resources/airport/KUNO) | SAVED |
| 9S5 | MT | ULTRALIGHT_SKYDIVE | Montana 2025 airport directory confirms Three Forks public 5100ft asphalt field with glider, skydiving, ultralight activity and 100LL. | [Source](https://www.iflightplanner.com/Airports/9S5) | SAVED |
| M46 | MT | NO_FUEL_SERVICES | Rosebud County says Colstrip Ricks field has no fuel or repairs; PAPI lights and pilot facilities exist. | [Source](https://rosebudcountymt.gov/departments/airport/) | SAVED |
| RPX | MT | UNATTENDED_GA | FAA Oct 2026 Roundup airfield open public, unattended at 3490ft elevation with PAPI/MIRL lighting. | [Source](https://www.airnav.com/airport/RPX) | SAVED |
| BWP | ND | GA_WINTER_WARNING | Wahpeton Harry Stern FAA record lists public airport and Jet A/100LL, deer/birds and winter field-condition verification. | [Source](https://www.airnav.com/airport/BWP) | SAVED |
| D60 | ND | FBO_SUSPENDED | individual source review: Tioga Aero Center published suspension of fixed base operations effective Aug 29 2024; do not assume prior FBO available. | [Source](https://www.tiogaaero.com/news.html) | SAVED |
| IML | NE | GA_FBO_ONLY | October FAA Imperial Municipal confirms public civil airport with 5030ft-range paved runway, weekday attendance and PAPI/MIRL, no charter airline proven. | [Source](https://www.airnav.com/airport/KIML) | SAVED |
| OGA | NE | GA_FBO_ONLY | individual source review: October FAA lists Searle Field public 5102ft concrete runway, Jet A/100LL and major repairs; no carrier verified. | [Source](https://airnav.com/airport/OGA) | SAVED |
| I23 | OH | GA_FBO_ONLY | Fayette County lists public GA airport 5097ft runway, 24h fuel and flight training. | [Source](https://fayette-co-oh.com/281/Airport) | SAVED |
| LNN | OH | PART135_CHARTER_ADVERTISED | Classic Jet Center based at Willoughby Lost Nation airport explicitly offers private aircraft charter and publishes FAA Air Carrier Certificate 8CLA151N, certificate status still to confirm directly. | [Source](https://www.classicjetcenter.com/) | SAVED |
| CHK | OK | GA_BUSINESS | individual source review: Oklahoma state authority lists Chickasha Municipal as regional business, concrete runway, Jet A/100LL; no current charter carrier. | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/chickasha-municipal.html) | SAVED |
| GAG | OK | GENERAL_ONLY_NO_FUEL_LISTED | Oklahoma Aeronautics classifies Gage as General airport, unattended, no based jets, no fuel listed, 5033ft asphalt runway. | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/gage.html) | SAVED |
| OJA | OK | GA_FBO_ONLY | FAA October Weatherford Stafford municipal listing confirms city-operated FBO and ground handling, no verified air carrier. | [Source](https://www.airnav.com/airport/KOJA) | SAVED |
| RVS | OK | TWO_GA_FBOS | Tulsa airport owner identifies Christiansen and Riverside Jet Center as full-service FBOs. | [Source](https://flytulsa.com/tulsa-river-side/services/) | SAVED |
| 5S6 | OR | STATE_GA | Oregon state Cape Blanco public airfield runway 5100ft, estimated 750 GA movements. | [Source](https://www.oregon.gov/aviation/airports/pages/cape-blanco-5s6.aspx) | SAVED |
| BKE | OR | CHARTER_SUPPORTED | Baker Aircraft FBO on Baker City airport explicitly offers charter, fuel, maintenance and aerial work. | [Source](https://www.bakeraircraft.com/fbo-airport) | SAVED |
| BNO | OR | GA_WILDLIFE_WARNING | individual source review: FAA chart supplement describes Burns Municipal 5101ft paved concrete main runway, Jet A and seasonal bird hazard. | [Source](https://aeronav.faa.gov/afd/19MAR2026/NW_164_19MAR2026.pdf) | SAVED |
| DLS | OR | GA_FBO_ONLY | Columbia Gorge operator identifies Hood Aero FBO supplying Jet A, 100LL and maintenance; charter not established. | [Source](https://www.flycgra.com/pilots) | SAVED |
| S33 | OR | CHARTER_LISTED | Madras airport-specific directory lists charter business service and current runway procedure NOTAMs. | [Source](https://www.iflightplanner.com/Airports/S33) | SAVED |
| ZER | PA | BUSINESS_JETS | Schuylkill County operator supports midsize business jets with 5101ft paved main runway. | [Source](https://www.schuylkillregionalairport.com/) | SAVED |
| 49B | SD | CITY_GA_FBO | Sturgis public municipal field FBO and 24h self-service fuel, no carrier proven. | [Source](https://www.sturgis-sd.gov/sturgis-municipal-airport) | SAVED |
| 2T1 | TX | AVGAS_ONLY | Muleshoe public airport is unattended, 5100ft asphalt with 100LL only. | [Source](https://airnav.com/airport/2T1) | SAVED |
| E41 | TX | DISPLACED_THRESHOLD_LOOSE_STONES | FAA Reagan County runway 16/34 5035x50ft asphalt, 1005ft displaced threshold and loose stones; secondary paved runway 9/27 poor surface. | [Source](https://airnav.com/airport/E41) | SAVED |
| F05 | TX | AGRICULTURAL_121 | Wilbarger County operator confirms Vernon public paved field with Jet A/avgas, and seasonal aerial agriculture; no carrier verified. | [Source](https://www.co.wilbarger.tx.us/page/Airport) | SAVED |
| 1L7 | UT | HIGH_ALTITUDE_UNATTENDED | Escalante city airport-specific FAA record identifies public field at 5737ft elevation, unattended, paved runway; this page is older and current airport rules still require review. | [Source](https://escalanteutah.gov/wp-content/uploads/2017/06/AirNav_-1L7-Escalante-Municipal-Airport.html) | SAVED |
| 41U | UT | HIGH_ALTITUDE_24H_FUEL | Manti-Ephraim FAA chart supplement lists 5021ft paved main runway at 5516ft altitude, unattended with 24hr self-service Jet A and avgas; carrier not established. | [Source](https://aeronav.faa.gov/d-tpp/2512/10960r3.pdf) | SAVED |
| S52 | WA | EMERGENCY_USE_WARNING | Washington DOT says Methow Valley State public paved 5049ft runway, limited winter snow removal, state airports mainly for emergency use; controlled forest service taxiway access. | [Source](https://wsdot.wa.gov/travel/aviation/airports-list/methow-valley-state) | SAVED |
| RRL | WI | GA_ULTRALIGHT | Merrill FAA airport data shows public paved runways and ultralight traffic, charter unverified. | [Source](https://www.airnav.com/airport/RRL) | SAVED |
| UNU | WI | GA_ULTRALIGHT_BIRDS | FAA October Dodge County public 5070ft asphalt runway, Jet A, repairs and irregular ultralight/bird activity; charter unverified. | [Source](https://www.airnav.com/airport/UNU) | SAVED |
| LSK | WY | SMALL_GA_AVGAS | Town of Lusk describes 5058ft runway, 100LL self-service and small GA airport; no named certificated charter provider. | [Source](https://townofluskwy.gov/municipal-airport) | SAVED |
| MIO | OK | REGIONAL_BUSINESS_GA | Oklahoma authority describes 5020ft public business airport, Jet A and avgas, repairs; no named charter operator. | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/miami-regional.html) | PENDING DATABASE WRITE |
| DTN | LA | GA_RELIEVER | Shreveport airport authority confirms DTN is GA reliever with Tubreaux Aviation FBO. Scheduled services use SHV, not proven at DTN. | [Source](https://flyshreveport.com/airport-information/) | PENDING DATABASE WRITE |
| HUL | ME | GA_CUSTOMS | Houlton town confirms 5000ft public general aviation border airport, Jet A/100LL and customs services; no scheduled carrier established. | [Source](https://www.houlton-maine.com/airport/) | PENDING DATABASE WRITE |
| 1F0 | OK | REGIONAL_BUSINESS_GA | Oklahoma aviation authority lists 5014ft paved Ardmore Downtown Executive airport, Jet A/100LL and minor repairs; airline unverified. | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/ardmore-downtown-executive.html) | PENDING DATABASE WRITE |

## Next action
Save the exact remaining **MIO, DTN, HUL, 1F0** into `airlinerra.airport_commercial_verification` by FAA code and state only when `independent_review_at IS NULL`, then read back and confirm **50 batch29** and expected **643/1,929** reviewed and **1,286** remaining. Update this report after confirmation. Keep original 3,140 and exact six game tiers (Local, Regional, Medium, Large, Major Hub, Mega Hub) unchanged. Source review is not final commercial-service or aircraft-compatibility approval.
