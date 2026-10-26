# Airlinerra — US Expansion Phase 5 Batch 8: Missing Landing Distance

**26 October 2026 · Supabase private research schema `airlinerra` · GitHub `main`.**

## Verified completion

**20 of the 75 queued Priority-3 airports reviewed**, each against an FAA-derived AirNav source that reports **FAA information effective 01 October 2026**. Detailed notes and source URLs are preserved per airport in Supabase. Every one of these airports remains `EVIDENCE_HOLD`, `OFFICIAL_LDA_NOT_VERIFIED` for its potential qualifying runway, and `NOT_APPROVED` for gameplay. No active world airports or airport category approvals created.

| Verified measurement | Count |
| --- | ---: |
| Airports individually source-reviewed in Batch 8 | **20** |
| New runway-direction observations | **66** |
| Runway ends physically eligible for further LDA verification but official LDA unknown | **48** |
| Runway ends physically short or surface-ineligible | **16** |
| Runway ends with source-published LDA shorter than 1,200m (LXL short runway) | **2** |
| Overall Phase 5 first-pass source-reviewed | **156 / 211 (73.9%)** |
| Still queued for initial source review | **55** |
| Cumulative Phase 5 runway-direction records | **192** |
| Phase 5 game approvals | **0** |
| Original Phase 1 cohort unchanged | **3,140 airports** |
| World activations | **0** |

## Evidence classification

All 20 AirNav airport-directory pages independently fetched for this batch display 01 October 2026. Such **FAA-derived directory records are secondary references**, not independently authenticated original FAA NASR APT data downloads. As in preceding batches, the direction's *published LDA* cannot be inferred from gross runway pavement length, displaced-threshold arithmetic, a stopway, instrument procedures, owner acceptance, or a city master plan. Where the exact LDA is unavailable, the database stores NULL, not zero. A published LDA on a **short separate runway** does not approve the other runway.

## All 20 airports

