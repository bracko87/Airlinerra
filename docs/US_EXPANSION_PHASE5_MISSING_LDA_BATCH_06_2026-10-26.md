# Airlinerra — US Expansion Phase 5 Batch 6: Missing LDA Evidence Audit

**Date: 26 October 2026 · Private Supabase project `hwllkabgzaynalahvkpz`, schema `airlinerra`.**

## Results and evidence limitations

Twenty Priority-3 airport desk-source records were completed and audited. All 20 remain `EVIDENCE_HOLD`, `OFFICIAL_LDA_NOT_VERIFIED`, `NOT_APPROVED`; **no officially authenticated direction-specific FAA LDA** was established by this pass. These are FAA-derived third-party and airport-owner observations, not a legal airline operating approval. Added 20 direction-specific rows for 10 airports, all explicitly `ALTERNATE_DIRECTION_LDA_UNVERIFIED` with NULL official LDA.

After Batch 6, **116 of 211 Phase 5 airports have had initial source reviews, 95 remain queued, and all 211 remain NOT_APPROVED**. The direction ledger contains 90 rows. The 3,140 runway-only original records remain untouched; world activation remains empty.

The original [FAA NASR current October 1, 2026 APT CSV source](https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/) was identified, but its ZIP could not be fetched through web/container tools and the original eNASR site/ZIP timed out through browser extraction. No source confidence was increased on that basis. A 'not published' value from secondary listings means unknown; do not substitute gross runway length, TORA, displaced-threshold arithmetic or an instrument approach.

## The 20 airport cases

