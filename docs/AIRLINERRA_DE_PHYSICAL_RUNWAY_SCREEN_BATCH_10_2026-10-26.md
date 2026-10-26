# Airlinerra — German expansion physical-runway screen, Batch 10

**Completed 26 October 2026.** Central Supabase research project `hwllkabgzaynalahvkpz`, private `airlinerra` schema, archived to `bracko87/Airlinerra` GitHub `main`.

## Outcome and precise scope

The **last three airports on Germany's general independent runway-source hold**—Großenhain, Freiburg and Flensburg—were adjudicated for the **basic physically paved runway collection screen**, using independently corroborating documents. All three now have a lower-confidence **`INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`** status. **None has an authenticated effective 2026 AIP declaration, commercial air-carrier approval or game airport admission.** They remain unsuitable for unrestricted aircraft scheduling until their outstanding runway-direction and operational constraints are checked.

| Metric | Verified after Batch 10 |
|---|---:|
| Existing German expansion airports reviewed in Batch 10 | **3** |
| Basic physical paved runway evidence advanced (multi-source, NOT current AIP) | **3** |
| German generic `HOLD_INDEPENDENT_VERIFICATION` queue | **0** |
| German operator-evidence advanced | **34** |
| German multi-source-evidence advanced | **7** |
| German specialist holds still open | **3** |
| Total German expansion airports accounted for | **44 = 34 + 7 + 3** |
| Global expansion generic `HOLD_INDEPENDENT_VERIFICATION` queue | **1,783** |
| Founding World 1 airport activations / registration airport options | **3,140 / 3,140** |
| New expansion world activations / World 2 or 3 activations | **0 / 0** |

This finishes the **generic German runway-source triage**, not all work for Germany. The **three specialist holds** are EDMB (Biberach: operator-runway 980m against stale >1,200m registry), EDXJ (Husum: 1,450m gross asphalt but only 1,140m usable civil LDA) and EDCP (Peenemünde: time-bounded NOTAM aerodrome closure, plus source-width discrepancy and separate ongoing restricted airspace). The statuses are separate by design, to avoid conflating permanent runway disqualification with temporary or direction-specific operating restrictions.

## Evidence and exclusions

| Airport | Physical runway collection observation | Still unresolved — do not permit aircraft operations on that basis |
|---|---|---|
| **EDAK — Großenhain** | [2026 independent aviation publisher](https://tpm-mediashop.com/pages/edak-grossenhain) and [DULV aerodrome directory](https://dulv.de/fmwebphp/Flugplatz/details.php?id=840) independently identify concrete RW11/29 **1,415 × 48m**, plus separate subthreshold 950m grass. | Both are **secondary**, not an original effective 2026 AIP/operator declaration. The longer former military pavement must not be substituted for the published civilian runway. Per-end declared LDA and actual commercial permission remain unverified. |
| **EDTF — Freiburg** | [IVAO Germany technical source](https://de.ivao.aero/prozeduren/edgg/s/edtf/) cites **1,240 × 30m** asphalt (AIRAC 2023); [historic resident club information](https://bvm-freiburg.de/flugplatzdaten/) cites **1,400 × 30m** asphalt; the research master has **1,338.1m**. All reported paved physical lengths exceed 1,200m, but they **disagree**. | [Current operator](https://freiburg-airport.de/) reports **RW16 LDA 1,190m** and **RW34 LDA 1,040m**, so **both directions are BELOW a 1,200m landing-distance screen**. Obtain authoritative 2026 physical length and effective LDA. The active operator also reports closures around SC Freiburg home matches. Basic airport collection passing does **not** authorize a landing. |
| **EDXF — Flensburg-Schäferhaus** | [Original airport-operator-hosted 2019 VFR aerodrome chart](https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf), [DULV directory](https://dulv.de/fmwebphp/Flugplatz/details.php?id=805) and newer third-party airport registries document **RW11/29 1,220 × 30m bitumen/asphalt**. The operator [2022 infrastructure report](https://www.flensburger-flughafen.de/images/pdf/Entwicklungen-und-Perspektiven-2022.pdf) cites **1,580m INCLUDING 300m + 60m overruns**; that is **not a 1,580m runway**. | The 2019 chart has **RW11 LDA 1,220m**, **RW29 LDA 1,040m**. A separate newer user-facing airport directory labels **1,040m** as runway without clarifying its type. Therefore, the physical 1,220m result has **just a 20m margin** and must be verified against current effective AIP. If actual operative paved runway is below 1,200m, reverse the multi-source basic screening conclusion. |

## Source grading and safeguarding

The dedicated, private and RLS-enabled `airlinerra.airport_expansion_de_batch10_multisource_runway_screen` table records source URLs, alternative measurements, historical registry geometry, direction-specific LDA where published, an explicit `latest_effective_aip_verified=false`, and detailed next source actions. The table hard-enforces **`game_admission_status='NOT_APPROVED'`**, `aircraft_specific_operating_permission=false` and `game_world_activation_authorized=false`. It is not readable by Supabase `anon` or ordinary `authenticated` roles.

Only the three original airport rows in `airport_access_reviews` were advanced for **physical paved runway evidence**, not commercial approval, not final six-category assignment and not playable-world activation. Historic master source runway values and original keys remain untouched.

`paved_runway_status='VERIFIED'` here means only the **specified source-level runway research screen** was met; the central row's distinct `review_status='INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'` and preserved source cautions must be used together. Do not interpret the single field in isolation as an AIP-certified runway.

## Reproducibility

- [Applied research table and three guarded evidence advancements](./sql/AIRLINERRA_DE_PHYSICAL_RUNWAY_SCREEN_BATCH_10_2026-10-26.sql)
- [Live Supabase acceptance test — PASS](./sql/AIRLINERRA_DE_PHYSICAL_RUNWAY_SCREEN_BATCH_10_TESTS_2026-10-26.sql)

The executed regression verifies all three records, explicit AIP/airline/game denials, physical length and LDA distinctions, 41 source-advanced plus 3 specialist-held German airports, a **zero** German generic queue, global generic expansion queue **1,783**, and the untouched **3,140 World 1 airports**.

## Next priorities

**Germany:** technical-exception adjudication of **EDMB, EDXJ and EDCP**; effective 2026 AIP/source validation of EDAK/EDTF/EDXF; and direction-specific LDA/aircraft class and operator-permission gates for the 41 research-advanced fields. EDCP's present NOTAM is scheduled for **recheck 1 November 2026**, not automatically cleared on that date. **International:** continue independent verification in the other countries within the 3,906-airport expansion pool, using small country batches. The original 3,140 first-wave World 1 airports remain available in the game-side catalog without waiting for expansion research.

**Batch 10: Germany's generic physical-runway research queue cleared; 3 source-level advances, 3 separate specialist holds, 0 new playable airports.**
