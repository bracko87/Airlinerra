# Airlinerra — U.S. Expansion Airport Research Batch 21
_Date: 2026-10-23. Live Supabase source: project `hwllkabgzaynalahvkpz`, private schema `airlinerra`._

## Verified milestone
**50 distinct FAA-matched U.S. expansion candidates** each received an airport-specific external source URL, a dated individual research note, a type-specific first-pass outcome, and `independent_review_at` timestamp. Live read-after-write check: **243 of 1,929** have a first individual airport-source review (previously 193), leaving **1,686** without it. Zero game-admission changes; all still `NOT_APPROVED`. No original 3,140 airport records or six game classifications altered.

**Important:** This is a first-pass *source-based review*, **not** 50 commercially verified airline airports. GA-only evidence documents an operating airport but does **not** establish a qualifying certificated passenger charter, scheduled passenger or cargo operator. Any game approval requires subsequent assessment of use restrictions, service and aircraft suitability.

## Distribution confirmed by SQL
| First-pass finding | Airports |
|---|---:|
| GA_ONLY_EVIDENCE | 34 |
| CHARTER_SUPPORTED | 4 |
| CHARTER_ADVERTISED | 2 |
| CHARTER_LISTED | 1 |
| CHARTER_ACTIVITY | 1 |
| MEDICAL_ACTIVITY | 2 |
| CARGO_ACTIVITY | 1 |
| LIMITED_SERVICES | 1 |
| NO_SCHEDULED_PASSENGER | 1 |
| OPERATIONAL_RESTRICTIONS | 1 |
| ACCESS_RESTRICTION | 1 |
| RUNWAY_WORK_REVIEW | 1 |
| **Total** | **50** |

## Exceptions and significant findings
- FXE has a city-published directory of named charter operators and city states no scheduled passenger services.
- ORL operator (Greater Orlando Aviation Authority) lists aircraft charter among FBO services.
- JWN owner (Metropolitan Nashville Airport Authority) lists aircraft charter companies.
- TDF Red Mountain Aviation is identified by the airport-specific FBO listing as offering aircraft charter.
- LZU county confirms no scheduled airline service while corporate/charter passenger arrivals occur.
- GLS City of Galveston says no current commercial airline service; that statement must not be misused to claim no charter can operate.
- E06 Zip Franklin Memorial is **Lovington**, while scheduled JSX/United services on the same county website are at **HOB**, NOT E06.
- RVF is **Ruby Valley Field at Twin Bridges**, NOT Livingston's Mission Field (LVM).
- CMR City of Cottonwood says **Jet A is unavailable** in its airport directory (as of the source), important to jet/aircraft compatibility.
- FWS city lists Boeing 737 as requiring prior permission; check aircraft approval rather than admitting by runway length alone.
- MAI city agenda October 2026 covers proposed runway 8/26 and taxiway rehabilitation. Current NOTAM and closures must be checked, not assumed.
- DWA public GA field has controlled gate access for non-tenants; not an automatic commercial ban.
- AND airport-specific October 2026 state record has runway condition and helicopter restrictions.
- 79J includes general aviation and military operations: presence of military use does not imply *military-only* airport.

