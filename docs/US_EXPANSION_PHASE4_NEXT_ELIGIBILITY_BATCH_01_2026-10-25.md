# Airlinerra — Phase 4 Next-Eligibility Evidence Gate, Batch 01 — 25 October 2026

**Verified:** 10 distinct, previously narrowly advanced Phase 3 airports have received a second, separate evidence-based runway/aircraft/operator review. **All ten stay blocked from gameplay.** This is not another Phase 3 first-pass batch and does not overwrite the closed Phase 3 review results.

**Supabase batch:** `US_EXPANSION_PHASE4_NEXT_GATE_BATCH_01_2026_10_25`. **Assessment:** 2026-10-25. **Data persistence:** new private `airlinerra.airport_expansion_next_eligibility_phase4` table, with row-level security enabled, public/authenticated table permissions revoked and explicit check constraint requiring `game_admission_status='NOT_APPROVED'`.

**Schema snapshot:** [Phase 4 restricted evidence ledger SQL](US_EXPANSION_PHASE4_NEXT_ELIGIBILITY_LEDGER_SCHEMA_2026-10-25.sql).

## Batch findings

| Measure | Independently verified |
|---|---:|
| Separate Phase 4 airport reviews in Batch 01 | **10** |
| Airports with a direction's nominal landing pavement below 1,200m | **1** |
| Airports with documented LDA above 1,200m, still requiring current checks | **1** |
| Airports with gross length only, no independently verified per-direction LDA | **8** |
| Owner paid-commercial-flight permits independently verified | **0** |
| Actual named air-carrier operating certificates independently verified | **0** |
| Date-valid flight NOTAMs and specific aircraft type approval completed | **0** |
| Gameplay approvals and activations | **0** |

## All ten Phase 4 assessments

| Airport ID | Airport | Runway-distance finding | Decision |
|---|---|---|---|
| **05C** | Griffith-Merrillville Airport | RW26 nominal landing pavement under 1200m | Blocked pending full evidence |
| **0E0** | Moriarty Municipal Airport | Only gross runway length checked; official LDA pending | Blocked pending full evidence |
| **16G** | Seneca County Airport | Only gross runway length checked; official LDA pending | Blocked pending full evidence |
| **1M9** | Lake Barkley State Park Airport | 4600ft LDA documented; live reconfirmation needed | Blocked pending full evidence |
| **2G9** | Somerset County Airport | Only gross runway length checked; official LDA pending | Blocked pending full evidence |
| **3F3** | C E 'Rusty' Williams Airport | Only gross runway length checked; official LDA pending | Blocked pending full evidence |
| **3LF** | Litchfield Municipal Airport | Only gross runway length checked; official LDA pending | Blocked pending full evidence |
| **CMD** | Cullman Regional Airport-Folsom Field | Only gross runway length checked; official LDA pending | Blocked pending full evidence |
| **HCR** | Heber Valley Airport | Only gross runway length checked; official LDA pending | Blocked pending full evidence |
| **ORK** | North Little Rock Municipal Airport | Only gross runway length checked; official LDA pending | Blocked pending full evidence |

## Individual runway, capacity, service and operator records

### 05C — Griffith-Merrillville Airport
**Permanent airport key:** `OURAIRPORTS:18319`. **Examined runway:** RW26 4899ft asphalt; displaced threshold 1120ft. **Gross length:** 4899ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `DIRECTIONAL_LANDING_PAVEMENT_BELOW_1200M`.

**Aircraft pavement/gear review:** 75ft pavement; wheel load not verified

**Independent Phase 4 finding:** FAA data show 1120ft RW26 threshold displacement: landing pavement 3779ft or 1152m, below the Airlinerra 1200m minimum. RW08 must be examined separately. Fuel/repairs listed, operator and owner permissions unverified.

**Remaining evidence and actions:** Keep RW26 blocked; confirm RW08 usable LDA, obstacles, wheel loads, owner rights and certified carrier.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.airnav.com/airport/05C)

### 0E0 — Moriarty Municipal Airport
**Permanent airport key:** `OURAIRPORTS:18355`. **Examined runway:** RW08/26 7702ft; RW17/35 6200ft day VMC asphalt. **Gross length:** 7702ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft pavement/gear review:** City lists 30000lb single/45000lb dual wheel capacity

