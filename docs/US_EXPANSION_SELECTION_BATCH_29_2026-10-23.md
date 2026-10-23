# Airlinerra — U.S. Expansion, Batch 29 (2026-10-23)
## Completion verified in Supabase
- **50 / 50** individual airport-source reviews saved to project `hwllkabgzaynalahvkpz`, private table `airlinerra.airport_commercial_verification`.
- Separate aggregate SQL verification: **643 / 1,929** reviewed in total, **1,286** remain, **0** new gameplay approvals.
- This replaces the **temporary partial-write** status published earlier: all four recovery records **MIO, DTN, HUL, 1F0** are now saved. Every airport record has its first-source note, independent timestamp, URL and scoped evidence category.
- Source review is **not** proof of current airline commercial access, certificated cargo/charter operations, or final aircraft permission.

## Important conclusions
- **D60 Tioga:** former FBO Tioga Aero Center suspended operations in August 2024; airport service assumptions must not rely on it.
- **PHG Phillipsburg:** October 2026 FAA record reports **5,101ft** concrete runway, superseding older city listing of 4,500ft; current pinned Supabase length remains correct.
- **3K7:** Mark Hoard Memorial in **Leoti, KS**; not Syracuse (FAA **3K3**).
- **M46 Colstrip:** Rosebud County explicitly lists **no fuel or repairs**.
- **FFZ Falcon Field:** closely spaced parallel runways and busy controlled airspace beneath Phoenix Class B; FAA highlights wrong-surface landing risk.
- **BKE Baker City:** Baker Aircraft actively advertises charter and FBO.
- **LNN Lake County Executive:** Classic Jet Center advertises aircraft charter and an FAA air carrier certificate number; independently verify certification status before final admission.
- **E41 Reagan County:** 5,035ft paved main runway is only 50ft wide, 1,005ft threshold displacement, loose stones; second paved runway rated poor.
- **S52 Methow Valley State:** state warns limited winter plowing and restricted taxiway access.
- **4A4 Polk County GA:** extensive weekend skydiving and no runway-end line-of-sight.
- **LRJ Le Mars:** 300ft displaced thresholds at both ends of primary runway.
- **DTN Shreveport Downtown:** GA reliever, not conflated with scheduled commercial service at SHV.

