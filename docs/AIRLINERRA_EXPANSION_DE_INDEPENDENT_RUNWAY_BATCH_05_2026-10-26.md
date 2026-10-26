# Airlinerra — German Expansion Runway Review, Batch 05

**26 October 2026 | Supabase project `hwllkabgzaynalahvkpz`, private schema `airlinerra` | GitHub `main`**

## Executed outcome

Eight distinct airports from the 3,906-airport expansion pool underwent current source review. **Six** moved from general independent verification hold to **operator-verified paved-runway research, awaiting any later game-release approval**. Two cases now have explicitly recorded exceptional source/runway landing-distance data and remain held.

| Measure | Verified result |
|---|---:|
| German Batch 05 airports source-reviewed | **8** |
| Operator-confirmed paved-runway cases advanced | **6** |
| Source discrepancy / direction landing-distance exceptions held | **2 (EDTD, EDTF)** |
| German generic independent-source holds after batch | **12**, down from 18 |
| Worldwide expansion generic independent-source holds | **1,795**, down from 1,801 |
| Founding World 1 airports active | **3,140** |
| World 1 original home-airport registration catalog | **3,140** |
| Newly activated expansion airports | **0** |
| Activations in World 2 or World 3 | **0** |

**Runway-only airport collection** and **direction-/aircraft-specific operations** are different questions. A paved runway physically at least 1,200m can qualify for the research collection even when its actual published landing distance is shorter, but no individual runway direction should be treated as passing a direction-specific distance screen in that case. Commercial permissions and game admissions were not granted by this batch.

## All eight records and authoritative evidence

