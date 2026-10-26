# Airlinerra — German expansion, independent runway evidence Batch 08

**26 October 2026 · Central private Supabase `hwllkabgzaynalahvkpz` / `airlinerra` · GitHub `main`**

## Verified result

Eight still-held German expansion airport candidates underwent another source-backed technical evidence review. **Two**—**EDLD Dinslaken/Schwarze Heide** and **ETHM/EDRE Mendig**—have sufficient multi-source evidence to mark the **paved physical runway research screen verified**; their actual civil airline operating rights, effective AIP declared distances and game admission are **not approved**. **Six** remain on generic independent runway-source hold: **EDAK, EDBN, EDCP, EDMO, EDTF, EDXF**.

| Measure | After Batch 08 |
|---|---:|
| Airport source/reconciliation cases documented | **8** |
| Advanced using current operator/on-field plus multiple independent runway sources | **2** |
| Still general-source-held in this batch | **6** |
| German general source verification queue | **6**, was 8 |
| Global expansion generic source verification queue | **1,789**, was 1,791 |
| German evidence advances through Batches 01–08 (physical-only, **not game approval**) | **36** |
| Original World 1 airports active and original home-airport picker records | **3,140 / 3,140** |
| New expansion game airport activations / World 2–3 activations | **0 / 0** |

## The eight source decisions

