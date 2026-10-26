# Airlinerra — Phase 5 Batch 5: Missing Directional Landing Distance Source Review

**Reviewed 26 October 2026.** Supabase private schema `airlinerra`, project `hwllkabgzaynalahvkpz`. Batch key: `US_EXPANSION_PHASE5_MISSING_LDA_BATCH_05_2026_10_26`.

## Results and limits

**20 of 20 individual airport source reviews were saved and audited. All 20 remain `EVIDENCE_HOLD` and `NOT_APPROVED`; none has an independently confirmed current official direction-specific FAA LDA.** This is completion of an initial FAA-derived *secondary source* desk review, not certification of airport availability, airline authority, service or flight-date safety.

Supabase checks: 20 distinct airport entries, 20 sourced review notes, 18 new runway-end records covering 8 airports, no positive LDA values in those 18 records, zero approvals. Phase 5 totals after Batch 5: **96/211 source-reviewed**, **115 queued**, **211/211 NOT_APPROVED**; runway-direction research table **70 records**. The original 3,140 airports and world-activation table (zero rows) remain unchanged.

## All 20 airports and source findings

| FAA code | Airport | Region | Source finding / follow-up |
| --- | --- | --- | --- |
| CDS | Childress Municipal Airport | US-TX | FAA-derived AirNav independently confirms RW18/36 5949x75ft good asphalt, S-21000lb, and RW36 nonstandard threshold edge lights 60ft south of runway end. RW04/22 listed closed indefinitely despite 4425ft physical gross; do not treat as active alternate or disqualify RW18/36. No official direction-specific LDA… |
| CEU | Oconee County Regional Airport | US-SC | FAA-derived AirNav confirms RW07/25 excellent 5000x100ft grooved asphalt, PCN10, runway-end visibility/CTAF separation issue in Phase4 dossier, no published per-direction LDA shown. Validate current parachute remarks and NOTAM, PCN/selected airplane, county permission and certificated operator separately. |
| CFS | Tuscola Area Airport | US-MI | FAA-derived AirNav confirms primary RW06/24 4302x75ft asphalt with PAPI sector and approach trees; turf 13/31 below floor is not alternate. Neither RW06 nor RW24 LDA explicitly published in consulted directory. Wildlife/RC airplanes, airport commercial rights and named carrier unverified. |
| CFV | Coffeyville Municipal Airport | US-KS | FAA-derived AirNav confirms RW17/35 5868x100ft fair asphalt PCN12, S30000/D42000lb, physical main differs from old city rounded 5872ft. No per-direction published LDA in consulted record; do not treat nominal pavement length or airport's small-jet marketing as eligibility. Repairs, commercial owner permission… |
| CGZ | Casa Grande Municipal Airport | US-AZ | FAA-derived AirNav verifies main RW05/23 5200x100ft good asphalt and approach/hold-line restrictions; no official per-direction LDA displayed. RW05 ILS does not prove distance, available Jet A does not grant air-carrier rights. Hot-day performance, city legal paid-use consent, certificate and flight-date NOTA… |
| CKM | Fletcher Field | US-MS | FAA-derived AirNav RW18/36 5404x100ft excellent grooved asphalt PCN PCR/30, S25000/D32000lb; **operational restriction: aircraft over 30000lb require 1 HOUR PPR**. Phase 4 described PCN30; the FAA-derived page actually displays PCR/30. Prior permission requirement separate from airplane wheel load and LDA; no… |
| CKP | Cherokee County Regional Airport | US-IA | FAA-derived AirNav primary RW18/36 concrete 4001x75ft fair PCN9 R/C/W/U, S15000lb; only about 20m gross over 1200m. Short 01/19 turf winter closure does not disqualify main. No published LDA for either paved direction in consulted listing. Trees/winter/PCN fit and owner/operator authority pending. |
| CMD | Cullman Regional Airport-Folsom Field | US-AL | FAA-derived AirNav RW02/20 asphalt/grooved 5500x100ft excellent, PCR/243 F/D/X/T, S61000/D78000/DT130000lb. No published per-direction LDA in AirNav display. Skydivers/traffic, FAA cycle NOTAM, aircraft load, paid-use authorization and certified carrier unverified. |
| CON | Concord Municipal Airport | US-NH | FAA-derived AirNav main RW17/35 asphalt 6005x100ft fair, **RW17 threshold displaced 641ft** so nominal post-threshold pavement 5364ft (still NOT official LDA), RW35 no displacement; short 12/30 3200ft fails. ILS and municipal/military ramp constraints are separate. Need official RW17/RW35 LDA, owner/Part135 o… |
| CPF | Wendell H Ford Airport | US-KY | FAA-derived AirNav current code CPF RW14/32 good asphalt 5499x100ft, 14/32 PCN10 with RW32 PAPI usable-sector restrictions and steep near-runway tree obstacles. Secondary 06/24 3246ft is underlength and closed daily SS-SR, not blanket airport closure. No official published main per-direction LDA shown. Regist… |
| CRG | Jacksonville Executive at Craig Airport | US-FL | FAA-derived AirNav shows RW14/32 **4008x100ft** good asphalt PCN34 and RW05/23 **4004x100ft** fair asphalt PCN31. BOTH have 150ft STOPWAYS at BOTH runway ends; stopways are NOT landing pavement and must not be added to any LDA. All 4 headings have only about 20m gross length margin over 1200m; AirNav page doe… |
| CTB | Cut Bank International Airport | US-MT | FAA-derived AirNav shows two independent 5300x75ft asphalt runways RW05/23 and RW14/32, PCN10, but no published LDA in four directions. Intl airport of entry does not imply flight-specific CBP landing permission or carrier certification; MT cold temp altitude corrections/winter services and selected airframe … |
| CTY | Cross City Airport | US-FL | Important source staleness: directly opened FAA-derived AirNav CTY page states effective **03 SEP 2026**, not Oct despite earlier Phase 4 note. RW04/22 5005x75ft asphalt and RW13/31 5001x100ft asphalt/concrete with PCN8/10 and restrictive S13000lb, but no official LDA in page. Current FAA cycle, runway markin… |
| CUL | Carmi Municipal Airport | US-IL | Important staleness: directly opened AirNav CUL page identifies FAA information effective **06 AUG 2026**, older than Phase 4 claimed Oct. RW18/36 good asphalt nominal 4000x75ft, only 19m gross over game minimum, S12000lb, but no published direction-specific LDA. Seek current FAA source first; holiday staffin… |
| CXL | Calexico International Airport | US-CA | FAA-derived AirNav explicitly confirms 08/26 excellent asphalt 4683x75ft, RW26 **160ft displaced threshold**, yielding nominal 4523ft; RW08 no displacement, nominal 4683ft. This is NOT a verified FAA LDA on either heading. Approach powerline and border/CBP requirements, city written paid-use, aircraft/airport… |
| CXU | Camilla Mitchell County Airport | US-GA | FAA-derived AirNav independently confirms 08/26 fair asphalt 5004x100ft, S30000/D52000/DT85000lb, trees by RW26, no explicit per-direction published LDA. Agriculture/medevac flights and maintenance availability require coordination, not blanket closure; paid service rights and certificated carrier not establi… |
| DNS | Denison Municipal Airport | US-IA | FAA-derived AirNav page opened states **03 SEP 2026**, despite Phase 4 summarizing Oct; need effective-cycle refresh. RW12/30 good concrete 5000x75ft PCN9, short turf 18/36 winter closed; no official RW12/30 direction-specific LDA listed. Gear load, FBO callout/winter and city/air-carrier permissions unverifi… |
| EEO | Meeker Airport | US-CO | FAA-derived AirNav names facility **Meeker Coulter Field Airport**, while existing registry says Meeker Airport. Maintain stable airport key and note source display-name discrepancy for identity reconciliation, no automatic overwrite. RW03/21 asphalt 6503x100ft PCN16 good, field ~6400ft MSL and FAA cold temp … |
| EFT | Monroe Municipal Airport | US-WI | FAA-derived AirNav KEFT RW12/30 excellent asphalt 5000x75ft, S12500lb single-wheel; secondary 02/20 ~3000ft below minimum. No FAA declared LDA shown for RW12 or RW30 in the consulted source. PAPI limited RW30, winter runway/fuel hours and municipal commercial permit/licensed operator pending. |
| EIK | Erie Municipal Airport | US-CO | FAA-derived AirNav RW16/34 4700x60ft good concrete, S12500lb and longitudinal terrain ditch 60-70ft east of runway centerline. No per-direction LDA published in consulted extract. High elevation and runway width/wheel load, obstruction 78ft tree and owner/commercial/air operator evidence outstanding. |

