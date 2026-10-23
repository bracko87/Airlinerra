# Airlinerra — U.S. Expansion Batch 20: 50 Individual Airport-Source Reviews

_Date: 2026-10-23. Source of truth: Supabase project `hwllkabgzaynalahvkpz`, private schema `airlinerra`._

## Verified milestone
- **50** newly reviewed, distinct U.S. FAA-matched airport expansion candidates, each with an individual airport-specific external source, research note, and `independent_review_at` timestamp.
- Database check: **193 / 1,929** have an individual source review, up from 143; **1,736** are awaiting a first review.
- **0** game-admission approvals changed. The original **3,140** and all six Airlinerra game classifications remain unchanged.
- **Important:** A first airport-specific source review is **not** certification for passenger airlines, cargo airlines, charter operators, or all aircraft. Where owner/airport pages establish general aviation only, the evidence category is GA_ONLY_EVIDENCE, not an affirmative commercial-service clearance.

## Outcomes from live database
| Evidence finding | Number |
|---|---:|
| General/business aviation evidence only; commercial unconfirmed | 30 |
| Limited service/facilities | 4 |
| Charter advertised by airport/operator (further qualification pending) | 4 |
| Charter explicitly supported in airport or owner listing | 4 |
| Medical activity | 2 |
| Cargo activity | 1 |
| No scheduled airline | 1 |
| Charter/cargo supported | 1 |
| Commercial infrastructure (no operator proof) | 1 |
| Commercial service advertised but details unconfirmed | 1 |
| Owner explicitly says no commercial air service | 1 |
| **Total** | **50** |

## Significant distinctions
- CMA Camarillo: Ventura County authority specifically lists authorized on-demand charter operators.
- AAO Jabara and CXP Carson City: owner/airport resources list charter aviation services.
- PAQ Palmer: city describes flightseeing and air cargo charters.
- PRB Paso Robles: city explicitly says no scheduled airline, but charter services operate.
- LWT Lewistown: airport states it does not offer commercial air service.
- HBG Hattiesburg: airport says former commercial air service has ceased; cargo handling remains, not necessarily airline cargo routes.
- E25 is Wickenburg (Arizona); L71 is California City Municipal (California); RCV is Astronaut Kent Rominger (Del Norte, Colorado). These identifiers were checked to avoid place-name mix-ups.