| Airport | Sources and checked facts | Saved research decision |
|---|---|---|
| **EDLD — Dinslaken/Schwarze Heide** | [Airport operator](https://schwarze-heide.com/) confirms operational **1,500m** runway; [resident certified flight school](https://jp-flugschule.de/standorte/) explicitly states asphalt **RW08/26 1,500 × 30m**; [on-field air club](https://gfl-dinslaken.de/angebote/ausbildung) confirms **1.5km asphalt**; [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=764) independently agrees. **TPM-Media** and original research master say **concrete**, contradicting the detailed asphalt subtype. | **Advance physical paved-runway research only**, using a separate `INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING` status, not a current-AIP-certification status. Asphalt **and** concrete are permissible under the minimum screening rule; do not silently overwrite the disputed subtype. Obtain effective AIP for exact pavement/declared distances before aircraft scheduling. |
| **ETHM / EDRE — Mendig** | [Resident PPR/landing organization](https://sfgmendig.jimdoweb.com/infos-f%C3%BCr-piloten/) documents current ICAO **EDRE**, asphalt **RW07/25 1,615 × 35m** with separate 690m grass runway. [Municipality Mendig](https://www.mendig.de/wirtschaft-gewerbe/gewerbe-und-industrie/flugplatz-mendig/) confirms civilian conversion of the former military airfield; [DULV](https://www.dulv.de/fmwebphp/Flugplatz/details.php?id=1319) corroborates the 1,615 × 35m paved geometry. [Resident aircraft manufacturer](https://www.roland-aircraft.com/index.php/info-fuer-piloten) instead uses 1,628 × 36m. Research registry already uses `source_ident=ETHM` and `source_gps_code=EDRE`. | **Advance physical paved-runway research only** under the same special *multi-source* status. Preserve **original `OURAIRPORTS:2726`** and historical code ETHM, without duplicating as an EDRE airport. Separate precise 1,615/1,628m measurement and identity alias reconciliation still required. Strict **written PPR**, no fuel/customs, and specific aircraft limitations are not airline permissions. |
| **EDAK — Großenhain** | [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=840) and [technical directory](https://tpm-mediashop.com/pages/edak-grossenhain) both identify concrete **11/29 1,415 × 48m**; secondary only. | **Hold** until effective 2026 DFS AIP or direct airport-operator technical declaration. |
| **EDBN — Neubrandenburg/Trollenhagen** | [Airport-hosted official 2018 AIP](https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf) identifies concrete **09/27 2,293 × 45m**, historic LDA 2,293m both ends; [independent directory](https://www.pilotcenter.app/flugplaetze/edbn) agrees. | **Hold** pending current effective AIP to rule out changes since 2018; historical official data is valid provenance but not newly current. |
| **EDCP — Peenemünde** | [IVAO source](https://de.ivao.aero/prozeduren/edww/e/edcp/) says concrete **13/31 2,400 × 48m**, [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071) gives **2,400 × 60m**; another [community listing](https://www.ulforum.de/ultraleicht/flugplatz/peenemuende/EDCP) uses **14/32 bitumen**, adding a direction/surface conflict. | **Hold** current original airport or DFS AIP dimensions and identification; do not guess width, surface or runway direction. |
| **EDMO — Oberpfaffenhofen** | [Resident DLR flying organization](https://www.fsg-im-dlr.de/node/49) and [independent aviation system](https://server.learn-atc.com/de/tools/aerodrome/EDMO) give asphalt **04/22 2,286 × 45m**. [Current airport operator](https://www.edmo-airport.de/flugbetrieb/) provides special-use/PPR procedures without matching operator-owned runway specifications on inspected page. | **Hold** pending original operator or effective AIP runway evidence; do not conflate special-use airport status with physical runway closure. |
| **EDTF — Freiburg** | [Current airport operator](https://freiburg-airport.de/) reports **RW16 LDA 1,190m and RW34 LDA 1,040m**, both short for **direction-specific** 1,200m screen. Older [on-field club](https://bvm-freiburg.de/flugplatzdaten/) lists 1,400m asphalt, [2023 IVAO](https://de.ivao.aero/prozeduren/edgg/s/edtf/) lists 1,240m, existing master lists 1,338.1m. | **Hold** pending current authoritative physical length. Published LDAs are **not** interchangeable with gross paved runway length. |
| **EDXF — Flensburg/Schäferhaus** | [Official airport-operator 2022 infrastructure report](https://www.flensburger-flughafen.de/images/pdf/Entwicklungen-und-Perspektiven-2022.pdf) confirms bitumen but describes **1,580m INCLUDING overruns**. [Airport-hosted 2019 VFR chart](https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf) records RW11/29 **1,220 × 30m** bitumen and RW11/RW29 historic LDA **1,220/1,040m**, independently corroborated by [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=805). | **Hold**: runway-only gross 1,220m is just 20m above threshold, and an older source cannot establish current precise qualifying length. The airport's **1,580m total cannot be substituted for runway pavement without overruns**. Effective 2026 AIP confirmation required. |

## Supabase implementation

- Added eight source-linked cases in private RLS table `airport_expansion_de_multisource_adjudications`, explicitly distinguishing `runways_only_screen_boolean=true` for **two** and **NULL/unknown** for six.
- Advanced only **EDLD** and **ETHM** to `INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`, with identity and paved-runway evidence `VERIFIED`. This is intentionally different from a claim of current **operator/AIP** approval.
- The other six remain `HOLD_INDEPENDENT_VERIFICATION` with `paved_runway_status=UNVERIFIED`.
- All eight are `NOT_APPROVED` for gameplay and real commercial permission; the new table's constraints forbid game activation or falsified approval.
- Neither master runway registry, historical airport keys, 3,140 founding World 1 game airports nor six class proposals were changed.
- New research table has RLS enabled and **no anonymous or ordinary authenticated-user SELECT access**.

## Reproducibility and validation

- [Batch08 private source registry and two safeguarded research advances](./sql/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.sql)
- [Batch08 Supabase acceptance test — executed PASS](./sql/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_TESTS_2026-10-26.sql)

The accepted database test checked **8 source cases, 2 advanced, 6 held, exact EDLD and ETHM source dimensions, unresolved historic Flensburg/Freiburg measurements, zero game permission/activation flags, global source backlog 1,789 and preserved 3,140 World 1 airports**.

## Next work

Obtain effective 2026 DFS AIP or dated airport-operator technical runway evidence for the **six remaining German general-source holds**, starting with EDXF and EDTF because their reported runway lengths are near the 1,200m cutoff. Keep specialized short/usable-distance exceptions **EDMB** (980m operator runway), **EDXJ** (1,140m civil LDA on 1,450m gross runway), and prior direction-specific limits distinct from the six generic source holds. Begin further independent expansion reviews outside Germany in separate country batches; no new game airports require activation until the owner separately requests a controlled release.

**Result: 8 re-reviewed, 2 advanced on runway-only multi-source evidence, 6 on source hold, 0 game airports activated.**
