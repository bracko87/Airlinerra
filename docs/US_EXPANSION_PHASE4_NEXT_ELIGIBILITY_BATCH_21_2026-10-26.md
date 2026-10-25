# Airlinerra — Phase 4 Next-Eligibility Batch 21 — 26 October 2026

**Committed from independently verified Supabase findings:** 10 distinct previously unreviewed airport eligibility assessments. **Seven airports have an FAA-published LDA above the 1,200-metre threshold in one or more specified directions; three retain unverified published landing distances.** All ten are `BLOCKED_PENDING_REQUIRED_EVIDENCE` / `NOT_APPROVED`; a passed runway-distance screen does **not** imply commercial flight permission or activation.

**Batch identifier:** `US_EXPANSION_PHASE4_NEXT_GATE_BATCH_21_2026_10_26`; **review date:** 2026-10-26; primarily FAA aeronautical data effective 2026-10-01. Research/eligibility only, not navigation advice or flight authorization.

## Independent database audit

| Gate/check | Verified result |
|---|---:|
| Distinct Batch 21 Phase 4 airport assessments saved | **10** |
| Airports with FAA-published qualifying LDA | **7** |
| Cases lacking authoritative direction-specific LDA | **3** |
| Wrong FAA identifiers, duplicate airport keys, incomplete sources or actions, parent-state mismatches | **0** |
| Phase 4 reviewed through Batch 21 | **210 of 211** |
| Narrowly advanced airports awaiting Phase 4 | **1** |
| Phase 3 individual first-pass reviews | **833** |
| Separate Phase 3 operational holds | **622** |
| US expansion candidate records preserved | **1,929** |
| Original playable airports preserved | **3,140** |
| Gameplay approvals / expansions activated / final game category assignments | **0 / 0 / 0** |

## Ten individually recorded airport findings

### HUT — Hutchinson Municipal Airport

**Immutable key:** `OURAIRPORTS:3598` · **Reviewed runway:** 13/31 excellent asphalt 7003x100ft LDA 7003ft both directions; 04/22 fair asphalt 4405ft LDA 4401ft both; 17/35 excellent concrete 4012ft LDA 4012ft both · **Gross primary length:** 7003ft · **Selected FAA LDA:** 7003ft · **Distance gate:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft loading and operational limitations:** Primary PCN17 S44/D58/DT103 thousand lb; 04/22 S42/D52, 17/35 PCN14 S43.5/D58.5; do not transfer loads

**Case finding:** FAA Oct data establish primary RW13 and RW31 LDA 7003ft, crosswind RW04/22 LDA 4401ft and RW17/35 LDA 4012ft; all above 1200m but third runway has only ~23m margin. Crossing runways used for taxi, birds, 0300-1100Z surface conditions unmonitored, tower 0600-2200 and after-hours assistance require date-specific routing/NOTAM. Published landing distance does not confer signed commercial rights or certified operator.

**Required next checks:** Reconfirm declared distances and runway-specific pavement/aircraft fit, crossing-runway taxi and winter/FICON, fuel and ARFF, city commercial-use contract and named certificated carrier.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://aeronav.faa.gov/Upload_313-d/supplements/CS_NC_20260319.pdf) · [Source 2](https://www.flyhutchks.com/airport-info) · [Source 3](https://www.airnav.com/airport/HUT)

### JXN — Jackson County Airport/Reynolds Field

**Immutable key:** `OURAIRPORTS:3626` · **Reviewed runway:** 07/25 excellent grooved asphalt 5351x100ft, PCN30; 14/32 good grooved asphalt 4000x100ft PCN16 · **Gross primary length:** 5351ft · **Selected FAA LDA:** NOT VERIFIED · **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft loading and operational limitations:** 07/25 PCN30 S76/D100/DT180 thousand lb; 14/32 PCN16 S42/D62/DT115 and only ~19m gross length margin

**Case finding:** FAA Oct confirms active towered public airport, Jet A+ self-service and two paved runways. Official direction-specific LDA not shown for either runway. Deer and large birds, winter FICON unmonitored when ATCT closed, power line and trees on approaches, and Taxiway D potentially entering runway 07/25 safety zone require taxi and dispatch checks. County lists private/corporate charter but that is not a licence for an Airlinerra carrier.