## Individually recorded runway ends

All 18 entries have status `ALTERNATE_DIRECTION_LDA_UNVERIFIED`. Nominal pavement estimates are runway gross physical length minus explicitly listed displaced threshold, **not** the published landing distance. The database records official LDA as NULL for each.

| FAA code | End | Pair | Gross ft | Threshold shift ft | Nominal ft | Source cycle |
| --- | --- | --- | ---: | ---: | ---: | --- |
| CDS | 18 | 18/36 | 5949 | — | — | 2026-10-01 |
| CDS | 36 | 18/36 | 5949 | — | — | 2026-10-01 |
| CKM | 18 | 18/36 | 5404 | — | — | 2026-10-01 |
| CKM | 36 | 18/36 | 5404 | — | — | 2026-10-01 |
| CKP | 18 | 18/36 | 4001 | — | — | 2026-10-01 |
| CKP | 36 | 18/36 | 4001 | — | — | 2026-10-01 |
| CON | 17 | 17/35 | 6005 | 641 | 5364 | 2026-10-01 |
| CON | 35 | 17/35 | 6005 | 0 | 6005 | 2026-10-01 |
| CPF | 14 | 14/32 | 5499 | — | — | 2026-10-01 |
| CPF | 32 | 14/32 | 5499 | — | — | 2026-10-01 |
| CRG | 05 | 05/23 | 4004 | — | — | 2026-10-01 |
| CRG | 14 | 14/32 | 4008 | — | — | 2026-10-01 |
| CRG | 23 | 05/23 | 4004 | — | — | 2026-10-01 |
| CRG | 32 | 14/32 | 4008 | — | — | 2026-10-01 |
| CUL | 18 | 18/36 | 4000 | — | — | 2026-08-06 |
| CUL | 36 | 18/36 | 4000 | — | — | 2026-08-06 |
| CXL | 08 | 08/26 | 4683 | 0 | 4683 | 2026-10-01 |
| CXL | 26 | 08/26 | 4683 | 160 | 4523 | 2026-10-01 |