| FAA | Airport | Region | Checked source cycle | Findings and next action |
| --- | --- | --- | --- | --- |
| EKX | Addington Field / Elizabethtown Regional Airport | US-KY | 2026-09-03 | Direct AirNav source available shows 03 Sep 2026 cycle, not an independently current October NASR entry. Primary 05/23 asphalt 6001x100ft and S50000/D77000lb; FAA remark prohibits taxiway D use by aircraft with >50ft wingspan OR >12500lb gross. This is a *taxiway routing restriction*, not 12500lb runway load. Per-direction official LDA not shown. Need current FAA APT record, alternate ground routing, airport-board paid use and named certified carrier. |
| ELO | Ely Municipal Airport | US-MN | 2026-10-01 | AirNav current 01 Oct 2026 confirms RW12/30 asphalt 5596ft, good condition, PCN39 and S99000/D159000lb, RW30 approach trees. No RW12 or RW30 officially published LDA established in consulted directory. Forest-service aircraft/TFRs, northern winter FICON, customs clearance if relevant, seasonal staffing and carrier/owner permissions remain separate. |
| ELY | Ely Airport Yelland Field | US-NV | 2026-09-03 | Direct AirNav opened version shows 03 Sep 2026 FAA effective date, not October. Main 18/36 excellent asphalt 6017x150ft at elevation 6259ft; secondary 12/30 4825x60ft S15000lb must be fleet-matched separately. No official per-direction LDA in accessed source; high-density-altitude/after-hours FBO, local owner permits and certified carrier outstanding. |
| EPH | Ephrata Municipal Airport | US-WA | 2026-10-01 | AirNav 01 Oct 2026 confirms main RW03/21 5500x75ft good asphalt S30000/D60000, separate 11/29 3843ft below 1200m and 04/22 glider runway 3467ft short. No published RW03 or RW21 LDA in secondary directory. Glider and aerobatic traffic April-Nov requires flight-date checks, not a blanket main runway closure. Fuel/owner/operator clearance outstanding. |
| EPM | Eastport Municipal Airport | US-ME | 2026-10-01 | AirNav 01 Oct 2026 lists RW14/32 asphalt 4002x75ft, only ~20m gross margin above 1200m. No per-direction FAA declared landing distances in consulted page; RW14 PAPI unusable angular sectors, Maine winter/FICON and CBP permission if border operations, city paid use and carrier certificate still unverified. |
| EST | Estherville Municipal Airport | US-IA | 2026-09-03 | Direct AirNav page shows effective 03 Sep 2026, despite earlier Phase4 October characterization. RW16/34 concrete 4797x75ft S11000lb; separate turf 06/24 ineligible. No direction-specific published LDA. Use Oct NASR current cycle for final review, then airplane loads/obstacles, winter callout, owner/certificated operator. |
| ETB | West Bend Municipal Airport | US-WI | 2026-10-01 | AirNav 01 Oct 2026 confirms main 13/31 asphalt 4494x75ft S15000lb, short 06/24 3898ft below minimum. No published direction-specific LDA in consulted record. Approach trees/road, winter dispatch, government heliport usage and paid-charter city rights/operator cert must be assessed separately. |
| EZM | Heart of Georgia Regional Airport | US-GA | 2026-09-03 | AirNav rendered page cached effective 03 Sep 2026, while independently indexed GlobalAir runway page reports 01 Oct 2026 and explicitly shows LDA 'N/A' RW02 and RW20. Asphalt grooved 02/20 6506x100ft, S75000/D120000lb, no published declared LDA established. FAA original eNASR web page and Oct CSV ZIP access attempted but blocked/timeouts, so no falsely verified current official LDA. Tower/ILS, trees, owner-carrier permits unverified. |
| F00 | Jones Field | US-TX | 2026-10-01 | AirNav 01 Oct 2026 FAA-derived RW17/35 4000x75ft good asphalt, S12500lb, physical length only ~19m above 1200m, no published per-end LDA. Approach trees/antenna and April-Aug crop flights require current NOTAM; named airline approval and city written commercial use absent. |
| F05 | Wilbarger County Airport | US-TX | 2026-10-01 | AirNav 01 Oct 2026 lists RW02/20 5099x100ft excellent asphalt and independent RW16/34 4304x80ft fair asphalt with only S10000lb rating; do not transfer secondary's weight rating to primary. No official RW02/20 LDA shown. Crop flying, tall grass near pavement, county paid-use/certified carrier and ground services unverified. |
| FBL | Faribault Municipal Airport-Liz Wall Strohfus Field | US-MN | 2026-10-01 | CURRENT October-indexed AirNav and SkyVector detail confirms paved RW12/30 4257x75ft, displaced RW30 230ft. Nominal RW30 pavement is 4027ft (1227.4m), **~27.4 METRES / 90 feet above 1200m**, not 27 feet or 8 metres as prior Phase4 text incorrectly stated. RW12 4257ft gross with no displacement; neither direction's official LDA published in consulted source. Preserve Oct result rather than stale AirNav August cached copy. S16000/D22000 aircraft fit, RW12 tree and RW30 roadway, owner/airline permission unresolved. |
| FDK | Frederick Municipal Airport | US-MD | 2026-10-01 | AirNav 01 Oct 2026 primary 05/23 5819x100ft grooved asphalt PCN30, 12/30 secondary 3599ft under minimum. FAA-derived source does not establish main per-direction LDA. City landing fees apply to some nonbased aircraft >12500lb; **a fee is not an aircraft maximum or legal carrier permission**. ATC/approach/owner permit and selected airframe pending. |
| FLP | Marion County Regional Airport | US-AR | 2026-10-01 | AirNav 01 Oct 2026 lists runway 04/22 5001x75ft good asphalt S30000lb, visibility line-of-sight limitation across runway ends and deer/tree risks; per-direction official LDA absent. CTAF separation and legal county paid-carrier/operator permissions, fuel/ARFF proof pending. |
| FLX | Fallon Municipal Airport | US-NV | 2026-10-01 | AirNav 01 Oct 2026 RW03/21 5705x75ft asphalt with RW03 displaced threshold 102ft, nominal RW03 landing pavement 5603ft. This is NOT official published LDA. Separate 13/31 dirt 3581ft disqualified. Source TORA 5703ft is a different declared-distance field, not LDA. High-desert crop/road/aircraft wheel S17000 and owner/operator access unverified. |
| FMM | Fort Morgan Municipal Airport | US-CO | SOURCE_NOT_OPENED | Direct AirNav FMM access failed; city owner source and retained Phase4 dossier describe RW14/32 5731x75ft asphalt and turf/dirt RW17/35 ineligible by surface. This Batch 6 case had no independent accessible currently-effective FAA per-direction LDA or source cycle. Do not label October FAA verified. Airframe, road obstacle, altitude/wildfire/ag traffic, fuel/repairs, owner commercial and named carrier pending. |
| FOA | Flora Municipal Airport | US-IL | SOURCE_NOT_OPENED | Direct AirNav FOA page was inaccessible in this pass. Retained Phase4 source dossier lists 03/21 paved 5003x75ft and 15/33 2715ft turf. No current official per-direction FAA LDA verified; instrument LOC RW21 alone does NOT prove usable landing distance. Document source retrieval gap, approach trees, aircraft gear, owner paid-use and certified operator outstanding. |
| FOT | Rohnerville Airport | US-CA | 2026-10-01 | AirNav 01 Oct 2026 shows runway 11/29 4004x100ft fair asphalt, S30000lb and no published LDA despite nominal physical 4004ft (~20m above floor). Landing fee does not mean commercial air carrier allowed. FAA-published runway GPS instrument approach charts NOT accepted as LDA without documented declared distance. Fuel lists 100LL only, no confirmed Jet A; coastal fog/wildfire aircraft and county permissions outstanding. |
| FTY | Fulton County Airport Brown Field | US-GA | 2026-10-01 | AirNav 01 Oct 2026 calls airfield **Fulton County Executive Airport/Charlie Brown Field**, while stable registry uses Fulton County Airport Brown Field; preserve key, flag name harmonization. RW08/26 grooved asphalt 5797x100ft, S105000/D121000/DT198000lb, ILS RW08. Do not transfer Atlanta ATL operator rights or assume customs landing-rights status permits flight-specific entry. No per-direction official LDA found; traffic/animal/noise/airport project NOTAM and county commercial agreement outstanding. |
| FVE | Northern Aroostook Regional Airport | US-ME | 2026-10-01 | AirNav 01 Oct 2026 lists RW14/32 excellent asphalt 4600x75ft, S25000lb, airport customs landing rights but no per-direction official LDA shown. Municipal fee/customs designation is not an airline permit; cold winter services, named certificated operator and owner paid-use agreement unverified. |
| FWC | Fairfield Municipal Airport | US-IL | SOURCE_NOT_OPENED | Direct AirNav FWC page failed to load; city official airport webpage in Phase4 indicates RW09/27 4000x75ft asphalt with ~19m gross margin and a short secondary runway. This does NOT establish an official FAA usable landing distance or publication cycle. Crop activity, runway bearing capacity, after-hours handling, city commercial rights and actual operator certificate must be checked. |

