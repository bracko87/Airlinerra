# Airlinerra — US Expansion Phase 5 Batch 7: Directional LDA Evidence Review

**Date:** 26 October 2026. Supabase project `hwllkabgzaynalahvkpz`, private `airlinerra` schema. Status: **20/20 initial desk source reviews complete, ALL NOT_APPROVED.** These findings do not certify flight-date airport safety or lawful paid airline service.

## Verified outcome

| Metric | After Batch 7 |
| --- | ---: |
| Batch 7 airport source reviews | 20 |
| Added runway-direction observations | 36 |
| Potential direction candidates, official LDA unverified | 31 |
| Directions too short in gross pavement length | 4 |
| Explicitly prohibited landing direction (LAM RW09) | 1 |
| Phase 5 source-reviewed | 136/211 |
| Phase 5 queued for initial reviews | 75 |
| Whole Phase 5 runway direction ledger | 126 |
| Phase 5 gameplay approvals | 0 |
| Original cohort airports preserved | 3,140 |
| World activations | 0 |

### Source scope

FAA-derived AirNav airport listings, local airport-owner data and the existing Phase 4 technical dossiers were used. These are not independently authenticated current original FAA NASR APT extracts. Some accessible AirNav pages show older cycles (GLY August, HTL June, IYK September 2026). HAI and HYR pages did not open; these cases are **source holds based on pre-existing Phase 4 files** rather than newly authenticated FAA runway reviews. The official 1 October 2026 [FAA NASR archive](https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/) exists; parsing the original effective APT dataset remains pending. No per-direction official usable landing distances were established, and all such values remain NULL.

## All 20 airports and their critical follow-ups

