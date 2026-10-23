# Airlinerra — Batch 26: 50 U.S. airport-source reviews (2026-10-23)

## Verified write results
Two separate Supabase `UPDATE ... RETURNING` statements wrote **25 + 25 individual airport-source records**, including the dated `independent_review_at` timestamp, evidence URL, airport-specific note, and evidence category. Another read-only SQL query enumerated **50** `BATCH 26 FIRST SOURCE REVIEW` identifiers.

Previous verified overall 443/1,929, so arithmetic after these 50 successful writes is **493/1,929**, with **1,436** outstanding; the aggregate confirmation query was blocked, therefore **these overall figures are expected, not independently rechecked**.

**Do not treat 50 first-pass source reviews as 50 commercially authorized passenger/charter/cargo airports.** No approval field was targeted in the writes.

## Significant evidence and exceptions
- MUT Muscatine city describes airport as non-commercial but lists private charter via FBO. This is not a contradiction: charter differs from scheduled airline operation.
- PRO Perry city advertises charter; Iowa DOT and the city's runway extension project establish 5,500ft (city legacy airport page says 4,000ft).
- PEO Penn Yan airport identifies Seneca Flight as based private charter operator.
- GVL Gainesville airport directory lists Lanier Flight Express jet and turboprop charter services.
- ORG Orange County Texas official operator says no commercial airline traffic.
- FIN Flagler County airport says no scheduled airlines.
- WVL Waterville city's FY 2026 airport plan describes daily inbound/outbound UPS freight, not necessarily certificated scheduled air cargo flights.
- UDG Darlington requires advance coordination for after-hours service; CPF Hazard runway 06/24 closed sunset-to-sunrise with runway-end drop-off hazards; W43 has aircraft load/terrain constraints; S24 has airport FBO restrictions.
- VUJ Stanly County is a **joint civilian/military public-use airport**, not military-only.
- LHZ public directory lists helicopter charter business, to be validated for actual based services.

