# Airlinerra — Phase 5 Batch 9: Missing Landing Distance Desk Review

**Completed:** 26 October 2026 · **Source of truth:** private Supabase project `hwllkabgzaynalahvkpz`, schema `airlinerra` · **GitHub branch:** `main`.

## Executive audit

Twenty additional US expansion airports received an individual source review. All 20 airport source pages were independently retrieved from FAA-derived AirNav listings with **FAA information effective 01 October 2026** and cross-checked against their earlier Phase 4 airport dossiers. **No authenticated original FAA NASR runway-end LDA was obtained**, and none of the potentially qualifying runways was certified for gameplay. The 20 airport records remain `EVIDENCE_HOLD`, `OFFICIAL_LDA_NOT_VERIFIED` and `NOT_APPROVED`.

| Measured result | Count |
| --- | ---: |
| New airport source reviews | **20** |
| New runway-end evidence records | **72** |
| Runway directions awaiting official per-end LDA | **46** |
| Runway directions physically too short or wrong surface | **20** |
| Runway directions on independent pavement-condition hold | **6** |
| Overall Phase 5 source reviews completed | **176/211 (83.4%)** |
| Phase 5 airports still queued | **35** |
| All runway-direction records | **264** |
| Phase 5 game-approved airports | **0** |
| Original airport cohort preserved | **3,140** |
| Active world airport rows | **0** |

## Source methodology and restrictions

Source effective date proves only that the **FAA-derived directory is marked effective October 1, 2026**; it is not primary-source authentication of the October FAA NASR APT archive, a flight-date NOTAM, aircraft compatibility, or legal authorization to carry passengers. DO NOT infer `LDA` from a runway's surveyed gross length, an instrument approach, a runway stopway, or displaced-threshold arithmetic. Nonverified FAA LDAs remain NULL. Do not transfer physical runway condition/weight limits, a runway closure, or a taxiway restriction to a different airport runway. Owner permission, operator certification, date-valid NOTAM/FICON/weather, fuel and rescue/ground handling are separate gates.

## All 20 airport findings