| FAA | Airport | Source cycle observed | Evidence/next action |
| --- | --- | --- | --- |
| FWS | Fort Worth Spinks Airport | 2026-10-01 | AirNav direct October 2026 lists good paved RW18R/36L 6002x100ft, and separate RW18L/36R short turf 3660ft (ineligible surface/length). Main bearing S60000/D70000/DT100000lb is NOT aircraft certification. FAA published LDA for RW18R and RW36L not found in checked secondary page. Fort Worth Class D tower,… |
| GED | Delaware Coastal Airport | 2026-10-01 | October FAA-derived source gives RW04/22 5500x150ft grooved asphalt, threshold displacements RW04 370ft, RW22 169ft, nominal 5130/5331ft, NOT declared LDA. Secondary 10/28 3109ft gross below floor. Frequent backtaxi on long runway; tree approach, customs by CBP prior arrangements, owner-airline and load … |
| GIF | Winter Haven Regional Airport - Gilbert Field | 2026-10-01 | October AirNav and Florida DOT official annual inspection establish RW05/23 asphalt 5005x100ft and RW11/29 asphalt 4001x60ft, FAA runway landing-distance values not shown. FDOT notes RW05 and RW29 displaced thresholds, but numeric displacements cannot safely be filled from the inspection summary; 11/29 h… |
| GLY | Clinton Memorial Airport | 2026-08-06 | Directly opened AirNav GLY is FAA-effective 06 AUG 2026, NOT October, notwithstanding Phase4 case summary. RW18/36 5000x75ft excellent concrete main and RW04/22 4001x60ft fair asphalt crosswind, with different airplane bearing (crosswind S12500/D16000lb). No authentic October per-direction LDA. Require c… |
| GWR | Gwinner Roger Melroe Field | 2026-10-01 | FAA-derived October source: Gwinner Airport/Roger Melroe Field active concrete grooved 16/34 5000x75ft, S14000/D19000lb. Separate 06/24 2991ft turf winter-closed does not disqualify paved primary. No published usable LDA for 16/34 in checked record; winter snow/FICON/Jet A emergency handling and owner/op… |
| HAI | Three Rivers Municipal Dr Haines Airport | SOURCE_NOT_OPENED | Direct AirNav HAI URL failed to open in this batch. Phase4 retained municipality and runway dossier reports RW09/27 4000x75ft asphalt, only 19m gross above game threshold; RW05/23 2720ft too short. No current FAA cycle or official LDA independently confirmed in Batch7. Runway wheel loading, trees/owner r… |
| HCR | Heber Valley Airport | 2026-10-01 | October FAA-derived airfield record: Heber Valley RW04/22 6898x75ft asphalt, ~5600ft elevation, S30000 PCN32, no officially verified LDA. Published owner landing fees since 2024 are financial rules, not runway closure; high-density-altitude and mountain approaches plus permitted charter operator/owner ag… |
| HDC | Hammond Northshore Regional Airport | 2026-10-01 | October AirNav has RW13/31 mixed asphalt/concrete 6502x100ft, RW31 threshold displaced 690ft => nominal 5812ft not published LDA; opposite RW13 no displaced threshold reported. Independent concrete RW18/36 5001x150ft and ILS, lower/different S/D pavement ratings. RW31 right-side REIL inoperative, ramp al… |
| HKS | Hawkins Field | 2026-10-01 | FAA-derived October source identifies Hawkins Field RW16/34 5387x150ft good grooved asphalt, other 11/29 3431ft concrete below floor. Active military/Guard helicopter, medevac and public aviation are not licensed commercial service. Main per-direction LDA unverified; runway bearing, tower after hours, ow… |
| HND | Henderson Executive Airport | 2026-10-01 | October FAA-derived listing shows Henderson Exec RW17R/35L 6501x100ft asphalt and RW17L/35R 5001x75ft, both nominal physical qualifying but direction-specific official LDAs absent. Owner states airport open 24h but FBO shorter hours; event PPR windows include 17-23 Nov and 02-13 Dec 2026. Prior 16-23 Oct… |
| HTL | Roscommon County - Blodgett Memorial Airport | 2026-06-11 | Important stale source: directly opened AirNav HTL effective 11 JUN 2026, not October. Primary RW09/27 asphalt 4000x75ft, only 19m gross margin; secondary RW18/36 2200ft turf winter-closed. Direct source fuel 100LL ONLY; do not rely on older suggestions of Jet A. Official FAA October direction-specific L… |
| HWD | Hayward Executive Airport | 2026-10-01 | October FAA-derived AirNav RW10R/28L asphalt grooved 5694x150ft: displaced threshold RW10R 826ft and RW28L 676ft, nominal 4868/5018ft. CITY Hayward airport specs show RW10R 816ft (10ft less), RW28L 676ft, and fair vs AirNav excellent surface status. Preserve conflicting threshold source values and use ne… |
| HYI | San Marcos Regional Airport | 2026-10-01 | AirNav October confirms three separate San Marcos Regional paved runways: 08/26 6330ft, 13/31 5601ft, 17/35 5214ft, with differing bearing limits. FAA airport remarks restrict transient parking to FBO ramp or elsewhere only with management PPR; parking limit NOT runway closure. No published per-end LDA v… |
| HYR | Sawyer County Airport | SOURCE_NOT_OPENED | Direct AirNav HYR failed to open this batch. Phase4 dossier, FAA-derived secondary and county notes document primary grooved RW03/21 5003x100ft, separate turf 16/34 1088ft, seasonal December-April closure confined to turf. No independently verified latest FAA cycle or LDA. Field overnight condition unmon… |
| I74 | Grimes Field | 2026-10-01 | FAA-derived October Grimes Field RW02/20 4400x100ft fair asphalt, separate RW01/19 turf 3000ft ineligible. Landing fees begin at aircraft max landing wt 6000lb with fuel waiver, an economic charge rather than 6000lb pavement bearing limit. No official per-direction LDA; owner carrier permission, aircraft… |
| IDP | Independence Municipal Airport | 2026-10-01 | October FAA-derived Independence Municipal primary RW17/35 asphalt 5501x100ft PCN15, secondary RW04/22 3402ft gross under minimum. Actual published LDA not displayed for RW17/35. ILS RW35 and self-service 100LL not substitutes for declared LDA, usable Jet A after hours, airport signed airline approval or… |
| IER | Natchitoches Regional Airport | 2026-10-01 | October AirNav Natchitoches Regional main RW17/35 good asphalt 5003x150ft and secondary paved 07/25 close to 4000ft threshold; runway-specific S/D loading differs. No official direction-specific LDAs established. Jet A 24hr self-service vs manager callout; tree obstructions and approved airport commercia… |
| IYK | Inyokern Airport | 2026-09-03 | Direct AirNav IYK page accessible but FAA-effective 03 SEP 2026; prior Phase4 reports Oct, so source-cycle reconciliation needed. RW15/33 asphalt 7100x75ft fair with pavement cracks PCN7; RW02/20 good 6275x75ft PCN6, distinct aircraft bearing classes. No current original per-direction LDA. Filming/NOTAM,… |
| JXN | Jackson County Airport/Reynolds Field | 2026-10-01 | October FAA-derived Jackson County/Reynolds main RW07/25 grooved asphalt 5351x100ft PCN30 and crosswind 14/32 4000x100ft PCN16. Crosswind only ~19m gross margin, no official published LDAs on either pair. Taxiway D safety-area issue, deer/winter/ATCT hours, independently required airplane loading and cou… |
| LAM | Los Alamos Airport | 2026-10-01 | CRITICAL official FAA-derived October airport remark LND W; TKOF E on single paved RW09/27 asphalt 6000x120ft, 1.5% uphill to west. Hence **RW27 westbound landing is potentially allowed and RW09 eastbound landing is not a lawful reciprocal arrival under published restriction**. Neither RW27 official LDA … |

