# Airlinerra — Phase 4 Next-Eligibility Batch 20 — 25 October 2026

**Independently verified in Supabase:** 10 new distinct airport assessments. **2** airports have FAA-published primary landing distances exceeding 1,200m (BAK, DAN), and **8** require official direction-specific LDA verification. **All remain BLOCKED_PENDING_REQUIRED_EVIDENCE / NOT_APPROVED**. None was activated or assigned a final category. These are game eligibility reviews, not real-world commercial operating authorizations.

**Batch:** `US_EXPANSION_PHASE4_NEXT_GATE_BATCH_20_2026_10_25` · FAA reference cycle: October 1, 2026 where available.

## Audit and cohort invariants

| Metric | Independently confirmed |
|---|---:|
| New Phase 4 individual assessments | **10** |
| Published LDA above 1,200m | **2** |
| Official LDA still unverified | **8** |
| Missing evidence / wrong code / parent status / game admissions | **0** |
| Phase 4 total reviewed | **200 of 211** |
| Advanced cases awaiting Phase 4 | **11** |
| Phase 3 first-pass reviews and separate operational holds | **833 / 622** |
| Expansion candidates and original playable airports preserved | **1,929 / 3,140** |
| Game approvals / activations / final categories | **0 / 0 / 0** |

## Source-linked airport assessments

### 1QK — Gove County Airport

**Airport key:** `OURAIRPORTS:328038`; **runway:** 17/35 excellent concrete 4000x60ft, only 19m above 1200m physical length. **Gross paved length:** 4000ft. **Published selected LDA:** not verified. **Distance screen:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft/pavement:** FAA current 2026 runway S-30000lb D-30000lb; 60ft width and only ~19m length margin; RW35 60ft tree 1320ft away imposes approach clearance requirement.

**Finding:** Public Gove County airport has a 4000ft concrete operating runway with AWOS and RNAV both ends, and agricultural/medical activities that require coordination rather than entire airport closure. No fuel or repair service independently listed by the FAA; a landing clearance must not be inferred from public-use designation. Both official direction-specific LDAs, flight-date NOTAM/ground rescue, and county paid charter/cargo permission remain absent.

