# Airlinerra — German Expansion Airport Runway Verification, Batch 06

**26 October 2026** · Central private Supabase `hwllkabgzaynalahvkpz`, schema `airlinerra`. GitHub `bracko87/Airlinerra` `main`.

## Verified outcome

Reviewed **eight German expansion airport records** (four freshly reached from the pending queue: **EDWI, EDXF, EDXJ, ETHM**, and four earlier research holds rechecked: **EDAK, EDBN, EDCP, EDMO**). Exactly **one**, JadeWeser Airport **EDWI**, advanced on operator-authenticated paved runway and published landing-distance evidence. **Husum-Schwesing EDXJ** moved into an explicit, private `HOLD_CIVIL_RUNWAY_USABLE_DISTANCE_1140M` case; **six** are still in the general source-verification hold.

| Measure | Verified value |
|---|---:|
| Batch 06 source reviews and reconciling re-reviews | **8** |
| Newly advanced on current operator paved runway verification | **1 (EDWI)** |
| New specialist civil-usable runway hold | **1 (EDXJ)** |
| Still on generic independent-source verification hold | **6** |
| Additional runway-direction source exception records | **2 (EDXJ, EDXF)** |
| German generic verification holds after this batch | **10**, previously 12 |
| Worldwide expansion generic verification holds | **1,793**, previously 1,795 |
| Active original World 1 airports | **3,140** |
| World 1 original home-airport picker entries | **3,140** |
| Expansion airports activated | **0** |
| World 2 / 3 activations | **0** |

### Detailed airport findings