**Required next checks:** Obtain published RW07/RW25 LDA and optional RW14/32 LDA, confirm PCN30/PCN16 and airplane wheel loads, current wildlife/winter NOTAM and compliant taxi route, county paid-use permission and named licensed operator.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://www.airnav.com/airport/JXN) · [Source 2](https://www.mijackson.org/232/Airport)

### OLU — Columbus Municipal Airport

**Immutable key:** `OURAIRPORTS:3750` · **Reviewed runway:** 14/32 good concrete 6801x100ft; FAA RW14 LDA 6260ft, RW32 LDA 5850ft; 02/20 4135ft turf excluded · **Gross primary length:** 6801ft · **Selected FAA LDA:** 6260ft · **Distance gate:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft loading and operational limitations:** Primary concrete S43/D58 thousand lb; 950ft RW32 displaced threshold; actual LDA is already declared and must not be reduced twice

**Case finding:** FAA Oct lists RW14 LDA 6260ft and RW32 5850ft, both above 1200m; the 4135ft turf alternate is excluded despite its gross length and is unplowed in winter. Wildlife/deer, RW32 calm-wind preference, 60ft tree approach, daylight attendance and fuel by after-hours call require actual flight planning. Municipality has not supplied signed commercial landing consent or a named active airline certificate.

**Required next checks:** Validate current RW14/32 LDA, aircraft S43/D58 and obstacle limits, winter response/after-dark fuel, municipal signed commercial-use rights and licensed charter/cargo/passenger operator.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://www.columbusne.us/280/Airport-Information) · [Source 2](https://www.airnav.com/airport/OLU)

### OQU — Quonset State Airport

**Immutable key:** `OURAIRPORTS:3753` · **Reviewed runway:** 16/34 fair grooved asphalt 7000x150ft LDA 7000ft both; 05/23 4000x75ft poor asphalt with uneven RW23 pavement · **Gross primary length:** 7000ft · **Selected FAA LDA:** 7000ft · **Distance gate:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft loading and operational limitations:** Primary 16/34 D175 thousand lb; RW05/23 S12.5 thousand lb and poor condition, only ~19m gross margin; civil 16/34 declared LDA 7000ft—not 8000ft military-only remark

**Case finding:** FAA Oct main runway RW16/RW34 LDA 7000ft each, above 1200m. FAA remark 8000ft available for MILITARY aircraft ONLY must not extend civil LDA. Secondary 05/23 is poor and uneven near 23 end. Military ANG/ARNG ramps have special PPR, some taxiways closed, bird strike migration and 180-degree turns over 12500lb on runway 16/34 prohibited. Civil/paid operator rights from RI airport corporation and date-valid NOTAM remain unverified.

**Required next checks:** Match aircraft loading to actual 7000ft civilian declared LDA; check military ramp exclusions, bird phase, taxiway/turn restrictions, customs if international, RIAC commercial consent and named certificated operator.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://www.airnav.com/airport/OQU) · [Source 2](https://rules.sos.ri.gov/Organizations/agency/800)

### OSU — The Ohio State University Airport - Don Scott Field

**Immutable key:** `OURAIRPORTS:3758` · **Reviewed runway:** 09R/27L good grooved asphalt 5004x100ft LDA 5004ft each; 05/23 asphalt 3562ft and 09L/27R 2994ft underlength · **Gross primary length:** 5004ft · **Selected FAA LDA:** 5004ft · **Distance gate:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft loading and operational limitations:** Main PCR860 F/C/X/T S120/D250/DT550 thousand lb; airport FAA remark prohibits specified Part121/Part380 scheduled passenger >9 seats and non-scheduled passenger >30 seats; unscheduled >30 seats 90-day PPR

**Case finding:** FAA October 2026 main 09R and 27L LDAs 5004ft, both exceed 1200m. FAA explicitly limits specified Part121/380 passenger operations and requires 90-day prior permission for certain >30 passenger seat unscheduled air carriers. Inactive historical Part139 is not a runway closure but airline-class certification cannot be bypassed. Short 05/23 and 09L/27R do not qualify. University owner permission and actual carrier certificate not verified.