**Evidence still required:** Obtain current FAA RW17/RW35 declared LDA (possible failure with only 19m margin), S30/D30 aircraft and narrow 60ft width, approach trees/NOTAM/winter/ground fuel plans, signed Gove County commercial access, named licensed carrier.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.airnav.com/airport/1QK) · [2](https://govecountyks.gov/airport/)

### AXN — Chandler Field

**Airport key:** `OURAIRPORTS:3389`; **runway:** 13/31 good asphalt 5099x100ft with ILS; separate 04/22 fair asphalt 4098x75ft. **Gross paved length:** 5099ft. **Published selected LDA:** not verified. **Distance screen:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft/pavement:** Both FAA runways S35000lb D60000lb, but 04/22 has only ~49m gross buffer above 1200m; load and pavement must be aircraft-specific.

**Finding:** FAA current Chandler Field 13/31 5099ft operational good asphalt with instrument ILS, and separate 04/22 fair asphalt 4098ft. Approach RW31 tree 59ft and road inside primary surface require careful obstacle analysis. Airport has Jet A/avgas and major maintenance, but medevac helicopters, ultralights and seasonal waterfowl require ramp separation and current wildlife/snow NOTAM. Flight school/FBO does not itself authorize a scheduled passenger airline. Official usable direction-specific LDA and signed municipal commercial permits absent.

**Evidence still required:** Obtain FAA RW13/RW31 and RW04/RW22 official usable LDA and S35/D60 airframe compatibility, approach road and wildlife winter NOTAM, off-hours Jet A/ARFF, airport owner commercial-use agreement and named current certificated operator.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.airnav.com/airport/KAXN) · [2](https://www.alexandriaaviation.com/)

### BAK — Columbus Municipal Airport

**Airport key:** `OURAIRPORTS:3394`; **runway:** 05/23 excellent grooved concrete 6401x150ft, published LDA 6401ft both directions; 14/32 excellent concrete 5000x100ft separately. **Gross paved length:** 6401ft. **Published selected LDA:** 6401ft. **Distance screen:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft/pavement:** Main 05/23 PCR320 R/A/W/T S75000lb D130000lb DT200000lb, ARFF index A; separate 14/32 PCR300 requires aircraft-specific fit.

**Finding:** FAA October 2026 officially publishes 6401ft LDA RW05 and RW23, both comfortably >1200m; physically open public airfield has Jet A and tower 0630-2200. Crucially, FAA says RW05/23 NOT AVAILABLE for Part121/Part380 scheduled passenger operations >9 seats and nonscheduled >30 seats, and requires 90-day PPR for unscheduled air-carrier ops above 30 seats. This is a passenger-service legal ban/permission gate, not full closure of GA runway. Secondary runway 14/32 loading and official LDA cannot be inherited from main.

**Evidence still required:** Enforce BAK scheduled Part121/380 >9-seat and non-scheduled >30-seat restrictions, establish active Part139/class and approved named carrier first; confirm 6401ft LDA, aircraft load/ARFF/NOTAM, 90-day PPR where applicable, city signed commercial-use rights.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.columbus.in.gov/airport/) · [2](https://www.airnav.com/airport/BAK)

### CAR — Caribou Municipal Airport

**Airport key:** `OURAIRPORTS:3440`; **runway:** 01/19 4003x100ft good asphalt; 11/29 fair asphalt 3016ft underlength and RW29 398ft displaced. **Gross paved length:** 4003ft. **Published selected LDA:** not verified. **Distance screen:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft/pavement:** Primary S30000lb; 4003ft just ~20m gross margin above 1200m, cannot assume true usable LDA passes; crosswind 11/29 underlength.

**Finding:** FAA Oct2026 operating paved 01/19 good asphalt 4003ft S30000lb, but runway RW01 approach has power poles/trees and rising ground. Secondary 11/29 3016ft is below minimum; its RW29 displaced 398ft is not relevant to main landing LDA. FAA lists only 24h card 100LL and NO current verified Jet A or on-field repair. County/city calls airport of entry: any crossborder arrivals need CBP approval. Unattended field/winter maintenance and owner signed commercial permissions not established.

**Evidence still required:** Obtain FAA actual RW01/RW19 declared LDA with ~20m length margin, approach power-line/trees, winter NOTAM/FICON and fuel/ARFF rescue or range plan, written city commercial rights, international CBP if applicable and licensed operator.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.airnav.com/airport/CAR) · [2](https://www.cariboumaine.org/living-in-caribou/airport/)

### CTB — Cut Bank International Airport

**Airport key:** `OURAIRPORTS:3470`; **runway:** 05/23 5300x75ft good asphalt and 14/32 5300x75ft good asphalt; separate equal-length primary candidates. **Gross paved length:** 5300ft. **Published selected LDA:** not verified. **Distance screen:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft/pavement:** Both paved runways FAA PCN10 F/D/Y/U, S27500lb D37500lb; 75ft width and high density altitude/cold weather require aircraft compatibility.

**Finding:** FAA Oct2026 shows two operating paved 5300ft runways with Jet A and ASOS; international entry designation requires explicit CBP landing authorization in advance, not an airline licence. Airport owner advertises 24h Customs support but permission/specific flight clearance is still obligatory. Montana severe winter and FAA notes cold-temperature-altimetry corrections at or below -28C, which affects arrival performance; the single runway length does not verify usable LDA in either direction. No named certified charter/cargo provider or signed owner paid operations.

**Evidence still required:** Confirm all four official RW05/RW23/RW14/RW32 LDA and PCN10/aircraft gear, high elevation and -28C correction weather NOTAM, flight-specific CBP landing clearance for border traffic, rescue/fuel, owner signed commercial access and licensed carrier.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.airnav.com/airport/KCTB) · [2](https://cutbankairport.org/)

### CXL — Calexico International Airport

**Airport key:** `OURAIRPORTS:3474`; **runway:** 08/26 excellent asphalt 4683x75ft, RW26 displaced 160ft (nominal RW26 4523ft). **Gross paved length:** 4683ft. **Published selected LDA:** not verified. **Distance screen:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft/pavement:** FAA main single-wheel S30000lb/75ft wide; RW26 displaced 160ft yields nominal 4523ft (~1379m), but not FAA published LDA.

**Finding:** FAA Oct2026 confirms single active paved 08/26 runway 4683ft excellent asphalt with 100LL and Jet A. City owner classifies airport as general aviation without existing scheduled commercial air service; international port-of-entry status does not establish lawful new airline or prepaid customs clearance. RW08 PAPI and approach powerline 37ft high, Mexico border airspace and attendance 0800-1700 need flight-date coordination. No official published 08 or 26 LDA established, nor written city operator access or actual air-carrier certificate.

**Evidence still required:** Verify official RW08 and RW26 usable LDA with displaced RW26 threshold, S30000lb selected aircraft gear and RW08 powerline, flight-specific CBP/military-border airspace/NOTAM, after-hours Jet A and city paid-service permit with certified operator.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.airnav.com/airport/CXL) · [2](https://www.calexico.ca.gov/?SEC=531EF4A5-0975-43B0-9A41-3FAC5DBE4774)

### DAN — Danville Regional Airport

**Airport key:** `OURAIRPORTS:3480`; **runway:** 02/20 5900x100ft good grooved asphalt with published RW02 and RW20 LDA 5600ft; separate 13/31 3910ft below 1200m. **Gross paved length:** 5900ft. **Published selected LDA:** 5600ft. **Distance screen:** `PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION`.

**Aircraft/pavement:** Main 02/20 FAA S90000lb D130000lb, trees/approach and passenger-airline legal class need aircraft-specific review.

**Finding:** FAA Oct2026 reports official RW02 LDA 5600ft and RW20 LDA 5600ft on 5900ft paved runway, both above game 1200m minimum. RW20 displaced threshold 300ft but FAA declared LDA must not be double-subtracted. Separate paved 13/31 3910ft (<1200m) cannot count. Danville municipal FAQ states NO EXISTING scheduled air service, not a blanket future service prohibition. Main ILS, Jet A and major repairs, with services staffed 0700-1900; written city airline authorizations, actual licensed operator and live NOTAM are still missing.

**Evidence still required:** Reconfirm both official 5600ft LDAs and S90/D130 aircraft loading, approach trees/ILS and 0700-1900 after-hours handling/ARFF, city signed passenger/charter/cargo agreement, operator's relevant Part119/121/135 certificate and date-valid NOTAM.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.danvilleva.gov/507/Danville-Regional-Airport) · [2](https://www.danville-va.gov/m/faq?cat=26) · [3](https://www.airnav.com/airport/DAN)

### ELO — Ely Municipal Airport

**Airport key:** `OURAIRPORTS:3511`; **runway:** 12/30 5596x100ft good asphalt, FAA PCN39; owner rounds to 5600ft. **Gross paved length:** 5596ft. **Published selected LDA:** not verified. **Distance screen:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft/pavement:** FAA current PCN39 F/B/X/U S99000lb D159000lb, 100ft width; RW30 90ft approach tree, northern snow/forest wildfire periods.

**Finding:** Ely municipal airport has a good paved 5596ft 12/30 with Jet A and avgas but no maintenance/replacement repairs listed; city calls it a rounded 5600ft. US Forest Service firefighting aircraft activity and customs landing-rights status are operational/administrative conditions, not a permanent runway closure or evidence of an active certificated airline. Airport staffed 0800-1700 with after-hours callout. The city's older '2% air taxi' statistics cannot verify a present paid passenger operator or owner consent. Official direction-specific LDA missing.

**Evidence still required:** Get current official RW12/RW30 LDA, S99/D159/PCN39 airplane fit and RW30 tree obstacle, date wildfire/TFR/winter FICON, advance CBP permission if international, after-hours fuel/rescue, city commercial consent and currently certificated operator.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.ely.mn.us/airport) · [2](https://www.airnav.com/airport/ELO)

### FTY — Fulton County Airport Brown Field

**Airport key:** `OURAIRPORTS:3546`; **runway:** 08/26 5797x100ft good grooved asphalt, ILS RW08, FAA 2026 survey; county rounds to 5796ft. **Gross paved length:** 5797ft. **Published selected LDA:** not verified. **Distance screen:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft/pavement:** FAA S105000lb D121000lb DT198000lb on runway 08/26; airplane and ramp/taxi restrictions, wildlife and obstacle clearance pending.

**Finding:** FAA Oct 2026 confirms operating 5797ft good paved 08/26, ILS and full-service Jet A/major repair, continuous ATCT and controlled Atlanta Class B vicinity. County owner describes 5796ft primary, a rounding/survey difference, plus two FBOs and general aviation/corporate service. The August 2026 draft environmental assessment for runway 08/26 safety improvements is not a current closed runway, completed construction or automatic airport-carrier authorization. FAA lists birds, deer and all-quadrant noise-sensitive area; runway ramp runups not authorized. Distinct current FAA LDA is unverified, and ATL scheduled-airline rights do not transfer to FTY.

**Evidence still required:** Obtain official RW08/RW26 published usable LDA, S105/D121/DT198 aircraft/load and ILS trees, airport project date-specific construction/NOTAM, Atlanta airspace/ATCT and apron limitations, signed Fulton County commercial rights and a named valid carrier.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://fultoncountyga.gov/airport) · [2](https://www.airnav.com/airport/FTY)

### TX0 — Shank N Bank Airport

**Airport key:** `OURAIRPORTS:325326`; **runway:** 09/27 5002x75ft excellent asphalt, FAA source; owner rounds runway to 5001ft. **Gross paved length:** 5002ft. **Published selected LDA:** not verified. **Distance screen:** `GROSS_LENGTH_ONLY_LDA_UNVERIFIED`.

**Aircraft/pavement:** FAA 2026 has no independently verified aircraft wheel-load value in runway record; owner TX0 site quotes PCR 45/F/B/X/T and ramp tug up to 60000lb, neither confirms selected airplane authorization.

**Finding:** Privately owned but FAA-listed public-use airport. Gates locked; owner requires advance landing authorization with signed owner and operator waiver forms. Owner offers prearranged business/charter jet fueling and a landing/ramp fee waived with qualifying fuel purchase. Public-use FAA status does not waive contractual owner permission. RW09/RW27 approach trees with slopes, no instrument approach in source, and official usable LDA not established; 5001ft owner vs 5002ft FAA is minor data discrepancy.

**Evidence still required:** Obtain FAA authoritative RW09/RW27 LDA, aircraft PCR/load and approach trees/weather, owner-and-operator permission forms signed before trip, Jet A/rescue/handling schedule, and named currently certificated paid-flight operator.

**Owner commercial rights:** `NOT_VERIFIED`; **certificated carrier:** `NOT_VERIFIED`; **flight-date NOTAM:** `NOT_VERIFIED`; **gameplay:** `NOT_APPROVED`.

**Sources:** [1](https://www.airnav.com/airport/TX0) · [2](https://www.tx0.com/pilots-info)

## Decision-critical corrections

**BAK Columbus Municipal:** FAA RW05 and RW23 each publish **LDA 6,401ft**, but FAA explicitly restricts covered Part 121/Part 380 scheduled passenger operations over 9 seats, non-scheduled passenger operations over 30 seats, and requires 90-day prior permission for certain larger non-scheduled flights. LDA pass is **not** an airline game admission. [FAA 2026 record](https://www.airnav.com/airport/BAK).

**DAN Danville Regional:** The FAA publishes **RW02 LDA 5,600ft** and **RW20 LDA 5,600ft**, both passing runway distance. RW20 300ft displaced threshold must **not** be subtracted a second time from FAA declared LDA. Separate 13/31 3,910ft is under 1,200m. City's lack of current scheduled airline service is not an independent prohibition on a different legally qualified future carrier. [FAA](https://www.airnav.com/airport/DAN).

**TX0 Shank N Bank:** FAA public-use label coexists with **privately owned, locked-gate premises**. Owner requires **advance operator/owner forms** to obtain landing authorization and offers Jet A by arrangement, with landing fee. The owner's 5,001ft versus FAA 5,002ft discrepancy and PCR/aircraft loading must be reconciled; owner-paid-use must be signed before considering service. [Airport owner's pilot information](https://www.tx0.com/pilots-info).

**CAR and 1QK:** Paved primary gross dimensions of **4,003ft** and **4,000ft** leave only ~20m/19m above 1,200m. These are not confirmed official LDA. CAR FAA fuel lists 100LL, not verified Jet A. Gove County FAA lists no dependable field fuel/repair service, and its concrete primary is only 60ft wide. [CAR FAA](https://www.airnav.com/airport/CAR) · [1QK FAA](https://www.airnav.com/airport/1QK).

**CXL, CTB:** Border airport-of-entry designations need **flight-specific Customs and Border Protection landing clearance**, not simply an airport label. CTB's two 5,300ft paved runways have separate directional LDAs pending; CXL's RW26 displaced threshold requires a distinct landing-distance assessment. [CTB](https://www.airnav.com/airport/CTB) · [CXL](https://www.airnav.com/airport/CXL).

**AXN, ELO and FTY:** Medevac/wildlife, Forest Service wildfire flights and Atlanta corporate traffic respectively are operating/dispatch coordination gates, **not permanent physical runway closures**. ELO city's 5,600ft is a rounded version of current FAA 5,596ft. FTY's 5,797ft FAA survey versus county's 5,796ft remains a minor record discrepancy, and its August 2026 runway-project environmental document is not proof of current runway closure or constructed work. [AXN](https://www.airnav.com/airport/AXN) · [ELO](https://www.airnav.com/airport/ELO) · [FTY](https://www.airnav.com/airport/FTY).

## Next and non-negotiable safeguards

No airport is gameplay-approved until **operating asphalt/concrete with >=1,200m authoritative usable LDA for the specific landing direction**, aircraft type/wheel/pavement/terrain and obstacles, current FAA NOTAM/FICON/weather, fuel/ground/rescue, a signed owner commercial-use agreement, and a current named certificated operator. **Exactly six pre-agreed Airlinerra category definitions remain unchanged**.

Phase 4 evidence ledger RLS is enabled and `anon`/`authenticated` lack SELECT access. The **3,140** original playable airports and **1,929** expansion candidates remain unchanged.

**Next:** Phase 4 Batch 21, another 10 of the **11** advanced airport cases awaiting review; independently remediate **622** held Phase 3 operational candidates.
