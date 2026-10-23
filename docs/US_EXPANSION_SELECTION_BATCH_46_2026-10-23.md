# Airlinerra — U.S. Airport Expansion Research Batch 46 (2026-10-23)

**50 new airport-specific first-pass source reviews successfully saved in Supabase.** Current aggregate: **1,493 / 1,929 reviewed** (77.40%), **436 still pending**, **zero game admissions**. The existing 3,140 game airport records remain unchanged.

**Source-quality boundary:** Most airport-specific records are facility/fuel/runway evidence, not certified commercial access. Do NOT infer scheduled passenger rights, cargo routes, Part 121/135 authorization, Airlinerra category or compatible aircraft simply from a public-use FAA listing, a passenger lounge, a business name or a runway length.

## Key findings

- **67R is Rio Grande City Municipal in Texas, NOT Gonzales.** Published FAA-derived record lists a 4,000x75ft runway and locked airport gate. Direct local manager contact required. https://www.airnav.com/airport/67R
- **8WC is Washington County Airport near Potosi Missouri, NOT Warsaw.** Airport notes include right traffic RW02 and a prison no-overflight caution. https://www.airnav.com/airport/8WC
- **GPM Grand Prairie TX:** city confirms airport handles some cargo and aviation businesses, but no scheduled carrier routes can be inferred. https://www.gptx.org/Departments/Airport
- **CBG Cambridge MN:** published single-wheel runway load about 19,000lb, self-service 100LL, but no confirmed commercial passenger routes. https://www.ci.cambridge.mn.us/our-community/municipal-airport
- **BFK Buffalo Municipal OK:** Oklahoma aviation authority has no fuel, transport or based jets listed in its 2023 state profile. https://oklahoma.gov/aerospace/airports/find-an-airport/buffalo-municipal.html
- **CNC Chariton IA:** runway 10 VASI and runway-end identifier lights on two ends are reported out in autumn 2026; verify active NOTAMs. https://www.iflightplanner.com/Airports/KCNC
- **H79 Eldon Model Airpark MO:** PAPI/REIL outage notices affect its approaches; check the active FAA NOTAM listing before aircraft assignment. https://www.iflightplanner.com/Airports/H79

## Admission and classification controls

Every record remains `game_admission_status=NOT_APPROVED`. Airlinerra has exactly six categories: Local, Regional, Medium, Large, Major Hub, Mega Hub. Airport proper names and FAA/state planning classes are not substitutes. The full individual source ledger follows.

## Source evidence ledger — airports 1–12

