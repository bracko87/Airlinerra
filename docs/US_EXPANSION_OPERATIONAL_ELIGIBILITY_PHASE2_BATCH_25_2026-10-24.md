# Airlinerra — US Expansion Operational Eligibility Phase 2 — Batch 25 (2026-10-24)

**VERIFIED COMPLETE:** 50 new airport assessments, with 50 distinct immutable airport keys, directly read back from `airlinerra.airport_operational_triage`.

## Progress and controls

| Metric | Verified value |
|---|---:|
| Phase 2 assessed before Batch 25 | 1,166 |
| Batch 25 distinct new assessments | **50** |
| Phase 2 cumulative triaged | **1,216 / 1,929 (63.04%)** |
| Still pending Phase 2 | **713** |
| Batch 25 constraint holds | **14** |
| Batch 25 commercial/operator evidence gaps | **35** |
| Batch 25 provisional current-screen exclusions | **1** |
| All cumulative constraint holds | **438** |
| All cumulative evidence gaps | **706** |
| All cumulative identifier/source reconciliations | **64** |
| All cumulative provisional exclusions | **8** |
| Game admissions, world activations, game tier approvals | **0, 0, 0** |
| Original playable game airports | **3,140 unchanged** |

Phase 1 initial independent FAA/owner research was completed across all 1,929 expansion airports before this separate operational triage. Batch 25 source notes distinguish FAA runway/aircraft capability, time-limited owner/NOTAM operating conditions, cargo ground-handling from air cargo airline flights, and actual on-demand charter from scheduled passenger service. **No finding represents real-world flight safety clearance or automatic game admission.** Each row's unabridged previous evidence context, source date, action and UTC checked timestamp remain in Supabase.

## Highest-priority evidence