## Complete individual source ledger
| FAA | State | Evidence category | Source |
|---|---|---|---|
| MUT | IA | CHARTER_ADVERTISED | [Airport-specific evidence](https://muscatineiowa.gov/550/Muscatine-Municipal-Airport) |
| MWK | NC | GA_FBO_ONLY | [Airport-specific evidence](https://www.flightaware.com/resources/airport/KMWK/services/FBO/Mount_Airy-Surry_County_Airport_Authority) |
| ORG | TX | NO_COMMERCIAL_AIRLINE | [Airport-specific evidence](https://www.co.orange.tx.us/departments/OrangeCountyAirport) |
| OWA | MN | GA_BUSINESS_ONLY | [Airport-specific evidence](https://www.owatonna.gov/162/Degner-Regional-Airport) |
| PMV | NE | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/PMV) |
| PMZ | NC | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/PMZ) |
| PRO | IA | CHARTER_ADVERTISED_RUNWAY_RECONCILED | [Airport-specific evidence](https://www.perryia.org/city-projects-blog/perry-municipal-airport-runway-reconstruction-expansion) |
| PTT | KS | GA_FBO_ONLY | [Airport-specific evidence](https://prattairportauthority.com/details.html) |
| RHP | NC | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/RHP) |
| RYN | AZ | GA_CONTROLLED_FIELD | [Airport-specific evidence](https://www.airnav.com/airport/RYN) |
| S24 | OH | MEDICAL_ACTIVITY_SERVICE_LIMIT | [Airport-specific evidence](https://www.iflightplanner.com/Airports/S24) |
| ICR | SD | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/ICR) |
| TAD | CO | GA_IDENTITY_ONLY | [Airport-specific evidence](https://www.coloradoairports.org/airport-members-details/) |
| UDG | SC | GA_BUSINESS_LIMITED_HOURS | [Airport-specific evidence](https://darcosc.com/departments/airport/index.php) |
| UKL | KS | GA_FBO_ONLY | [Airport-specific evidence](https://www.coffeycountyks.org/315/Airport) |
| UZA | SC | GA_BUSINESS_ONLY | [Airport-specific evidence](https://aeronautics.sc.gov/airports/rock-hillyork-countybryant-fld-airport) |
| W43 | WY | HIGH_ALTITUDE_RUNWAY_LOAD | [Airport-specific evidence](https://www.globalair.com/airport/apt.runway.aspx?aptcode=w43) |
| WVL | ME | FREIGHT_ACTIVITY | [Airport-specific evidence](https://www.waterville-me.gov/Archive.aspx?ADID=95) |
| FIN | FL | NO_SCHEDULED_AIRLINE | [Airport-specific evidence](https://www.flaglercounty.gov/Government/Departments/Airport) |
| CXW | AR | GA_FBO_ONLY | [Airport-specific evidence](https://conwayarkansas.gov/airport/) |
| SXK | IA | GA_FBO_ONLY | [Airport-specific evidence](https://publications.iowa.gov/52348/1/917-2025-2026%20Airport%20Directory-WEB.pdf) |
| SYM | KY | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/SYM) |
| GLD | KS | GA_FBO_ONLY | [Airport-specific evidence](https://www.butterflyaviation.net/) |
| CPF | KY | RUNWAY_RESTRICTIONS | [Airport-specific evidence](https://aeronav.faa.gov/afd/22JAN2026/SE_277_22JAN2026.pdf) |
| JVW | MS | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/JVW) |
| PEO | NY | CHARTER_SUPPORTED | [Airport-specific evidence](https://www.pennyanairport.org/fbo) |
| VUJ | NC | JOINT_CIVIL_MILITARY | [Airport-specific evidence](https://www.stanlycountyairport.com/) |
| BYL | KY | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/BYL) |
| 27K | KY | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/27K) |
| AFP | NC | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/AFP) |
| LHZ | NC | HELICOPTER_CHARTER_LISTED | [Airport-specific evidence](https://www.flightaware.com/resources/airport/KLHZ) |
| OKV | VA | GA_WITH_JET_PATTERN_LIMIT | [Airport-specific evidence](https://www.airnav.com/airport/OKV) |
| BDE | MN | GA_CUSTOMS_IDENTITY | [Airport-specific evidence](https://www.airnav.com/airport/BDE) |
| DNN | GA | GA_FBO_ONLY | [Airport-specific evidence](https://myfiles.dot.ga.gov/Aviation/AirportDirectory.pdf) |
| GVL | GA | CHARTER_SUPPORTED | [Airport-specific evidence](https://www.airnav.com/airport/GVL) |
| HAB | AL | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/HAB) |
| ILE | TX | GA_CORPORATE | [Airport-specific evidence](https://www.killeentexas.gov/546/Skylark-Field-Airport) |
| DRI | LA | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/DRI) |
| LXN | NE | GA_FBO_ONLY | [Airport-specific evidence](https://www.airnav.com/airport/LXN) |
| BVS | WA | GA_JET_FBO | [Airport-specific evidence](https://corporateaircenter.com/) |
| RBL | CA | GA_FBO_ONLY | [Airport-specific evidence](https://www.iflightplanner.com/Airports/KRBL) |
| CSV | TN | GA_FBO_ONLY | [Airport-specific evidence](https://crossvilletn.gov/department/airport/) |
| MMV | OR | GA_FBO_ONLY | [Airport-specific evidence](https://www.mcminnvilleoregon.gov/airport) |
| S39 | OR | GA_FBO_ONLY | [Airport-specific evidence](https://www.flyprineville.com/1682/Pilot-Guide) |
| CKM | MS | AGRICULTURAL_ACTIVITY | [Airport-specific evidence](https://www.airnav.com/airport/KCKM/RED_PANTHER_AERO) |
| DWU | KY | GA_FBO_ONLY | [Airport-specific evidence](https://transportation.ky.gov/Aviation/Pages/Kentucky-Airports.aspx) |
| OFP | VA | GA_RELIEVER | [Airport-specific evidence](https://www.hanovercounty.gov/1209/Hanover-County-Municipal-Airport) |
| ULM | MN | GA_FBO_ONLY | [Airport-specific evidence](https://www.newulmmn.gov/251/Municipal-Airport) |
| RAL | CA | BUSY_CORPORATE_GA | [Airport-specific evidence](https://www.riversideca.gov/airport/) |
| MQS | PA | GA_JET_FBO | [Airport-specific evidence](https://www.signatureaviation.com/locations/mqs) |

## Admission control
The original 3,140 airports, exact six Airlinerra categories (Local, Regional, Medium, Large, Major Hub, Mega Hub), final game categories and game admission/activation remain unchanged. Review timestamp means first airport-specific source research, not aviation regulatory certification. Scheduled passenger, charter, cargo, runway loads, special NOTAMs and aircraft performance remain separate downstream checks.