**Required next checks:** Enforce FAA passenger-class restrictions and Part139 requirements first; recheck 09R/27L LDA and PCR860 airplane loading, current NOTAM/ARFF, university signed paid commercial-use rights and named licensed operator.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://osuairport.org/news/2026/10/airport-welcomes-community-2026-open-house) · [Source 2](https://www.airnav.com/airport/OSU)

### PUJ — Silver Comet Field at Paulding Northwest Atlanta Airport

**Immutable key:** `OURAIRPORTS:42970` · **Reviewed runway:** 13/31 good grooved concrete 5505x100ft with ILS/DME RW31 · **Gross primary length:** 5505ft · **Selected FAA LDA:** NOT VERIFIED · **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft loading and operational limitations:** FAA main S90000/D130000lb bearing; private FBO tug service limited 15000lb is HANDLING equipment cap, NOT a 15000lb runway weight class

**Case finding:** FAA Oct runway 13/31 5505ft concrete S90/D130 thousand lb, Jet A+ and full maintenance, but authoritative direction-specific RW13 and RW31 LDA not independently published in consulted record. Airport FBO advertises aircraft tug up to 15000lb, a ground-moving limitation requiring an alternate qualified handling/parking plan for larger airframes; do not treat as a runway closure or structural weight ceiling. No current named airline/operator certificate, legal paid-service owner rights, ARFF, or live NOTAM verified.

**Required next checks:** Obtain official RW13 and RW31 LDA, S90/D130 aircraft loading, suitable tow/stand arrangements for >15000lb airplanes, current NOTAM/ARFF and Paulding County signed commercial operating rights with named licensed carrier.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://pauldingairport.com/services.html) · [Source 2](https://www.airnav.com/airport/PUJ)

### RAL — Riverside Municipal Airport

**Immutable key:** `OURAIRPORTS:3837` · **Reviewed runway:** 09/27 good asphalt 5401x100ft ILS primary; 16/34 fair asphalt 2850x50ft underlength · **Gross primary length:** 5401ft · **Selected FAA LDA:** NOT VERIFIED · **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft loading and operational limitations:** 09/27 main S48/D70/DT110 thousand lb; FAA states operator limits short 16/34 single-wheel class to 12500lb—not a main runway restriction

**Case finding:** FAA Oct 2026 documents active 5401ft good paved primary with Jet A, ILS and tower 0700-2000. Crosswind 16/34 2850ft is too short and owner single-wheel 12500lb restriction applies there, not airport-wide. Flight training and nearby Los Angeles basin airspace need tower and approach sequencing. No independently published official RW09/RW27 LDA in consulted airport record or signed city paid-flight rights and named certified provider.

**Required next checks:** Verify official RW09/RW27 landing distances and primary S48/D70/DT110 aircraft fit, current obstacles/tower/noise/NOTAM, approved stand/handling, City of Riverside commercial agreement and licensed operator.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://www.riversideca.gov/airport/) · [Source 2](https://www.airnav.com/airport/RAL)

### SFF — Felts Field

**Immutable key:** `OURAIRPORTS:3877` · **Reviewed runway:** 04L/22R good concrete 4499x140ft LDA 4499ft each; 04R/22L fair asphalt 2650ft underlength; 03W/21W 6000ft water excluded · **Gross primary length:** 4499ft · **Selected FAA LDA:** 4499ft · **Distance gate:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft loading and operational limitations:** Main 04L/22R S30000lb, 43m wide. Short 04R/22L S30000 but only 2650ft. Water runway not paved. FAA cold-temp correction at or below -15C

**Case finding:** FAA October declares 4499ft LDA on RW04L and RW22R, both exceed 1200m by ~171m. Water runway does not count as paved. Spokane airport board lists SeaPort service; March 2026 King County announcement projected four daily Seattle-Spokane roundtrips, but current completed flights and operator certificate not independently audited. FAA warns blind taxiway areas, bird hazard, tower 0600-2000, and cold-temperature adjustments. Presence of advertised service is not permission for any Airlinerra airline.

**Required next checks:** Verify active named carrier FAA certificate and actual flights, signed Spokane airport board commercial rights, runway 04L/22R LDA and S30000 fleet match, winter/birds/taxiway NOTAM and permitted ground route.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://www.spokaneairports.com/felts-field/at-felts-field/) · [Source 2](https://kingcounty.gov/en/dept/executive-services/transit-transportation-roads/airport/news-announcements/20260304-seaport-service-spokane) · [Source 3](https://www.airnav.com/airport/SFF)

