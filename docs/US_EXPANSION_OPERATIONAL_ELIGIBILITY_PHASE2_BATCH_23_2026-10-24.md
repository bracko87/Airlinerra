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