| Airport | Paved runway and usable distance evidence | Review outcome and source |
| --- | --- | --- |
| **EDWI JadeWeser Airport (Wilhelmshaven)** | Current operator **RW02/20 asphalt 1,459 × 30m**; published **RW02 TORA 1,267m / LDA 1,233m**; **RW20 TORA 1,293m / LDA 1,207m** | **Advance runway evidence only.** [Current operator's technical table](https://www.edwi.info/piloten.html) confirms both LDA directions at least 1,200m (RW20 only +7m). Its separate 615m asphalt 16/34 is below the game's runway length rule. Aircraft mass, PPR/IFR, operator and flight-date restrictions are not verified game approvals. |
| **EDXF Flensburg-Schäferhaus** | Operator-hosted **2019** VFR airfield chart shows bitumen **RW11/29 1,220 × 30m**, with historic **RW11 LDA 1,220m** and **RW29 LDA 1,040m**. An operator report distinguishes 300m west/60m east runway overruns. | **Remain held: chart must be validated against current AIP.** [Original operator-hosted VFR chart](https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf), [independent 2021 chart transcription](https://de.ivao.aero/prozeduren/edww/w/edxf/). Do not treat overruns as landing pavement, or assert historic RW29 passes direction-specific 1,200m requirement. |
| **EDXJ Husum-Schwesing** | Operator confirms paved **RW03/21 1,450 × 30m gross**, BUT **only 1,140m between thresholds**, **TORA/LDA 1,140m in both directions**. The airport explicitly warns that the former NATO runway's northeast portion is not available for civil use. | **Move to specialist restriction hold, not approval or final rejection.** [Current airport operator's runway specification](https://www.flughafen-husum.de/de/flughafen/daten/startbahn.php) describes the closed/cross-marked segment and fence. Physical gross-runway eligibility requires adjudication independently from civil usable-distance requirement. Both present published landing directions fail 1,200m. |
| **ETHM / EDRE Mendig** | Historical research `source_ident=ETHM`, `source_gps_code=EDRE`. Resident airfield flying club now reports asphalt **RW07/25 1,615 × 35m**; older source research registry **1,628.2m** and another resident company suggests **1,628 × 36m**. | **Remain held on current authoritative operator/AIP dimensions and identifier provenance.** [Resident flying club's operating and PPR rules](https://sfgmendig.jimdoweb.com/infos-f%C3%BCr-piloten/) list maximum 5.7t, **no available fuel**, **no customs**, and written PPR, while [resident manufacturer](https://www.roland-aircraft.com/index.php/info-fuer-piloten) lists different dimensions. Neither commercial-airline suitability nor safe identifier correction is implied. |
| **EDAK Großenhain** | Secondary sources agree on **RW11/29 concrete 1,415 × 48m**, plus 950m grass. No current declared landing lengths. | **Remain held.** [DULV airfield directory](https://dulv.de/fmwebphp/Flugplatz/details.php?id=840) and [second technical guide](https://tpm-mediashop.com/pages/edak-grossenhain) explicitly disclaim current authoritative AIP status. Primary operator/effective AIP required before runway evidence is marked verified. |
| **EDBN Neubrandenburg-Trollenhagen** | Genuine operator-hosted **2018 effective German AIP AD 2**: concrete **RW09/27 2,293 × 45m**, PCN75; **historic TORA/TODA/ASDA/LDA 2,293m each end**. | **Remain held for current AIP revalidation**, not because physical evidence absent. [Airport operator-hosted German AIP](https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf) includes the official 2018 runway chart. [Current operator contact page](https://www.flughafen-neubrandenburg.de/index.php?Itemid=299&id=58&option=com_content&view=article) shows aviation operations but does not certify that eight-year-old runway data remains unchanged. |
| **EDCP Peenemünde** | [Historic IVAO procedure](https://de.ivao.aero/prozeduren/edww/e/edcp/) shows concrete **RW13/31 2,400 × 48m**, whereas [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071) says **2,400 × 60m**. | **Remain held**; exact runway width and live runway status still lack current operator/AIP authority. Source conflict must not be silently resolved to either width. |
| **EDMO Oberpfaffenhofen** | On-field DLR flying group describes asphalt **RW04/22 2,286 × 45m**, but current inspected airport operator page confirms special-airport conditions/PPR without supplying the matching geometry. | **Remain held.** [Resident flying group](https://www.fsg-im-dlr.de/node/49); [airport operator operational restrictions](https://www.edmo-airport.de/flugbetrieb/). No unrestricted public-airline access or runway certification inferred. |

### Two distinct thresholds — important design protection

The currently agreed **airport-collection technical rule** is at least one operational **asphalt or concrete runway with physical gross length ≥1,200m**. A given runway-end's *published usable landing distance* may be shorter owing to displaced thresholds, unusable portions, or airport restrictions. Do not incorrectly replace physical runway size with LDA, or incorrectly replace a deficient LDA with the full physical length.

- **EDWI** meets the physical threshold and *both* published direction-specific 1,200m landing-distance screens; it is not thereby certified for any particular model or commercial service.
- **EDXF** has historic 1,220m paved gross runway; the 2019 RW29 LDA of **1,040m** is held for current source confirmation and was **not falsely certified**.
- **EDXJ** has 1,450m gross pavement but its airport operator says only **1,140m** available to civil takeoff and landing operations due to permanent physical access limitation. Whether this still counts as an operational ≥1,200m runway for the game's airport-only technical rule needs explicit technical adjudication rather than automatic rejection or inclusion.

### Persisted Supabase changes

1. Added **8** independently cited research source rows in the private `airport_expansion_independent_paved_runway_reviews` table, with their distinct original provenance grades. Previously held records were re-reviewed rather than duplicated under new airport identities or promoted without stronger source data.
2. Created private RLS-protected `airport_expansion_german_civil_runway_end_holds` with **2** runway-end technical exception records (EDXJ current operator and EDXF historical operator-hosted chart). Both hard-enforce `NOT_APPROVED` and `game_world_activated=false`.
3. Advanced **only EDWI** to `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`. Moved **only EDXJ** to `HOLD_CIVIL_RUNWAY_USABLE_DISTANCE_1140M`, preserving `paved_runway_status=UNVERIFIED`.
4. Kept **EDAK, EDBN, EDCP, EDMO, EDXF and ETHM** on `HOLD_INDEPENDENT_VERIFICATION`, explicitly retaining old AIP/secondary evidence status. No first-wave game profiles, master source identifiers, source runway lengths or operational-commercial permission values were overwritten.
5. Verified first 3,140 playable simulation airports and first-world registration catalog remain unchanged, **zero** expanded airport activations or world2/3 activations, and the exception research table denies anonymous and ordinary authenticated SELECT access.

### Reproducibility and acceptance

- [Batch06 research source replay, exception schema/rows, and guarded source status updates](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_06_2026-10-26.sql)
- [Database acceptance assertions — executed PASS](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_06_TESTS_2026-10-26.sql)

The live Supabase `DO` acceptance test verified **8 records, 2 detailed exceptions, one promotion and six generic holds**, plus specific EDWI, EDXF and EDXJ direction-distance figures, no game approval, unchanged original 3,140 airports and 10 remaining German generic source holds.

### Next priority

The **10 German generic source holds** now comprise **EDAK, EDBN, EDCP, EDFE, EDLD, EDMO, EDTD, EDTF, EDXF and ETHM**. Also keep **EDMB** and the new **EDXJ** visible in dedicated technical exception queues; generic-hold count does **not** count these specialized cases.

Next, use effective current German AIP or up-to-date original airport-operator declarations to adjudicate the source conflicts. Maintain the original 3,140-game-airport first wave while further 3,906 expansion candidates are researched independently.

**Batch 06 completed: 8 reviewed/rechecked, 1 operator-evidence advance, 1 explicit civil-use hold, 6 retained on generic hold, zero airports activated.**