| FAA | Airport | Region | Research result and unresolved gate |
| --- | --- | --- | --- |
| LCG | Wayne Municipal Airport / Stan Morris Field | US-NE | AirNav FAA-derived 2026-10-01 currently labels paved main 18/36 (not older municipal 17/35), excellent concrete 4201x75ft S30000lb. Secondary concrete 05/23 3406ft below 1200m; turf 13/31 shorter. RW18 road/approach slope 22:1 and RW36 approach crosses turf RW31. Fuel currently 100LL only (no Jet A verified). No official per-end LDA in consulted listing; selected aircraft, rescue, winter NO |
| LCQ | Lake City Gateway Airport | US-FL | AirNav 2026-10-01: primary 10/28 fair asphalt 8003x150ft PCN42, S75/D105/DT250; secondary 05/23 excellent asphalt 4000x75ft much weaker PCR11 and only ~19m gross margin over minimum. Do not transfer secondary pavement strength to primary. Original official LDA absent both ends; tower service 0800-1630 weekday is not whole-airport closure, pole obstruction and current NOTAM, county paid-carr |
| LFK | Angelina County Airport | US-TX | AirNav FAA-derived 2026-10-01 verifies paved 07/25 5400x100ft good asphalt S60/D90 with poor/faded approach markings and ILS RW07; 16/34 4311x100ft fair asphalt S30, RW34 107ft displaced threshold, nominal 4204ft. FAA remarks 296ft PAVED STOPWAY northwest end of 16/34; do not add stopway to landing length. No published official LDA on any eligible end; trees, pavement/performance, owner per |
| LHM | Lincoln Regional Karl Harder Field | US-CA | AirNav effective 2026-10-01: Lincoln Regional/Karl Harder 15/33 asphalt 6001x100ft with ILS and approach trees; S30000/D60000lb. No declared per-direction LDA published in consulted source. FBO Jet A/parking/after-hours callout, current NOTAM and city written commercial operation permission with certificated carrier unverified. Authentic per-direction original FAA LDA for potentially qualif |
| LIU | Littlefield Municipal Airport | US-TX | AirNav effective 2026-10-01 lists 01/19 fair asphalt 4021x60ft (ONLY ~25.8m gross above minimum), S12000lb single-wheel and hot-high 3611ft elevation; 13/31 secondary asphalt only 2513x40ft below minimum S5000 not same load as main. 100LL-only listed, Jet A not verified. Official RW01/19 direction-specific LDA unknown, aircraft 60ft width/load, obstacles and municipality paid-use/operator s |
| LMO | Vance Brand Airport | US-CO | AirNav FAA-derived effective 2026-10-01 confirms Vance Brand 11/29 good concrete 4799x75ft at ~5055ft elevation, S30000lb; RW11 VASI not valid for obstacle clearance beyond 3.9nm and nearby drainage ditch, RW29 highway/structures. City voluntary noise abatement is not binding closure; skydiving and hot-high performance require flight date assessment. Direction LDA, municipal written rights  |
| LND | Hunt Field | US-WY | AirNav 2026-10-01 Hunt Field 04/22 excellent asphalt 5000x75ft PCN37, altitude 5589ft; RW04 PAPI unusable beyond 2nm, significant approach trees/hill and mountain downslope turbulence. Published official RW04/22 LDA not in directory. City airplane/carrier permits, climb hot-high/weather and emergency response unresolved. Authentic per-direction original FAA LDA for potentially qualifying ru |
| LPC | Lompoc Airport | US-CA | AirNav effective 2026-10-01 runway 07/25 4600x100ft excellent asphalt, RW25 displaced threshold 118ft -> nominal pavement 4482ft, NOT official LDA. S17000 single-wheel, approach power lines/brush; heavy frequent skydiving and explicit no midfield crossing during drop operations. Airport owner commercial right, operator certificate and flight-date drop zone/NOTAM unresolved. Authentic per-di |
| LUM | Menomonie Municipal Score Field | US-WI | AirNav FAA-derived 2026-10-01 RW09/27 5074x75ft fair asphalt primary; 18/36 3470x75ft secondary below minimum. Menomonie city round figure 5100ft is NOT the current published FAA-derived physical length; official per-end LDA not recorded. Jet A+ / repair services, seasonal birds, noise-sensitive west approach and owner charter authorization need verification. Authentic per-direction origina |
| LVK | Livermore Municipal Airport | US-CA | AirNav 2026-10-01 RW07L/25R 5253x100ft excellent grooved asphalt S45000/D90000lb; short 07R/25L 2699ft ineligible and helipad H1 explicitly closed, not main runway closure. IMPORTANT: tower hours 0700-2100; secondary lighting not available when tower shut, main runway lighting independent; city voluntary restraint 2200-0600 is guidance, not blanket legal curfew. Main official LDA absent, wr |
| LWV | Lawrenceville Vincennes International Airport | US-IL | AirNav effective 2026-10-01: two distinct paved RW18/36 5199x100ft and RW09/27 5198x100ft, FAA-listed pavement S75000/D100000/DT180000lb, plus separate ultralight turf. Neither pair has official declared LDA in consulted directory. VASI angular warnings, airport-owner paid-operation agreement, repairs absent, traffic/NOTAM, customs status and certified operator unverified despite internatio |
| LXL | Little Falls-Morrison County-Lindbergh field | US-MN | AirNav effective 2026-10-01: main 13/31 asphalt runway *4010x75ft* with 'ADNL 500 FT OFF NW END MKD UNUSBL' (additional 500ft beyond runway end marked unusable), do NOT automatically subtract it from 4010ft surveyed primary pavement without FAA certified declared data. Main official LDA missing, only ~22m physical margin. Secondary 18/36 paved 2858ft with explicitly source-published **LDA 2 |
| LZZ | Lampasas Airport | US-TX | AirNav 2026-10-01 primary 16/34 currently 4202x75ft good asphalt S12500lb, not a proposed 5000ft extension. City approved design does not establish built usable runway. Main official LDA unavailable, airport with 100LL only/no Jet A verified. Wildlife, close trees/terrain, pavement gear load and owner signed paid carrier rights pending. Authentic per-direction original FAA LDA for potential |
| M17 | Bolivar Municipal Airport | US-MO | AirNav effective 2026-10-01 RW18/36 4000x75ft excellent asphalt S12500lb, only ~19m physical above 1200m; separate 17/35 2120ft turf ineligible. RW36 PAPI prior fault needs current flight-date NOTAM; 100LL and Jet A card fuel listings not proof certified airline access. Official declared landing distance both ends not shown; owner contract and carrier pending. Authentic per-direction origin |
| MAI | Marianna Municipal Airport | US-FL | AirNav 2026-10-01 primary RW18/36 good asphalt 6001x100ft and separate 08/26 asphalt 4763x100ft POOR with grass-filled cracks, loose aggregates and faded markings. Oct13 city recommendation to repair 08/26 is not proof closure or completed rehabilitation. No authentic current published RW18/RW36 LDA in consulted listing. Aircraft PCN52, military rotor traffic, construction flight-date NOTAM |
| MBG | Mobridge Municipal Airport | US-SD | AirNav 2026-10-01 paved RW12/30 4410x75ft good asphalt S15000lb, separate 17/35 turf 2387ft with snow/animal limitations ineligible. Main official LDA missing, trees/winter FICON, fuel/ground rescue and city commercial charter/operator permissions unresolved. Authentic per-direction original FAA LDA for potentially qualifying runways NOT VERIFIED, game NOT_APPROVED, other operating gates re |
| MBY | Omar N Bradley Airport | US-MO | AirNav 2026-10-01 paved main 13/31 excellent concrete 5000x75ft S30000/D38000lb, separate 05/23 concrete 3350x60ft under minimum S4000. City explicitly maintains commercial aircraft permit/policy; availability of a permit application is NOT prior approval. No published main LDA, airplane-class loading, crop traffic/current NOTAM and named licensed operator agreement pending. Authentic per-d |
| MEB | Laurinburg Maxton Airport | US-NC | AirNav 2026-10-01 05/23 excellent asphalt 6503x100ft with RW23 threshold displacement 187ft -> nominal pavement 6316ft, not official LDA. Secondary 13/31 3536ft concrete under minimum with huge **2750ft STOPWAY ON SOUTHEAST END** that MUST NOT be added to runway length or LDA; 18/36 closed. Heavy parachute/military ops, owner FAQ no currently scheduled commercial service; require written au |
| MFI | Marshfield Municipal Airport | US-WI | AirNav FAA-derived 2026-10-01 primary RW16/34 5003x100ft FAIR asphalt S35000/D50000lb; 05/23 3600ft short ineligible. Main direction-specific LDA unverified; airport and NOTAM third-party references show potential approach lighting/PAPI/REIL and crane restrictions but these are dated, NOT certified flight-date NOTAM. Winter response and municipality owner carrier certification outstanding.  |
| MGJ | Orange County Airport | US-NY | AirNav FAA-derived 2026-10-01 primary RW04/22 grooved asphalt 5006x100ft S30000/D57000/DT85000lb. Alternate 08/26 3664x100ft (RW26 threshold displaced 315ft) gross below 1200m; cannot rescue missing primary LDA. Main 04/22 has steep approach tree slopes, right traffic RW22, nearby Stewart jets, noise procedures. County FAA-derived values differ from older owner-rounded runway sizes; signed  |