## Individual source ledger
| FAA | State | First-pass evidence category | Individual finding | Public source |
|---|---|---|---|---|
| 79J | AL | GA_ONLY_EVIDENCE | Covington County official airport authority identifies South Alabama Regional public regional airport serving general aviation, industrial and military operations; no airline carrier established. | [Evidence](https://www.covingtoncountyal.gov/288/South-Alabama-Regional-Airport-Authority) |
| ARG | AR | GA_ONLY_EVIDENCE | Arkansas state aeronautics identifies Walnut Ridge Regional as city-owned public general-aviation airport with three runways; active airline service unconfirmed. | [Evidence](https://fly.arkansas.gov/walnut-ridge.html) |
| AWM | AR | CARGO_ACTIVITY | West Memphis municipal authority explicitly states GA airport serves business jets, private aircraft and freight/cargo operations; individual cargo airline not confirmed. | [Evidence](https://westmemphisar.gov/204/Airport) |
| CMR | AZ | LIMITED_SERVICES | Cottonwood city airport lists self-service 100LL only, with Jet A currently unavailable and maintenance/air-tour businesses; jet fueling restriction important. | [Evidence](https://cottonwoodaz.gov/770/Airport-Directory) |
| DWA | CA | ACCESS_RESTRICTION | Yolo County says Yolo County public-use GA airport is fenced, aviation areas secured; non-tenant users must obtain access instructions from FBO; fuel and maintenance available. | [Evidence](https://www.yolocounty.gov/government/general-government-departments/general-services/airport) |
| LHM | CA | GA_ONLY_EVIDENCE | Lincoln city reports 6001-foot paved runway, 10 aviation businesses and temporary restrictions on MONTHLY tie-down availability due to construction; charter operator not established. | [Evidence](https://www.lincolnca.gov/business-and-development/airport/) |
| SNS | CA | CHARTER_LISTED | October 2026 FAA-derived airport service directory lists charter service among airport services at Salinas; specific current operator not validated; check NOTAMs. | [Evidence](https://www.iflightplanner.com/Airports/KSNS) |
| 28J | FL | GA_ONLY_EVIDENCE | Palatka City operates Kay Larkin airport with 6003-foot runway, Jet A/100LL and commercial-aviation minimum standards; no active commercial charter certificate verified. | [Evidence](https://palatka-fl.gov/356/Palatka-Kay-Larkin-Airport) |
| FXE | FL | CHARTER_SUPPORTED | City of Fort Lauderdale lists multiple named private charter companies at Fort Lauderdale Executive, and explicitly says no scheduled commercial passenger flights. | [Evidence](https://www.flyfxe.com/visitors/charters) |
| MAI | FL | RUNWAY_WORK_REVIEW | Marianna city October 2026 council agenda considers rehabilitation of runway 8/26 and reconstruction of Taxiway B; current closures/NOTAMs must be verified before route use. | [Evidence](https://www.cityofmarianna.com/AgendaCenter/ViewFile/Agenda/_10132026-557?html=true) |
| ORL | FL | CHARTER_SUPPORTED | Greater Orlando Aviation Authority states Orlando Executive FBO services include aircraft charter, private/corporate travel; no scheduled airline service inferred. | [Evidence](https://web.goaa.aero/orlando-executive-airport/fixed-base-operators/) |
| CVC | GA | GA_ONLY_EVIDENCE | Covington Georgia city confirms KCVC airport public business/general aviation and FBO with 5500-foot runway, Jet A/100LL; no named charter/cargo airline confirmed. | [Evidence](https://cityofcovington.org/index.php?section=departments_covington-airport) |
| LZU | GA | CHARTER_ACTIVITY | Gwinnett County confirms no scheduled airline service at Briscoe Field, but businesses and charter companies use FBO passenger drop-off; currently two FBOs. | [Evidence](https://www.gwinnettcounty.com/government/departments/transportation/aviation/faqs) |
| TVI | GA | GA_ONLY_EVIDENCE | Thomasville city confirms airport active with two runways, terminal, FBO, flight training and courtesy cars; no operating commercial airline identified. | [Evidence](https://thomasville.org/departments/airport) |
| VDI | GA | GA_ONLY_EVIDENCE | Vidalia city confirms public regional airport fuel Jet A/100LL, ILS/GPS approaches and crew amenities; no charter airline operator established. | [Evidence](https://vidaliaga.gov/departments/vidalia-regional-airport/) |
| OTM | IA | GA_ONLY_EVIDENCE | Iowa DOT airport-specific public directory records Ottumwa Regional concrete/asphalt runways, Jet A and 100LL; current charter/cargo airline operator unconfirmed. | [Evidence](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=OTM) |
| 1H2 | IL | GA_ONLY_EVIDENCE | Effingham County airport operator confirms public regional airport and passenger/pilot lounge; on-field maintenance and fuel services not proof of charter airline. | [Evidence](https://effinghamcountyil.gov/airport/) |
| UGN | IL | GA_ONLY_EVIDENCE | Waukegan National airport lists North Shore Jet Center with fuel, ground handling and international customs by appointment; no specific air charter carrier established here. | [Evidence](https://waukeganairport.com/services/) |
| ASW | IN | GA_ONLY_EVIDENCE | Current Warsaw Municipal FAA-based listing describes public airport with city-run City Aviation Services FBO, fuel and terminal; no named charter airline established. | [Evidence](https://www.airnav.com/airport/ASW) |
| MQJ | IN | GA_ONLY_EVIDENCE | Indianapolis Airport Authority identifies Indianapolis Regional open public field with Jet Access FBO, Jet A/100LL and runways; current charter certification not independently established. | [Evidence](https://www.ind.com/business/general-aviation-airports/indianapolis-regional-airport) |
| OKK | IN | GA_ONLY_EVIDENCE | Kokomo official tourism page identifies Kokomo Municipal as open to corporate and private aviation; current certificated charter/cargo operator not identified. | [Evidence](https://www.visitkokomo.org/getting-here) |
| SER | IN | GA_ONLY_EVIDENCE | Current October 2026 AOPA/FAA airport profile identifies Freeman Municipal as public with 6001-foot paved runway, city FBO and flight school; charter airline unconfirmed. | [Evidence](https://www.aopa.org/destinations/airports/KSER/details) |
| EKX | KY | GA_ONLY_EVIDENCE | Elizabethtown Regional Addington Field airport board lists FBO Elizabethtown Flying Services offering fuel, rental and maintenance; GA and military operations. | [Evidence](https://ekxairport.com/) |
| RSN | LA | MEDICAL_ACTIVITY | Ruston city explicitly describes active general aviation airport including an air ambulance helicopter service, business jets and fuel; passenger/cargo airline unconfirmed. | [Evidence](https://www.ruston.org/airport/) |
| BIV | MI | CHARTER_ADVERTISED | West Michigan Regional Airport authority advertises charter flights and business travel; operator approval and individual aircraft types not yet checked. | [Evidence](https://westmichiganregionalairport.com/) |
| MNM | MI | GA_ONLY_EVIDENCE | Menominee County lists regional public airport, ramp/terminal and 24-hour fuel/aircraft handling; no passenger charter airline confirmed. | [Evidence](https://www.menomineecountymi.gov/departments/menominee-regional-airport/) |
| HFJ | MO | GA_ONLY_EVIDENCE | Neosho city reports Hugh Robinson Memorial public airfield with 5001-foot paved runway, hangar facilities, pilots courtesy vehicle and AWOS; no charter operator established. | [Evidence](https://www.neoshomo.gov/160/Airport) |
| RVF | MT | GA_ONLY_EVIDENCE | October 2026 FAA-derived record identifies Ruby Valley Field at Twin Bridges (RVF), public use, Jet A/100LL and service facilities. Do not confuse with Livingston's LVM. | [Evidence](https://www.airnav.com/airport/KRVF) |
| DPL | NC | GA_ONLY_EVIDENCE | Duplin County says airport is public-access general aviation with fuel, towing, hangars and 24/7 on-call service, not proof of commercial airline operations. | [Evidence](https://www.duplinnc.gov/162/Airport) |
| EDE | NC | GA_ONLY_EVIDENCE | Town of Edenton identifies Northeastern Regional EDE as public-use GA airport with part-time staffing and business/civilian hangars; no carrier charter operator established. | [Evidence](https://www.townofedenton.com/airport) |
| TDF | NC | CHARTER_ADVERTISED | Airport-specific listing for Raleigh Regional at Person County lists Red Mountain Aviation FBO offering aircraft charters; operator legal certificate/current flights not rechecked. | [Evidence](https://airnav.com/airport/TDF) |
| MIV | NJ | GA_ONLY_EVIDENCE | Millville Executive airport authority/DRBA lists public business aviation facility and Big Sky Aviation FBO; two paved runways, no scheduled airline proof. | [Evidence](https://www.millvilleairport.com/airport-information) |
| E06 | NM | GA_ONLY_EVIDENCE | Lea County identifies E06 as Zip Franklin Memorial at Lovington with Avgas, pilot lounge and courtesy car. Commercial United/JSX flights described for HOB, NOT E06. | [Evidence](https://www.leacounty.gov/243/Airport-Information) |
| WWR | OK | GA_ONLY_EVIDENCE | Woodward city confirms West Woodward fuel, passenger facilities, hangars and welcomes up to midsize jet traffic; no current charter/cargo airline demonstrated. | [Evidence](https://www.cityofwoodward-ok.gov/333/West-Woodward-Airport) |
| AND | SC | OPERATIONAL_RESTRICTIONS | South Carolina Aeronautics updated Oct 2026 confirms Anderson Regional public GA/business airport; runway 17/35 widespread cracks and helicopter skids restricted to pads/grass. | [Evidence](https://aeronautics.sc.gov/airports/anderson-rgnl-airport) |
| GGE | SC | GA_ONLY_EVIDENCE | South Carolina Aeronautics August 2026 airport record confirms open public Georgetown County Airport, paved runway and operating hours; commercial operator not established. | [Evidence](https://aeronautics.sc.gov/airports/georgetown-county-airport) |
| LKR | SC | GA_ONLY_EVIDENCE | South Carolina Aeronautics August 2026 record confirms open public-use Lancaster County McWhirter Field and runway information; no active commercial operator identified. | [Evidence](https://aeronautics.sc.gov/airports/lancaster-county-mc-whirter-fld-airport) |
| RBW | SC | GA_ONLY_EVIDENCE | South Carolina Aeronautics August 2026 Lowcountry Regional record confirms public airport, services/runways and attendance; charter/cargo airline not independently shown. | [Evidence](https://aeronautics.sc.gov/airports/lowcountry-rgnl-airport) |
| JWN | TN | CHARTER_SUPPORTED | Nashville airport authority lists Contour Flight Support chartering and Harmony Air Charter on-field at John C Tune; tower and airport services confirmed. | [Evidence](https://flynashville.com/nashville-airport-authority/john-c-tune/about) |
| COT | TX | GA_ONLY_EVIDENCE | Cotulla Jet Center is the active on-field FBO providing Jet A, Avgas, ramp handling and maintenance; no airline/charter operator confirmed from its page. | [Evidence](https://www.cotullajet.com/) |
| DUX | TX | GA_ONLY_EVIDENCE | Dumas economic development airport-specific record identifies Moore County airport public-use and attended weekdays; older record only, so contemporary charter/cargo service unresolved. | [Evidence](https://dumasedc.org/moore-county-airport/) |
| ERV | TX | MEDICAL_ACTIVITY | Kerrville-Kerr County airport authority confirms full-service public GA field and airborne ambulance, aircraft maintenance and FBO; no charter airline established. | [Evidence](https://kerrvilletx.gov/1765/Airport) |
| FWS | TX | CHARTER_SUPPORTED | Fort Worth city aviation authority identifies Spinks as serving air charter/business aviation; Boeing 737 requires prior permission according to city FBO data. | [Evidence](https://www.fortworthtexas.gov/departments/aviation/spinks/general-aviation) |
| GLS | TX | NO_SCHEDULED_PASSENGER | Galveston City FAQ explicitly says Scholes International currently lacks commercial airline service; official airport identifies business and private GA; charter authorization unconfirmed. | [Evidence](https://www.galvestontx.gov/FAQ/Topic?mobile=ON&topic=21) |
| HDO | TX | GA_ONLY_EVIDENCE | City of Hondo identifies South Texas Regional as general aviation airport with four active runways, Jet A/100LL and terminal services; charter airline unconfirmed. | [Evidence](https://www.hondo-tx.org/161/South-Texas-Regional-Airport) |
| OSA | TX | GA_ONLY_EVIDENCE | Current Mount Pleasant airport FBO page lists city-operated fuel, ground services and general maintenance; no named certificated passenger/cargo operator confirmed. | [Evidence](https://www.flightaware.com/resources/airport/KOSA/services/FBO/Mt._Pleasant_Regional) |
| OZA | TX | GA_ONLY_EVIDENCE | Ozona airport community site identifies 6000x75ft runway, 70000lb limitation and McCleary Aircraft FBO, fuel and maintenance; no airline or charter confirmed. | [Evidence](https://www.ozona.com/ozona-municipal-airport) |
| PRX | TX | GA_ONLY_EVIDENCE | Paris City lists Cox Field full FBO, Jet A/100LL and 6002-foot paved runway; city history distinguishes past passenger airline stops from current private/business use. | [Evidence](https://www.paristexas.gov/airport) |
| TXW | TX | GA_ONLY_EVIDENCE | South Texas Aviation Services publicly identifies on-field Mid Valley airport maintenance facility supporting Part 91/135 and cargo-airline maintenance; this does not prove cargo flight service at TXW. | [Evidence](https://southtexasaviationservices.com/) |
| VHN | TX | GA_ONLY_EVIDENCE | FAA remarks for Culberson County airport Van Horn show fuel available by call and airfield operational notes; commercial passenger/cargo service unconfirmed. | [Evidence](https://www.flightaware.com/resources/airport/KVHN/remarks) |

## Controls and next action
No source URL is a substitute for verifying airport access rights, current NOTAMs, runway/pavement load, aircraft performance and relevant commercial operating permissions. Retain `game_admission_status=NOT_APPROVED` until game-selection rules are satisfied. Preserve the original 3,140, and only use the six Airlinerra classes: Local, Regional, Medium, Large, Major Hub, Mega Hub.

Next batch: source-review another 50 unreviewed high-priority physical candidates; after source screening, triage the subset with confirmed charter/cargo services for actual game admission and classifications.
