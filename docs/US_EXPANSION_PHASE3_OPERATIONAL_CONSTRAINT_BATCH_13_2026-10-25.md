# Airlinerra — Phase 3 Operational Constraint Batch 13 — 2026-10-25

**COMPLETED AND VERIFIED:** 20 individual Supabase airport reviews, 2 advances only to subsequent eligibility checks, 18 retained holds. No airport approved, activated or categorized for gameplay.

## Live database audit following Batch 13

| Audit | Verified |
|---|---:|
| Total Phase 3 operational reviews | **389** |
| Advanced to further eligibility gate | **115** |
| Operational holds remaining | **718** |
| Holds not yet individually reviewed | **444** |
| Holds previously reviewed and still held | **274** |
| Total Phase 3 selection candidates | **1,929** |
| Original playable game airport cohort | **3,140** |
| Expansion game approvals / activations / final categories | **0 / 0 / 0** |

Batch identifier `US_EXPANSION_PHASE3_OPERATIONAL_BATCH_13_2026_10_25`. Source cycle date recorded: 2026-10-01. Assessment date: 2026-10-25.

### Evidence and eligibility policy

Research clarifies **limited restriction scope**, not airport-level game admission. Any eligible operational runway must be paved asphalt/concrete, operational, and have sufficient *direction-specific usable landing distance* of at least **1,200m**, width, pavement strength and aircraft performance. Verify current NOTAM, obstacles, fuel, owner commercial permission, and actual licensed operator. Preserve Airlinerra's **exactly six established airport categories**; none assigned in this batch.

**Litchfield 3LF:** runway 18/36 4,002ft physically meets the nominal threshold and separate 09/27 3,900ft does not. Primary declared LDA remains unverified. **Saratoga County 5B2:** customs-by-arrangement is not equivalent to total runway closure; each relevant international flight still requires CBP clearance and all legal commercial checks.

## Complete 20-airport evidence and follow-up ledger

### 3LF — Litchfield Municipal Airport
**Advanced only to further eligibility** · `QUALIFYING_PRIMARY_PAVED_RUNWAY_DISTINCT` · `OURAIRPORTS:18716`

**Runway:** 18/36 4002x75ft paved; 09/27 3900x75ft short. **Finding:** 2026 FAA-derived airport information confirms 18/36 nominally clears 1200m while independent 09/27 fails. The short secondary does not close or disqualify 18/36. Older city statement about missing RW18/36 approaches is superseded by FAA 2026 approach listings. **Next action:** Verify RW18/RW36 usable LDA, weight loading, latest FAA IAP/NOTAM, licensed operator and city permission.