## Significant runway-end exceptions and source controls

### LXL — Little Falls / Morrison County (Minnesota)

Source [AirNav LXL](https://www.airnav.com/airport/LXL) explicitly lists the short **18/36 runway, gross 2,858ft, published LDA 2,856ft in both directions**, below the game threshold. Those two runway ends were marked `PUBLISHED_LDA_BELOW_1200M`. A different, potentially qualifying main **13/31 runway is 4,010ft gross**; the comment 'additional 500ft off northwest end marked unusable' concerns pavement *beyond* the stated runway dimensions. Do not subtract 500ft from 4,010ft without an authenticated FAA runway survey. Main-runway official LDA remains unverified.

### MEB — Laurinburg–Maxton (North Carolina)

AirNav [runway 05/23](https://www.airnav.com/airport/MEB) is 6,503ft gross, RW23 has a 187ft displaced threshold, leaving 6,316ft *nominal* landing pavement, NOT official LDA. Separate **13/31 runway only 3,536ft**, and its unusual **2,750ft concrete stopway** on the southeast end is *not* landing distance. Closed runway 18/36, parachute jumps and military aircraft require independent notices. Owner reports no existing scheduled passenger airline service; legal paid-use rights and certified carrier must be verified separately.

### LFK — Angelina County (Texas)

Two separate paved runways, 07/25 at 5,400ft and 16/34 at 4,311ft. RW34 has a **107ft displaced threshold**, yielding 4,204ft nominal pavement, and there is a **296ft paved stopway** outside the surveyed usable runway. Stopway must NOT increase runway/LDA. Differing pavement strength and tree obstruction require aircraft-specific analysis. [FAA-derived AirNav entry](https://www.airnav.com/airport/LFK).

### LCQ, LVK, MAI — Independent runways and restrictions

- Lake City (LCQ): primary 10/28 at 8,003ft, PCN42, while secondary 05/23 at 4,000ft has a much lower bearing class. Never carry the higher primary load rating to secondary. [Source](https://www.airnav.com/airport/LCQ).
- Livermore (LVK): 07L/25R is 5,253ft while separate 07R/25L is only 2,699ft. City's 22:00–06:00 night-flying restraint is published as **voluntary**, not a mandatory closure; the short runway lighting and closed helipad do not shut the main runway. [Source](https://www.airnav.com/airport/LVK).
- Marianna (MAI): 18/36 6,001ft good asphalt; other 08/26 4,763ft is **poor/cracked with loose aggregate**. A rehabilitation proposal or contract action does not prove completed work or permanent runway closure. Live NOTAM required. [Source](https://www.airnav.com/airport/MAI).

### Narrow-margin and aircraft-compatibility cases

LIU (4,021ft × 60ft asphalt; S12), M17 (4,000ft × 75ft; S12.5), and LXL main (4,010ft × 75ft) have limited physical distance above 1,200m. Failing to obtain per-direction official LDA would make a false approval particularly likely. Airport-owner commercial rights, certified operator, aircraft load and width/turning performance, fuel and flight-date NOTAM are separate mandatory gates.

## Source and SQL archives

Every airport has an individually saved AirNav source link at `https://www.airnav.com/airport/<FAA ID>` plus any prior Phase 4 agency sources in private Supabase. Three idempotent SQL archives (22 runway-end rows each) contain the **full 66 direction records**, source-cycle dates, runway names, surface, nominal/displaced information, LDA or NULL, classification and airport-approval hold:

- [Direction SQL archive — Part 1](./sql/AIRLINERRA_PHASE5_BATCH_08_RUNWAY_DIRECTIONS_PART_01_2026-10-26.sql)
- [Direction SQL archive — Part 2](./sql/AIRLINERRA_PHASE5_BATCH_08_RUNWAY_DIRECTIONS_PART_02_2026-10-26.sql)
- [Direction SQL archive — Part 3](./sql/AIRLINERRA_PHASE5_BATCH_08_RUNWAY_DIRECTIONS_PART_03_2026-10-26.sql)

## Next steps

**Batch 9** should take 20 of the 55 remaining queued Priority-3 airports. In parallel retrieve original FAA effective-cycle NASR runway-end data for the reviewed cohort, and continue independent aircraft performance/load, owner signed legal permissions, certificated operator by commercial flight class, fuel/handling/rescue and flight-date NOTAM/FICON/weather checks. The 156/211 figure means **initial source-review coverage only, not 156 operationally approved airports**. Never change Airlinerra's six-category classification or world activation based merely on this research.