| FAA | State | Immutable key | Evidence | Individual finding | Reviewed UTC |
|---|---|---|---|---|---|
| CBG | MN | `OURAIRPORTS:19464` | [Source](https://www.ci.cambridge.mn.us/our-community/municipal-airport) | Cambridge city owns CBG, 100LL self-service, 4,000ft-class runway and published 19,000lb single-wheel load rating; planned commercial hangar sites do not establish scheduled airline or charter rights. | 2026-10-23 21:37:45.822845+00 |
| DEH | IA | `OURAIRPORTS:19622` | [Source](https://www.decorahia.org/departments/decorah-airport) | Decorah city documents runway 11/29 at 4,000x75ft, 24h FBO, Jet A and avgas; an airport FBO separately lists aircraft charters. Verify carrier licensing and actual routes. | 2026-10-23 21:37:45.822845+00 |
| FKA | MN | `OURAIRPORTS:19871` | [Source](https://www.airnav.com/airport/FKA) | FAA 2026 Fillmore County FKA at Preston Minnesota is unattended with AWOS, pilot-activated runway lights and PAPI/REIL. Current licensed air charter, cargo, and scheduled routes not established. | 2026-10-23 21:37:45.822845+00 |
| FTT | MO | `OURAIRPORTS:19904` | [Source](https://www.faa.gov/AIR_TRAFFIC/FLIGHT_INFO/AERONAV/PROCEDURES/application/index.cfm?event=procedure.results&nasrId=FTT) | FAA identifies Elton Hensley Memorial FTT Fulton MO with RNAV GPS approaches for runway 06/18/24/36. Instrument approach availability does not establish commercial operator authorization. | 2026-10-23 21:37:45.822845+00 |
| GPM | TX | `OURAIRPORTS:19973` | [Source](https://www.gptx.org/Departments/Airport) | Grand Prairie city documents GPM 4,000x75ft concrete runway, cargo-handling and GA/business activities, plus a locally listed commercial aviation business. Certified cargo/passenger service not verified. | 2026-10-23 21:37:45.822845+00 |
| I75 | IA | `OURAIRPORTS:20145` | [Source](https://opmapps.iowadot.gov/aviation/airports/I75) | Iowa DOT lists Osceola I75 with 4,001x75ft concrete 18/36, weekday attendance only to 2pm and self-service 100LL; no scheduled airline or charter certification evidenced. | 2026-10-23 21:37:45.822845+00 |
| JWG | OK | `OURAIRPORTS:20225` | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/watonga-regional.html) | Oklahoma state JWG Watonga Regional: 4,001x60ft asphalt, 100LL/Jet A and AWOS, unattended and zero based jets in 2023; state Local planning role is not game approval. | 2026-10-23 21:37:45.822845+00 |
| LHB | TX | `OURAIRPORTS:20338` | [Source](https://ftp.txdot.gov/pub/txdot-info/d/airport_directory/lhb.pdf) | Historical Texas DOT Hearne Municipal LHB 4,001x75ft runway, 100LL, no listed maintenance and active glider use. Recheck current services; no passenger/charter/cargo rights confirmed. | 2026-10-23 21:37:45.822845+00 |
| MPZ | IA | `OURAIRPORTS:20552` | [Source](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=MPZ) | Iowa DOT Mount Pleasant MPZ: 4,001x75ft paved and shorter turf strip, Air Advantage operator, Jet A/100LL and weekend callout; no evidence of scheduled airline routes. | 2026-10-23 21:37:45.822845+00 |
| N98 | MI | `OURAIRPORTS:20630` | [Source](https://www.michigan.gov/mdot/travel/mobility/aeronautics/pilots/aeronautical-chart-distribution-locations) | Michigan DOT identifies N98 Boyne City Municipal, not other northern Michigan airline fields; current services, charter permissions and actual cargo operation need direct manager confirmation. | 2026-10-23 21:37:45.822845+00 |
| SFY | IL | `OURAIRPORTS:21059` | [Source](https://www.globalair.com/airport/apt.remarks.aspx?aptcode=sfy) | 2026 FAA-derived Tri-Township SFY Savanna IL: seasonal irrigation under approach/runway 31, restricted PAPI sectors and controlled lighting. Recheck obstacles/aircraft capability, no commercial route proof. | 2026-10-23 21:37:45.822845+00 |
| TCY | CA | `OURAIRPORTS:21181` | [Source](https://www.cityoftracy.org/Departments/Public-Works/Traffic-Transportation/Tracy-Municipal-Airport) | Tracy city identifies TCY as GA serving corporate/business traffic and a maintenance/aircraft-shipping tenant. Aircraft shipment as freight item is not scheduled air-cargo service. | 2026-10-23 21:37:45.822845+00 |

## Source evidence ledger — airports 13–25

| FAA | State | Immutable key | Evidence | Individual finding | Reviewed UTC |
|---|---|---|---|---|---|
| TZT | IA | `OURAIRPORTS:21242` | [Source](https://iowadot.gov/modes-travel/aviation/airport-information/tzt) | Iowa DOT confirms Belle Plaine Municipal/Mansfield Tippie TZT, with pavement-condition reports and airport layout; current charter/cargo operators and fuel availability unconfirmed. | 2026-10-23 21:38:00.380343+00 |
| X51 | FL | `OURAIRPORTS:21403` | [Source](https://www.miami-airport.com/homestead.asp) | Miami-Dade operates Homestead GA X51 with paved and ultralight turf runways, Jet A/100LL and glider, skydiving, FBO and flight-training tenants. Commercial airline permission not established. | 2026-10-23 21:38:00.380343+00 |
| ZEF | NC | `OURAIRPORTS:21440` | [Source](https://www.airnav.com/airport/ZEF) | FAA 2026 Elkin Municipal ZEF 4,001x75ft runway, fuel and 25,000lb single-wheel rating but steep runway-end drop-offs, trees and unmarked power lines. Mandatory aircraft-specific obstacle review. | 2026-10-23 21:38:00.380343+00 |
| OLD | ME | `OURAIRPORTS:3748` | [Source](https://www.airnav.com/airport/OLD) | FAA October 2026 DeWitt Field/Old Town OLD offers Jet A/100LL and published approaches but reports Sunday FBO closure and wildlife; current commercial passenger or cargo operators unverified. | 2026-10-23 21:38:00.380343+00 |
| 1I9 | IN | `OURAIRPORTS:8323` | [Source](https://www.delphimunicipalairport.com/airport-information) | Delphi Municipal 1I9 operator confirms 4,000x60ft runway and pilot terminal. Width may constrain larger aircraft, and scheduled/charter/cargo rights remain unknown. | 2026-10-23 21:38:00.380343+00 |
| 1M7 | KY | `OURAIRPORTS:8428` | [Source](https://www.airnav.com/airport/1M7) | FAA 2026 Fulton Kentucky 1M7, unattended nontowered airport with runway 09/27 PAPI, REIL and runway lights. Not Fulton Missouri FTT; no charter or scheduled-route evidence. | 2026-10-23 21:38:00.380343+00 |
| 3B1 | ME | `OURAIRPORTS:18673` | [Source](https://greenvilleme.gov/municipal-airport/) | Greenville Maine municipality confirms 3B1 with 24-hour card fuel Jet A/100LL, 4,000x75ft main runway, FBO and snow-maintenance information; charter/cargo permissions not established. | 2026-10-23 21:38:00.380343+00 |
| 48K | KS | `OURAIRPORTS:18793` | [Source](https://aviation.ks.gov/files/KDOT_Airport_Directory_2025-2026.pdf) | Kansas DOT directory lists Ness City 48K 4,000x60ft concrete runway and unattended status; source does not establish fuel, maintenance or carrier rights. | 2026-10-23 21:38:00.380343+00 |
| 4J1 | GA | `OURAIRPORTS:18825` | [Source](https://www.airnav.com/airport/4J1) | FAA 2026 Brantley County 4J1 at Nahunta Georgia, unattended with RNAV 01/19 and pilot-activated approach lights; commercial air carrier operations unconfirmed. | 2026-10-23 21:38:00.380343+00 |
| 5A6 | MS | `OURAIRPORTS:18892` | [Source](https://www.airnav.com/airport/5A6) | FAA 2026 Winona–Montgomery County 5A6 Mississippi public airfield with continuous attendance, AWOS, RNAV 03/21 and avgas fuel; no current airline/charter/cargo certificate evidenced. | 2026-10-23 21:38:00.380343+00 |
| 61R | TX | `OURAIRPORTS:18947` | [Source](https://www.airnav.com/airport/61R) | FAA 2026 Newton Municipal 61R Texas public-use unattended airport; Texas DOT historical directory reports no fuel and no repairs. Verify current services before aircraft fit and charter review. | 2026-10-23 21:38:00.380343+00 |
| 67R | TX | `OURAIRPORTS:18967` | [Source](https://www.airnav.com/airport/67R) | Identity correction: 67R is Rio Grande City Municipal TX, NOT Gonzales. FAA 2026 reports 4,000x75ft runway, 12,500lb single-wheel pavement rating and locked gate; call manager for access. No instrument approaches or commercial permissions. | 2026-10-23 21:38:00.380343+00 |
| 70J | GA | `OURAIRPORTS:19021` | [Source](https://myfiles.dot.ga.gov/Aviation/AirportDirectory.pdf) | Georgia DOT 2026-27 Cairo–Grady County 70J lists 4,000x75ft runway, crop-duster operations and 100LL available 9am-4pm weekdays. Jet A and commercial route rights not established. | 2026-10-23 21:38:00.380343+00 |