| FAA | Airport | Region | Key FAA-derived evidence and unresolved issues |
| --- | --- | --- | --- |
| MIW | Marshalltown Municipal Airport | US-IA | FAA-derived AirNav effective 01 Oct 2026 shows primary RW13/31 asphalt 5007x100ft FAIR, PCN32, S35000/D42000, and separate RW18/36 2759x50ft under minimum, despite secondary PCN26. No published direction-specific primary LDA in consulted source. Do not transfer secondary aircraft loads. Iowa DOT, snow FICON, fuel, owner's written paid-use, named licensed carrier and aircraft compatibility remain unverified. |
| MKY | Marco Island Executive Airport | US-FL | FAA-derived 01 Oct 2026 Marco Island Executive primary RW17/35 5000x100ft GOOD GROOVED ASPHALT, PCN26 F/A/W/T, S75000/D108000lb; no displaced threshold documented in runway table, contrary to vague old Phase3. No published per-direction LDA in accessible source. Airport physically open 24h but after-hours FBO and rescue by prior request; flight-date coastal storm/bird and owner/operator permissions unresolved. |
| MNN | Marion Municipal Airport | US-OH | FAA-derived 01 Oct 2026 Marion Municipal: main RW07/25 5000x100ft GOOD grooved asphalt S70000/D95000/DT150000; secondary RW13/31 3498x100ft too short. FAA published TWY D between runway and ramp limited to aircraft <=35ft wingspan: this is NOT 35ft runway width or airport-wide aircraft restriction; choose lawful alternative taxi/ramp. Main per-direction official LDA, glider NOTAM, municipal paid-use and air operator unverified. |
| MPZ | Mount Pleasant Municipal Airport | US-IA | FAA-derived 01 Oct 2026 Mount Pleasant Municipal: main RW15/33 excellent concrete 4001x75ft, S12000/D16000; only ~19m gross above 1200m, so even small declared landing distance penalty could fail; RW03/21 1967ft turf nonqualifying. Official per-end LDA absent in consulted directory, aircraft wheel/75ft width, trees, weekend fueling, signed city commercial rights and named licensed carrier unresolved. |
| MQI | Dare County Regional Airport | US-NC | FAA-derived 01 Oct 2026 Dare County primary RW05/23 asphalt excellent 4306x100ft: RW05 threshold 305ft displaced = 4001ft nominal pavement; RW23 threshold 301ft displaced = 4005ft nominal. Only ~19-21m above 1200m, NOT official published FAA LDA. Secondary 17/35 3303x75ft gross fails; RW17/35 displacements 290ft/989ft. TWY F permanently closed does not blanket shut primary. Banner tow/seaplane, migratory waterfowl Oct-Feb, drop-off RW05, signed county/actual air operator unresolved. |
| OKV | Winchester Regional Airport | US-VA | FAA-derived 01 Oct 2026 Winchester Regional RW14/32 excellent grooved asphalt 5498x100ft, ILS/MALSR runway 32, S75000/D150000; no published per-direction LDA. 2026 taxiway relocation grant with expected spring 2027 construction is NOT existing runway closure or completed project. Airport owner rights, operator, flight-date NOTAM and approach obstacles/wildlife pending. |
| ONO | Ontario Municipal Airport | US-OR | FAA-derived 01 Oct 2026 Ontario Municipal RW15/33 fair asphalt 5006x100ft S30000/D60000; no published per-direction LDA. FAA airport traffic remark calm-wind RW15 preferred <=5 knots, glider ops April-Oct and wildfire aircraft June-Oct; parking/rotor/fire zone scheduling is not permanent runway closure. Winter/wildfire dated NOTAM and city commercial-use licensed carrier pending. |
| ONY | Olney Municipal Airport | US-TX | FAA-derived 01 Oct 2026 Olney Municipal has **three distinct physical runways**: 04/22 5100x75ft GOOD asphalt with rubberized friction seal, 17/35 5101x75ft FAIR similar surface, and 13/31 5099x75ft asphalt reported extensive FIRST and LAST thirds cracked with vegetation/loose stones, explicitly a pavement-condition operational HOLD pending independent engineering and current NOTAM. Do not assign 13/31 based on length. No published LDAs on the three in consulted source. Currently source fuel 100LL only. Runway strength is not commercial authorization. |
| ORK | North Little Rock Municipal Airport | US-AR | FAA-derived 01 Oct 2026 North Little Rock Municipal RW05/23 concrete GOOD 5002x75ft S30000/D60000, secondary RW17/35 asphalt 3019x75ft under length threshold. Neither RW05 nor RW23 original published LDA established. Separate training/ultralight use and Jet A/repair listing not proof of paid carrier permit or a certified operator. |
| OUN | University of Oklahoma Westheimer Airport | US-OK | FAA-derived 01 Oct 2026 University of Oklahoma Westheimer RW18/36 good grooved asphalt 5199x100ft and RW03/21 good asphalt 4748x100ft, both S30000/D50000/DT100000. No direction-specific original LDA displayed. University airport 2026 football home game PPR and special event fees are date-specific; do NOT treat as unconditional curfew or paid-airline permission. Tower hours, student operations, dated game-day permits and owner/operator credentials unverified. |
| OVO | North Vernon Airport | US-IN | FAA-derived 01 Oct 2026 North Vernon RW05/23 excellent asphalt 5002x75ft S100000/D135000/DT230000, secondary RW15/33 2730x50ft asphalt below 1200m. Secondary bearing limits do not transfer to primary. Main per-direction published LDA unavailable, approach road/crops, actual after-hours Jet A/ground callout and county paid-use certification required. |
| OXI | Starke County Airport | US-IN | FAA-derived 01 Oct 2026 Starke County primary RW18/36 GOOD asphalt 5002x75ft S30000; secondary RW09/27 turf 3096x145ft physically/ surface ineligible, turf RW09 has 285ft displaced threshold (does NOT apply primary). Main direction-specific LDA unavailable, crop obstruction/NOTAM, Jet A arrangements and certificated commercial operator/airport rights unresolved. |
| PHN | St Clair County International Airport | US-MI | FAA-derived 01 Oct 2026 St Clair County International: RW04/22 good grooved asphalt 5104x100ft S40000/D55000/DT90000, secondary RW10/28 good asphalt 4000x75ft, only ~19m gross over minimum S16000. Published LDA absent on both pairs. Customs/Agriculture reporting affects international flights only, landing fees with fuel waiver are economic not ban. Owner commercial authority and carrier, axle load, weather/NOTAM outstanding. |
| PMH | Greater Portsmouth Regional Airport | US-OH | FAA-derived 01 Oct 2026 Greater Portsmouth Regional RW18/36 good asphalt 5001x100ft, S30000/D42000/DT70000, no published official directional LDA in accessible directory. Skydiver/air tour traffic, after-hours Jet A+ callout, trees/gear performance, airport owner agreement and named certified carrier require separate verification. |
| PRO | Perry Municipal Airport | US-IA | FAA-derived 01 Oct 2026 confirms Perry Municipal primary RW14/32 excellent 5500x100ft CONCRETE, PCN15, S28000/D48000. Older city source shows obsolete ~4000ft runway; use newer Iowa DOT + FAA. Turf 04/22 source currently 2321ft (Iowa DOT rounds to 2322ft), no snow removal and below game rule. Main published LDAs unknown, parachute jumping/NOTAM and owner-approved paid use with licensed carrier unverified. |
| PSK | New River Valley Airport | US-VA | FAA-derived 01 Oct 2026 New River Valley primary RW06/24 good grooved asphalt 6201x150ft, ILS RW06; published directional LDA unavailable in consulted directory. Customs FTZ/airport-of-entry designation not CBP permission for each actual flight. Approach trees, aircraft gear limits, weekend/holiday fuel/ARFF and airport owner commercial permits/ certificated carrier pending. |
| PSX | Palacios Municipal Airport | US-TX | FAA-derived 01 Oct 2026 Palacios Municipal RW13/31 good concrete 5001x150ft S46000/D58000/DT105000, separate RW08/26 **POOR** concrete 5001x150ft tall vegetation and RW18/36 **POOR** concrete 5001x75ft tall vegetation; latter both kept distinct PAVEMENT-CONDITION HOLD, NOT classified eligible solely on 5001ft dimensions. Main published per-direction official LDA unavailable, RW13 approach trees, current FAA NOTAM, fuel/rescue, county legal paid-use and certified operator unverified. |
| PUJ | Silver Comet Field at Paulding Northwest Atlanta Airport | US-GA | FAA-derived 01 Oct 2026 Silver Comet Field (Paulding NW Atlanta) main RW13/31 good grooved CONCRETE 5505x100ft, S90000/D130000, ILS/DME. No published per-direction official LDA in checked source. Ground handler advertised tug capacity 15000lb refers to moving equipment, NOT runway structural capacity; qualified tow/stand and rescue for larger aircraft plus county owner paid operator agreement and named certificated carrier are unverified. |
| RAL | Riverside Municipal Airport | US-CA | FAA-derived 01 Oct 2026 Riverside Municipal main RW09/27 good asphalt 5401x100ft S48000/D70000/DT110000, secondary 16/34 fair 2850x50ft asphalt underlength (its owner 12500lb restricted gear class is NOT main runway load). Main published RW09/RW27 LDA unavailable, ATCT 0700-2000, busy pilot training/SoCal airspace, tower/NOTAM and city licensed paid-use carrier unresolved. |
| RCM | Skyhaven Airport | US-MO | FAA-derived 01 Oct 2026 Skyhaven (University of Central Missouri) primary RW01/19 good concrete 4206x75ft S21000/D26000, secondary RW14/32 good asphalt 2801x60ft physically under 1200m. No per-direction authoritative LDA for primary in checked source, gear certification, campus-owned airport rights, operator certificate, emergency handling and active NOTAM outstanding. |