### STP — Saint Paul Downtown Holman Field

**Immutable key:** `OURAIRPORTS:3906` · **Reviewed runway:** 14/32 good grooved asphalt 6491x150ft LDA RW14 6148ft and RW32 6109ft; 13/31 4004x150ft LDA 4004ft each; 09/27 3642ft below 1200m · **Gross primary length:** 6491ft · **Selected FAA LDA:** 6148ft · **Distance gate:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft loading and operational limitations:** Primary S83/D111/DT197 thousand lb; 13/31 S97/D135/DT228 but LDA 4004ft (~1220m) near minimum. TWY A >101ft wingspan and B >72ft restrictions localized. >100000lb aircraft PPR.

**Case finding:** FAA 2026 declares RW14 LDA 6148ft and RW32 LDA 6109ft, above 1200m despite displaced thresholds 343/382ft. Crosswind 13/31 LDA 4004ft each barely over minimum; separate 09/27 only 3642ft below. EMAS 280ft/225ft not additive landing pavement. Controlled river/urban airspace, voluntary noise measures, wingspan-limited taxiway segments, flight-specific customs and >100000lb prior permission require operator-specific plans; fuel or FBO presence not a carrier licence.

**Required next checks:** Verify runway 14/32 LDAs and airplane S83/D111/DT197, >100000lb PPR, compliant taxiway/ramp by wingspan, river/wildlife/NOTAM/cold weather and signed MAC commercial/carrier authorization.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://metroairports.org/our-airports/st-paul-downtown-airport) · [Source 2](https://www.airnav.com/airport/STP)

### TPL — Draughon Miller Central Texas Regional Airport

**Immutable key:** `OURAIRPORTS:3927` · **Reviewed runway:** 16/34 good grooved asphalt 7000x150ft LDA 7000ft both; 03/21 good asphalt 4740x100ft LDA 4740ft both · **Gross primary length:** 7000ft · **Selected FAA LDA:** 7000ft · **Distance gate:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft loading and operational limitations:** Main S55/D70/DT110 thousand lb, crosswind D31/DT37 different loading. FAA ARFF Index B daytime but ARFF unavailable 2000-0700; crosswind 03/21 runway lights unavailable after 2200.

**Case finding:** FAA Oct shows 7000ft usable LDA in both 16/34 directions and 4740ft both 03/21, above 1200m. ARFF is explicitly unavailable overnight 2000-0700 and runway 03/21 MIRL unavailable after 2200; the runway is not necessarily physically closed, but specific certificated passenger-carrier dispatch requiring ARFF or lighting cannot be approved in those periods. Gliders operate near runway 16; actual date NOTAM, airline certificate and signed City of Temple paid-use rights unresolved.

**Required next checks:** Verify LDA and S55/D70/DT110 aircraft wheel fit, flight-specific ARFF coverage (not 2000-0700), nighttime approach/lighting, glider/NOTAM, city commercial consent and named certified operator.

**Airport-owner paid-commercial rights:** `NOT_VERIFIED`; **current certificated air carrier:** `NOT_VERIFIED`; **date-valid NOTAM/weather:** `NOT_VERIFIED`; **next gate:** `BLOCKED_PENDING_REQUIRED_EVIDENCE`; **gameplay:** `NOT_APPROVED`.