**Independent Phase 4 finding:** Moriarty city confirms long paved runways and Jet A, but at 6199ft altitude density-altitude performance and glider activity need aircraft-specific validation; directional published LDA, owner commercial permit and licensed carrier not obtained.

**Remaining evidence and actions:** Validate FAA LDA, airplane climb and loading, airport commercial terms, current NOTAM and licensed carrier.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.moriartynm.gov/city-venues/moriarty-airport)

### 16G — Seneca County Airport
**Permanent airport key:** `OURAIRPORTS:18427`. **Examined runway:** 06/24 asphalt 4000x75ft. **Gross length:** 4000ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft pavement/gear review:** Airplane wheel strength unverified

**Independent Phase 4 finding:** Gross 4000ft only 1219m. FAA indicates PAPI sector limits, holiday unattended status and after-hours fuel. Official usable LDA and certified airline/owner permissions remain unknown.

**Remaining evidence and actions:** Check FAA per-direction LDA and load, NOTAM/PAPI, owner commercial permission and operator certificate.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.airnav.com/airport/16G)

### 1M9 — Lake Barkley State Park Airport
**Permanent airport key:** `OURAIRPORTS:18494`. **Examined runway:** 02/20 asphalt 4800x75ft, published LDA 4600ft each. **Gross length:** 4800ft. **Declared LDA recorded:** 4600ft. **Distance gate:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft pavement/gear review:** FAA-derived S-30000lb single wheel; specific fleet pending

**Independent Phase 4 finding:** Current FAA-derived chart notes LDA 4600ft both ends (1402m). Despite good published LDA, no instrument approach, deer/birds, state-park paid-use terms, commercial provider and emergency service remain unresolved.

**Remaining evidence and actions:** Recheck official current LDA/NOTAM, weather flight minima, Kentucky park owner commercial consent and certified carrier.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.airnav.com/airport/1M9)

### 2G9 — Somerset County Airport
**Permanent airport key:** `OURAIRPORTS:18586`. **Examined runway:** 07/25 asphalt 5002x75ft; 14/32 turf under 1200m. **Gross length:** 5002ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft pavement/gear review:** County owner reports main single-wheel 18000lb

**Independent Phase 4 finding:** PennDOT confirms 5002ft asphalt RW07/25 and shorter turf 14/32, which is nonqualifying. Jet A listed; no official directional LDA, selected gear performance or certificated paid-flight provider verified.

**Remaining evidence and actions:** Get FAA 07/25 LDA/load and snow/obstacle notices, county permission, charter operator and ground support.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.pa.gov/agencies/penndot/traveling-in-pa/airports/somerset-county-airport)

### 3F3 — C E 'Rusty' Williams Airport
**Permanent airport key:** `OURAIRPORTS:18685`. **Examined runway:** 18/36 asphalt 5005x100ft, trees at approaches. **Gross length:** 5005ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft pavement/gear review:** FAA-derived single-wheel 12000lb, so many heavier aircraft must be excluded

**Independent Phase 4 finding:** Current FAA-derived source lists good paved 5005ft runway, S-12000lb, 100LL and Jet A, but no repair capability; tree obstacles and only irregular weekends need dispatch screening. Crop traffic neither closes runway nor certifies a charter.

**Remaining evidence and actions:** Check official usable LDA and obstacle slopes, 12000lb airplane rating, named certified carrier and owner ground/ramp agreement.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.flightaware.com/resources/airport/3F3) · [2](https://www.airnav.com/airport/3F3)

### 3LF — Litchfield Municipal Airport
**Permanent airport key:** `OURAIRPORTS:18716`. **Examined runway:** 18/36 asphalt 4002x75ft; 09/27 3900x75ft too short. **Gross length:** 4002ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft pavement/gear review:** FAA source shows good main asphalt, aircraft wheel loads not published

**Independent Phase 4 finding:** 2026 FAA-derived listing verifies long primary only barely above 1200m (1220m). 09/27 fails basic length. Jet A and major repairs exist, but official usable RW18/RW36 LDA, pavement load and owner/licensed carrier rights have not been obtained.

**Remaining evidence and actions:** Validate per-direction 18/36 usable LDA and gear strength, current lights/NOTAM, owner signed paid flights and licensed operator.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.airnav.com/airport/3LF)