## Important exceptions

- **CRG, Jacksonville Executive:** 14/32 is 4008ft and 05/23 4004ft. Both have 150ft STOPWAYS beyond BOTH ends, which cannot be added to landing pavement. Both runway gross lengths are only ~20m above 1200m; official published LDA remains essential. https://www.airnav.com/airport/CRG
- **CKM, Fletcher Field:** FAA-derived published remark specifies **one-hour advance permission** for aircraft over 30000lb; page pavement shows PCR/30 (rather than a generic runway takeoff approval), and S25/D32 wheel ratings require individual airplane matching. https://www.airnav.com/airport/CKM
- **CON, Concord:** RW17 displaced threshold 641ft on 6005ft gross; nominal landing pavement 5364ft, not official LDA. https://www.airnav.com/airport/CON
- **CXL, Calexico:** RW26 displaced threshold 160ft on 4683ft; nominal landing pavement 4523ft, not official LDA; border-related customs/flight-class permission is separate. https://www.airnav.com/airport/CXL
- **CDS, Childress:** RW36 threshold edge lights are unusually located 60ft south of pavement end; that does not establish a published LDA. RW04/22 closed indefinitely, main RW18/36 listed active. https://www.airnav.com/airport/CDS
- **CUL, CTY and DNS source staleness:** CUL checked cache effective 06 AUG 2026, CTY and DNS 03 SEP 2026. Do not label any of them October-verified. All require a refreshed FAA cycle or authenticated original source. https://www.airnav.com/airport/CUL ; https://www.airnav.com/airport/CTY ; https://www.airnav.com/airport/DNS
- **EEO / Meeker:** FAA-derived directory displays 'Meeker Coulter Field Airport' but registry retains 'Meeker Airport'; preserve stable identity key pending names reconciliation. https://www.airnav.com/airport/EEO
- **CKP, CUL, CRG:** runway physical lengths narrowly exceed the game's minimum, making official per-end declared LDA critical.