## The 20 directional runway evidence records

| FAA | End | Runway | Physical ft | Displaced threshold ft | Nominal ft | FAA source cycle | Status |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| EKX | 05 | 05/23 | 6001 | — | — | 2026-09-03 | LDA NOT VERIFIED |
| EKX | 23 | 05/23 | 6001 | — | — | 2026-09-03 | LDA NOT VERIFIED |
| EPH | 03 | 03/21 | 5500 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| EPH | 21 | 03/21 | 5500 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| EPM | 14 | 14/32 | 4002 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| EPM | 32 | 14/32 | 4002 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| EZM | 02 | 02/20 | 6506 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| EZM | 20 | 02/20 | 6506 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| F00 | 17 | 17/35 | 4000 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| F00 | 35 | 17/35 | 4000 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| FBL | 12 | 12/30 | 4257 | 0 | 4257 | 2026-10-01 | LDA NOT VERIFIED |
| FBL | 30 | 12/30 | 4257 | 230 | 4027 | 2026-10-01 | LDA NOT VERIFIED |
| FLX | 03 | 03/21 | 5705 | 102 | 5603 | 2026-10-01 | LDA NOT VERIFIED |
| FLX | 21 | 03/21 | 5705 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| FOT | 11 | 11/29 | 4004 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| FOT | 29 | 11/29 | 4004 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| FTY | 08 | 08/26 | 5797 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| FTY | 26 | 08/26 | 5797 | — | — | 2026-10-01 | LDA NOT VERIFIED |
| FWC | 09 | 09/27 | 4000 | — | — | — | LDA NOT VERIFIED |
| FWC | 27 | 09/27 | 4000 | — | — | — | LDA NOT VERIFIED |

## Exception register

- **FBL (Faribault):** RW30 nominal available pavement = 4,257 − 230 = **4,027ft**, approximately **27.4 metres / 90 feet above** 1,200m. Earlier Phase 4 reports describing the margin as 27 feet or 8m are incorrect. This is still *not* a published FAA LDA. Evidence: https://www.airnav.com/airport/KFBL and https://skyvector.com/airport/FBL/Faribault-Municipal-Liz-Wall-Strohfus-Field-Airport
- **EKX (Addington):** 12,500lb and 50ft wingspan remark is specific to **taxiway D**, not runway weight-bearing and not an airport-wide closure. Current FAA routing/owner approval pending. Evidence: https://www.airnav.com/airport/EKX
- **EZM (Heart of Georgia):** Original eNASR source unavailable and GlobalAir October listing states LDA N/A on both headings; the record cannot be promoted from 6,506ft gross. Evidence: https://www.globalair.com/airport/apt.runway.aspx?aptcode=ezm
- **FTY (Fulton County):** Current FAA-derived display name Fulton County Executive Airport/Charlie Brown Field differs from the registry's older label; preserve stable identity key. FTY must not borrow ATL commercial airline permissions. Evidence: https://www.airnav.com/airport/FTY
- **FOT, F00, EPM, FWC:** Physical runway ~4,000ft leaves very narrow margin; FAA-specific usable per-end LDA unknown. FWC source could not be retrieved from FAA-derived directory, so city source-only dated information is not represented as current FAA. Evidence: https://www.airnav.com/airport/FOT ; https://www.airnav.com/airport/F00 ; https://www.airnav.com/airport/EPM ; https://cityoffairfieldillinois.com/airport/
- **FLX (Fallon):** RW03's 102ft displaced threshold leaves 5,603ft nominal, and TORA 5,703ft is **not LDA**; short dirt second runway excluded. Evidence: https://www.airnav.com/airport/FLX
- **ELO vs ELY:** distinct Ely airports in Minnesota (ELO) and Nevada (ELY), different keys. ELY has very high-elevation airplane-performance risk; no name-based coalescing.
- Source-cycle gaps remain for EKX, ELY, EST and EZM (directly opened September snapshots); some available FBL snapshots were older but an October-indexed FAA-derived page was also accessible. FMM, FOA and FWC directories failed to open and remain flagged.