Evidence: [Source 1](https://www.airnav.com/airport/3LF)

### 3MY — Mount Hawley Auxiliary Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18722`

**Runway:** 18/36 4001x60ft asphalt S-20 at 3MY. **Finding:** Peoria Airport Authority confirms S-20 load, 60ft width, near-minimum 4001ft physical length and Jet A/100LL. Mount Hawley is not Peoria International and cannot inherit its airline service. **Next action:** Hold for actual landing distance, gear weight/width, current NOTAM, certified carrier and Peoria airport authority access.

Evidence: [Source 1](https://www.fly3my.com/airport/pilot-information/)

### 3S8 — Grants Pass Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18737`

**Runway:** Grants Pass 3S8 ~4001ft asphalt primary. **Finding:** Airport has a near-minimum paved GA runway in a mountain valley, not Medford MFR's airline runway. Declared landing distance and local terrain/landing services remain unverified. **Next action:** Hold for FAA direction-specific LDA, terrain/performance, pavement strength, FBO and county-approved licensed air service.

Evidence: [Source 1](https://www.airnav.com/airport/3S8)

### 41F — Floydada Municipal Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18761`

**Runway:** Floydada 41F ~4600x60ft paved. **Finding:** 60ft paved width at high-plains GA field does not establish compatibility with commercial fleet, fuel or winter dispatch; no airport/charter service certificate evidenced. **Next action:** Hold for runway LDA/weight/width, fuel and winter response, city owner and certified operator.

Evidence: [Source 1](https://www.airnav.com/airport/41F)

### 41U — Manti-Ephraim Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18763`

**Runway:** Manti-Ephraim 41U ~5021ft paved at 5516ft MSL. **Finding:** High-elevation paved airport with self-service fuel still requires loaded-aircraft hot/high climb, landing and terrain/weather checks and legal commercial access. **Next action:** Hold for aircraft type climb/landing calculations, directional LDA, runway load, NOTAM and owner-approved air service.

Evidence: [Source 1](https://aeronav.faa.gov/d-tpp/2512/10960r3.pdf)

### 42M — Thayer Memorial Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18767`

**Runway:** Thayer Memorial 42M 4200x50ft, 1.1% slope. **Finding:** Historical FAA chart supplement reported 50ft paved width, runway slope, nonstandard lights, trees/wildlife and runway safety-area deficiencies. Current dated status and aircraft compatibility have not been confirmed. **Next action:** Hold for 2026 FAA NOTAM, live runway markings/lights, usable LDA, slope and obstacle clearance, pavement bearing and owner-approved operator.

Evidence: [Source 1](https://aeronav.faa.gov/afd/22JAN2026/NC_278_22JAN2026.pdf)

### 48I — Braxton County Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18792`

**Runway:** Braxton County 48I 3995ft paved (near minimum). **Finding:** Nominal ~1218m physical length is only ~18m above the game's 1200m rule. Appalachian terrain, runway declared landing distances and commercial handling are not verified. **Next action:** Hold for FAA usable LDA, aircraft climb/terrain, snow/weather, runway load, FBO and paid charter/cargo permission.

Evidence: [Source 1](https://www.airnav.com/airport/48I)

### 4F2 — Panola County Sharpe Field
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18813`

**Runway:** Panola County 4F2 4000ft asphalt POOR. **Finding:** FAA-derived 2026 assessment categorizes main paved surface as POOR, with no established Jet A, aircraft loading or commercial runway acceptance. The pavement issue affects primary runway, not only a short secondary. **Next action:** Keep held until manager engineering/weight inspection, NOTAM, runway landing length, aviation fuel and licensed operator confirmed.

Evidence: [Source 1](https://www.airnav.com/airport/4F2)

### 4R3 — Jackson Municipal Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18844`

**Runway:** Jackson Municipal 4R3 source conflict: FAA 5003x80ft versus old city 4497x100ft. **Finding:** Disagreement between more recent FAA-derived profile and old municipal airport dimensions must be resolved before type-specific classification. Prior source also records S-25 and avgas without confirmed Jet A. **Next action:** Hold for signed 2026 as-built/FAA dimension, directional LDA, wheel load, turbine service and county/city permitted certified flights.

Evidence: [Source 1](https://www.airnav.com/airport/4R3)

### 4U6 — Circle Town County Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18855`

**Runway:** Circle Town County 4U6 ~4100ft asphalt POOR. **Finding:** FAA-derived source reports poor pavement condition and unconfirmed winter runway maintenance. Nominal asphalt runway length does not satisfy strength and dispatch reliability requirements. **Next action:** Hold pending airport pavement survey/NOTAM, winter snow clearing, LDA/load, fuel/handling and licensed commercial agreement.

Evidence: [Source 1](https://www.airnav.com/airport/4U6)

### 4V1 — Spanish Peaks Airfield
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18858`

**Runway:** Spanish Peaks 4V1 CO ~4715ft paved mountain field. **Finding:** FAA charts list RNAV approaches to RW09 and RW27 but neither procedure availability nor runway length guarantees aircraft-specific density-altitude or terrain climb clearance; carrier rights unproven. **Next action:** Hold for FAA declared LDA and loading, mountain/hot-day climb, actual NOTAM, airport fuel/ground support and permitted air operator.

Evidence: [Source 1](https://www.faa.gov/air_traffic/flight_info/aeronav/procedures/application/index.cfm?event=procedure.results&nasrId=4V1&tab=charts)

### 50I — Kentland Municipal Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18866`

**Runway:** Kentland Municipal 50I IN 4004x60ft paved. **Finding:** Indiana 2022 state report lists training/agricultural GA role, fuel and maintenance, but an old zero-enplanement forecast cannot verify 2026 operator status. Near-minimum runway length and 60ft width constrain aircraft. **Next action:** Hold for current landing LDA and load, actual aircraft width, FBO and city-approved licensed air carrier.

Evidence: [Source 1](https://kentland.in.gov/wp-content/uploads/2022/09/50I_Kentland-Municipal.pdf)

### 54T — RWJ Airpark
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18879`

**Runway:** RWJ Airpark 54T TX ~5035x40ft asphalt; distinct from Baytown HPY. **Finding:** Airport-specific 2026 source identifies exceptionally narrow 40ft pavement, owner permission needs and staffed daytime hours. Baytown HPY traffic and authorizations must not be transferred to 54T. **Next action:** Hold for 40ft aircraft and runway bearing fit, directional LDA, Houston approach procedures, airport owner paid-flight consent and certificated operator.

Evidence: [Source 1](https://www.airnav.com/airport/54T)

### 56D — Wyandot County Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18885`

**Runway:** Wyandot County 56D OH ~3997ft-class paved strip. **Finding:** FAA-derived runway physical screening is only just over 1200m; possible threshold displacement and aircraft loading can remove the usable-distance margin. No proven operating carrier or on-call services. **Next action:** Hold for authoritative RW direction LDA, exact pavement dimensions/loads, NOTAM and owner-approved paid route services.

Evidence: [Source 1](https://www.airnav.com/airport/56D)

### 5B2 — Saratoga County Airport
**Advanced only to further eligibility** · `ADMINISTRATIVE_NOT_PHYSICAL_CLOSURE` · `OURAIRPORTS:18894`

**Runway:** Saratoga County 5B2 NY public paved ~4700ft; customs landing by arrangement. **Finding:** Prior FAA-derived airport profile distinguishes CBP landing rights by appointment from a physical runway closure. The appointment requirement applies to specific cross-border flights, not all domestic runway use. No international or airline authorization follows from the advance. **Next action:** Advance only the customs-versus-runway issue; obtain dated CBP appointment for international routes, runway LDA/load and NOTAM, FBO, owner commercial consent and operating certificate.

Evidence: [Source 1](https://www.airnav.com/airport/5B2)

### 5R1 — Roy Wilcox Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18920`

**Runway:** Roy Wilcox 5R1 AL 4002x80ft asphalt S-15; RW12 displaced 200ft. **Finding:** October FAA-derived record lists ~15000lb single-wheel load, displaced threshold, trees/deer and absent fuel. Nominal 4002ft runway is insufficient to infer RW12 usable landing distance meets 1200m. **Next action:** Hold for official RW12/RW30 LDA and actual load, approach obstacles, fuel/ground crew, NOTAM and legal commercial operator.

Evidence: [Source 1](https://www.airnav.com/airport/5R1)

### 5T9 — Maverick County Memorial International Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18930`

**Runway:** Maverick County Memorial International 5T9 TX 5506x100ft asphalt POOR. **Finding:** October 2026 FAA-derived listing reports extensive runway 13/31 cracking and faded markings, plus brush near RW13 approach. ADCUS/customs services and Jet A availability are not proof of safe runway pavement for chosen airplane or certificated air carrier. **Next action:** Retain hold until manager engineering pavement/weight inspection, current markings/NOTAM and LDA, airport/CBP permissions and certified carrier.

Evidence: [Source 1](https://www.airnav.com/airport/5T9)

### 5V5 — Shiprock Airstrip
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18934`

**Runway:** Shiprock Airstrip 5V5 Navajo Nation NM ~5214ft paved at ~5272ft elevation. **Finding:** Public use at Navajo Nation airport does not imply tribal commercial operating consent. High elevation and terrain create type-specific departure/climb limits; local handling unverified. **Next action:** Hold for tribal authority written paid-flight permission, runway load/usable LDA, mountain/hot-day aircraft performance, fuel/emergency handling and licensed operator.

Evidence: [Source 1](https://maps.avnwx.com/airport/5V5)

### 60J — Odell Williamson Municipal Airport
**Operational hold** · `RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK` · `OURAIRPORTS:18942`

**Runway:** Odell Williamson Municipal 60J NC ~4198ft paved near Atlantic coast. **Finding:** Municipal GA field has coastal wind and weather, a relatively short paved runway and no confirmed charter/cargo certificate or scheduled passenger rights; airport identity alone provides no type-specific suitability. **Next action:** Hold for owner charter terms, FAA LDA/loading and NOTAM, selected airplane in coastal winds and available Jet A/FBO and carrier credentials.

Evidence: [Source 1](https://www.airnav.com/airport/60J)

### 65S — Boundary County Airport
**Operational hold** · `FUEL_OR_FBO_HANDLING_RECHECK` · `OURAIRPORTS:18960`

**Runway:** Boundary County 65S ID 02/20 4002x75ft asphalt at 2337ft MSL. **Finding:** Northern Air's recently updated site confirms Jet A/100LL, active FBO maintenance and charter marketing. These services are positive evidence, but the near-minimum runway in a mountain valley still lacks verified directional LDA, winter NOTAM and aircraft-specific legal charter/airport permission. **Next action:** Keep hold for actual LDA and runway loading, winter terrain/weather performance, confirmed FBO response and county owner-approved certificated operator.

Evidence: [Source 1](https://northernairaviation.com/) · [Source 2](https://northernairaviation.com/)


## Read-back controls

**20 unique records, 2 next-gate selection changes, 18 retained holds; zero missing issue text, evidence or follow-up actions; all 20 game_admission_status = NOT_APPROVED.** Original 3,140 airport cohort and 1,929 candidate selection records unchanged.

**Next: Batch 14** — continue resolving the 444 current unreviewed holds; keep the 274 reviewed-but-held cases blocked until their own remaining evidence gates pass.