## Source evidence

- CDS: [Evidence 1](https://www.airnav.com/airport/CDS) · [Evidence 2](https://www.flightaware.com/resources/airport/KCDS/remarks) · [Evidence 3](https://www.iflightplanner.com/Airports/KCDS)
- CEU: [Evidence 1](https://eflight.com/airports/CEU) · [Evidence 2](https://www.airnav.com/airport/CEU)
- CFS: [Evidence 1](https://www.airnav.com/airport/CFS) · [Evidence 2](https://www.tuscolaairport.com/) · [Evidence 3](https://www.tuscolaairport.com/about)
- CFV: [Evidence 1](https://www.airnav.com/airport/CFV) · [Evidence 2](https://www.coffeyville.com/67/Airport)
- CGZ: [Evidence 1](https://www.airnav.com/airport/CGZ) · [Evidence 2](https://www.casagrandeaz.gov/321/Airport)
- CKM: [Evidence 1](https://www.airnav.com/airport/CKM) · [Evidence 2](https://www.airnav.com/airport/KCKM/RED_PANTHER_AERO)
- CKP: [Evidence 1](https://www.airnav.com/airport/CKP)
- CMD: [Evidence 1](https://www.airnav.com/airport/CMD)
- CON: [Evidence 1](https://concordnh.gov/344/Concord-Municipal-Airport) · [Evidence 2](https://www.airnav.com/airport/CON)
- CPF: [Evidence 1](https://aeronav.faa.gov/afd/22JAN2026/SE_277_22JAN2026.pdf) · [Evidence 2](https://www.airnav.com/airport/CPF) · [Evidence 3](https://www.iflightplanner.com/Airports/KCPF)
- CRG: [Evidence 1](https://www.airnav.com/airport/CRG) · [Evidence 2](https://www.fdot.gov/aviation/airportslist/CRG)
- CTB: [Evidence 1](https://cutbankairport.org/) · [Evidence 2](https://www.airnav.com/airport/CTB) · [Evidence 3](https://www.airnav.com/airport/KCTB)
- CTY: [Evidence 1](https://www.airnav.com/airport/CTY)
- CUL: [Evidence 1](https://www.airnav.com/airport/CUL)
- CXL: [Evidence 1](https://www.airnav.com/airport/CXL) · [Evidence 2](https://www.calexico.ca.gov/?SEC=531EF4A5-0975-43B0-9A41-3FAC5DBE4774)
- CXU: [Evidence 1](https://www.airnav.com/airport/CXU) · [Evidence 2](https://www.dot.ga.gov/InvestSmart/Aviation/GAAirportsDocuments/Individual%20Report_CXU.pdf)
- DNS: [Evidence 1](https://opmapps.iowadot.gov/aviation/airports/dns) · [Evidence 2](https://www.airnav.com/airport/DNS)
- EEO: [Evidence 1](https://www.airnav.com/airport/EEO) · [Evidence 2](https://www.rbc.us/departments/operations/airports.php) · [Evidence 3](https://www.rioblanco.gov/departments/operations/airports.php)
- EFT: [Evidence 1](https://www.airnav.com/airport/EFT) · [Evidence 2](https://www.iflightplanner.com/Airports/KEFT)
- EIK: [Evidence 1](https://www.airnav.com/airport/EIK) · [Evidence 2](https://www.erieco.gov/2308/Standard-Airport-Operating-Procedures) · [Evidence 3](https://www.erieco.gov/airport)

## Remaining gates and next batch

Retrieve official current FAA per-end declared landing distances and aircraft-specific pavement/width/performance. Separately verify commercial-owner written consent, named certificated carrier and permitted flight class, flight-date NOTAM/FICON/weather, rescue, handling and fuel. Physical runway qualification is not approval. **Next Batch 6:** begin the next manageable 20 of 115 not yet source-reviewed Priority-3 airports. No change to approved six-level categories or active worlds.
