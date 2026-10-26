# Airlinerra — US Expansion Phase 5 Batch 10: Missing Landing Distance Review

**Date:** 26 October 2026 · **Private working database:** Supabase `hwllkabgzaynalahvkpz`, `airlinerra` schema · **GitHub:** `main`.

## Results and methodology

**20 of 20 queued Priority-3 airports were source-reviewed and saved in Supabase.** For each, the FAA-derived [AirNav](https://www.airnav.com/) airport directory displayed **FAA information effective 01 October 2026** and was compared against its older Phase 4 research. These are *secondary FAA-derived records*, not independently retrieved and verified original FAA NASR APT files or live NOTAMs. All 20 airport gate statuses remain `EVIDENCE_HOLD`, `OFFICIAL_LDA_NOT_VERIFIED`, and `NOT_APPROVED`. No airport game admission, six-level category changes, or world activations occurred.

| Verified measure | Count |
| --- | ---: |
| Batch 10 airports individually reviewed | **20** |
| Batch 10 individual runway ends added | **70** |
| Potentially qualifying runway ends still missing authenticated declared LDA | **46** |
| Runway ends failing physical length or surface | **24** |
| Cumulative Phase 5 initial reviews completed | **196/211 (92.9%)** |
| Phase 5 airports still queued | **15** |
| Cumulative Phase 5 runway-end evidence records | **334** |
| Phase 5 airports with gameplay admission | **0** |
| Original cohort unchanged | **3,140 airports** |
| World activation records | **0** |

Important methodology: the game's 1,200-metre runway minimum corresponds to approximately 3,937.008 feet. A 4,001ft physical runway can pass a gross initial screen but still fail direction-specific **LDA**. Use `NULL` for a not-published/not-authenticated LDA, not zero. **Do not** count threshold-displaced pavement or stopways as official declared distance, and **do not** transfer a closure, poor surface, pavement-bearing value, taxiway restriction or noise policy from one runway to the airport as a whole.

## Twenty individually sourced cases

| FAA | Airport | Region | Source-observed evidence and unresolved gate |
| --- | --- | --- | --- |
| RCX | Rusk County Airport | US-WI | Main RW14/32 is FAIR asphalt 4001x75ft, only about 19m gross above 1200m, no source-published LDA. Separate RW01/19 asphalt 3199ft POOR with numerous cracks/vegetation, and too short. Source fuel 100LL only while county owner advertises Jet A; reconcile current actual turbine fuel. RW14/32 steep tree approaches, winter and S25000lb airframe need check. |
| RDK | Red Oak Municipal Airport | US-IA | Main good concrete RW05/23 5100x75ft, RW05 threshold displaced 1000ft -> 4100ft nominal (not declared LDA); RW23 has no displaced threshold and is FAA calm-wind preferred. Separate concrete RW17/35 2901ft and seasonal turf RW13/31 2050ft both fail. PCN9, RW05 railway/tree obstacles, actual FAA LDA, city commercial charter rights and carrier not confirmed. |
| RIL | Garfield County Regional Airport | US-CO | Good grooved asphalt RW08/26 7000x100ft PCN43 F/B/X/U; no independently published per-direction LDA. At 5500ft elevation requires high-density-altitude mountain/snow and cold weather aircraft performance. Owner landing fee for >10000lb is economic rather than structural limit; runway entry/IFR, glider pattern and date NOTAM separately required. |
| RLD | Richland Airport | US-WA | Two independent GOOD asphalt runways RW01/19 4009x75ft and RW08/26 4001x100ft. Both barely above 1200m gross and no declared LDAs published in checked directory. October source clarifies BOTH list single-wheel 30000lb, double-wheel 45000lb, tandem 70000lb. RW01 PAPI unusable beyond 3NM and RW08 VASI directional limits; Port of Benton owner operating permission, actual fuel and operator unverified. |
| RNM | Ramona Airport | US-CA | Ramona RW09/27 GOOD asphalt 5001x150ft, S75000/D95000/DT170000 at ~1395ft MSL, no published FAA direction-specific LDA. RW09 PAPI unusable beyond 3NM, Class D tower 0800-2000 and wildfire aerial operations/fire TFR require dated checks; city/county commercial paid use, airplane suitability and certificated operator not established. |
| RPH | Graham Municipal Airport | US-TX | Main RW03/21 GOOD asphalt 5001x75ft PCN20 S25000/D75000, no official LDA displayed. Independent secondary RW18/36 FAIR asphalt 3317x60ft, RW18 639ft displaced threshold; physically below 1200m even before displacement. The earlier Phase4 dossier omitted this secondary; not eligible as substitute. Graham aerobatic area, traffic, city paid-flight permission and aircraft checks outstanding. |
| RRL | Merrill Municipal Airport | US-WI | Merrill RW07/25 GOOD asphalt 5101x75ft S45000/D65000/DT100000, short RW16/34 FAIR asphalt 2997x75ft underlength (NOT turf). Source 01 Oct 2026 FAA cycle. RW07 PAPI runway-specific outage noted Aug31-Nov30 and date NOTAM must be rechecked, not treated as permanent airport closure. Jet A and municipal legal charter permissions unresolved; official per-end LDA not established. |
| RSL | Russell Municipal Airport | US-KS | Russell Municipal main RW17/35 excellent concrete 5000x75ft PCN11 S30000/D30000; older city 5500ft wording is stale. Secondary RW03/21 turf 1602ft below min. Main official FAA LDA not shown; railroad obstacle RW17 and gear loading, city commercial license and actual Jet A/handling to verify. |
| RVL | Mifflin County Airport | US-PA | Mifflin County RW06/24 GOOD asphalt 5001x75ft, official RW06/RW24 LDA not published in retrieved source. Seasonal glider traffic and obstacle trees require flight-date NOTAM; Jet A after-hours by appointment and S60000 weight class need type matching, county written commercial permission and certificated carrier. |
| RVS | Tulsa Riverside Airport | US-OK | Tulsa Riverside main RW01L/19R 5101x100ft good grooved asphalt PCN27, separate RW01R/19L 4205x100ft GOOD asphalt: RW19L 142ft displaced threshold leaves only 4063ft nominal (not published LDA). Secondary RW13/31 2639ft underlength. FAA hangar taxilane restrictions >49ft wingspan/12500lb are taxilane-specific, NOT main runway structural limits. Airport PPR after 2200 and tower/aircraft/operator require separate checks. |
| SEZ | Sedona Airport | US-AZ | Sedona RW03/21 GOOD asphalt 5132x100ft at ~4830ft high mesa and aircraft S30000/D75000. FAA-derived October says calm-wind RW03 PREFERRED for landing and RW21 for takeoff; preference is NOT the categorical reciprocal landing prohibition used at Los Alamos. RW21 PAPI unusable beyond 2NM, mountain turbulence and voluntary owner night Fly Friendly guidance are separate. Official per-end LDA and owner paid-carrier rights unverified. |
| SFQ | Suffolk Executive Airport | US-VA | Suffolk Executive GOOD main RW04/22 asphalt 5007x100ft, RW22 tree only 110ft from threshold; source lacks official LDA. Second RW07/25 3750x100ft FAIR asphalt gross below 1200m, not a substitute. Parachuting/after-hours and runway-specific S30000/D60000/DT60000 class plus city paid-use and operator certificate outstanding. |
| SFZ | North Central State Airport | US-RI | North Central State main RW05/23 GOOD asphalt 5000x100ft S30000/D60000, secondary 15/33 GOOD asphalt 3211x75ft underlength. County airport corporation charges some commercial operators fees and has customs landing rights; neither is legal prior commercial airline authorization. Published per-end FAA LDA not shown; owner charter rights, airplane bearing, CBP if international and dated NOTAM still missing. |
| SGT | Stuttgart Municipal Airport / Carl Humphrey Field | US-AR | Stuttgart main RW18/36 good grooved asphalt 6015x100ft S75000/D150000/DT200000/DDT300000; other RW09/27 good concrete 5002x150ft lower S25000/D65000/DT120000. Both paved runway pairs physically pass, but no published source per-end FAA LDA. Seasonal low agricultural aircraft, migratory birds, Jet A handling/repair absence and city/certificated operator need review. |
| SKI | Sac City Municipal Airport | US-IA | Sac City FAA-derived record NOW effective 01 OCT 2026 rather than earlier September: main RW18/36 FAIR concrete 4100x75ft, engineering low PCN5 previously in Phase4, runway 36 crossing visibility/vehicle issues; separate RW14/32 GOOD concrete 2350x60ft PCN4, physically too short. 100LL only listed, official main per-end LDA and fuel/service, city consent and named carrier not established. |
| SPK | Spanish Fork Municipal Airport/Woodhouse Field | US-UT | Spanish Fork RW12/30 GOOD asphalt 6500x100ft at 4529ft MSL, PCN17 S24000/D36000; RW12 approach 60ft lit powerline and source reports nonprecision markings in poor condition. Cold temp -17C corrections and hot/high airline runway performance need analysis. Owner landing fees not categorical closure; source does not publish official per-end LDA or grant signed commercial rights. |
| SQI | Whiteside County Airport - Joseph H Bittorf Field | US-IL | Whiteside County FAA-derived now confirms 01 Oct 2026 effective record, rather than earlier September: primary RW07/25 FAIR asphalt/porous friction courses 6499x150ft, S50000/D60000/DT90000, source landing distances not explicitly published; secondary RW18/36 grooved asphalt 3900x100ft below 1200m even though pavement GOOD. ILS, friction performance, maintenance and holiday FBO, county owner/airline rights still unverified. |
| STE | Stevens Point Municipal Airport | US-WI | Stevens Point RW03/21 EXCELLENT asphalt 6028x120ft S30000/D75000/DT195000, ILS RW21. Separate RW12/30 FAIR asphalt 3635x75ft under 1200m and S9000 single wheel applies there, NOT main. FAA runway directional LDA not in retrieved secondary source. Winter, medevac/training, FBO/legal commercial approval and named operator still outstanding. |
| TDO | Ed Carlson Memorial Field South Lewis County Airport | US-WA | Ed Carlson South Lewis County RW06/24 GOOD asphalt 4479x150ft S25000, trees/skydivers/gliders require current flight-date restrictions. Only 100LL confirmed, Jet A not verified for turbine. FAA original RW06/24 LDA not independently established, nor county paid-use consent, after-hour rescue and named licensed operator. |
| THV | York Airport | US-PA | York Airport privately owned public-use RW17/35 GOOD grooved asphalt 5188x100ft, RW17 threshold displaced 794ft -> nominal 4394ft, RW35 threshold displaced 739ft -> nominal 4449ft, neither official FAA declared LDA. RW35 near obstacle 4:1 tree slope. Published taxiway restriction to RW35 bans >60ft wingspan, taxiway only. Landing fees/fuel waiver do not grant charter rights. OCT 01 source now current, correcting prior Sept. |

## Priority runway and operating exceptions

### Red Oak (RDK)

FAADerived current runway **05/23** is good concrete 5,100ft × 75ft, **RW05 threshold 1,000ft displaced**. RW05 nominal post-threshold landing pavement is 4,100ft, not a published official FAA LDA. RW23's no-displacement record and calm-wind preference do not establish LDA. Secondary **17/35 2,901ft concrete** and **13/31 2,050ft turf** are too short and do not invalidate the primary. PCN9 aircraft loading and railway/tree approach need fleet/flight-date assessment. https://www.airnav.com/airport/RDK

### Tulsa Riverside (RVS)

Main **01L/19R** is 5,101ft grooved asphalt PCN27, independent **01R/19L** is 4,205ft asphalt. RW19L displaced threshold is **142ft**, leaving nominal 4,063ft; actual FAA published LDA remains unknown and may differ. Short 13/31 2,639ft is ineligible. A private-hangar taxilane wingspan/weight restriction is specific to movement routes, not a runway-wide maximum. After-hours PPR and assigned taxi stands require flight-date verification. https://www.airnav.com/airport/RVS

### York (THV)

Privately owned, public-use paved **17/35** is 5,188ft, with displaced thresholds **RW17 794ft** and **RW35 739ft**. Nominal landing pavement 4,394ft / 4,449ft does **not** constitute authenticated declared LDA. A 4:1 close tree obstacle near RW35 and taxiway-only >60ft wingspan prohibition require alternate approach/taxi compatibility. Written private-owner commercial permission is not implied by public use. https://www.airnav.com/airport/THV

### Richland (RLD), Sac City (SKI), Whiteside (SQI)

- **Richland RLD:** both good asphalt runways marginal: 01/19 4,009ft and 08/26 4,001ft. October FAA-derived source reports S30/D45/DT70 wheel strengths on both, but official per-direction LDAs absent. https://www.airnav.com/airport/RLD
- **Sac City SKI:** independently current 1 October FAA-derived source improves on old September; main 18/36 4,100ft **fair concrete** with low PCN5, second 14/32 2,350ft concrete underlength. Explicit original landing distances still missing. https://www.airnav.com/airport/SKI
- **Whiteside SQI:** October source improves on previously cached September data; 07/25 6,499ft fair asphalt/porous-friction surface, secondary 18/36 3,900ft **below 1,200m**, regardless of its good asphalt. The primary's official LDA and friction-performance approval remain open. https://www.airnav.com/airport/SQI

### Operational restrictions that must not be generalized

- **Sedona SEZ:** airport's calm-wind preference to *land runway 03 and take off runway 21* is not an explicit ban on runway 21 arrivals. This differs from **LAM**'s one-way landing prohibition. Mountain/high-temperature airplane performance and RW21 PAPI limits still require approval. https://www.airnav.com/airport/SEZ
- **Merrill RRL:** RW07 PAPI unavailable per dated 31 Aug–30 Nov 2026 notice; update the live NOTAM for actual arrival rather than treating the whole airfield as closed. Separate 16/34 is 2,997ft **asphalt** (not turf). https://www.airnav.com/airport/RRL
- **Stuttgart SGT:** separate qualifying 18/36 6,015ft asphalt and 09/27 5,002ft concrete have **different load ratings**; agricultural and winter waterfowl activities are NOT whole-airport closures. https://www.airnav.com/airport/SGT
- **Graham RPH:** current directory also lists a 3,317ft paved 18/36 crosswind runway (RW18 639ft displaced), absent from prior Phase4 narrative; secondary cannot be treated as a qualifying alternative. https://www.airnav.com/airport/RPH
- **Suffolk SFQ, North Central SFZ, Stevens Point STE:** separate short paved runways are not game-eligible even when primary has longer runway. Airframe weight and commercial operating permissions remain independent.

## Database source archive

Every airport's full individual note, FAA-derived source URL and previous Phase 4 evidence URLs are preserved in Supabase. Seventy individual runway-direction rows, with the source-effective cycle, primary/alternate runway distinction, surface, threshold displacement where known, nominal landing-pavement calculation (when applicable), and NULL source LDA are version archived in **three replayable SQL files**:

- [Part 1 — 24 runway-end records](./sql/AIRLINERRA_PHASE5_BATCH_10_RUNWAY_DIRECTIONS_PART_01_2026-10-26.sql)
- [Part 2 — 24 runway-end records](./sql/AIRLINERRA_PHASE5_BATCH_10_RUNWAY_DIRECTIONS_PART_02_2026-10-26.sql)
- [Part 3 — 22 runway-end records](./sql/AIRLINERRA_PHASE5_BATCH_10_RUNWAY_DIRECTIONS_PART_03_2026-10-26.sql)

## Next phase

**Batch 11:** complete the final 15 airport *initial source reviews* in the 211-airport Phase 5 cohort. That will **not** mean 211/211 airports are fully approved: separately retrieve authenticated FAA official per-direction declared LDAs; evaluate aircraft-specific landing, weight, width and hot/high performance; obtain written airport-owner paid-carrier rights, named certificated commercial operator, flight-date NOTAM/weather/FICON and fuel/handling/rescue confirmation. Keep all gameplay admission blocked until those gates are independently satisfied.
