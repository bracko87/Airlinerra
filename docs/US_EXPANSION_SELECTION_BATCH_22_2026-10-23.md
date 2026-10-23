# Airlinerra — Batch 22: 50 airport-source reviews
Research date: 2026-10-23. Recovery and database completion: 2026-10-23.

## Confirmed outcome
The previously interrupted Batch 22 has been **fully recovered**. Supabase private table `airlinerra.airport_commercial_verification` confirms:
- **50** Batch 22 review rows with an individually recorded external-source URL, finding and timestamp.
- **293 / 1,929** FAA-matched expansion candidates with a first source review; **1,636** not yet reviewed.
- **0** game admission status changes.

The final 25 missing database rows were recovered in two successful updates (12 and 13) after checking that the first 25 had saved; a read-after-write count verified all 50. This replaces the earlier *PARTIAL* recovery copy.

**Definition:** first-pass airport-source review is not commercial suitability approval. Some sources verify charter activities while others show general aviation, restrictions, fuel/facilities only, or no commercial airline service. Do not classify all 50 as commercially eligible.

## Complete database-sourced individual findings

| FAA | State | Finding | Evidence summary | Source |
|---|---|---|---|---|
| PBF | AR | GA_ONLY_EVIDENCE | Pine Bluff Regional airport operator confirms FBO, aircraft maintenance on field, fuel and round-the-clock terminal access; no named charter or cargo airline. | [Source](https://www.pbf-airport.com/fbo/) |
| P04 | AZ | LIMITED_SERVICES | Bisbee avgas only, no Jet A; narrow runway and high elevation. | [Source](https://www.airnav.com/airport/P04) |
| APC | CA | PUBLIC_CHARTER_SUPPORTED | Napa County confirms seasonal JSX public charter, not traditional scheduled airline. | [Source](https://connect.napacounty.gov/AirportApproach/frequently-asked-questions) |
| F70 | CA | CHARTER_SUPPORTED | Riverside County airport tenant directory lists American Valet Air and cruiseAIR under Air Charter and Reach medical service. | [Source](https://rctlma.org/french-valley-airport-information) |
| MOD | CA | NO_SCHEDULED_CHARTER_AVAILABLE | No scheduled commercial air service; FBO handles private charter inquiries. | [Source](https://www.modestogov.com/334/Flight-Schedule) |
| PTV | CA | GA_ONLY_EVIDENCE | FAA airport record identifies fuel and major repairs. | [Source](https://www.gcr1.com/5010ReportRouter/default.aspx?airportID=PTV) |
| 33V | CO | HIGH_ALTITUDE_NO_FUEL | Walden field elevation above 8100 feet; no listed fuel. | [Source](https://www.iflightplanner.com/Airports/33V) |
| 2IS | FL | PROPOSED_CARGO_NOT_ACTIVE | FDOT describes future cargo redevelopment; existing cargo airline not proven. | [Source](https://www.fdot.gov/aviation/airportslist/2IS) |
| AYS | GA | GA_ONLY_EVIDENCE | County confirms functioning GA airport, no charter airline established. | [Source](https://www.warecountyga.gov/department-nodes/airport) |
| DQH | GA | GA_MEDICAL_ACTIVITY | City of Douglas airport page documents fuel and runway/business services; state aviation profile identifies business jet and air evacuation activity, not scheduled airlines. | [Source](https://ga-douglas.civicplus.com/95/Airport-Division) |
| MGR | GA | GA_ONLY_EVIDENCE | Georgia airport directory identifies Moultrie Municipal as 6000-foot paved airport with FBO, 100LL/Jet A and crew services; no named charter operator established. | [Source](https://www.airnav.com/airport/MGR) |
| TBR | GA | CHARTER_BROKER_ADVERTISED | Statesboro airport FBO advertises Air Charter Advisors, a charter broker; this is not evidence that the broker is a based certificated air carrier. | [Source](https://www.statesboroairport.com/KTBR/air-charter-advisors) |
| I63 | IL | FUEL_UNAVAILABLE_NOTAM | October NOTAM shows fuel unavailable to Nov 30 2026; verify current status. | [Source](https://www.iflightplanner.com/Airports/I63) |
| IKK | IL | CARGO_HANDLING | FBO offers cargo offload and forklifts, no cargo airline established. | [Source](https://www.greaterkankakeeairport.com/fbo-services) |
| VYS | IL | CHARTER_ADVERTISED | City of Peru explicitly states private charter flights can be arranged at Illinois Valley Regional; Midwest Aero provides Jet A, Avgas and maintenance. | [Source](https://www.peru.il.us/government/city-departments/airport-illinois-valley-regional-airport) |
| ULS | KS | GA_ONLY_EVIDENCE | October 2026 airport-specific listing confirms North Star Aviation FBO, Jet A, Avgas, pilot amenities; no current charter company corroborated. | [Source](https://www.iflightplanner.com/Airports/KULS) |
| OPL | LA | GA_ONLY_EVIDENCE | St Landry Parish airport administration documents open public-use airport and staffed operating hours; no charter/cargo airline named. | [Source](https://stlandrypg.org/departments/airport/) |
| JEF | MO | CHARTER_LISTED | Airport-specific current FBO directory lists Jefferson City Flying Service with aircraft charter alongside fuel, flight instruction and maintenance. Operating authority still to verify. | [Source](https://www.airnav.com/airport/KJEF) |
| OLV | MS | GA_ONLY_EVIDENCE | Olive Branch Aviation FBO offers fuel, ramp, passenger terminal and maintenance; airport service is business aviation, current charter operator not established here. | [Source](https://fbo.fltplan.com/index.cfm?f=8938) |
| BHK | MT | GA_ONLY_EVIDENCE | Fallon County confirms fuel maintenance and public airport. | [Source](https://falloncountymt.gov/airport/) |
| JYR | NE | GA_ONLY_EVIDENCE | Airport-specific directory identifies FBO fuel and maintenance. | [Source](https://www.iflightplanner.com/Airports/KJYR) |
| ASH | NH | CHARTER_SUPPORTED | Nashua Airport Authority explicitly reports charter and corporate flight operations at Boire Field; no scheduled airline route inferred. | [Source](https://nashuaairport.com/) |
| LCI | NH | GA_ONLY_EVIDENCE | Laconia city identifies two FBOs maintenance and hangars. | [Source](https://cityoflaconianh.org/975/Airport) |
| MJX | NJ | CHARTER_LISTED | Ocean County airport pilot website lists Ocean Aire charter service. | [Source](https://planning.co.ocean.nj.us/airport/frmPilotInfo) |
| MMU | NJ | CHARTER_SUPPORTED | Airport names based charter operator Short Hills Aviation. | [Source](https://www.mmuair.com/fly-mmu/charter/) |
| LAM | NM | GA_MEDICAL_ACTIVITY | Los Alamos County lists medical transport by Classic Air, research-laboratory/business aviation; no maintenance on field and fuel is self-service only. | [Source](https://www.losalamosnm.gov/Services/Los-Alamos-Airport) |
| XNI | NM | ACCESS_SERVICE_RESTRICTION | Andrew Othole Memorial Airport at Zuni is a high-elevation unattended public-use airport; FAA-based records identify gate access procedures, tie-downs only and no known commercial operator. | [Source](https://www.airnav.com/airport/KXNI) |
| TMT | NV | LIMITED_SERVICES | Nevada DOT lists Austin Airport TMT as public airport with 100LL, runway lighting and telephone, but no Jet A or maintenance listed. No commercial airline evidence. | [Source](https://www.dot.nv.gov/mobility/aviation/public-use-airports) |
| AOH | OH | CHARTER_ADVERTISED | Airport authority lists business and charter services, but does not establish a particular Part 135 operator in this source. | [Source](https://www.allencountyairport.com/) |
| HZY | OH | GA_ONLY_EVIDENCE | Airport authority identifies corporate/private aviation. | [Source](https://flyhzy.com/) |
| GUY | OK | GA_ONLY_EVIDENCE | Oklahoma authority confirms regional GA and business airport. | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/guymon-municipal.html) |
| SNL | OK | GA_ONLY_EVIDENCE | State airport directory confirms fuel maintenance and jets; charter unproven. | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/shawnee-regional.html) |
| 26U | OR | NO_FUEL_OR_FBO | Oregon state airport record explicitly lists no fuel FBO or repairs. | [Source](https://www.oregon.gov/aviation/airports/pages/mcdermitt-26u.aspx) |
| CVO | OR | CHARTER_ADVERTISED | Corvallis city airport page lists charter through airport FBO. | [Source](https://www.corvallisoregon.gov/airport) |
| CRE | SC | CHARTER_INFRASTRUCTURE | FBO handles executive charter arrivals; based carrier not proven. | [Source](https://www.myrtlebeachaviation.com/airport-information/) |
| BKX | SD | GA_ONLY_EVIDENCE | Brookings city reports public large general-aviation airport, SDSU training, corporate/private aircraft and Pheasants Fury Aviation FBO; certificated charter not established. | [Source](https://www.cityofbrookings-sd.gov/223/Airport) |
| CKV | TN | GA_ONLY_EVIDENCE | Clarksville Regional airport authority lists public-use Outlaw Field with 6000-foot main runway, FBO and terminal hours; commercial operator not established. | [Source](https://www.clarksvilleregional.com/airport-information) |
| FYM | TN | GA_ONLY_EVIDENCE | FBO and fuel with limited after-hours availability. | [Source](https://fayettevillemunicipalairport.com/) |
| MRC | TN | FREIGHT_HANDLING | Maury Regional airport FBO lists around-the-clock freight handling, loading/unloading and forklift service; this is NOT proof of a cargo airline. | [Source](https://www.flymaury.com/) |
| PVE | TN | GA_ONLY_EVIDENCE | October 2026 AOPA profile confirms public airport attended by Beech River Regional FBO with 100LL, Jet A and landing/ramp fees; airline not established. | [Source](https://www.aopa.org/destinations/airports/PVE/details) |
| ALI | TX | GA_ONLY_EVIDENCE | FAA listing confirms city FBO Jet A and services; charter unproven. | [Source](https://www.airnav.com/airport/ALI) |
| CDS | TX | RUNWAY_RESTRICTION | Runway 04/22 poor or unmaintained; check current NOTAM. | [Source](https://www.iflightplanner.com/Airports/KCDS) |
| GLE | TX | GA_ONLY_EVIDENCE | Current on-field municipal FBO listing shows Jet A and Avgas, aircraft maintenance and passenger lounge, without a verified charter airline. | [Source](https://www.flightaware.com/resources/airport/KGLE/services/FBO/Gainesville_Municipal_Airport) |
| HQZ | TX | GA_ONLY_EVIDENCE | City of Mesquite identifies airport and FBO with Jet A, 100LL and passenger/crew terminal; no specific commercial passenger or cargo operator. | [Source](https://cityofmesquite.com/653/FBO-Services-and-Amenities) |
| IKG | TX | GA_ONLY_EVIDENCE | Kleberg County airport FAA master record documents open public civilian airfield with Jet A/100LL, major repairs and staffed FBO; charter operator unconfirmed. | [Source](https://www.airnav.com/airport/IKG) |
| DAN | VA | NO_COMMERCIAL_AIR_SERVICE | City explicitly says airport has no commercial air service. | [Source](https://www.danville-va.gov/m/faq?cat=26) |
| RMN | VA | GA_ONLY_EVIDENCE | Stafford Regional airport operator lists FBO, aircraft maintenance and Aviation Adventures flight training; no charter operator named. | [Source](https://staffordairport.com/stafford-terminal/) |
| PWT | WA | GA_ONLY_EVIDENCE | Washington State DOT confirms Port of Bremerton-owned Bremerton National airport and publishes pavement/camera and airport-guide resources. Charter operations unconfirmed. | [Source](https://wsdot.wa.gov/travel/aviation/airports-list/bremerton-national) |
| MDZ | WI | GA_ONLY_EVIDENCE | Taylor County operator confirms corporate and GA fueling, 24-hour Jet A and avgas fuel, car rental; no named passenger charter carrier established. | [Source](https://co.taylor.wi.us/departments/airport/) |
| EAN | WY | GA_ONLY_EVIDENCE | Wyoming DOT identifies Phifer Airport general aviation terminal and lounge. | [Source](https://dot.state.wy.us/home/aeronautics/education-outreach/wy-fly-passport-program/visitor-station-locations.html) |

## Rules
Maintain the original 3,140 airports unchanged. Six game categories only: Local, Regional, Medium, Large, Major Hub and Mega Hub. `independent_review_at` records this first source review, not passenger/cargo/charter authorization. The actual final airport admission remains NOT_APPROVED until independently justified and explicitly approved.