## Original evidence links retained per airport

- **EKX**: [Source 1](https://ekxairport.com/) · [Source 2](https://www.airnav.com/airport/EKX)
- **ELO**: [Source 1](https://www.airnav.com/airport/ELO) · [Source 2](https://www.ely.mn.us/airport)
- **ELY**: [Source 1](https://whitepinecounty.net/127/Airport) · [Source 2](https://www.airnav.com/airport/ELY)
- **EPH**: [Source 1](https://wsdot.wa.gov/travel/aviation/airports-list/ephrata-municipal) · [Source 2](https://www.airnav.com/airport/EPH)
- **EPM**: [Source 1](https://www.airnav.com/airport/EPM) · [Source 2](https://www.eastport-me.gov/206/Municipal-Airport)
- **EST**: [Source 1](https://secure.iowadot.gov/aviation/data_driven/publications/mapinfosys/AirportDirectory.aspx?FAACode=EST) · [Source 2](https://www.airnav.com/airport/EST)
- **ETB**: [Source 1](https://www.airnav.com/airport/ETB)
- **EZM**: [Source 1](https://enasr.faa.gov/eNASR/nasr/Current/Airport/8416) · [Source 2](https://www.airnav.com/airport/EZM)
- **F00**: [Source 1](https://www.airnav.com/airport/F00) · [Source 2](https://www.cityofbonham.org/371/Jones-Field-Airport)
- **F05**: [Source 1](https://www.airnav.com/airport/F05) · [Source 2](https://www.co.wilbarger.tx.us/page/Airport)
- **FBL**: [Source 1](https://www.airnav.com/airport/FBL)
- **FDK**: [Source 1](https://cityoffrederick.com/1265/Airport-Services) · [Source 2](https://www.airnav.com/airport/FDK)
- **FLP**: [Source 1](https://fly.arkansas.gov/uploads/7/5/7/7/75772239/flippin.pdf) · [Source 2](https://www.airnav.com/airport/FLP)
- **FLX**: [Source 1](https://www.airnav.com/airport/FLX) · [Source 2](https://www.fallonnevada.gov/fallon-municipal-airport-flx/)
- **FMM**: [Source 1](https://www.airnav.com/airport/FMM) · [Source 2](https://www.cityoffortmorgan.com/80/Airport)
- **FOA**: [Source 1](https://airnav.com/airport/KFOA) · [Source 2](https://www.airnav.com/airport/FOA)
- **FOT**: [Source 1](https://www.airnav.com/airport/FOT)
- **FTY**: [Source 1](https://fultoncountyga.gov/airport) · [Source 2](https://www.airnav.com/airport/FTY)
- **FVE**: [Source 1](https://www.airnav.com/airport/FVE)
- **FWC**: [Source 1](https://cityoffairfieldillinois.com/airport/) · [Source 2](https://www.airnav.com/airport/FWC)

## Next gates

Obtain authenticated currently effective original FAA APT/NASR runway-end fields; distinguish missing declarations from below-minimum declarations. Verify selected aircraft type and runway-specific strength/width, airport-owner signed paid-commercial use rights, an actually certificated operator and permitted flight class, date-valid NOTAM/weather/FICON, fuel and rescue/handling. No world activation, category promotion or release from this research.

**Next queue:** 95 not yet reviewed Priority-3 airports for Phase 5 Batch 7; FAA original-source backfill is also a parallel prerequisite for the existing 116 initial reviews.