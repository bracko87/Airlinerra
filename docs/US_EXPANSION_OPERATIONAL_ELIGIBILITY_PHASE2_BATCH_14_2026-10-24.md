# Airlinerra — Phase 2 Batch 14, October 24, 2026

**Supabase verified:** 50 new distinct airport keys in Phase 2. Cumulative **666/1,929 assessed**, **1,263 pending**. Batch 14: 15 operational constraint holds, 22 evidence gaps, 12 source-code reconciliations and 1 provisional temporary exclusion. All 1,929 expansion candidates still NOT_APPROVED; original 3,140 playable airports unchanged, zero world activations and zero new category approvals.

Important restrictions: 53A runway closure until November 15 2026 ([current notice](https://www.iflightplanner.com/Airports/53A)); MKS 650ft RW05 displaced threshold ([FAA-derived airport listing](https://www.airnav.com/airport/MKS)); 4A4 extensive weekend parachuting ([source](https://www.airnav.com/airport/4A4)); HRF distinct weight-bearing maxima and landing-fee thresholds ([county rules](https://ravallicounty.gov/DocumentCenter/View/6971/Res-4353-Airport-Rules-and-Regulations-RECORDED)).

This is source-based eligibility triage, not airport certification, flight permission or a final exclusion. Individual findings, actions, dates, and full evidence lists remain in Supabase `airlinerra.airport_operational_triage`.

## All 50 distinct airport assessments

| FAA | Immutable key | Triage status | Issue | Evidence source |
|---|---|---|---|---|
| 49X | `OURAIRPORTS:18800` | EVIDENCE_GAP_HOLD | REMOTE_GA_SERVICE_NOT_CARRIER_PROOF | [Airport evidence](https://www.airnav.com/airport/49X) |
| 4A4 | `OURAIRPORTS:18802` | CONSTRAINT_CONFIRMED_HOLD | WEEKEND_PARACHUTING_RUNWAY_LINE_OF_SIGHT | [Airport evidence](https://www.airnav.com/airport/4A4) |
| 4A6 | `OURAIRPORTS:18804` | EVIDENCE_GAP_HOLD | SCOTTSBORO_NOT_GUNTERSVILLE | [Airport evidence](https://www.airnav.com/airport/4A6) |
| 4A9 | `OURAIRPORTS:18806` | EVIDENCE_GAP_HOLD | FBO_PASSENGER_LOUNGE_NOT_SCHEDULED | [Airport evidence](https://fortpayne.org/city-services/airport/) |
| 4I3 | `OURAIRPORTS:18822` | EVIDENCE_GAP_HOLD | KNOX_COUNTY_NOT_MORROW_COUNTY | [Airport evidence](https://www.airnav.com/airport/4I3) |
| 4J2 | `OURAIRPORTS:18826` | EVIDENCE_GAP_HOLD | UNATTENDED_GA_OPERATOR_GAP | [Airport evidence](https://www.airnav.com/airport/4J2) |
| 4J5 | `OURAIRPORTS:18827` | EVIDENCE_GAP_HOLD | BROOKS_COUNTY_CARRIER_NOT_VERIFIED | [Airport evidence](https://www.airnav.com/airport/4J5) |
| 4O4 | `OURAIRPORTS:18840` | EVIDENCE_GAP_HOLD | PLANNING_REGIONAL_BUSINESS_NOT_GAME_TIER | [Airport evidence](https://oklahoma.gov/aerospace/airports/find-an-airport/mccurtain-county-regional.html) |
| 4R3 | `OURAIRPORTS:18844` | CONSTRAINT_CONFIRMED_HOLD | RUNWAY_LENGTH_SOURCE_CONFLICT_AND_25K_LOAD | [Airport evidence](https://www.airnav.com/airport/4R3) |
| 4R7 | `OURAIRPORTS:18847` | EVIDENCE_GAP_HOLD | FBO_FUEL_NO_CHARTER_CERT | [Airport evidence](https://www.iflightplanner.com/Airports/4R7) |
| 53A | `OURAIRPORTS:18876` | CURRENT_SCREEN_INELIGIBLE | CURRENT_RUNWAY_CLOSURE_TO_NOV15 | [Airport evidence](https://www.iflightplanner.com/Airports/53A) |
| 5S6 | `OURAIRPORTS:18927` | EVIDENCE_GAP_HOLD | CAPE_BLANCO_REMOTE_CARRIER_EVIDENCE_GAP | [Airport evidence](https://www.oregon.gov/aviation/airports/pages/cape-blanco-5s6.aspx) |
| 5V5 | `OURAIRPORTS:18934` | CONSTRAINT_CONFIRMED_HOLD | NAVAJO_TRIBAL_OWNER_PERMISSION | [Airport evidence](https://maps.avnwx.com/airport/5V5) |
| 62S | `OURAIRPORTS:18950` | EVIDENCE_GAP_HOLD | REMOTE_GA_UNATTENDED_HIGH_ELEVATION | [Airport evidence](https://www.airnav.com/airport/62S) |
| 67L | `OURAIRPORTS:18966` | CONSTRAINT_CONFIRMED_HOLD | RUNWAY_END_DROP_AND_NOISE_ZONE | [Airport evidence](https://www.mesquitenv.gov/locations/airport) |
| 6A1 | `OURAIRPORTS:18974` | EVIDENCE_GAP_HOLD | UNATTENDED_RNAV_NOT_CARRIER_PROOF | [Airport evidence](https://www.airnav.com/airport/6A1) |
| 6I2 | `OURAIRPORTS:18989` | EVIDENCE_GAP_HOLD | FBO_FUEL_NOT_CERTIFIED_ROUTE | [Airport evidence](https://www.airnav.com/airport/6I2) |
| 6R3 | `OURAIRPORTS:19006` | EVIDENCE_GAP_HOLD | PUBLIC_USE_SECURITY_AND_FUEL_UNVERIFIED | [Airport evidence](https://www.iflightplanner.com/Airports/6R3) |
| 6S0 | `OURAIRPORTS:19008` | CONSTRAINT_CONFIRMED_HOLD | RUNWAY_PAVEMENT_CONDITION_DISCREPANCY | [Airport evidence](https://www.airnav.com/airport/6S0) |
| 6S8 | `OURAIRPORTS:19013` | CONSTRAINT_CONFIRMED_HOLD | IRREGULAR_WINTER_PLOWING_MULTI_RUNWAY | [Airport evidence](https://www.flylaurelmt.com/) |
| 74V | `OURAIRPORTS:19031` | CONSTRAINT_CONFIRMED_HOLD | REPORTED_RUNWAY07_PAPI_OUTAGE | [Airport evidence](https://www.airnav.com/airport/74V) |
| 79J | `OURAIRPORTS:19042` | CONSTRAINT_CONFIRMED_HOLD | MIXED_INDUSTRIAL_MILITARY_CIVIL_USE | [Airport evidence](https://www.covingtoncountyal.gov/288/South-Alabama-Regional-Airport-Authority) |
| 7S6 | `OURAIRPORTS:19078` | EVIDENCE_GAP_HOLD | HIGH_ELEVATION_AVGAS_OPERATOR_UNVERIFIED | [Airport evidence](https://www.airnav.com/airport/7S6) |
| 7W6 | `OURAIRPORTS:19091` | CONSTRAINT_CONFIRMED_HOLD | COASTAL_BIRDS_AND_MILITARY_AIRSPACE | [Airport evidence](https://www.airnav.com/airport/7W6) |
| 82V | `OURAIRPORTS:19101` | CONSTRAINT_CONFIRMED_HOLD | HIGH_ELEVATION_AND_LIMITED_STAFFING | [Airport evidence](https://www.airnav.com/airport/82V) |
| 8A1 | `OURAIRPORTS:19115` | EVIDENCE_GAP_HOLD | GUNTERSVILLE_LAND_AND_SEAPLANE_RUNWAYS | [Airport evidence](https://guntersvilleal.org/departments/guntersville-municipal-airport-joe-starnes-field/) |
| 8A3 | `OURAIRPORTS:19116` | CONSTRAINT_CONFIRMED_HOLD | RW03_145FT_THRESHOLD_DISPLACED | [Airport evidence](https://www.tdot.tn.gov/PublicDocuments/aeronautics/Airport-directory.pdf) |
| 8M1 | `OURAIRPORTS:19135` | EVIDENCE_GAP_HOLD | STAFFED_0800_1400_GA_ONLY_EVIDENCE | [Airport evidence](https://www.airnav.com/airport/8M1) |
| 8V7 | `OURAIRPORTS:19150` | EVIDENCE_GAP_HOLD | SPRINGFIELD_COLORADO_GA_ONLY | [Airport evidence](https://www.airnav.com/airport/8V7) |
| 9A5 | `OURAIRPORTS:19177` | EVIDENCE_GAP_HOLD | AVGAS_RNAV_NO_JETA_PROOF | [Airport evidence](https://www.airnav.com/airport/9A5) |
| 9D9 | `OURAIRPORTS:19185` | EVIDENCE_GAP_HOLD | GA_FBO_REPAIRS_NOT_CARRIER_LICENSE | [Airport evidence](https://www.airnav.com/airport/9D9) |
| 9S5 | `OURAIRPORTS:19201` | CONSTRAINT_CONFIRMED_HOLD | GLIDER_SKYDIVE_ULTRALIGHT_MIX | [Airport evidence](https://www.iflightplanner.com/Airports/9S5) |
| AAO | `OURAIRPORTS:19225` | EVIDENCE_GAP_HOLD | POSITIVE_CHARTER_EVIDENCE_CERT_UNVERIFIED | [Airport evidence](https://www.flywichita.com/jabara-airport/) |
| AAS | `OURAIRPORTS:19226` | EVIDENCE_GAP_HOLD | KENTUCKY_AIRPORT_WEIGHT_LIMIT_TO_RECHECK | [Airport evidence](https://taylorcountyky.gov/airport) |
| AQX | `OURAIRPORTS:19110` | EVIDENCE_GAP_HOLD | SC_GA_SERVICE_NOT_CERTIFIED_CARRIER | [Airport evidence](https://aeronautics.sc.gov/airports/allendale-county-airport) |
| BFZ | `OURAIRPORTS:19114` | SOURCE_IDENTITY_RECONCILIATION | FORMER_8A0_CURRENT_BFZ | [Airport evidence](https://www.airnav.com/airport/BFZ) |
| CVC | `OURAIRPORTS:19175` | SOURCE_IDENTITY_RECONCILIATION | FORMER_9A1_CURRENT_CVC | [Airport evidence](https://cityofcovington.org/index.php?section=departments_covington-airport) |
| FHB | `OURAIRPORTS:18881` | SOURCE_IDENTITY_RECONCILIATION | FORMER_55J_CURRENT_FHB | [Airport evidence](https://fbfl.us/168/Airport-Information) |
| GDA | `OURAIRPORTS:18916` | SOURCE_IDENTITY_RECONCILIATION | FORMER_5M9_CURRENT_GDA | [Airport evidence](https://www.airnav.com/airport/GDA) |
| GPC | `OURAIRPORTS:18823` | SOURCE_IDENTITY_RECONCILIATION | FORMER_4I7_CURRENT_GPC | [Airport evidence](https://www.airnav.com/airport/GPC) |
| HMP | `OURAIRPORTS:18805` | SOURCE_IDENTITY_RECONCILIATION | FORMER_4A7_CURRENT_HMP | [Airport evidence](https://www.atlantaspeedwayairport.com/) |
| HRF | `OURAIRPORTS:19012` | CONSTRAINT_CONFIRMED_HOLD | 40K_SINGLE_53K_DUAL_WHEEL_CAPACITY | [Airport evidence](https://www.airnav.com/airport/HRF) |
| HTF | `OURAIRPORTS:18819` | SOURCE_IDENTITY_RECONCILIATION | FORMER_4G6_CURRENT_HTF | [Airport evidence](https://www.airnav.com/airport/HTF) |
| JSY | `OURAIRPORTS:18851` | SOURCE_IDENTITY_RECONCILIATION | FORMER_4S3_CURRENT_JSY | [Airport evidence](https://www.oregon.gov/aviation/airports/Pages/joesph-JSY.aspx) |
| MKS | `OURAIRPORTS:18867` | CONSTRAINT_CONFIRMED_HOLD | RW05_650FT_DISPLACED_THRESHOLD | [Airport evidence](https://aeronautics.sc.gov/airports/berkeley-county-airport) |
| PJC | `OURAIRPORTS:19132` | CONSTRAINT_CONFIRMED_HOLD | FAA_VS_OLD_LENGTH_TREES_AND_HOURS | [Airport evidence](https://www.airnav.com/airport/PJC) |
| RCV | `OURAIRPORTS:19147` | SOURCE_IDENTITY_RECONCILIATION | FORMER_8V1_CURRENT_RCV | [Airport evidence](https://www.flycolorado.org/index.php/airstrip-database/public-airports/del-norte/) |
| RVF | `OURAIRPORTS:19076` | SOURCE_IDENTITY_RECONCILIATION | FORMER_7S1_CURRENT_RVF | [Airport evidence](https://www.airnav.com/airport/KRVF) |
| SCR | `OURAIRPORTS:18938` | SOURCE_IDENTITY_RECONCILIATION | FORMER_5W8_CURRENT_SCR | [Airport evidence](https://www.airnav.com/airport/SCR) |
| TMT | `OURAIRPORTS:19204` | SOURCE_IDENTITY_RECONCILIATION | FORMER_9U3_CURRENT_TMT | [Airport evidence](https://www.dot.nv.gov/mobility/aviation/public-use-airports) |

**Next:** Batch 15, continuing pending airports. Six game tiers remain Local, Regional, Medium, Large, Major Hub, Mega Hub.