## Important independent exceptions

### MQI — Dare County Regional Airport

The main RW05/23 is 4,306ft long. FAA-derived source has displaced thresholds RW05 **305ft** and RW23 **301ft**, leaving nominal landing pavement **4,001ft/4,005ft** respectively. These are only ~19.5m and ~20.8m above 1,200m and **not published LDAs**. The separate RW17/35 is only 3,303ft and physically ineligible. A permanent closure of *taxiway F*, waterfowl, banner tow, and seaplane activity do not close RW05/23 automatically. Source: https://www.airnav.com/airport/MQI

### ONY — Olney Municipal Airport

The airport has RW04/22 asphalt rubberized seal coat in **good** condition (5,100ft), RW17/35 similar surface in **fair** condition (5,101ft), and a third RW13/31 5,099ft with heavy cracks/vegetation/loose stones on its first and last thirds. Because gross length is not sufficient evidence of serviceability, RW13 and RW31 now have **`PAVEMENT_CONDITION_HOLD`**, while the good/fair runways retain separate `ALTERNATE_DIRECTION_LDA_UNVERIFIED`. This is an independent research hold, not a fabricated regulatory permanent closure. All remain NOT_APPROVED. Source: https://www.airnav.com/airport/ONY

### PSX — Palacios Municipal Airport