**Evidence:** [Source 1](https://vfrmap.com/fe?q=KTPL&req=get_afd) · [Source 2](https://flytemple.com/draughon-miller-central-texas-regional-airport/about-the-temple-airport/) · [Source 3](https://www.airnav.com/airport/TPL)

## Critical physical-versus-commercial eligibility findings

**Ohio State University (OSU):** Paved main RW09R/27L has **5,004ft FAA-declared LDA** both directions, but FAA explicitly restricts specified Part121/Part380 passenger service above prescribed seats and requires **90-day prior permission for unscheduled air-carrier flights over 30 passenger seats**. A distance pass does not negate university owner rights or certification. [FAA](https://www.airnav.com/airport/OSU).

**Quonset State (OQU):** Civil main RW16/34 has **7,000ft published LDA**, not the FAA remark about **8,000ft available for military aircraft only**. Secondary RW05/23 is 4,000ft but POOR and uneven near the runway 23 threshold; ANG/ARNG ramp PPR, bird hazards and prohibition of 180-degree turns on 16/34 for aircraft over 12,500lb require an aircraft-specific procedure. [FAA](https://www.airnav.com/airport/OQU).

**Temple (TPL):** Main RW16/34 LDA **7,000ft** and crosswind RW03/21 **4,740ft** both ways. Nevertheless ARFF is **unavailable 20:00–07:00** and RW03/21 MIRL is unavailable after **22:00**; certain airline/aircraft operations cannot be allowed in those periods regardless of qualifying LDA. [FAA](https://www.airnav.com/airport/TPL).

**St. Paul Downtown (STP):** Main RW14 LDA **6,148ft** and RW32 **6,109ft**; secondary RW13/31 LDA **4,004ft**, only ~20m over 1,200m, while RW09/27 is underlength. EMAS beyond runway ends is not extra LDA; taxiway segments limit wingspans, and aircraft over 100,000lb require airport-manager PPR. [FAA](https://www.airnav.com/airport/STP).

**Hutchinson (HUT):** Main 13/31 LDA **7,003ft** in both directions; separate 04/22 4,401ft and 17/35 4,012ft declared distances. All pass on distance, but one secondary is only ~23m above threshold; intersecting-runway taxi operations and unmonitored overnight pavement require current assessment. [FAA](https://www.airnav.com/airport/HUT).

**Columbus (OLU):** Main 14/32 **6,801ft concrete** declares RW14 LDA **6,260ft** and RW32 **5,850ft**. Winter-closed/unplowed turf 02/20 is not qualifying. Do not double subtract the RW32 threshold displacement from declared distance. [FAA](https://www.airnav.com/airport/OLU).

**Felts Field (SFF):** Main concrete RW04L/22R publishes **4,499ft LDA** each way. The short parallel and water runway do not qualify. SeaPort Airlines' March 2026 announcement and airport-owner listing are evidence of advertised service, not independent evidence of completed flights, certificate coverage or blanket permission for game operators. [FAA](https://www.airnav.com/airport/SFF) · [King County announcement](https://kingcounty.gov/en/dept/executive-services/transit-transportation-roads/airport/news-announcements/20260304-seaport-service-spokane).

**Jackson County (JXN), Riverside (RAL), Silver Comet Field (PUJ):** Long paved primaries **5,351ft, 5,401ft and 5,505ft respectively**, but official direction-specific LDA was **not independently published/verified** here. JXN has a narrow-gross 4,000ft crosswind, wildlife/winter reporting and Taxiway D runway-incursion hazard. RAL's separate short crosswind carries a **12,500lb operator limit that must not be applied to the primary runway**. PUJ's FBO has a **15,000lb tug equipment limit**, not a 15,000lb structural runway maximum; identify a safe handling alternative for larger aircraft. [JXN](https://www.airnav.com/airport/JXN) · [RAL](https://www.airnav.com/airport/RAL) · [PUJ](https://www.airnav.com/airport/PUJ) · [FBO](https://pauldingairport.com/services.html).

## Final eligibility protection and next step

The private Supabase ledger uses RLS with SELECT denied to `anon` and `authenticated`; gameplay states are hard-constrained to NOT_APPROVED. The independently audited candidate and original airport populations did not change.

**Required before any new playable airport:** Current operating asphalt/concrete with **>=1,200m published actual direction-specific Landing Distance Available**, safe aircraft-specific pavement/wingspan/terrain/obstacles and live NOTAM/FICON/weather, reliable fuel/ground/rescue and permitted carrier class, **signed airport-owner permission for paid operations**, and a **named validly certificated charter/passenger/cargo operator**. Exactly **six previously agreed Airlinerra airport categories** remain unchanged; none assigned here.

**Next:** Phase 4 Batch 22, **one remaining Palmer Municipal (PAAQ)** airport review, then plan remediation/evidence gates for all 211 narrowed cases and separately the **622 Phase 3 holds**. Completion of first-pass Phase 4 review does not mean game approvals.
