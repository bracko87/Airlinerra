# Airlinerra — Phase 2 Batch 23 (October 24, 2026)

**Supabase verified:** 50 unique new airport reviews. Total Phase 2 reviewed **1,116/1,929**, pending **813**. Batch 23 = **21 constraint holds, 26 evidence gaps, 3 airport-source/identifier reconciliations**.

**Gameplay safeguarded:** 0 new approvals, 0 activations, original 3,140-airport roster unchanged; exactly six game categories retained: Local, Regional, Medium, Large, Major Hub, Mega Hub. Findings are preliminary source-research triage, not commercial airport clearance or permanent denial.

## High-priority cases

- **HFJ:** source note mistakenly describes Neosho, not Monett Regional. [FAA verifies KHFJ/Monett](https://www.faa.gov/air_traffic/flight_info/aeronav/procedures/application/index.cfm?event=procedure.results&nasrId=HFJ). Reconcile original research.
- **MTH:** [Monroe County](https://www.monroecounty-fl.gov/m/faq?cat=27) says no regularly scheduled airlines; [airport project page](https://eyw.com/marathon-international-airport) describes efforts to introduce scheduled flights, not a currently operating route.
- **MTO:** [Airport authority](https://www.flymto.com/about) reports Part139 certification, no current scheduled passenger airline, but charter services available.
- **LXV:** Leadville is extremely high elevation, so density-altitude and airplane climb/payload must be evaluated, not just runway length.
- **MGY:** RW20 threshold displacement reduces landing distance, while MNN has a taxiway-specific 35ft wingspan restriction; neither is an automatic whole-airport closure.
- **MRC:** freight handling by FBO is not automatically a certificated air cargo route.

## 50 airport records and evidence

Full independent individual findings, dated evidence, actions and audit timestamps are stored in Supabase `airlinerra.airport_operational_triage`.

| FAA | Immutable key | Triage status | Individual issue | Primary source |
|---|---|---|---|---|
| ADF | `OURAIRPORTS:20461` | `SOURCE_IDENTITY_RECONCILIATION` | FORMER_M89_CURRENT_ADF | [Evidence](https://www.airnav.com/airport/ADF) |
| FYG | `OURAIRPORTS:20541` | `SOURCE_IDENTITY_RECONCILIATION` | FORMER_MO6_CURRENT_FYG | [Evidence](https://www.airnav.com/airport/KFYG) |
| HFJ | `OURAIRPORTS:20444` | `SOURCE_IDENTITY_RECONCILIATION` | SOURCE_NOTE_BELONGS_TO_NEOSHO | [Evidence](https://www.neoshomo.gov/160/Airport) |
| M46 | `OURAIRPORTS:20436` | `CONSTRAINT_CONFIRMED_HOLD` | NO_FUEL_REPAIRS | [Evidence](https://rosebudcountymt.gov/departments/airport/) |
| M54 | `OURAIRPORTS:20442` | `CONSTRAINT_CONFIRMED_HOLD` | LIGHTING_PAPI_PROJECT_NOT_FINISHED | [Evidence](https://www.lebanontn.org/AgendaCenter/ViewFile/Agenda/_02052026-908) |
| M91 | `OURAIRPORTS:20463` | `EVIDENCE_GAP_HOLD` | FBO_FUEL_TRAINING_NOT_CARRIER | [Evidence](https://www.iflightplanner.com/Airports/M91) |
| MAI | `OURAIRPORTS:20470` | `CONSTRAINT_CONFIRMED_HOLD` | OCT_2026_RUNWAY_TAXI_PROPOSED_REHAB | [Evidence](https://www.cityofmarianna.com/AgendaCenter/ViewFile/Agenda/_10132026-557?html=true) |
| MAW | `OURAIRPORTS:20473` | `CONSTRAINT_CONFIRMED_HOLD` | JET_A_ADVANCE_NOTICE | [Evidence](https://airnav.com/airport/maw) |
| MBY | `OURAIRPORTS:20478` | `CONSTRAINT_CONFIRMED_HOLD` | COMMERCIAL_AIRCRAFT_LOCAL_RESOLUTION | [Evidence](https://www.moberlymo.org/321/Omar-N-Bradley-Regional-Airport) |
| MCX | `OURAIRPORTS:20483` | `CONSTRAINT_CONFIRMED_HOLD` | NO_ONFIELD_MECHANIC_FUEL_TRUCK_PPR | [Evidence](https://mcxaero.godaddysites.com/) |
| MCZ | `OURAIRPORTS:20484` | `EVIDENCE_GAP_HOLD` | OLD_2016_AIRPORT_EVIDENCE | [Evidence](https://martincountyedc.com/mcz-jetport/) |
| MDD | `OURAIRPORTS:20486` | `CONSTRAINT_CONFIRMED_HOLD` | BUSINESS_AIRPARK_FEES_OVER_30000LB | [Evidence](https://www.flymaf.com/airport-information/airpark/) |
| MDS | `OURAIRPORTS:20489` | `EVIDENCE_GAP_HOLD` | STATE_BII_PLANNING_NOT_GAME_TIER | [Evidence](https://dot.sd.gov/media/documents/AviationSystemPlan/Chapter%203%20SDSASP%20Airport%20Roles_FINAL.pdf) |
| MDZ | `OURAIRPORTS:20490` | `EVIDENCE_GAP_HOLD` | CORPORATE_JETA_NO_CERTIFIED_ROUTE | [Evidence](https://co.taylor.wi.us/departments/airport/) |
| MEB | `OURAIRPORTS:20491` | `CONSTRAINT_CONFIRMED_HOLD` | PARACHUTING_CONFLICT_NOT_RUNWAY_BAN | [Evidence](https://www.ncdot.gov/divisions/aviation/NC%20Airports/AirportGuideMEB.pdf) |
| MFV | `OURAIRPORTS:20497` | `CONSTRAINT_CONFIRMED_HOLD` | OCT2026_INSTRUMENT_APPROACH_OUTAGE | [Evidence](https://doav.virginia.gov/airport-directory/) |
| MGJ | `OURAIRPORTS:20499` | `CONSTRAINT_CONFIRMED_HOLD` | MULTIPLE_TRAFFIC_PATTERNS | [Evidence](https://www.airnav.com/airport/MGJ) |
| MGR | `OURAIRPORTS:20501` | `EVIDENCE_GAP_HOLD` | FBO_BOTH_FUEL_GRADES_NO_CARRIER | [Evidence](https://www.airnav.com/airport/MGR) |
| MGY | `OURAIRPORTS:20502` | `CONSTRAINT_CONFIRMED_HOLD` | RW20_590FT_DISPLACED_THRESHOLD | [Evidence](https://flydayton.com/dayton-wright-brothers-airport/) |
| MHL | `OURAIRPORTS:20504` | `CONSTRAINT_CONFIRMED_HOLD` | SEASONAL_ATTENDANCE_24H_SELF_FUEL | [Evidence](https://www.airnav.com/airport/MHL) |
| MHP | `OURAIRPORTS:20505` | `EVIDENCE_GAP_HOLD` | METTER_GA_DISTINCT_MANCHESTER_NH | [Evidence](https://airport-data.com/airport/MHP/) |
| MIO | `OURAIRPORTS:20509` | `EVIDENCE_GAP_HOLD` | OKLAHOMA_REGIONAL_BUSINESS_NOT_GAME | [Evidence](https://oklahoma.gov/aerospace/airports/find-an-airport/miami-regional.html) |
| MJD | `OURAIRPORTS:20512` | `EVIDENCE_GAP_HOLD` | CITY_HANGARS_NOT_CARRIER | [Evidence](https://www.picayune.ms.us/180/Airport) |
| MJX | `OURAIRPORTS:20514` | `EVIDENCE_GAP_HOLD` | OCEAN_AIRE_CHARTER_MARKETING_LEAD | [Evidence](https://planning.co.ocean.nj.us/airport/frmPilotInfo) |
| MKJ | `OURAIRPORTS:20516` | `CONSTRAINT_CONFIRMED_HOLD` | APPALACHIAN_TERRAIN_REGIONAL_LABEL | [Evidence](https://doav.virginia.gov/airport_sponsors/) |
| MKY | `OURAIRPORTS:20521` | `CONSTRAINT_CONFIRMED_HOLD` | DISPLACED_THRESHOLDS_COUNTY_AFTERHOURS | [Evidence](https://www.collier.gov/County-Development/Transportation-Management/Airport-Authority/Marco-Island-Executive-Airport) |
| MLD | `OURAIRPORTS:20522` | `CONSTRAINT_CONFIRMED_HOLD` | HIGH_DESERT_NARROW_RUNWAY_NO_STAFF | [Evidence](https://www.airnav.com/airport/MLD) |
| MLF | `OURAIRPORTS:20524` | `CONSTRAINT_CONFIRMED_HOLD` | HIGH_ALTITUDE_FUEL_24H | [Evidence](https://milfordcityutah.com/visitors/airport) |
| MLJ | `OURAIRPORTS:20525` | `EVIDENCE_GAP_HOLD` | GEORGIA_COUNTY_GA_NO_CERTIFIED_OPERATOR | [Evidence](https://www.visitmilledgeville.org/plan-your-trip/before-your-visit/directions/) |
| MMI | `OURAIRPORTS:20528` | `EVIDENCE_GAP_HOLD` | POSITIVE_FACTORY_FREIGHT_NOT_SCHEDULED_CARGO | [Evidence](https://mcminncountytn.gov/airport.html) |
| MNM | `OURAIRPORTS:20535` | `EVIDENCE_GAP_HOLD` | COUNTY_24H_FUEL_NOT_CARRIER | [Evidence](https://www.menomineecountymi.gov/departments/menominee-regional-airport/) |
| MNN | `OURAIRPORTS:20536` | `CONSTRAINT_CONFIRMED_HOLD` | TAXIWAY_D_35FT_WINGSPAN_CAP | [Evidence](https://www.iflightplanner.com/Airports/KMNN) |
| MNZ | `OURAIRPORTS:20538` | `EVIDENCE_GAP_HOLD` | HAMILTON_TEXAS_FUEL_GA_NOT_CERTIFICATE | [Evidence](https://www.hamiltontexas.com/149/Airport) |
| MO8 | `OURAIRPORTS:20542` | `EVIDENCE_GAP_HOLD` | NORTH_CENTRAL_MISSOURI_GA_NO_CERTIFICATE | [Evidence](https://www.airnav.com/airport/MO8) |
| MOR | `OURAIRPORTS:20544` | `EVIDENCE_GAP_HOLD` | REGIONAL_TITLE_NO_AIRLINE_AT_FIELD | [Evidence](https://selectmorristowntn.com/location-logistics/) |
| MPE | `OURAIRPORTS:20546` | `EVIDENCE_GAP_HOLD` | PHILADELPHIA_MS_NOT_PHL | [Evidence](https://www.iflightplanner.com/Airports/KMPE) |
| MPJ | `OURAIRPORTS:20548` | `CONSTRAINT_CONFIRMED_HOLD` | ARKANSAS_STATE_PARK_GA_OWNER_RULES | [Evidence](https://fly.arkansas.gov/morrilton.html) |
| MPO | `OURAIRPORTS:20549` | `EVIDENCE_GAP_HOLD` | MOYER_CHARTER_LEADS_HISTORICAL | [Evidence](https://www.pa.gov/agencies/penndot/traveling-in-pa/airports/pocono-mountains-municipal-airport) |
| MPR | `OURAIRPORTS:20550` | `EVIDENCE_GAP_HOLD` | MEDICAL_PIPELINE_FLIGHTS_NOT_AIRLINE | [Evidence](https://www.airnav.com/airport/KMPR) |
| MPV | `OURAIRPORTS:20551` | `EVIDENCE_GAP_HOLD` | AMERIFLIGHT_CARGO_LINK_NOT_ROUTE_PROOF | [Evidence](https://vtrans.vermont.gov/aviation/airports/knapp) |
| MQJ | `OURAIRPORTS:20555` | `EVIDENCE_GAP_HOLD` | INDIANAPOLIS_REGIONAL_JET_ACCESS_FBO | [Evidence](https://www.ind.com/business/general-aviation-airports/indianapolis-regional-airport) |
| MRC | `OURAIRPORTS:20557` | `EVIDENCE_GAP_HOLD` | FREIGHT_HANDLING_SERVICE_NOT_AIR_CARGO_AIRLINE | [Evidence](https://www.flymaury.com/) |
| MRF | `OURAIRPORTS:20558` | `CONSTRAINT_CONFIRMED_HOLD` | MARFA_HIGH_DESERT_BUSINESS_PRIVATE | [Evidence](https://visitmarfa.com/travel) |
| MRH | `OURAIRPORTS:20559` | `EVIDENCE_GAP_HOLD` | GA_COUNTY_FIELD_NOT_NEARBY_EWN | [Evidence](https://www.carteretcountync.gov/2396/Port-and-Airports) |
| MRJ | `OURAIRPORTS:20560` | `EVIDENCE_GAP_HOLD` | 24H_FUEL_AND_SNOW_NOT_CARRIER | [Evidence](https://www.iowacountywi.gov/directory/Airport) |
| MRN | `OURAIRPORTS:20561` | `EVIDENCE_GAP_HOLD` | FOOTHILLS_FBO_HOURS_NO_CERTIFIED_ROUTE | [Evidence](https://www.foothillsairport.com/airport-authority-board-and-staff) |
| MSV | `OURAIRPORTS:20563` | `CONSTRAINT_CONFIRMED_HOLD` | LARGE_JET_RESERVATION_REQUIRED | [Evidence](https://www.sullivanny.gov/Departments/Airport) |
| MTH | `OURAIRPORTS:20564` | `EVIDENCE_GAP_HOLD` | NO_SCHEDULED_PASSENGER_CURRENT_FUTURE_PLANS | [Evidence](https://www.monroecounty-fl.gov/m/faq?cat=27) |
| MTO | `OURAIRPORTS:20566` | `EVIDENCE_GAP_HOLD` | PART139_CERTIFIED_NO_SCHEDULED_AIRLINE_WITH_CHARTER | [Evidence](https://www.flymto.com/) |
| MTV | `OURAIRPORTS:20568` | `CONSTRAINT_CONFIRMED_HOLD` | BLUE_RIDGE_APPALACHIAN_TERRAIN_BUSINESS | [Evidence](https://doav.virginia.gov/airport_sponsors/) |

**Next:** Phase 2 Batch 24 — next 50 still-pending airports, retaining `NOT_APPROVED` until separate game admission review.


## Verified individual findings and follow-ups — Part 1 (25 records)

| FAA | Source-specific finding | Action to complete |
|---|---|---|
| ADF | Dexter B Florence Memorial Airport Arkadelphia Arkansas has historic source KM89 and current code ADF/KADF; public GA identification requires documented FAA historical... | Validate M89→ADF FAA lineage and coordinates, retain original airport key, assess licensed operator and pavement after reconciliation. |
| FYG | Washington Regional Missouri registry source KMO6 and current GPS KFYG use same location pending FAA historical code reconciliation; first-pass FAA data notes Apr-Oct ... | Reconcile MO6→FYG official FAA code/coords under immutable airport key and check seasonal FBO and carrier rights. |
| HFJ | Monett Regional HFJ/KHFJ is in Monett Missouri (verified via FAA procedure directory), but Batch21 first-pass note accidentally attributes Neosho city/Hugh Robinson Me... | Discard cross-attributed Neosho research as evidence for Monett; fetch Monett/FAA source and airport actual operator; preserve immutable Monett key. |
| M46 | Colstrip/Ricks Field Montana public-use runway ~5,100ft with PAPI and pilot amenities but Rosebud County reports NO airport fuel or maintenance. | Confirm current fuel/no-repair provision, turbine dispatch options, remote winter support and licensed operator/owner permission. |
| M54 | Lebanon Tennessee M54 February 2026 city airport agenda discusses runway PAPI/lighting work, corporate hangars and safety assessment; planned work is not evidence of c... | Check completed-as-built runway lights/PAPI and current NOTAM, pavement load and actual charter operator. |
| M91 | Springfield Robertson County Tennessee provides Jet A/100LL, Wingnuts Aviation maintenance and Highland Rim flight training; no named certificated scheduled/charter/ca... | Confirm runway load, actual Part135/air-freight operator, owner commercial use standards and FBO support. |
| MAI | Marianna Florida October 2026 council documentation considers RW08/26 rehabilitation and Taxiway B reconstruction; proposed repair scope does not itself establish a cu... | Obtain city works timing/FAA NOTAM and runway/taxiway availability for game date, aircraft type and carrier rights. |
| MAW | Malden Regional Missouri airport-specific FAA-derived fuel source indicates Jet A requires advance call; don't assume instant turbine fueling or infer entire airport c... | Verify current Jet A advance notice and hours, pavement load, actual charter/cargo operator. |
| MBY | Moberly Missouri publishes an Airport Resolution for Commercial Aircraft and terminal/runway details; local commercial-aircraft rules need reading before commercial fl... | Obtain exact operative city commercial-aircraft resolution and flight approval, runway load and qualified operator certificate. |
| MCX | White County Indiana MCX Aero states 24-hour self-service Jet A/100LL and fuel truck by advance scheduling, but expressly no mechanic on field at present. | Check current repairs/maintenance logistics, truck appointment and aircraft runway rating, airport-commercial permission. |
| MCZ | Martin County/Williamston North Carolina airport site uses 2016 FAA reference data and GA public jetport descriptions, insufficient for 2026 carrier and runway operati... | Refresh current FAA NASR/owner commercial authorization, paved runway and operator certifications. |
| MDD | Midland Airpark Texas has two paved runways, Basin Aviation FBO and owner landing/handling fees for aircraft above 30,000lb; a fee trigger must not be misread as struc... | Verify current fee tariff versus gear load rating and per-runway LDA; obtain appropriate charter/cargo permission, do not import MAF flights. |
| MDS | Madison Municipal South Dakota has 5,000ft paved runway, Jet A/100LL and major repairs. South Dakota FAA B-II planning designation is an airport design reference, not ... | Check certified operator, available winter support, declared runway loading and city consent. |
| MDZ | Taylor County Wisconsin county confirms corporate/GA aviation, 24h Jet A/avgas and rental car support but not a named certified charter/cargo operator. | Confirm actual Part135/freight carrier, after-hours operational support, snow and pavement load. |
| MEB | Laurinburg–Maxton North Carolina airport NCDOT guide lists FBO, Jet A/avgas, maintenance and active parachute operations, with ~6,500ft paved runway. | Validate active drop zone windows/NOTAM, traffic separation, runway weight and certificated airline/charter use. |
| MFV | Accomack County Virginia October 2026 first-pass FAA notice flags instrument approach outages; current notice effective dates must be checked and do not imply physical... | Recheck published IAP NOTAM status and workable VFR/IFR procedures, runway/aircraft/charter rights. |
| MGJ | Orange County New York public airport has published multiple traffic pattern considerations for aircraft on different runways; GA intensity and aviation procedures nee... | Verify specific runway/CTAF traffic pattern, present NOTAM, load, operator certification and airport permission. |
| MGR | Moultrie Municipal Georgia 6,000ft paved airport and FBO/Jet A/100LL crew services are confirmed, but certificated passenger/cargo operator unknown. | Request FBO certified charter/cargo current activity, city commercial consent and runway weight. |
| MGY | Dayton Wright Brothers Ohio operator identifies RW20 displaced threshold 590ft on nominal 5,000ft paved runway, reducing usable landing distance on that end. FBO suppl... | Check FAA current RW20 LDA and approach restriction, fleet landing performance/weight and authorized Part135/cargo. |
| MHL | Marshall Municipal Missouri FAA-derived listing has 24h self-service Jet A1/100LL but varying seasonal attendance; fuel availability is not continuously staffed service. | Confirm seasonal manager/ramp coverage, snow and operator authorization separate from unattended runway access. |
| MHP | Metter Municipal Georgia MHP is John Edwin Jones Sr Field, 5,001ft paved with Jet A/avgas, maintenance; no passenger/cargo operator confirmed. Must not confuse with Ma... | Validate city commercial permissions and actual Part135/cargo provider, runway load. |
| MIO | Miami Municipal Oklahoma has 5,020ft asphalt, Jet A/avgas and state Regional Business classification, without verified operating commercial airline. | Check airport licensed charter or airfreight certificate, runway strength and city permissions; don't use planning term as game category. |
| MJD | Picayune Municipal Mississippi city advertises GA terminal/hangars and county manager; no currently verified passenger charter/cargo flight operator. | Verify owner commercial-use standards, ground support and specific carrier certificate. |
| MJX | Ocean County New Jersey airport pilot information names Ocean Aire charter service; current operator certificate, aircraft and actual flights remain to be validated. | Verify Ocean Aire current Part135 fleet, permit, runway rating, airport noise and operator rights. |
| MKJ | Mountain Empire at Rural Retreat Virginia is state-designated Regional Business but in Appalachian terrain; no named certificated carrier and type-specific mountain ap... | Confirm FAA runway LDA, elevation/obstacles/weather and certified operator/owner access. |


## Continued airport-specific review (records 26–50)

[Open the supplemental ledger of 25 individually verified findings and follow-up actions](US_EXPANSION_OPERATIONAL_ELIGIBILITY_PHASE2_BATCH_23_ACTIONS_PART_2_2026-10-24.md). Together with the 25 expanded findings above, this completes the 50 detailed Batch 23 assessments.