### CMD — Cullman Regional Airport-Folsom Field
**Permanent airport key:** `OURAIRPORTS:18667`. **Examined runway:** 02/20 grooved asphalt 5500x100ft. **Gross length:** 5500ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft pavement/gear review:** FAA-derived bearing S-61000lb D-78000lb, excellent runway

**Independent Phase 4 finding:** 2026 data confirms a long operating runway, Jet A, parachute jumping and extensive flight training. Ground emergency and airline permissions not established, and runway declared LDA still needs official validation for selected type.

**Remaining evidence and actions:** Obtain FAA runway LDA and gear match, current skydive NOTAM, owner agreement, operator certificate and handling capacity.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.airnav.com/airport/CMD)

### HCR — Heber Valley Airport
**Permanent airport key:** `OURAIRPORTS:18657`. **Examined runway:** 04/22 asphalt 6898x75ft at ~5600ft elevation. **Gross length:** 6898ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft pavement/gear review:** Excellent runway, S-30000lb single-wheel and PCN32 per FAA-derived data

**Independent Phase 4 finding:** Heber Valley owner documents 2024 onward aircraft landing fees managed by Vector; fees do not equal runway closure. Airport at 5600ft elevation requires airplane-specific hot/high/terrain performance, commercial owner permit and licensed operator.