**PVJ — Pauls Valley Municipal, Oklahoma:** [Airport operator's published notice](https://www.paulsvalley.com/airport) and [airport homepage](https://www.paulsvalleyairport.com/) still say airport closed from **November 3, 2025 indefinitely until further notice** for runway 17/35 removal and reconstruction. Classified `CURRENT_SCREEN_INELIGIBLE` as a **provisional current operating screen**, NOT permanent disqualification. Reopen only after owner and active FAA NOTAM verification.

**PEO — Penn Yan–Yates County, New York:** [Official airport FBO listing](https://www.pennyanairport.org/fbo) and [Seneca Flight's own website](https://senecaflight.com/) explicitly confirm currently marketed **private charters** and FBO/airport management. Aviation fuel and 24h airside access are listed. This is positive commercial charter evidence but NOT confirmation of ordinary scheduled airline service or authorization of any future game fleet.

**PRO — Perry Municipal, Iowa:** [Iowa DOT current directory](https://opmapps.iowadot.gov/aviation/airports/PRO) reports **concrete 5,500×100ft RW14/32** and **separate turf 2,322ft RW04/22**. Old city copy showing 4,000ft pre-dates the documented runway extension. The turf runway fails Airlinerra's paved minimum but the concrete main qualifies for **further aircraft and carrier checks**. Iowa state airport data also mentions skydiving vicinity.

**ONP from Batch 24, not repeated here:** Newport's existing prior-permission rule for air carriers using aircraft with over 30 passenger seats remains relevant to interpreting the difference between owner operating conditions and blanket disqualification; this is a cross-check, not another Batch 25 assessment.

**PLD — Portland Municipal, Indiana:** 2026 FAA-derived 5,505ft asphalt runway record matches database and supersedes old 4,002ft city copy. A **12,500lb single-wheel pavement rating** requires operator verification before aircraft fit; physical length alone does not establish suitability.

**PHN — St Clair County International, Michigan:** Port of Entry status does not mean unrestricted international commercial flight rights. Confirm customs notice and aircraft/airport-owner permission.

**PMU — Panola County, Mississippi:** county describes no commercial flights, without clearly specifying a universal charter/cargo ban. Seek explicit owner clarification before rejecting every form of on-demand activity.

**PSF — Pittsfield, Massachusetts:** city identifies charter, freight-charter and medical flights as positive activity, but ground access and after-hours fees require coordinated permission.

**PSK — New River Valley, Virginia:** the airport's CBP port-of-entry and foreign-trade-zone identity do not alone certify international air cargo or provide advance customs authorization.

**PWK — Chicago Executive, Illinois:** FAA flight deck highlights busy O'Hare-related Class B/Executive Class D interactions, runway/approach patterns and need for correct local procedures, not a proof of scheduled airline service.

## Full Batch 25 source-backed evidence ledger — 50 distinct airports

Each finding and next verification is individually stored in Supabase along with the full earlier FAA/owner research and timestamp. Links document evidence leads; operational restrictions that can change need fresh dated NOTAM/owner validation.

| FAA | Immutable airport key | Review status | Airport-specific finding | Required follow-up | Evidence URLs | Source effective date |
|---|---|---|---|---|---|---|
| P20 | `OURAIRPORTS:20799` | `CONSTRAINT_CONFIRMED_HOLD` | Avi Suquilla has tribal ownership, public flight access and fuel but charter rights are unverified. | Obtain airport authority consent, runway load and certificated operator. | [Airport source](https://www.crit-nsn.gov/critair/) | 2026-10-01 |
| P33 | `OURAIRPORTS:20802` | `EVIDENCE_GAP_HOLD` | Cochise County Willcox Aviation offers fuel, training, repairs and aerial survey but no proven charter airline. | Validate county permission, operator certificate and aircraft limits. | [Airport source](https://www.cochise.az.gov/210/Cochise-County-Airport) | 2026-10-01 |
| PAN | `OURAIRPORTS:20804` | `CONSTRAINT_CONFIRMED_HOLD` | Payson field elevation 5157ft, runway 5504x75ft, intended for piston, turboprop and small business jets. | Check density altitude, terrain and aircraft performance with airport owner and certificated carrier. | [Airport source](https://www.paysonaz.gov/Departments/Airport/) | 2026-10-01 |
| PBF | `OURAIRPORTS:20807` | `EVIDENCE_GAP_HOLD` | Pine Bluff Grider Field has FBO and maintenance, not a named charter/freight carrier. | Verify licensed flight operator, ramp access and aircraft load. | [Airport source](https://www.pbf-airport.com/fbo/) | 2026-10-01 |
| PBH | `OURAIRPORTS:20809` | `EVIDENCE_GAP_HOLD` | Price County has 5220ft paved runway, Jet A and avgas supporting corporate GA; charter airline unverified. | Confirm operator certification, winter service and runway strength. | [Airport source](https://pricecounty.wi.gov/351/Airport) | 2026-10-01 |
| PBX | `OURAIRPORTS:20810` | `EVIDENCE_GAP_HOLD` | Pike County advertises shipping possibilities, not an active licensed cargo airline. | Find real air-cargo operator and rights, loading and handling. | [Airport source](https://pikevilleky.gov/pikeville-pike-county-airport-board/) | 2026-10-01 |
| PDC | `OURAIRPORTS:20814` | `EVIDENCE_GAP_HOLD` | Prairie du Chien is public GA with AWOS; passenger and cargo operator credentials unknown. | Check airport manager permission, services and operator certificate. | [Airport source](https://cityofpdc.com/airport) | 2026-10-01 |
| PEO | `OURAIRPORTS:20817` | `EVIDENCE_GAP_HOLD` | Penn Yan airport and Seneca Flight explicitly advertise on-demand private charters, daily FBO and 24h airside access; scheduled airline unverified. | Verify active Seneca Flight Part135 certificate and actual fleet, runway compatibility and owner approval. | [Airport source](https://www.pennyanairport.org/fbo) | 2026-10-01 |
| PEQ | `OURAIRPORTS:20818` | `EVIDENCE_GAP_HOLD` | Pecos city states no scheduled airline but corporate jets routinely use the airport; charter operator unknown. | Identify licensed charter/cargo operator and owner runway terms. | [Airport source](https://www.pecostx.gov/177/Municipal-Airport) | 2026-10-01 |
| PHG | `OURAIRPORTS:20827` | `CONSTRAINT_CONFIRMED_HOLD` | Phillipsburg current FAA record lists 5101ft concrete while older city webpage lists 4500ft; FAA matches pinned 1555m. | Confirm current as-built/declared length and aircraft load, owner permission. | [Airport source](https://www.airnav.com/airport/phg) | 2026-10-01 |
| PHN | `OURAIRPORTS:20830` | `CONSTRAINT_CONFIRMED_HOLD` | St Clair County Port Huron is airport of entry; specific CBP advance notices apply to cross-border flights. | Verify customs/CBP requirements, runway load and licensed operator. | [Airport source](https://www.airnav.com/airport/PHN) | 2026-10-01 |
| PHT | `OURAIRPORTS:20832` | `EVIDENCE_GAP_HOLD` | Henry County Paris has Jet A/avgas and 5001ft paved airport but no verified commercial passenger/cargo carrier. | Check owner runway load, air-taxi certification and permissions. | [Airport source](https://www.iflightplanner.com/Airports/KPHT) | 2026-10-01 |
| PIM | `OURAIRPORTS:20834` | `EVIDENCE_GAP_HOLD` | Harris County Pine Mountain publishes 5001ft paved runway, fuel and maintenance, not a licensed carrier. | Verify named operator certificate, owner approval and runway weight. | [Airport source](https://www.harriscountyga.gov/airport-2/) | 2026-10-01 |
| PKV | `OURAIRPORTS:20838` | `EVIDENCE_GAP_HOLD` | Calhoun County staff is daytime though Jet A/avgas are self-service around the clock; air carrier unverified. | Confirm after-hours ground response, aircraft load and charter authorization. | [Airport source](https://www.airnav.com/airport/PKV) | 2026-10-01 |
| PLD | `OURAIRPORTS:20839` | `CONSTRAINT_CONFIRMED_HOLD` | Portland Indiana latest FAA lists 5505ft paved runway and 12500lb single-wheel bearing; older city website 4002ft is outdated. | Use newer official geometry, match gear load and check airline operator rights. | [Airport source](https://www.airnav.com/airport/KPLD) | 2026-10-01 |
| PMH | `OURAIRPORTS:20843` | `CONSTRAINT_CONFIRMED_HOLD` | Greater Portsmouth County airport supports skydiving and aerial tours with fuel and fee terms, but air tour is not a licensed airline. | Verify active parachute windows, runway load and permitted Part135 flights. | [Airport source](https://www.sciotocountyoh.com/airport) | 2026-10-01 |
| PMU | `OURAIRPORTS:20845` | `CONSTRAINT_CONFIRMED_HOLD` | Panola County describes PMU as GA with no commercial flights; scope for charter versus airline is ambiguous. | Seek county written clarification of charter/cargo eligibility and actual operator. | [Airport source](https://panolacounty.com/economic-development/panola-info/logistics/) | 2026-10-01 |
| PMV | `OURAIRPORTS:20846` | `EVIDENCE_GAP_HOLD` | Plattsmouth Jet A needs prior arrangements with FBO, and no named cargo/charter carrier is confirmed. | Confirm Jet A callout, runway loads, carrier license and airport permission. | [Airport source](https://www.airnav.com/airport/PMV) | 2026-10-01 |
| PMZ | `OURAIRPORTS:20847` | `EVIDENCE_GAP_HOLD` | Plymouth Municipal has 0800-1700 staffed hours and after-hours callout; no licensed carrier established. | Check callout response, aircraft bearing and paid-use operator. | [Airport source](https://www.airnav.com/airport/PMZ) | 2026-10-01 |
| PNT | `OURAIRPORTS:20853` | `EVIDENCE_GAP_HOLD` | Pontiac Municipal has weekday and Saturday-morning coverage and pilot-activated runway lights, not verified charter service. | Verify commercial licensing, night support and runway loading. | [Airport source](https://www.airnav.com/airport/PNT) | 2026-10-01 |
| POF | `OURAIRPORTS:20855` | `EVIDENCE_GAP_HOLD` | Poplar Bluff city describes approximately 15000 annual general aviation movements and 5000ft runway, not an airline. | Identify actual licensed air taxi or air cargo operator and local owner terms. | [Airport source](https://www.poplarbluff-mo.gov/150/Municipal-Airport) | 2026-10-01 |
| POY | `OURAIRPORTS:20857` | `CONSTRAINT_CONFIRMED_HOLD` | Powell Wyoming has 6205ft paved runway with 24h fuel, with high plains winter condition yet to verify. | Check actual snow runway, aircraft performance, owner approval and licensed carrier. | [Airport source](https://cityofpowell.com/municipal-airport/) | 2026-10-01 |
| PPA | `OURAIRPORTS:20858` | `EVIDENCE_GAP_HOLD` | Perry Lefors Pampa Aircraft FBO supplies Jet A and avgas, with no commercial passenger/cargo operator independently documented. | Confirm named operator certificate, city access and wheel loading. | [Airport source](https://www.airnav.com/airport/KPPA) | 2026-10-01 |
| PPF | `OURAIRPORTS:20859` | `EVIDENCE_GAP_HOLD` | Parsons Tri-City has lounge, meeting space and hangars; this is not evidence of an operating licensed charter/cargo airline. | Verify runway weight, owner commercial-use rules and operator credentials. | [Airport source](https://www.parsonsks.com/airport) | 2026-10-01 |
| PPO | `OURAIRPORTS:20860` | `EVIDENCE_GAP_HOLD` | La Porte municipal staffed public GA field with runway lighting aids does not establish an operating passenger or air-freight company. | Check runway loading, city permit and real Part135/cargo operator. | [Airport source](https://www.airnav.com/airport/PPO) | 2026-10-01 |
| PQL | `OURAIRPORTS:20862` | `EVIDENCE_GAP_HOLD` | Trent Lott International Jackson County Mississippi markets charter-capable aviation and corporate flights at its 6500ft runway, not a currently verified licensed airline route. | Verify actual carrier certificate, aircraft and airport handling/owner permissions. | [Airport source](https://www.co.jackson.ms.us/153/Airport) | 2026-10-01 |
| PRN | `OURAIRPORTS:20866` | `EVIDENCE_GAP_HOLD` | Mac Crenshaw Memorial Greenville Alabama has 5501ft runway and weekday FBO service, no current certificated passenger/cargo operator identified. | Confirm service hours, approved charter/cargo flight operator and aircraft load. | [Airport source](https://www.airnav.com/airport/PRN) | 2026-10-01 |
| PRO | `OURAIRPORTS:20867` | `CONSTRAINT_CONFIRMED_HOLD` | Perry Iowa DOT confirms 5500×100ft concrete RW14/32 and separate 2322ft turf RW04/22, with skydiving vicinity. Old 4000ft city description predates extension. | Screen concrete primary only, coordinate skydiving and obtain charter certification and airport rights. | [Airport source](https://www.perryia.org/city-projects-blog/perry-municipal-airport-runway-reconstruction-expansion); [Additional](https://opmapps.iowadot.gov/aviation/airports/PRO) | 2026-10-01 |
| PSF | `OURAIRPORTS:20871` | `CONSTRAINT_CONFIRMED_HOLD` | Pittsfield city confirms private charter, freight charter and medevac activity, but secure gate/access and after-hours staffing charges need arrangement. | Confirm airfield gated access/handling fees and named licensed freight/charter operator with aircraft fit. | [Airport source](https://www.pittsfieldma.gov/161/Airport) | 2026-10-01 |
| PSK | `OURAIRPORTS:20872` | `CONSTRAINT_CONFIRMED_HOLD` | New River Valley Airport Virginia operates a CBP port of entry and FTZ 238 for business/GA, but customs and international cargo rights are not automatically available without specific cle... | Verify CBP advance permission, cargo documentation, owner landing rules and certificated operator. | [Airport source](https://newrivervalleyairport.com/) | 2026-10-01 |
| PSN | `OURAIRPORTS:20873` | `EVIDENCE_GAP_HOLD` | Palestine Municipal Texas city airport services support GA fueling but no active licensed commercial flight operator is documented. | Confirm runway strength and airport-approved Part135/cargo service. | [Airport source](https://www.cityofpalestinetx.com/210/Airport) | 2026-10-01 |
| PTB | `OURAIRPORTS:20875` | `EVIDENCE_GAP_HOLD` | Dinwiddie County Airport Virginia has Jet A/avgas FBO and 5002ft paved runway; after-hours ground support requires arrangement, commercial operator unverified. | Confirm FBO callout, aircraft pavement load, and certificated charter/cargo operator. | [Airport source](https://www.fltplan.com/AirportInformation/PTB.htm) | 2026-10-01 |
| PTS | `OURAIRPORTS:20878` | `EVIDENCE_GAP_HOLD` | Atkinson Municipal Pittsburg Kansas has GA FBO capable of serving corporate jets, fuel and maintenance, but no named charter/cargo airline. | Verify active Part135 operator, owner use and aircraft/airfield match. | [Airport source](https://fbo.fltplan.com/fbo.cfm?fid=3305) | 2026-10-01 |
| PTT | `OURAIRPORTS:20879` | `EVIDENCE_GAP_HOLD` | Pratt Kansas airport authority reports 5500x100ft concrete RW17/35, Jet A/avgas and daytime FBO, no verified licensed airline. | Confirm lawful charter/cargo service and runway-specific load with airport. | [Airport source](https://prattairportauthority.com/details.html) | 2026-10-01 |
| PTV | `OURAIRPORTS:20880` | `EVIDENCE_GAP_HOLD` | Porterville Municipal California listing confirms fuel and major repairs but no named licensed passenger/freight operator. | Verify airport owner paid-flight rules, runway load and actual certificate. | [Airport source](https://www.gcr1.com/5010ReportRouter/default.aspx?airportID=PTV) | 2026-10-01 |
| PVE | `OURAIRPORTS:20886` | `EVIDENCE_GAP_HOLD` | Beech River Regional Tennessee FBO provides Jet A/100LL and publishes ramp/landing fees, but these do not establish actual certified airline service. | Check specific operator certificate, fuel/ground hours and wheel-bearing capacity. | [Airport source](https://www.aopa.org/destinations/airports/PVE/details) | 2026-10-01 |
| PVJ | `OURAIRPORTS:20889` | `CURRENT_SCREEN_INELIGIBLE` | Pauls Valley Municipal Oklahoma city and official airport homepage still state airport closed from November 3 2025 indefinitely until further notice for replacement of RW17/35; October 20... | Obtain currently effective FAA NOTAM and owner written runway-reopening confirmation before rescreening or any gameplay activation. | [Airport source](https://www.paulsvalley.com/airport); [Additional](https://www.paulsvalleyairport.com/) | 2026-10-01 |
| PWG | `OURAIRPORTS:20895` | `EVIDENCE_GAP_HOLD` | McGregor Executive near Waco Texas has a staffed FBO and public runway, with no named current licensed charter/cargo airline evidenced. | Verify actual operator certificate, airport owner terms and runway strength. | [Airport source](https://www.airnav.com/airport/PWG) | 2026-10-01 |
| PWK | `OURAIRPORTS:20896` | `CONSTRAINT_CONFIRMED_HOLD` | Chicago Executive is GA/business field in Class D below O'Hare Class B; FAA notes IFR approach/circle-to-land operational considerations, plus customs subject to advance arrangements. | Check current class/approach requirements and airport aircraft constraints, CBP authorizations and licensed charter operator. | [Airport source](https://www.faa.gov/flight_deck/pwk) | 2026-10-01 |
| PXE | `OURAIRPORTS:20897` | `EVIDENCE_GAP_HOLD` | Perry Houston County Georgia field staffed about 0800–1800, holidays may be unattended, and after-hours service needs a call; no charter company confirmed. | Verify ground handling for game-date flights, runway loading and licensed operator. | [Airport source](https://www.airnav.com/airport/PXE) | 2026-10-01 |
| PYX | `OURAIRPORTS:20902` | `EVIDENCE_GAP_HOLD` | Perryton Ochiltree Texas has Knox Aviation FBO and Jet A/100LL, but no named certificated passenger/freight operation. | Validate air-carrier license, winter fuel/support and aircraft load. | [Airport source](https://www.airnav.com/airport/KPYX) | 2026-10-01 |
| RBW | `OURAIRPORTS:20915` | `EVIDENCE_GAP_HOLD` | Lowcountry Regional South Carolina aeronautics source confirms public airport, runway services and staff, without demonstrating scheduled or licensed charter/cargo route. | Obtain operating carrier details and county permissions, runway wheel loading. | [Airport source](https://aeronautics.sc.gov/airports/lowcountry-rgnl-airport) | 2026-10-01 |
| RCR | `OURAIRPORTS:20917` | `EVIDENCE_GAP_HOLD` | Fulton County Rochester Indiana has Jet A/100LL, maintenance, training and medical helicopter. Medical helicopter presence does not establish scheduled passenger airline. | Verify separate fixed-wing charter/cargo company and airport aircraft/ground rights. | [Airport source](https://www.fultoncountyairport.net/) | 2026-10-01 |
| RCZ | `OURAIRPORTS:20920` | `EVIDENCE_GAP_HOLD` | Richmond County North Carolina runs public GA field with hangar rentals, no tower and no repairs; air-carrier credentials absent. | Verify county paid-use conditions, fuel/emergency support and qualified operator. | [Airport source](https://www.richmondnc.com/244/Airport) | 2026-10-01 |
| RDK | `OURAIRPORTS:20921` | `CONSTRAINT_CONFIRMED_HOLD` | Red Oak Iowa DOT lists 5100ft concrete RW05/23 and separate turf strip closed seasonally in winter; turf restriction does not close concrete main. | Screen concrete primary runway only, winter service, aircraft load and owner-certified charter/cargo permissions. | [Airport source](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=RDK) | 2026-10-01 |
| RHP | `OURAIRPORTS:20927` | `CONSTRAINT_CONFIRMED_HOLD` | Western Carolina Regional North Carolina has Jet A, avgas, repairs and variable attendance amid Appalachian terrain; aircraft terrain/weather fit and ground handling require validation. | Review mountain approach/climb, runway wheel load, FBO hours, lawful charter operator. | [Airport source](https://www.airnav.com/airport/RHP) | 2026-10-01 |
| RID | `OURAIRPORTS:20929` | `EVIDENCE_GAP_HOLD` | Richmond Municipal Indiana city advertises freight unloading and delivery by arrangement, on ~5502ft asphalt; freight ground services alone do not prove air-cargo route. | Identify actual certificated cargo airline, load handling contract and owner runway permission. | [Airport source](https://www.richmondindiana.gov/resources/municipal-airport) | 2026-10-01 |
| RKP | `OURAIRPORTS:20936` | `EVIDENCE_GAP_HOLD` | Aransas County Texas county aviation page identifies FBO, fuel and maintenance, but not actual licensed charter/freight operator. | Confirm carrier credentials, coastal operating conditions and runway rating. | [Airport source](https://aransascountyairport.com/) | 2026-10-01 |
| RKW | `OURAIRPORTS:20938` | `EVIDENCE_GAP_HOLD` | Rockwood Tennessee municipal GA 5000x100ft runway with Rockwood Aviation FBO, training, Jet A and avgas; no verified current scheduled or charter operator. | Seek current Part135/cargo license and airport manager operating terms. | [Airport source](https://cityofrockwoodtn.gov/rockwood-municipal-airport/) | 2026-10-01 |
| RMN | `OURAIRPORTS:20941` | `EVIDENCE_GAP_HOLD` | Stafford Regional Virginia operator reports FBO, repairs and Aviation Adventures training, not an operating certified passenger or freight airline. | Confirm county charter authorization, operator certificate and runway wheel strength. | [Airport source](https://staffordairport.com/stafford-terminal/) | 2026-10-01 |

## Batch 26 — first 20 airports still pending

These airport keys remain `PENDING` and have not yet been included in the 1,216 assessments.

| FAA | State | Immutable airport key |
|---|---|---|
| RNC | TN | `OURAIRPORTS:20943` |
| RNH | WI | `OURAIRPORTS:20944` |
| RNM | CA | `OURAIRPORTS:20945` |
| RNT | WA | `OURAIRPORTS:20947` |
| RNV | MS | `OURAIRPORTS:20948` |
| ROG | AR | `OURAIRPORTS:20949` |
| RPH | TX | `OURAIRPORTS:20954` |
| RPJ | IL | `OURAIRPORTS:20955` |
| RPX | MT | `OURAIRPORTS:20956` |
| RQB | MI | `OURAIRPORTS:20957` |
| RRL | WI | `OURAIRPORTS:20959` |
| RRT | MN | `OURAIRPORTS:20961` |
| RSL | KS | `OURAIRPORTS:20962` |
| RSN | LA | `OURAIRPORTS:20963` |
| RSV | IL | `OURAIRPORTS:20964` |
| RUE | AR | `OURAIRPORTS:20966` |
| RUQ | NC | `OURAIRPORTS:20968` |
| RVJ | GA | `OURAIRPORTS:20969` |
| RVL | PA | `OURAIRPORTS:20970` |
| RVS | OK | `OURAIRPORTS:20972` |

## Explicit game protection

Airlinerra's six airport categories remain **Local, Regional, Medium, Large, Major Hub, Mega Hub**. Every U.S. expansion candidate stays `NOT_APPROVED` for gameplay and the existing **3,140-airport** playable cohort is unchanged. Actual subsequent airport admission would require runway-specific paved and usable declared landing distance, wheel load, effective NOTAM, suitable aircraft performance, owner or tribal airfield permission, fuel/ground operations and legally certificated named passenger/charter/cargo providers. No such final approval occurred in Batch 25.

*Phase 2 research dated 2026-10-24; not a commercial aviation operating clearance.*