RW13/31 concrete (5,001ft) is listed **good**, while independent RW08/26 (5,001ft concrete) and RW18/36 (5,001ft concrete) are **poor with tall vegetation on the runway**. Each direction on these two poor-condition runways is marked `PAVEMENT_CONDITION_HOLD` — four records. Do not disqualify the good RW13/31 solely because alternatives are unsafe, but do not approve the main without its own official LDA, aircraft, fuel, flight-date and commercial legal checks. Source: https://www.airnav.com/airport/PSX

### MNN — Marion Municipal Airport

Airport-derived TWY D *between runway and apron* limits aircraft wingspan to **35ft**. This is a **taxiway ground-movement limit**, not a 35ft runway width or ban on wider aircraft at the airport. Aircraft wider than that require an independently verified safe legal taxiway/stand routing. Main RW07/25 physical length is 5,000ft. Source: https://www.airnav.com/airport/MNN

### PRO — Perry Municipal Airport

The current FAA-derived runway and Iowa DOT airport directory agree on 5,500ft **concrete** RW14/32, versus some obsolete shorter city figures. The short turf 04/22 is 2,321ft in the FAA-derived directory and 2,322ft in the Iowa DOT airport record; both fail the game length/surface rule. Snow removal is unavailable on the turf field. Do not transfer its conditions to the paved runway. Sources: https://www.airnav.com/airport/PRO and https://opmapps.iowadot.gov/aviation/airports/PRO

### OUN — University of Oklahoma Westheimer

Two independent paved runways: 18/36 at 5,199ft and 03/21 at 4,748ft. University policy requires event-specific PPR and charges on designated OU football home-game days. The PPR is *not a blanket airport closure*. Neither runway has an independently established current official LDA or commercial operator permit. Sources: https://www.airnav.com/airport/OUN and https://www.ou.edu/airport

## Source-controlled database safeguards and complete evidence

The Phase 5 runway-direction CHECK constraint was extended with `PAVEMENT_CONDITION_HOLD`, requiring a qualifying-length asphalt/concrete surface, NULL unpublished LDA and a nonempty restrictions note. Existing `LANDING_DIRECTION_PROHIBITED` and distance-screen statuses remain supported. The airport `game_admission_status` and runway `commercial_admission_status` continue to be constrained to `NOT_APPROVED`. Every airport source URL and full research text is saved inside the private Supabase ledger.

GitHub archives:

- [Batch 9 pavement-condition CHECK migration](./sql/AIRLINERRA_PHASE5_BATCH_09_PAVEMENT_CONDITION_MIGRATION_2026-10-26.sql)
- [Runway-direction SQL archive — Part 1](./sql/AIRLINERRA_PHASE5_BATCH_09_RUNWAY_DIRECTIONS_PART_01_2026-10-26.sql)
- [Runway-direction SQL archive — Part 2](./sql/AIRLINERRA_PHASE5_BATCH_09_RUNWAY_DIRECTIONS_PART_02_2026-10-26.sql)
- [Runway-direction SQL archive — Part 3](./sql/AIRLINERRA_PHASE5_BATCH_09_RUNWAY_DIRECTIONS_PART_03_2026-10-26.sql)

## Next

**Phase 5 Batch 10:** take 20 of the 35 Priority-3 airports still awaiting an initial source review, then Batch 11 can complete the final 15. Separately, obtain and import the authenticated current FAA NASR per-runway-end LDA data for all source-reviewed airports and complete every named owner/carrier/aircraft/NOTAM/rescue check. Initial source review completion does NOT mean eligibility approval or selection for a live game world.