**Remaining evidence and actions:** Confirm official FAA landing distances, current city commercial minimum standards/fee schedule, aircraft load/altitude and named carrier.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.heberut.gov/404/Aircraft-Landing-Fees) · [2](https://heberut.gov/airport)

### ORK — North Little Rock Municipal Airport
**Permanent airport key:** `OURAIRPORTS:18489`. **Examined runway:** 05/23 concrete 5002x75ft; 17/35 asphalt only 3019ft. **Gross length:** 5002ft. **Declared LDA recorded:** NOT VERIFIEDft. **Distance gate:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft pavement/gear review:** Main single-wheel 30000lb, dual-wheel 60000lb; secondary is short

**Independent Phase 4 finding:** October FAA-derived source confirms long concrete main, short asphalt secondary, Jet A and repairs. Only the main could pass Airlinerra length; specific aircraft/owner and current NOTAM remain unverified.

**Remaining evidence and actions:** Check main runway LDA and load, wildlife/ultralight NOTAM, city paid-use approval and licensed carrier.

**Hard gate states:** owner `NOT_VERIFIED`; operating certificate `NOT_VERIFIED`; live notices/weather `NOT_VERIFIED`. **Admission status:** `NOT_APPROVED`.

**Research sources:** [1](https://www.airnav.com/airport/ORK) · [2](https://www.airnav.com/airport/KORK)


## Material new evidence and gate conclusions

**Griffith–Merrillville (05C):** October 2026 FAA-based airport source reports RW08/26 at 4,899ft and an **RW26 displaced threshold of 1,120ft**, leaving **3,779ft (~1,152m) of nominal landing pavement** in RW26 direction. This fails the Airlinerra 1,200m physical landing-pavement screen for that **specific direction**. It does **not** establish that RW08 also fails. The official LDA, approach trees, runway/aircraft weight and authorized commercial operator need confirmation before any usage. [FAA-derived airport source](https://www.airnav.com/airport/05C).

**Lake Barkley State Park (1M9):** October FAA-derived runway source records **RW02 and RW20 actual LDA 4,600ft each (~1,402m)**, a positive direction-specific result. The strip belongs to a state-park airport, has no published instrument approaches and reports wildlife. Aircraft-specific load, current NOTAM, owner's written charter/paid-use permission and a named certified carrier are still unverified. Passing the runway LDA screen alone grants no game admission. [Current runway and official declared distances](https://www.airnav.com/airport/1M9).

**Moriarty (0E0):** City lists two long good asphalt runways (8/26 7,700ft and 17/35 6,200ft), **S-30,000lb / D-45,000lb**, Jet A and avgas, at about 6,199ft MSL. Secondary runway is day-VMC only, while glider use/high-altitude aircraft performance require particular operating procedures. Published direction-specific LDA and air carrier/owner permissions remain unverified. [City airport facts](https://www.moriartynm.gov/city-venues/moriarty-airport).

**North Little Rock (ORK):** October FAA source records qualifying **05/23 concrete 5,002ft** with S-30/D-60 bearing, separate nonqualifying **17/35 asphalt 3,019ft** with lower S-17 bearing, plus Jet A and repairs. Only the primary can be considered for this 1,200m runway screening. Each direction's official usable LDA, wildlife/ultralight operations and commercial permission still require validation. [FAA runway/operations source](https://www.airnav.com/airport/KORK).

**Seneca County (16G) and Litchfield (3LF):** Respectively about **4,000ft and 4,002ft** gross paved runways, just **19–20m over the 1,200m limit**. Neither may be approved using physical runway dimensions alone; authoritative usable LDA and aircraft wheel rating are essential. At Litchfield the other asphalt 09/27 is **3,900ft**, under the minimum. [Seneca source](https://www.airnav.com/airport/16G) · [Litchfield source](https://www.airnav.com/airport/3LF).

**Somerset County (2G9):** PennDOT confirms qualifying **5,002ft asphalt 07/25** separate from short turf 14/32. County reports **18,000lb single-wheel** bearing for paved 07/25 and lists Jet A/100LL; gross asphalt eligibility does not establish final LDA, a compatible passenger/cargo aircraft or certificated operator. [PennDOT](https://www.pa.gov/agencies/penndot/traveling-in-pa/airports/somerset-county-airport) · [County runway information](https://www.co.somerset.pa.us/airport/runway.asp).

**Heber Valley (HCR):** City landing fees managed by Vector, including 2024 revised schedule, are financial conditions, **not a physical runway restriction**. FAA-derived source shows good long paved RW04/22 but airport altitude near 5,600ft and airplane gear strength/climb limits remain relevant. Commercial minimum standards and actual carrier permission still required. [City landing fee policy](https://www.heberut.gov/404/Aircraft-Landing-Fees) · [FAA-derived field record](https://www.airnav.com/airport/HCR).

**Cullman Regional (CMD):** FAA source shows 5,500x100ft grooved pavement and S-61/D-78 bearing, plus documented weekday/weekend skydiving and intensive flight training. Airspace coordination is mandatory but this alone is not a physical closure; no signed commercial operator/owner authorization or live traffic notice verified. [FAA-derived runway details](https://www.airnav.com/airport/CMD).

**C E 'Rusty' Williams (3F3):** FAA source shows 5,005x100ft asphalt but only **S-12** single-wheel bearing, trees, no airframe/engine repair capability and crop-dusting movements. This materially narrows viable commercial aircraft and demands independent airplane/owner/operator checking. [FAA-derived airport record](https://www.airnav.com/airport/3F3).

## Cumulative protections after Phase 4 Batch 01

| System measure | Verified |
|---|---:|
| Phase 3 first-pass operational reviews (unchanged) | **833** |
| Phase 3 narrow advances awaiting follow-up review | **211** |
| Phase 4 records saved and audited | **10** |
| Phase 3 advancing records not yet reviewed in Phase 4 | **201** |
| Phase 3 continuing holds (unchanged) | **622** |
| Other expansion candidates on separate selection pathways | **1,096** |
| Original expansion candidate roster | **1,929** |
| Original playable airport roster | **3,140** |
| Gameplay approvals, world activations, final category assignments | **0 / 0 / 0** |

**SQL audit:** 10 rows, 10 distinct airports, 1 short-direction finding, 1 published LDA over minimum, 8 LDA-unverified cases; 0 mismatched registry codes, 0 missing two-source evidence, 0 incorrect Phase 3 parent statuses, 0 non-NOT_APPROVED admissions. RLS enabled; `anon` and `authenticated` have no `SELECT` table privilege. Existing Phase 3 statuses and all game admission registers remain unchanged.

**Next:** Phase 4 Next-Eligibility Batch 02, covering the next 10 of **201** unreviewed Phase 3 narrow advances. Run an independent workstream for the **622** first-pass operational holds. Future promotion requires both *airport/airframe safe runway and dated operational conditions* and *airport-owner commercial permission with appropriately certified actual carrier*. A first-pass or partial runway screen must never activate gameplay.