## High-priority exceptions

**LAM — Los Alamos:** The FAA-derived October airport listing states **'LND W; TKOF E'**. This identifies the westbound landing direction as runway 27 and eastbound takeoffs as runway 09. The new runway ledger therefore records RW09 `LANDING_DIRECTION_PROHIBITED` and RW27 `ALTERNATE_DIRECTION_LDA_UNVERIFIED`, rather than inaccurately counting both ends as available for scheduled arrivals. RW27's real LDA, uphill gradient, approach barriers, 7,171ft elevation, and flight-specific ARFF (24h prior permission), nearby restricted airspace, and paid-operating rights remain unresolved. https://www.airnav.com/airport/LAM

**HWD — Hayward:** The current FAA-derived source says **RW10R displaced threshold 826ft**, while the municipal airport specification page states **816ft**; both give RW28L 676ft. On a 5,694ft main runway, the nominal figures using 826ft/676ft are 4,868ft and 5,018ft, but **neither is declared LDA**. Record the dispute pending an original FAA record. RW10L/28R short runway is below 1,200m and closes whenever the tower closes. FAA notes wrong-surface/wrong-airport risk; taxiways Z1/A1 limit aircraft wingspan above 94/100ft. https://www.airnav.com/airport/HWD · https://www.hayward-ca.gov/airport/pilot-guide/airport-specifications · https://www.faa.gov/flight_deck/hwd

**HDC — Hammond Northshore:** RW13/31 uses valid **asphalt/concrete combined paving**; RW31 displaced threshold of 690ft gives 5,812ft nominal landing pavement from 6,502ft gross, not an official LDA. Separate concrete RW18/36 has different S/D wheel load and ILS. One runway's load rating cannot be transferred to the other. https://www.airnav.com/airport/HDC

**GED — Delaware Coastal:** RW04 threshold displacement 370ft and RW22 displacement 169ft give nominal post-threshold values 5,130/5,331ft respectively; these are *not* source-published LDA. Secondary runway 10/28 is only 3,109ft gross. Airport reported frequent backtaxi; customs authorization is flight-specific. https://www.airnav.com/airport/GED

**HND — Henderson Executive:** Both 17R/35L and 17L/35R exceed initial gross runway length screen but have different S/D capacities. The FAA listing's `OPS DLY 1900-0700` applies specifically to shorter runway 17L/35R and requires date/time/NOTAM interpretation, not assumed whole-airport closure. Airport 24-hour operation and special-event PPR programs do not grant a carrier operating certificate or landing approval. https://www.airnav.com/airport/HND

**GIF — Winter Haven:** Florida DOT notes displaced thresholds at RW05 and RW29 but the consulted accessible summary does not establish their numeric shift. They are deliberately kept NULL, not silently zero. The shorter paved RW11/29 is only 4,001ft × 60ft wide: official LDA plus airplane-specific compatibility is critical. https://www.fdot.gov/aviation/airportslist/GIF · https://www.airnav.com/airport/GIF

**GLY, HTL, IYK:** AirNav directly retrieved FAA-derived editions of August 6, June 11 and September 3, 2026 respectively. Refresh to the current effective original FAA source before making any definitive declaration. HTL directly lists 100LL only, not verified Jet A.

## Individual airport source URLs

