# Airlinerra — German Airport Expansion, Source Resolution Batch 07

**Executed 26 October 2026** · Private Supabase project `hwllkabgzaynalahvkpz`, schema `airlinerra` · GitHub `bracko87/Airlinerra`, branch `main`.

## What changed

All **10 German expansion airports** still on the general `HOLD_INDEPENDENT_VERIFICATION` queue at the start of this batch were reconciled into an explicit case-by-case private review ledger. **Two airport *physical paved-runway* source checks could be advanced**, specifically **EDFE** and **EDTD**. Each retains a separate **direction-specific published landing-distance exception** and is **not approved for game admission or real airline operations**. The remaining eight airport records retain their original `HOLD_INDEPENDENT_VERIFICATION` states with an exact evidence gap and next source action.

| Verified measure | After Batch 07 |
|---|---:|
| Source-discrepancy cases explicitly classified | **10** |
| Operator-supported paved runway checks advanced | **2: EDFE and EDTD** |
| Separate documented landing-direction exceptions | **2: EDFE and EDTD** |
| German generic independent-source holds | **8** (previously 10) |
| Worldwide expansion generic independent-source holds | **1,791** (previously 1,793) |
| German runway evidence advances across Batches 01–07 | **34** |
| Original airports active in World 1 | **3,140** |
| World 1 home-airport catalog entries | **3,140** |
| Newly activated expansion airports and additional worlds | **0** |
| New airport commercial authorizations/game admissions | **0** |

This is **runway-only airport collection**, not a live flight approval. The game's basic airport collection criterion is a physically operational asphalt/concrete runway **at least 1,200m long**. An aircraft-specific *usable landing distance* for a particular runway direction may be shorter. Never infer LDA from gross runway length.

## Case-by-case results