## Complete first-source verification ledger
| FAA | State | Finding category | Airport-specific evidence |
|---|---|---|---|
| EDN | AL | GA_SMALL_JET_OPERATIONS | [Source](https://www.enterprisealabama.com/enterprise-municipal-airport) |
| LLQ | AR | GENERAL_AVIATION | [Source](https://fly.arkansas.gov/monticello.html) |
| VBT | AR | CITY_GA | [Source](https://fly.arkansas.gov/bentonville.html) |
| FFZ | AZ | BUSINESS_GA_BUSY_AIRSPACE | [Source](https://www.faa.gov/flight_deck/ffz) |
| 4A4 | GA | SKYDIVE_NO_LINE_OF_SIGHT | [Source](https://www.airnav.com/airport/4A4) |
| IIY | GA | GA_FBO_ONLY | [Source](https://www.airnav.com/airport/KIIY) |
| LRJ | IA | DISPLACED_THRESHOLDS | [Source](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=LRJ) |
| RDK | IA | GA_GRASS_CLOSURE | [Source](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=RDK) |
| GIC | ID | COUNTY_GA | [Source](https://www.idahocounty.org/tmp/airport/idaho-county-airport/) |
| HFY | IN | GA_FBO_ONLY | [Source](https://www.airnav.com/airport/HFY) |
| 3K7 | KS | LEOTI_IDENT | [Source](https://www.iflightplanner.com/Airports/3K7) |
| PHG | KS | RUNWAY_RECONCILED | [Source](https://www.airnav.com/airport/phg) |
| TOP | KS | TOWERED_BUSINESS_GA | [Source](https://airnav.com/airport/TOP) |
| SJS | KY | GA_FBO_ONLY | [Source](https://bigsandyregional.com/) |
| DTN | LA | GA_RELIEVER | [Source](https://flyshreveport.com/airport-information/) |
| HUL | ME | GA_CUSTOMS | [Source](https://www.houlton-maine.com/airport/) |
| DET | MI | GA_AIR_CARRIER_TERMINAL | [Source](https://detroitmi.gov/departments/airport-coleman-young-international) |
| AXN | MN | MEDICAL_HELI_WARNINGS | [Source](https://www.airnav.com/airport/KAXN) |
| UNO | MO | GA_FBO_ONLY | [Source](https://www.flightaware.com/resources/airport/KUNO) |
| 9S5 | MT | ULTRALIGHT_SKYDIVE | [Source](https://www.iflightplanner.com/Airports/9S5) |
| M46 | MT | NO_FUEL_SERVICES | [Source](https://rosebudcountymt.gov/departments/airport/) |
| RPX | MT | UNATTENDED_GA | [Source](https://www.airnav.com/airport/RPX) |
| BWP | ND | GA_WINTER_WARNING | [Source](https://www.airnav.com/airport/BWP) |
| D60 | ND | FBO_SUSPENDED | [Source](https://www.tiogaaero.com/news.html) |
| IML | NE | GA_FBO_ONLY | [Source](https://www.airnav.com/airport/KIML) |
| OGA | NE | GA_FBO_ONLY | [Source](https://airnav.com/airport/OGA) |
| I23 | OH | GA_FBO_ONLY | [Source](https://fayette-co-oh.com/281/Airport) |
| LNN | OH | PART135_CHARTER_ADVERTISED | [Source](https://www.classicjetcenter.com/) |
| 1F0 | OK | REGIONAL_BUSINESS_GA | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/ardmore-downtown-executive.html) |
| CHK | OK | GA_BUSINESS | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/chickasha-municipal.html) |
| GAG | OK | GENERAL_ONLY_NO_FUEL_LISTED | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/gage.html) |
| MIO | OK | REGIONAL_BUSINESS_GA | [Source](https://oklahoma.gov/aerospace/airports/find-an-airport/miami-regional.html) |
| OJA | OK | GA_FBO_ONLY | [Source](https://www.airnav.com/airport/KOJA) |
| RVS | OK | TWO_GA_FBOS | [Source](https://flytulsa.com/tulsa-river-side/services/) |
| 5S6 | OR | STATE_GA | [Source](https://www.oregon.gov/aviation/airports/pages/cape-blanco-5s6.aspx) |
| BKE | OR | CHARTER_SUPPORTED | [Source](https://www.bakeraircraft.com/fbo-airport) |
| BNO | OR | GA_WILDLIFE_WARNING | [Source](https://aeronav.faa.gov/afd/19MAR2026/NW_164_19MAR2026.pdf) |
| DLS | OR | GA_FBO_ONLY | [Source](https://www.flycgra.com/pilots) |
| S33 | OR | CHARTER_LISTED | [Source](https://www.iflightplanner.com/Airports/S33) |
| ZER | PA | BUSINESS_JETS | [Source](https://www.schuylkillregionalairport.com/) |
| 49B | SD | CITY_GA_FBO | [Source](https://www.sturgis-sd.gov/sturgis-municipal-airport) |
| 2T1 | TX | AVGAS_ONLY | [Source](https://airnav.com/airport/2T1) |
| E41 | TX | DISPLACED_THRESHOLD_LOOSE_STONES | [Source](https://airnav.com/airport/E41) |
| F05 | TX | AGRICULTURAL_121 | [Source](https://www.co.wilbarger.tx.us/page/Airport) |
| 1L7 | UT | HIGH_ALTITUDE_UNATTENDED | [Source](https://escalanteutah.gov/wp-content/uploads/2017/06/AirNav_-1L7-Escalante-Municipal-Airport.html) |
| 41U | UT | HIGH_ALTITUDE_24H_FUEL | [Source](https://aeronav.faa.gov/d-tpp/2512/10960r3.pdf) |
| S52 | WA | EMERGENCY_USE_WARNING | [Source](https://wsdot.wa.gov/travel/aviation/airports-list/methow-valley-state) |
| RRL | WI | GA_ULTRALIGHT | [Source](https://www.airnav.com/airport/RRL) |
| UNU | WI | GA_ULTRALIGHT_BIRDS | [Source](https://www.airnav.com/airport/UNU) |
| LSK | WY | SMALL_GA_AVGAS | [Source](https://townofluskwy.gov/municipal-airport) |

## Next step
Select another 50 unreviewed records from live Supabase for Batch 30. Maintain six Airlinerra classes (Local, Regional, Medium, Large, Major Hub, Mega Hub). Do not alter the original 3,140 or any `game_admission_status` before final commercial-operational criteria are met.
