# Airlinerra — German expansion runway verification, Batch 04

**26 October 2026 · Supabase:** `hwllkabgzaynalahvkpz`, private `airlinerra` schema · **Repository:** `bracko87/Airlinerra`, `main`.

## Verified outcome

Eight **distinct existing expansion candidates** underwent independent runway research. **Seven** were advanced to `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`, and **one** (Oberpfaffenhofen) remains held because the airport operator's published information was sufficient to establish special-use restrictions but did not independently confirm the runway dimensions published by an on-field organization.

| Measure | Value |
| --- | ---: |
| Source-reviewed in this batch | **8** |
| Advanced on operator or primary aviation-provider runway evidence | **7** |
| Still on generic independent-source hold | **1** |
| Worldwide expansion independent-source holds | **1,801**, down from 1,808 |
| German generic independent-source holds | **18**, down from 25 |
| Active original World 1 airports / home-airport picker records | **3,140 / 3,140** |
| Expansion admissions/activations | **0** |

The original runway registry and the owner's initial 3,140 World 1 airport catalog have **not** been changed. All eight records remain `NOT_APPROVED` for a new game airport release. Runway verification never establishes certificated airline suitability, owner consent for paid services, flight-date NOTAM, safety or aircraft performance.

## Review results, one airport per record

| Airport | Paved runway research observation | Independent source, restrictions, and decision |
| --- | --- | --- |
| **EDMO — Oberpfaffenhofen** | RW04/22, **2,286 × 45m asphalt** from an on-site resident flying group | **Keep source hold.** [On-airport DLR flying organization](https://www.fsg-im-dlr.de/node/49) documents dimensions and explains airport is a `Sonderflughafen`; the [current operator](https://www.edmo-airport.de/flugbetrieb/) confirms special-use business/research flight classes and PPR but its inspected page does not itself state those dimensions. Obtain current German AIP or airport-operator runway specification. |
| **EDMS — Straubing-Wallmühle** | RW09/27, **1,350 × 30m asphalt**; **RW09 LDA 1,250m**, **RW27 LDA 1,350m** | **Advance.** [Airport operator current technical data](https://www.airport-straubing.com/de/infos-fuer-piloten/airport-data/) states runway size and per-end distances. Some secondary material lists a **1,470m runway strip**; [official source ordinance](https://www.airport-straubing.com/wp-content/uploads/2017/12/NfL_1-17-03.pdf) identifies the strip separately. **Do not count 1,470m as landing pavement.** |
| **EDON — Neuhardenberg** | RW08/26, **2,400 × 50m concrete** | **Advance.** [Operator's runway specifications](https://www.airport-neuhardenberg.com/de/Service/Piloteninformationen/Piloteninformation.html) confirm PCN53 and a narrow **14.3m taxiway**; airport is special-use, with PPR/outside-hour limitations and events sometimes on the runway. Per-end LDA remains unverified. |
| **EDOV — Stendal-Borstel** | RW08/26, **1,997 × 52m concrete** | **Advance.** [Airport operator technical page](https://www.flugplatz-stendal.de/pilots/) confirms runway, separates the **700m grass runway**, and states aircraft above 5.7t up to 14t require PPR. Older independent sources say **1,980m**; retain disagreement. No exact LDA obtained. |
| **EDQG — Giebelstadt** | RW08/26, **1,982 × 30m concrete**, **RW08 LDA 1,847m; RW26 LDA 1,882m** | **Advance.** [Operator-hosted technical dimensions and declared distances](https://en.edqg.de/information-for-pilots/installations-for-vfr-und-ifr-flights), corroborated by [older 2019 airport-use ordinance](https://www.edqg.de/wp-content/uploads/2019/10/Benutzungsordn112019.pdf). Displaced thresholds **135m / 100m** and commercial mass/PPR/fire coverage restrictions; current 2026 AIP still required for any individual operation. |
| **EDQM — Hof-Plauen** | Operator lists **1,540m for RW26** and **1,240m for RW08**, **30m asphalt width** | **Advance** on qualifying physical paved runway only. [Airport operator technical page](https://www.airport-hof.de/piloteninfo/flughafen-information) lists **RW26 TORA 1,480m**, **RW08 TORA 1,240m**. Research registry has **1,480.1m**. The **1,540m** source figure records the longest physical measurement from the operator, not a certified landing distance for both ends; source **LDA is unknown**, effective AIP reconciliation pending. |
| **EDRY — Speyer** | RW16/34, **1,677 × 30m asphalt**, published **TORA/LDA 1,400m** | **Advance.** [Airport operator](https://flugplatz-speyer.de/infos-entgelte/) states PCN40 and explicitly distinguishes **1,677m physical pavement** from **1,400m declared usable landing/takeoff distance**. Larger aircraft PPR, operating hours and customs requirements vary. |
| **EDRZ — Zweibrücken** | RW03/21, **2,675m asphalt**, **45m width** corroborated by recent aviation technical guide | **Advance** on operator/aviation infrastructure evidence. [February 2026 ESSP aviation service provider](https://www.essp-sas.eu/communication/news/essp-and-triwo-strengthen-ties-egnos-working-agreement-zweibrucken-airport/) identifies operator TRIWO and a **2,675m asphalt runway**; [operator](https://www.edrz-airport.de/ueber-den-flugplatz/) confirms approximately **2.7km** runway, special-use status and PPR, while [2025 IVAO guide](https://de.ivao.aero/prozeduren/edgg/s/edrz/) lists 45m width. Current AIP direction-specific LDA and paid-carrier access still unverified. |

All eight source observations and all research status changes are saved without changing the original airport master. No airport was added to any live game world.

## Reproducible data and tests

- [Private research data replay: eight source records and seven guarded status changes](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_04_2026-10-26.sql)
- [Supabase acceptance suite — executed PASS](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_04_TESTS_2026-10-26.sql)

The database acceptance suite verifies 8 source records, 7 operator-evidence advances, EDMO held, correct published landing distances, Hof source/registry length distinction, **1,801** worldwide generic source holds, **18** German generic holds, zero expansion activations, and preservation of **3,140** World 1 game/home-airport selection records.

The research table remains RLS protected without anonymous or normal authenticated-user read rights.

## Next

Proceed with German Batch 05 from the **18 generic independent-source holds**. In parallel, separately reconcile previously identified special evidence exceptions, including source-conflicting surface/length records and Biberach's **980m** operator-published runway. Do not permanently reject any airport before an independently authenticated final review, and do not activate an expansion cohort without a new owner-authorized simulation-game release.

**Batch 04 complete: 8 researched, 7 advanced, 1 held, 0 new airports activated.**