| Airport | Independently cited evidence | Status and next requirement |
|---|---|---|
| **EDFE — Frankfurt-Egelsbach** | [Airport operator's regulations effective 25 November 2025](https://egelsbach-airport.com/wp-content/uploads/2025/12/EDFE-Benutzungsordnung-25-11-2025-FinalohneUnterschrift-DE-v1-2.pdf), plus [airport-hosted DFS airfield chart dated 24 August 2023](https://egelsbach-airport.com/wp-content/uploads/2023/08/AIP-VFR-Flugplatzkarte.pdf) confirm **08/26 asphalt 1,400 × 25m**. The 2025 regulations' technical table is marked **as of 1 May 2014**; it gives **RW08 LDA 1,400m / TORA 1,166m** and **RW26 LDA 1,166m / TORA 1,400m**. | **Physical runway source VERIFIED, expansion game release still pending.** RW26 **fails the separate 1,200m landing-direction screen**. An explicit private runway-end hold records it. Retrieve 2026 effective AIP/NOTAM before aircraft route use; do not represent old embedded technical figures as newly measured in 2025. |
| **EDTD — Donaueschingen-Villingen** | [Current airport operator's technical page](https://donau-airport.de/piloteninformationen/) explicitly lists **18/36 asphalt 1,200 × 30m**, meeting runway-only threshold exactly, but lists **RW18 LDG 1,290m** and **RW36 LDG 1,200m**. Historical register 1,289.9m gross; older [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=766) reports 1,290m. | **Physical paved runway source VERIFIED at stated 1,200m, but landing declarations NOT reconciled.** The operator's landing distance exceeds its own physical runway figure, so a second separate runway-end hold remains. Obtain effective AIP or written correction before using declared LDA. |
| **EDAK — Großenhain** | [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=840) and [aviation technical directory](https://tpm-mediashop.com/pages/edak-grossenhain) concur on **11/29 concrete 1,415 × 48m**. | **Hold**: no direct current airport-operator or effective DFS AIP physical runway source; avoid claiming secondhand specifications are authoritative. |
| **EDBN — Neubrandenburg-Trollenhagen** | [Operator-hosted original German AIP PDF](https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf) documents **09/27 concrete 2,293 × 45m**, published historic LDA 2,293m both ends, **effective December 2018**. [Operator's current pilot instructions](https://www.flughafen-neubrandenburg.de/index.php?Itemid=104&catid=2&id=7%3Apiloteninformationen&option=com_content&view=article) direct pilots to effective AIP and NOTAM. | **Hold**: original historic AIP is valid provenance but is *not* proof of unchanged current runway data. Source the effective 2026 AIP AD2.12/2.13. |
| **EDCP — Peenemünde** | [IVAO aviation technical entry](https://de.ivao.aero/prozeduren/edww/e/edcp/) lists **13/31 concrete 2,400 × 48m**; [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071) instead lists **2,400 × 60m**. | **Hold**: current operator/AIP runway width and availability needed; conflicting physical widths remain recorded without arbitrary selection. |
| **EDLD — Dinslaken/Schwarze Heide** | [Resident flight school](https://jp-flugschule.de/standorte/) explicitly calls **08/26 asphalt 1,500 × 30m**, while [technical aviation directory](https://tpm-mediashop.com/pages/edld-dinslaken-schwarze-heide) and existing registry call it **concrete**; [airport operator](https://schwarze-heide.com/fuer-piloten/pilot-informationen/) confirms current landings and an extra RW26 touchdown procedure for aircraft under 2t, not a published LDA. | **Hold pending authoritative pavement subtype**. Both claimed materials would qualify the general runway-only rule, so this is *not* a known short-runway rejection. Do not silently overwrite asphalt/concrete disagreement. |
| **EDMO — Oberpfaffenhofen** | [Resident DLR flying group](https://www.fsg-im-dlr.de/node/49) lists **04/22 asphalt 2,286 × 45m**; [airport operator](https://www.edmo-airport.de/flugbetrieb/) publishes special-purpose PPR use but no matching technical dimensions in inspected page. | **Hold** for current operator/official aeronautical physical runway source. Special-use restrictions are separate from runway-only collection. |
| **EDTF — Freiburg** | [Current airport operator](https://freiburg-airport.de/) gives **RW16 LDA 1,190m / RW34 LDA 1,040m**. A dated [IVAO runway listing](https://de.ivao.aero/prozeduren/edgg/s/edtf/) cites **1,240m** asphalt while older [Freiburg flying club information](https://bvm-freiburg.de/flugplatzdaten/) cites **1,400m** and the research registry cites **1,338.1m**. | **Hold for exact current physical runway source**. Both *published landing directions* fail 1,200m; do not convert that into a fictitious physical-airport rejection. |
| **EDXF — Flensburg-Schäferhaus** | [Airport operator-hosted 2019 VFR chart](https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf) cites bitumen **11/29 1,220 × 30m**, historic **RW11 LDA 1,220m / RW29 LDA 1,040m**; [IVAO 2021 listing](https://de.ivao.aero/prozeduren/edww/w/edxf/) corroborates. | **Hold pending effective 2026 AIP confirmation**. Physical runway only 20m above threshold, and historic RW29 usable landing length below 1,200m. |
| **ETHM / EDRE — Mendig** | [Resident flying group administering landing PPR](https://sfgmendig.jimdoweb.com/infos-f%C3%BCr-piloten/) gives **ICAO EDRE**, asphalt **07/25 1,615 × 35m**, no fuel and no customs. Legacy `source_ident=ETHM`, `source_gps_code=EDRE`, registry longest runway 1,628.2m. | **Hold identity reconciliation** with current operator/AIP source. Preserve original identity key and record historical ETHM → present EDRE mapping without assuming two different airports are the same unless confirmed. |

## Persisted schema and permission boundaries

- New **private, RLS-enabled** `airlinerra.airport_expansion_de_runway_resolution_cases` stores **10** individually classified source gaps, links, dimensions, facts and required actions. There is **no** anonymous or ordinary authenticated-user SELECT access, nor any release-approval privileges.
- Two Batch 07 source records added to the pre-existing `airport_expansion_independent_paved_runway_reviews` table, with their original gross physical dimensions, existing registry values, published landing figures and independently cited operator references.
- Two explicitly held runway-end exceptions added to existing `airport_expansion_german_civil_runway_end_holds`, preserving the **EDFE RW26 1,166m** limitation and **EDTD 1,290m vs 1,200m** inconsistency.
- Updated only **EDFE** and **EDTD** in `airport_access_reviews` to `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING` for gross paved-runway research. Their commercial access and game admission remain **NOT_APPROVED**. The other eight are still general-source-held.
- **No** changes to original 3,140 World 1 airport activation, 3,140 home-airport picker entries, master source identities, game size classifications or any expansion world activation.

## Replay, regression and next work

- [Applied database schema, 10 case records, two specific runway-evidence advances and two landing-direction holds](./sql/AIRLINERRA_EXPANSION_DE_RUNWAY_RESOLUTION_BATCH_07_2026-10-26.sql)
- [Supabase acceptance tests — executed PASS](./sql/AIRLINERRA_EXPANSION_DE_RUNWAY_RESOLUTION_BATCH_07_TESTS_2026-10-26.sql)

Acceptance verified **10 cases, 2 gross physical-runway source advances, 8 source-held cases, 2 independently retained landing-distance holds, zero new approvals, zero expansion activations and the preserved 3,140 founding airports**, plus new private-table RLS.

**Next priority:** obtain and reconcile current original DFS AIP/operator technical runway publications for the **eight** remaining held airports, starting with pavement subtype for EDLD, EDBN current AIP, Flensburg **EDXF**, and source identity crosswalk for ETHM→EDRE. Do not confuse physical runway eligibility with commercial operating permissions or aircraft-specific landing lengths.

**Batch 07 complete: 10 reviewed, 2 physical-runway advances, 8 general source holds, 0 expansion airports activated.**