| Airport | Reported paved runway | Decision and source limitations |
|---|---|---|
| **EDSN Neuhausen ob Eck** | **09/27, asphalt 1,248 × 30m** | **Advanced.** [Operator's pilot page, updated Oct 15, 2026](https://www.take-off-park.de/flugplatz/fluginfos/) confirms official 09/27 designation and dimensions. Special landing site, routine 5.7t and PPR up to 14t. The 60m end strips are described for takeoff, not published landing distances; RW27 shifted touchdown point applies to aircraft below 2t. An older independent directory instead says 10/28; use current operator designation. |
| **EDTD Donaueschingen-Villingen** | Operator lists **18/36, asphalt 1,200 × 30m**, versus registry **1,289.9m** | **Specific source hold.** [Operator's pilot page](https://donau-airport.de/piloteninformationen/) simultaneously reports **RW18 LDG 1,290m / TORA 1,200m**, **RW36 LDG 1,200m / TORA 1,290m**. Declared figures exceed its stated physical length in one direction. This contradiction requires effective German AIP or corrected owner statement before source approval. PPR for aircraft beyond 5.7t. |
| **EDTF Freiburg** | Recorded historic paved runway approximately **1,338 × 30m asphalt**; conflicting older sources cite ~1,240–1,400m | **Specific landing-distance/source hold.** [Current Freiburg Airport operator](https://freiburg-airport.de/) lists **RW16 LDA 1,190m; RW34 LDA 1,040m**, both below a 1,200m **directional landing screen**. Its inspected front page does not establish current gross pavement dimensions; [an older technical guide](https://de.ivao.aero/prozeduren/edgg/s/edtf/) and registry give different values. Do not automatically reject the potentially qualifying airport *physical* collection merely because its published LDA is shorter. [Operator flight restrictions](https://freiburg-airport.de/infosfuerpiloten/) include runway closure around SC Freiburg home matches. |
| **EDTG Bremgarten (Gewerbepark Breisgau)** | **05/23, asphalt 1,650 × 45m** | **Advanced.** [Operator technical page](https://www.gewerbepark-breisgau.de/unser-flugplatz/kontakt-adesse-lage/) confirms surface, dimensions, runway designation and a separate nonqualifying 600m grass runway. Business/sport special-use aircraft up to 20t. Per-end published LDA not obtained; owner operating-hour and aircraft permissions remain unverified. |
| **EDTM Mengen-Hohentengen** | **07/25, asphalt 1,566 × 30m** | **Advanced.** [Current airport operator](https://www.regio-airport-mengen.de/piloteninfo/flugplatzdaten/) reports physical runway; grass 700m is not qualifying. Aircraft >5.7t up to 14t PPR, seasonal hours and stringent Sunday/holiday training-circuit restrictions. No per-end LDA independently obtained. |
| **EDTY Schwäbisch Hall / Adolf Würth Airport** | **10/28, concrete 1,540 × 30m**, **RW10 LDA 1,365m; RW28 LDA 1,413m** | **Advanced.** [Current operator runway and declared distances](https://www.edty.de/de/airport/pilot_information/approach_information/approach_information.php). RW10 published TODA **1,600m** exceeds gross pavement but is *not* a 1,600m landing runway. The operator publishes aircraft-category limits, IFR operations and seasonal hours. |
| **EDVE Braunschweig-Wolfsburg** | **08/26, asphalt 2,300 × 45m** | **Advanced.** [Operator aviation data](https://www.fhbwe.de/aviation) lists PCN 52, IFR/VFR, a separate 900m grass area, winter/weekend time limitations, deicing and available fuels. RFFS Cat 6, Cat 8 with prior notice; this does not establish contracted airline handling or any certified per-end LDA. |
| **EDVM Hildesheim** | **07/25, asphalt 1,220 × 23m** | **Advanced for physical runway only.** [Current airport operator](https://www.flugplatz-hildesheim.de/index.php?iCID=1) also lists a separate grass 07/25 1,220 × 30m and a nearby **TORA/LDA 1,160m** entry that appears on the *grass* line. Do **not** assign 1,160m to the asphalt direction without AIP verification. Asphalt gross length has only 20m margin over the minimum; 5.7t aircraft limit and PPR remain applicable. |

## Database implementation

1. Eight Batch05 `airport_expansion_independent_paved_runway_reviews` rows inserted with separate physical length, runway designation, surface, width, available *published landing distances*, source links and audit notes. No master airport length or original cohorts overwritten.
2. A private `airport_expansion_operator_runway_source_issues` table was created with RLS and no direct anonymous or authenticated-user privileges. It preserves two *different* anomalies: **EDTD** source-published physical length versus LDA inconsistency, and **EDTF** below-1,200m landing distances combined with its unresolved exact physical source length.
3. Only **EDSN, EDTG, EDTM, EDTY, EDVE and EDVM** advanced to `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`. **EDTD and EDTF** retain `HOLD_INDEPENDENT_VERIFICATION`. No gameplay admissions, commercial licenses or world activation rows changed.
4. Both exception records explicitly retain `NOT_APPROVED` and `simulation_world_active=false`. The existing 3,140 active World 1 airports and 3,140 registration airport options remain available.

## Reproduction and tests

- [Batch05 source records, new private exception table, guarded six-airport research-status updates](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_05_2026-10-26.sql)
- [Acceptance tests — executed `PASS` in live Supabase](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_05_TESTS_2026-10-26.sql)

The tests confirm eight batch records, six advanced operator cases, exactly two unchanged central holds, both directional-source discrepancies, the distinct landing figures at EDTY, 1,795 worldwide generic holds, 12 German generic holds, **zero** expansion activations and preservation of the 3,140 founding game airport records.

## Next step

Review the remaining **12 German airports in the general source queue**, including previously logged **EDAK, EDBN, EDCP, EDFE, EDLD and EDMO**, without conflating temporary site permissions or airplane performance with the physical 1,200m runway-only collection criterion. Keep the already separated **EDMB, EDTD and EDTF** technical exceptions visible. Conduct any later simulation-game expansion release only under a new, explicit owner decision; do not affect the first 3,140 playable World 1 airport records.

**Batch 05 finished: eight reviewed; six advanced; two remain held; no new game airports activated.**
