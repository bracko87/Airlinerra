# Airlinerra — Phase 3 Priority Runway Exception Reassessment (2026-10-24)

**DONE AND VERIFIED IN SUPABASE:** All nine priority runway/condition exceptions have an individually documented current research disposition in `airlinerra.airport_expansion_runway_exception_phase3`, with unique immutable airport keys, source URLs, condition and declared-distance bases, next actions and check timestamps. Exactly one airport advances past the missing-runway-condition check; the other eight remain provisionally held. **No airport was activated, rejected permanently, or approved for gameplay.**

## Verified result

| Outcome | Count |
|---|---:|
| **Alternate suitable paved runway verified, next eligibility gate** | **1 (AST)** |
| Dated current October NOTAM — recheck after expiry | 3 (53A, SRC, U14) |
| Insufficient available distance under 1,200m | 3 (14G, L66, O61) |
| Airport reconstruction closure, owner reopening needed | 1 (PVJ) |
| Indefinite paved-runway closure with nonqualifying dirt alternative | 1 (N59) |
| **Total cases individually reviewed** | **9** |
| Admissions / game activations / approved new categories | **0 / 0 / 0** |
| Original playable airports | **3,140 unchanged** |

## Meaningful improvement: AST Astoria Regional, Oregon

[FAA-derived airport record](https://www.airnav.com/airport/AST) establishes that although candidate screening stored no pavement condition for primary RW08/26, the *separate* runway **14/32** has **4,467 × 100ft asphalt in EXCELLENT condition, with 4,467ft LDA both ways**, meeting the initial 1,200m paved runway/condition screen. The original unknown-condition entry on RW08/26 is retained for provenance. Only **AST** moved from `RUNWAY_CONDITION_OR_DATA_HOLD` to `ALTERNATE_RUNWAY_VERIFIED_NEXT_ELIGIBILITY`, and `screen_result` became `ALTERNATE_PAVED_RUNWAY_1200M_PASS`. **It still requires owner rules, Coast Guard helicopter traffic, coastal weather, aircraft/weight and any actual operating restriction verification.**

## Dated restrictions — no automatic reopening

- **U14 — Nephi, Utah:** [October 21–30 NOTAMs](https://www.iflightplanner.com/Airports/U14) reduce both RW17 and RW35 published LDA to **2,550ft (~777m)**, despite roughly **6,300ft** physical runway. Recheck after **Oct 30, 2026 at 23:00 UTC**; other approach/REIL limitations may remain.
- **SRC — Searcy Regional, Arkansas:** [NOTAM](https://www.iflightplanner.com/Airports/KSRC) closes paved RW01/19 to **Oct 31, 2026 at 20:00 UTC**, with other navaid and avgas outages on different dates. Recheck live reopening; don't call the 6,008ft physical pavement permanently unavailable.
- **53A — Dr. C P Savage Sr., Georgia:** [NOTAM](https://www.iflightplanner.com/Airports/53A) closes RW18/36 through **Nov 15, 2026 at 23:59 UTC**. RW18 permanently displaced threshold yields **4,220ft LDA** and RW36 LDA about 5,002ft, so the physical runway should be evaluated anew only after closure confirmation. Midfield apron and PAPI have separate notices.

**PVJ Pauls Valley, Oklahoma:** [Airport-owner website](https://www.paulsvalley.com/airport) says closed from Nov 3, 2025 **indefinitely until further notice** during runway replacement. An FAA notice had expiry Nov 10, 2026; that alone is **not** a reliable reopening date. Require a fresh FAA NOTAM, owner confirmation, and completed as-built surface/dimensions.

## Persistent runway suitability holds

- **14G Fremont, Ohio:** [FAA 2026 remarks](https://www.airnav.com/airport/14G) report 4,137ft nominal runway but failed east 330ft and only **3,900ft daytime available pavement** (~1,189m), with a shorter illuminated segment and poor margins. 3,900ft is a *daytime usable-pavement statement*, **not** a certified declared LDA.
- **L66 Pollock, Louisiana:** [FAA record](https://www.airnav.com/airport/L66) states north 1,000ft of 4,499ft runway closed indefinitely and severe cracking/standing water. At most **3,499ft remaining physical pavement**, an estimate rather than officially declared LDA.
- **O61 Cameron Park, California:** [Airport owner](https://www.cameronparkairport.org/flight-planning) confirms roughly 200ft RW13 and 1,500ft RW31 threshold displacements from around 4,060ft asphalt. Thus about **3,850ft RW13** and **2,550ft RW31** for landings, below 1,200m in both directions; owner also restricts aircraft weight and wingspan absent exceptions. Exact FAA published declared distances and interpretation of Airlinerra's game gate must be resolved before a final reject decision.
- **N59 Rosaschi, Nevada:** [FAA current record](https://www.airnav.com/airport/N59) confirms 4,800×32ft asphalt RW07/25 **closed indefinitely**, with large cracks, potholes and vegetation. Only the alternate **3,700ft dirt** runway is open in source data; it cannot satisfy the 1,200m hard-surface rule. Reconsider only after authoritative resurfacing/reopening.

## Every reviewed airport: persisted evidence and required actions

| FAA | Immutable key | Exception disposition | Runway | Physical length (ft) | Reference usable distance (ft)* | Recorded issue | Next verification | Source |
|---|---|---|---|---:|---:|---|---|---|
| 14G | `OURAIRPORTS:18419` | USABLE_LANDING_DISTANCE_BELOW_1200M_HOLD | RW 09/27 | 4137 | 3900 | Current Oct 2026 FAA-derived remarks: published 4,137ft asphalt but east 330ft failed and unusable; only 3,900ft (~1,189m) pavement available during daylight, RW27 illuminated segment 3,390ft. Wide cracks, loose debris and vegetation. Below 1,200m usable screen; the separate short turf runway does not qualify. | Require owner/FAA documented repair or officially revised usable landing/takeoff distances meeting game gate, pavement structural survey and aircraft/owner approval. Do not count failed 330ft. | [Evidence](https://www.airnav.com/airport/14G) |
| 53A | `OURAIRPORTS:18876` | DATE_SCOPED_NOTAM_RECHECK | RW 18/36 | 5003 | 4220 | Confirmed NOTAM !MCN 08/712 closes paved RW18/36 August 24 to November 15 2026 23:59Z; runway is closed as of audit Oct24. Permanent RW18 threshold displacement ~780ft yields LDA 4,220ft; RW36 LDA 5,002ft. Both exceed 1,200m after reopening; no reason to call permanently short. RW18 PAPI remains out under separate notice. | Recheck FAA NOTAM and owner reopening after Nov15, apron closure through Nov13, RW18 PAPI/aircraft approaches, exact LDA, pavement and commercial permission. Do not move to playable roster while runway closure active. | [Evidence](https://www.iflightplanner.com/Airports/53A); [Additional](https://www.airnav.com/airport/53A) |
| AST | `OURAIRPORTS:19314` | ALTERNATE_PAVED_RUNWAY_VERIFIED_NEXT_ELIGIBILITY | RW 14/32 | 4467 | 4467 | October 2026 FAA-derived AST shows RW08/26 5,794ft asphalt but pavement-condition field absent in initial candidate screen; independently published alternate paved RW14/32 is 4,467x100ft in EXCELLENT condition, with declared LDA 4,467ft in both directions and substantial published wheel-loading limits. This specifically resolves lack of any evidenced runway condition meeting screen, but does not establish airport ... | Proceed to next aircraft/owner/operations evidence gate using qualifying RW14/32, not the unknown-condition RW08/26; check Coast Guard helicopter activity, coastal weather, runway-specific weight and airport owner commercial terms. No automatic admission. | [Evidence](https://www.airnav.com/airport/AST) |
| L66 | `OURAIRPORTS:20305` | USABLE_LANDING_DISTANCE_BELOW_1200M_HOLD | RW 18/36 | 4499 | 3499 | FAA Oct 2026 runway 4,499ft paved, north 1,000ft closed indefinitely, only up to 3,499ft (~1,066m) physically available; surface is severely cracked with grass and standing water. 4,499ft nominal cannot establish eligible usable pavement. | Require evidence of official reopening of north 1,000ft, rehabilitation and current FAA operational landing distances and aircraft surface capacity before reconsideration. | [Evidence](https://www.airnav.com/airport/L66) |
| N59 | `OURAIRPORTS:20615` | INDEFINITE_PAVED_RUNWAY_CLOSURE_HOLD | RW 07/25 | 4800 | not available | FAA Oct 2026 Rosaschi Air Park asphalt RW07/25 4,800x32ft closed indefinitely with potholes, severe >6in cracks, sagebrush and faded X. Only alternative is dirt RW17/35 3,700ft, which fails paved >=1,200m rule. Not a verified permanent airport-wide shutdown, but zero qualifying usable paved runway. | Obtain FAA/BLM reopening and resurfacing evidence for 07/25 and qualifying declared landing distance/structural width; do not substitute short dirt runway. | [Evidence](https://www.airnav.com/airport/N59) |
| O61 | `OURAIRPORTS:20700` | USABLE_LANDING_DISTANCE_BELOW_1200M_HOLD | RW 13/31 | 4051 | 2542 | Cameron Park Airport District confirms about 4,060ft total asphalt; RW13 landing threshold displaced about 200-210ft (usable about 3,850ft), RW31 displaced around 1,500-1,510ft (landing about 2,550ft); neither reaches 1,200m. Airport owner limits aircraft gross weight <=12,500lb and wingspan <=49ft unless approved. Physical nominal runway >1,200m is not actual runway landing distance. | Reconfirm current official LDA per direction and explicit game rule requiring usable landing length, owner aircraft size/weight and commercial access; no final rejection until rule-specific decision. | [Evidence](https://www.cameronparkairport.org/flight-planning); [Additional](https://www.cameronparkairport.org/files/116ca4a2c/8a%2B2.1%2BCPAD%2BAirport%2BRules%2Band%2BRegulations%2BNov.pdf?get_file=true) |
| PVJ | `OURAIRPORTS:20889` | CONSTRUCTION_REOPENING_HOLD | RW 17/35 | not validated | not available | Pauls Valley city airport website still states RW17/35 closed from Nov3 2025 indefinitely pending runway replacement. Current FAA NOTAM !PVJ 11/002 separately lists RW17/35 closure Nov10 2025 through Nov10 2026 23:59Z, which is an expected notice expiry, not evidence that construction will be complete. Open/public airport record does not override actual runway closure. | Require new live FAA NOTAM after construction, written city/owner reopening confirmation and new as-built length/condition; verify airport authority commercial use. No automatic clearance after NOTAM expiry. | [Evidence](https://www.paulsvalley.com/airport); [Additional](https://www.iflightplanner.com/Airports/KPVJ) |
| SRC | `OURAIRPORTS:21107` | DATE_SCOPED_NOTAM_RECHECK | RW 01/19 | 6008 | not available | Searcy Regional paved RW01/19 nominal ~6,008ft but confirmed NOTAM !SRC 10/001 closes it Oct5-Oct31 2026 20:00Z. Separate 100LL outage to Oct31, RW01 ILS/ALS until Oct28 and other obstacle/taxiway notices. The runway closure is time-specific, not proof of permanent structural inadequacy. | After Oct31 confirm no extended FAA runway closure, actual usable LDA/strength, fuel and airport-owner commercial service access. Keep not playable during scheduled closure. | [Evidence](https://www.iflightplanner.com/Airports/KSRC) |
| U14 | `OURAIRPORTS:21256` | DATE_SCOPED_NOTAM_RECHECK | RW 17/35 | 6300 | 2550 | Nephi Municipal Utah has about 6,300ft physical asphalt but Oct21-Oct30 23:00Z NOTAMs !CDC 10/244 and 10/245 restrict RW17 and RW35 landing distances to only 2,550ft (~777m), with shorter TORA/ASDA; pilot-operated REIL and procedure outages may persist. NOT a blanket runway closure, rather current declared landing-distance restriction. | On/after Oct30 verify NOTAM expiry, latest both-direction declared distances, aircraft performance at ~5,022ft elevation and permitted owner commercial operations. Never admit using nominal 6,300ft during reduced LDA. | [Evidence](https://www.iflightplanner.com/Airports/U14) |

*The reference usable-distance values have distinct **distance bases** in the Supabase record, including formally declared LDA, owner-published threshold-derived estimates and remaining pavement. They must **not be treated as interchangeable official LDA values**. Exact aircraft/landing and runway closure status must be verified against active FAA NOTAM/airport-owner documents.*

## Updated Phase 3 state

| Selection-stage status | Airports |
|---|---:|
| `PRELIMINARY_SHORTLIST` | 1013 |
| `OPERATIONAL_CONSTRAINT_HOLD` | 833 |
| `IDENTITY_RECONCILED_NEXT_ELIGIBILITY` | 74 |
| `PROVISIONAL_EXCLUSION_REVIEW` | 8 |
| `ALTERNATE_RUNWAY_VERIFIED_NEXT_ELIGIBILITY` | 1 |
| **TOTAL** | **1,929** |

The original **1,013 preliminary shortlist** has not been inflated. **AST** is recorded separately as alternate-runway verified, not approved. The eight other cases remain `PROVISIONAL_EXCLUSION_REVIEW`, with detailed individual substatus in the new exception table.

## Engineering and game-safety integrity

Supabase read-back verified nine unique exception rows, each with complete finding, action, evidence URLs, assessment date and zero unauthorized admission. Stage 3 contains exactly 1,929 rows and the game cohort remains 3,140. New exception table has row-level security enabled with public/anon/authenticated privileges revoked. The AST status-and-screen result was updated under explicit SQL check constraints; none of the 1,929 `game_admission_status` values or world-activation/category tables were changed.

**Next:** Evaluate actual operating constraints across the 833 `OPERATIONAL_CONSTRAINT_HOLD` airports by grouping dated/expired NOTAM versus binding runway width, LDA, surface, owner-access and weather conditions. Evaluate the 1,013 preliminary shortlist and the 74 identity-reconciled airports at the **separate final eligibility gate** before considering any category assignment. Exactly six permitted categories: **Local, Regional, Medium, Large, Major Hub, Mega Hub**.