- **FWS:** [Source 1](https://www.airnav.com/airport/FWS) · [Source 2](https://www.fortworthtexas.gov/departments/aviation/spinks/general-aviation)
- **GED:** [Source 1](https://www.airnav.com/airport/GED)
- **GIF:** [Source 1](https://www.airnav.com/airport/GIF) · [Source 2](https://www.fdot.gov/aviation/airportslist/GIF)
- **GLY:** [Source 1](https://cityofclintonmo.gov/community/clinton_regional_airport.php) · [Source 2](https://www.airnav.com/airport/GLY)
- **GWR:** [Source 1](https://tallyaero.com/atlas/chart-supplement/NC_339/) · [Source 2](https://www.airnav.com/airport/GWR)
- **HAI:** [Source 1](https://www.airnav.com/airport/HAI) · [Source 2](https://www.threeriversmi.org/city-departments/municipal-airport/)
- **HCR:** [Source 1](https://heberut.gov/airport) · [Source 2](https://www.airnav.com/airport/HCR) · [Source 3](https://www.heberut.gov/404/Aircraft-Landing-Fees)
- **HDC:** [Source 1](https://hammond.org/airport/) · [Source 2](https://www.airnav.com/airport/HDC)
- **HKS:** [Source 1](https://jmaa.com/hawkins-field/) · [Source 2](https://www.airnav.com/airport/HKS)
- **HND:** [Source 1](https://acc.web.hriairport.com/hnd/events) · [Source 2](https://hnd.aero/) · [Source 3](https://www.airnav.com/airport/HND) · [Source 4](https://www.hnd.aero/)
- **HTL:** [Source 1](https://www.airnav.com/airport/HTL) · [Source 2](https://www.roscommoncounty.net/158/Airport/)
- **HWD:** [Source 1](https://www.airnav.com/airport/HWD) · [Source 2](https://www.hayward-ca.gov/your-government/departments/hayward-executive-airport)
- **HYI:** [Source 1](https://flysanmarcos.com/travel-information/for-pilots/) · [Source 2](https://www.airnav.com/airport/HYI)
- **HYR:** [Source 1](https://www.airnav.com/airport/HYR) · [Source 2](https://www.iflightplanner.com/Airports/KHYR)
- **I74:** [Source 1](https://www.airnav.com/airport/I74)
- **IDP:** [Source 1](https://aviation.ks.gov/files/KDOT_Airport_Directory_2025-2026.pdf) · [Source 2](https://vfrmap.com/fe?q=KIDP&req=get_afd) · [Source 3](https://www.airnav.com/airport/IDP)
- **IER:** [Source 1](https://www.airnav.com/airport/IER) · [Source 2](https://www.natchitochesla.gov/government/city-departments/airport/)
- **IYK:** [Source 1](https://www.airnav.com/airport/IYK) · [Source 2](https://www.inyokernairport.com/roads-runways)
- **JXN:** [Source 1](https://www.airnav.com/airport/JXN) · [Source 2](https://www.mijackson.org/232/Airport)
- **LAM:** [Source 1](https://www.airnav.com/airport/LAM) · [Source 2](https://www.losalamosnm.gov/Services/Los-Alamos-Airport)

## Database schema improvement

Previous direction checks only permitted single-material asphalt or concrete, although Airlinerra's physical runway requirement also permits valid asphalt/concrete combinations. The Batch 7 migration explicitly adds both combination orders, while retaining safeguards for all previously recorded statuses. It also adds `LANDING_DIRECTION_PROHIBITED`, strictly distinguished from below-minimum distance or merely unverified landing direction. Airport `game_admission_status` and direction `commercial_admission_status` remain forced to `NOT_APPROVED`; the research schema's row-level security and role revocations are retained.

Source-controlled files:

- [Batch 7 validation migration](./sql/AIRLINERRA_PHASE5_BATCH_07_DIRECTION_RESTRICTION_MIGRATION_2026-10-26.sql)
- [Batch 7 reproducible 36-runway-direction ledger](./sql/AIRLINERRA_PHASE5_BATCH_07_RUNWAY_DIRECTIONS_2026-10-26.sql)

## Next

Begin Phase 5 Batch 8 with the next 20 of **75** Priority-3 airports not yet source reviewed. In parallel obtain the original current FAA NASR APT field set and per-direction LDA, distinguish unavailable/blank from zero, and validate owner permission, certified operators, runway loading/width, weather/NOTAM/FICON, PPR and emergency services. **Do not enable any game world or change six-category classifications based solely on this source audit.**