## Complete airport-specific source ledger
| FAA | State | Finding category | Evidence summary and remaining qualification | Public source |
|---|---|---|---|---|
| PAQ | AK | CHARTER_CARGO_SUPPORTED | City of Palmer municipal airport explicitly lists flightseeing and air cargo charters, fuel and aircraft maintenance; specific aircraft/flight/operator restrictions remain to be checked. | [Source](https://www.palmerak.org/airport) |
| BFZ | AL | GA_ONLY_EVIDENCE | Current airport-specific listing identifies Albertville Aviation FBO with Jet A and 100LL and on-field aircraft maintenance business; charter airline unconfirmed. | [Source](https://www.airnav.com/airport/BFZ) |
| EKY | AL | GA_ONLY_EVIDENCE | Bessemer Airport Authority confirms airport is public use and focused on general/corporate aviation; no airline/charter service established from owner page. | [Source](https://www.bessemerairportauthority.com/) |
| TOI | AL | GA_ONLY_EVIDENCE | City of Troy lists FBO, leasing, pilot availability, aircraft mechanics and fuel; 46 percent transient GA and 41 percent military operations; charter certificate unverified. | [Source](https://www.troyal.gov/KTOI) |
| ROG | AR | GA_ONLY_EVIDENCE | City of Rogers airport authority says Rogers Executive Carter Field is general/business aviation airport and important commerce gateway; charter or cargo carrier unspecified. | [Source](https://www.rogersar.gov//190/Airport) |
| SGT | AR | GA_ONLY_EVIDENCE | Arkansas Aeronautics Division identifies Stuttgart Municipal as city-owned general-aviation airport, two runways; no scheduled passenger/charter operator confirmed. | [Source](https://fly.arkansas.gov/stuttgart.html) |
| E25 | AZ | GA_ONLY_EVIDENCE | Wickenburg airport-specific source confirms city fueling/parking/maintenance support and service limits; identity is WICKENBURG, not Safford. | [Source](https://www.airnav.com/airport/E25) |
| P33 | AZ | GA_ONLY_EVIDENCE | Cochise County lists public-use general-aviation Cochise County airport, Willcox Aviation fuel/maintenance and flight training/aerial survey tenant; charter not confirmed. | [Source](https://www.cochise.az.gov/210/Cochise-County-Airport) |
| SAD | AZ | COMMERCIAL_UNCONFIRMED | Safford city airport site advertises commercial flights and lists Spalsbury Aviation FBO with fuel and line service; no operator schedule or certificate identified, so airline suitability remains pending. | [Source](https://flysafford.com/) |
| CMA | CA | CHARTER_SUPPORTED | Ventura County Airports authority lists Camarillo on-field authorized on-demand charter providers Air 7, Channel Islands Aviation and Sun Air Jets. | [Source](https://s48873.pcdn.co/camarillo-airport-businesses/) |
| L71 | CA | GA_ONLY_EVIDENCE | California state official general-aviation classification confirms California City Municipal FAA L71; airport charter service not established. DO NOT confuse with California Hot Springs. | [Source](https://www.cdph.ca.gov/Programs/CCDPHP/DEODC/CLPPB/Pages/GAAirportsList.aspx) |
| MYV | CA | MEDICAL_ACTIVITY | Yuba County authority confirms GA airport supporting critical medical transportation, 6006-ft paved runway and instrumentation; scheduled commercial services not established. | [Source](https://www.yuba.gov/departments/community_development/airport/index.php) |
| OVE | CA | GA_ONLY_EVIDENCE | City of Oroville airport facilities page identifies Table Mountain Aviation FBO, 6020-foot primary runway and apron/tie-down operations; commercial charter not confirmed. | [Source](https://www.orovilleca.gov/Facilities/Facility/Details/Oroville-Municipal-Airport-5) |
| PRB | CA | CHARTER_SUPPORTED | City of Paso Robles explicitly says no scheduled airline service, but air charter, ambulance, firefighting and other flying services regularly operate. | [Source](https://www.prcity.com/352/Airport-Overview) |
| RCV | CO | GA_ONLY_EVIDENCE | Colorado airport-operator association identifies Astronaut Kent Rominger airport at Del Norte; Fly Colorado lists recent lighting, AWOS and self-service fuel upgrades, no airline confirmed. | [Source](https://www.flycolorado.org/index.php/airstrip-database/public-airports/del-norte/) |
| ACJ | GA | GA_ONLY_EVIDENCE | Souther Field Aviation manager at Jimmy Carter Regional confirms active full-service FBO leasing airport, fuel and management; passenger charter unconfirmed. | [Source](https://www.southerfield.com/main.php) |
| CZL | GA | GA_ONLY_EVIDENCE | Calhoun Gordon County Airport Authority provides turbine and piston fuel, pilot terminal, maintenance and aircraft services; commercial carrier not identified. | [Source](https://calhounairport.com/about/) |
| SBO | GA | CHARTER_ADVERTISED | City of Swainsboro explicitly states East Georgia Regional provides charter flights and aircraft maintenance; operator certification remains unchecked. | [Source](https://cityofswainsboro.org/government/departments/airport/) |
| DNV | IL | GA_ONLY_EVIDENCE | Vermilion Regional Airport Authority describes operational general aviation field and FBO/Jet A. Historical aviation impact assessment cites cargo activity but current regular cargo airline not independently confirmed. | [Source](https://www.vrairport.com/) |
| GSH | IN | CHARTER_ADVERTISED | Goshen Municipal Airport's own website lists private charter solutions alongside FBO, maintenance and training; named certificated operating airline remains unverified. | [Source](https://flygoshen.com/) |
| MZZ | IN | GA_ONLY_EVIDENCE | Marion Municipal Airport authority identifies active Air Marion full-service FBO with fuel, maintenance and flight training; no identified charter company. | [Source](https://www.marionairport.net/) |
| AAO | KS | CHARTER_SUPPORTED | Wichita Airport Authority identifies Clemens Aviation providing aircraft charter at James Jabara GA reliever field. | [Source](https://www.flywichita.com/jabara-airport/) |
| PTS | KS | GA_ONLY_EVIDENCE | City of Pittsburg-operated Atkinson airport FBO serves corporate jets with Jet A, aircraft maintenance and public GA terminal; named charter airline not confirmed. | [Source](https://fbo.fltplan.com/fbo.cfm?fid=3305) |
| BEH | MI | GA_ONLY_EVIDENCE | Southwest Michigan Regional Airport authority describes active business and tourism airport services; no specific passenger charter or cargo operator identified. | [Source](https://www.swmiairport.com/about-us) |
| HBG | MS | NO_SCHEDULED_AIRLINE | Hattiesburg airport owner explicitly states commercial air service is no longer conducted; GA/business aviation continues. FBO advertises cargo handling, not proof of scheduled cargo airline. | [Source](https://hattiesburgairport.com/about/) |
| 3U3 | MT | LIMITED_SERVICES | Montana DOT official airport directory index identifies Bowman Field 3U3 at Anaconda with paved runway; airport-specific public airline/charter operator not established from index. | [Source](https://www.mdt.mt.gov/aviation/airports.aspx) |
| 7S6 | MT | LIMITED_SERVICES | White Sulphur Springs airport source lists 100LL self-service and operational instrument approach information; no identified passenger/cargo operator. Higher-elevation airfield. | [Source](https://www.airnav.com/airport/7S6) |
| LWT | MT | NO_COMMERCIAL_AIR_SERVICE | Lewistown Municipal official airport website explicitly states it does not offer commercial air service; GA FBO and runway remain operational. | [Source](https://www.lewistownairport.com/) |
| IBM | NE | GA_ONLY_EVIDENCE | City of Kimball lists public airport, Jet A/100LL fuel, courtesy cars and private aviation company offering repair/rental/instruction; charter airline not identified. | [Source](https://kimballne.org/airport/) |
| EEN | NH | CHARTER_ADVERTISED | City Keene lists Monadnock Aviation FBO and charter-oriented airport services; current airline certification not established. | [Source](https://keenenh.gov/airport/) |
| CXP | NV | CHARTER_SUPPORTED | Carson City Airport Authority officially lists Mountain West and Stellar Aviation providing charters along with fuel and maintenance. | [Source](https://flycarsoncity.com/services/) |
| ELY | NV | COMMERCIAL_INFRASTRUCTURE | White Pine County Ely/Yelland Field airport fee schedule explicitly allows commercial operators subject to fee; no named charter or passenger carrier identified. High elevation 6259 feet. | [Source](https://whitepinecounty.net/127/Airport) |
| MWO | OH | CHARTER_ADVERTISED | City-operated Middletown FBO lists aircraft rentals and charters, corporate/commercial aviation customer support; air carrier certificate not independently verified. | [Source](https://skyvector.com/fbo/kmwo/middletown-FBO-Services) |
| FDR | OK | LIMITED_SERVICES | Oklahoma Aeronautics profiles Frederick Regional as Basic GA airport, 100LL fuel, unattended, no based jet aircraft; no commercial air operator established. | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/frederick-regional.html) |
| RCE | OK | GA_ONLY_EVIDENCE | Oklahoma Aeronautics classifies Clarence E Page as National Business airport with Jet A and maintenance, one based jet in older listing; commercial operator not established. | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/clarence-e-page-municipal.html) |
| YKN | SD | GA_ONLY_EVIDENCE | City Yankton lists Chan Gurney fuel, maintenance, rental and pilot training for GA, without confirming airline/charter operator. | [Source](https://www.cityofyankton.org/departments-services/airport) |
| RZR | TN | GA_ONLY_EVIDENCE | City of Cleveland operates Regional Jetport, terminal and concrete runway for general aviation aircraft; scheduled service not proven. | [Source](https://www.clevelandtn.gov/525/Cleveland-Regional-Jetport) |
| BKS | TX | GA_ONLY_EVIDENCE | October 2026 airport-specific aviation listing identifies CosbyAir fuel/FBO at Brooks County Falfurrias; no charter company or cargo airline verified. | [Source](https://www.iflightplanner.com/Airports/KBKS) |
| GKY | TX | CARGO_ACTIVITY | Arlington municipal city authority describes corporate, cargo and recreational aviation and on-field FBO Arlington Air Center; no named cargo airline/schedule proven. | [Source](https://www.arlingtontx.gov/City-Services/Transportation-Streets-Traffic/Airport) |
| HRX | TX | GA_ONLY_EVIDENCE | Hereford airport FBO current listing confirms 100LL and Jet A, maintenance, crew vehicle; no independent charter operator confirmed. | [Source](https://www.flightaware.com/resources/airport/KHRX/services/FBO/Hereford_Municipal_Airport) |
| LLN | TX | GA_ONLY_EVIDENCE | City of Levelland explicitly categorizes airport as General Business GA and operates with Levelland Aero Service FBO, fuel and licensed mechanic; notes limitation for commercial air carriers. | [Source](https://www.levellandtexas.org/61/Levelland-Municipal-Airport) |
| ODO | TX | GA_ONLY_EVIDENCE | Airport-specific service directory lists Odessa-Schlemeyer FBO and Farmor Aviation for fueling/handling; no verified passenger charter company. | [Source](https://www.flightbridge.com/directory/airport/odo-kodo/odessa-schlemeyer-field-airport/7654) |
| DTA | UT | GA_ONLY_EVIDENCE | City of Delta confirms operational public municipal airfield and available Jet A/100LL fuel; no specific airline/charter operator. | [Source](https://www.delta.utah.gov/facilities/page/delta-municipal-airport) |
| KNB | UT | GA_ONLY_EVIDENCE | City Kanab airport lists 24-hour Jet A/100LL fueling and car rentals; scheduled or certificated charter operator not identified. | [Source](https://kanab.utah.gov/2151/Airport) |
| TVY | UT | LIMITED_SERVICES | Tooele Valley airport listing reports Salt Lake City Department of Airports 24-hour self-service 100LL with no formal FBO services; named commercial operator unverified. | [Source](https://www.globalair.com/airport/fbo-at-tvy-salt-lake-city-dept-of-airports-2250.aspx) |
| MTV | VA | GA_ONLY_EVIDENCE | Virginia Department of Aviation classifies Blue Ridge Regional as regional business and lists its airport authority and manager; airline or charter operator not established. | [Source](https://doav.virginia.gov/airport_sponsors/) |
| DEW | WA | GA_ONLY_EVIDENCE | Washington DOT identifies Deer Park municipal public aviation facility, pilot cameras and pavement-management information; current charter provider not established. | [Source](https://wsdot.wa.gov/travel/aviation/airports-list/deer-park-municipal) |
| STE | WI | MEDICAL_ACTIVITY | Stevens Point city describes airport as supporting emergency medical flights and business aviation plus agricultural, law enforcement and training flights; airline not confirmed. | [Source](https://stevenspoint.com/118/Airport) |
| BYG | WY | GA_ONLY_EVIDENCE | Wyoming DOT visitor directory confirms Buffalo Johnson County operational GA terminal/pilot lounge and airport contact; commercial operator not identified. | [Source](https://www.dot.state.wy.us/home/aeronautics/education-outreach/wy-fly-passport-program/visitor-station-locations.html) |
| POY | WY | GA_ONLY_EVIDENCE | City of Powell describes public GA airport with paved 6205-foot main runway, tie downs, hangars and 24-hour self-service fuel; airline not established. | [Source](https://cityofpowell.com/municipal-airport/) |

## Eligibility control
Do not equate FAA public-use or paved runway with a currently authorized airline route or certificated charter operation. Do not set the 50 airports to gameplay approved. Any aircraft/route admission must observe airport operator restrictions, NOTAMs, aircraft performance and relevant certification. `independent_review_at` marks **first-pass external airport-source research**, not final commercial suitability. All records remain subject to category finalization and commercial-service evidence where not yet established.
