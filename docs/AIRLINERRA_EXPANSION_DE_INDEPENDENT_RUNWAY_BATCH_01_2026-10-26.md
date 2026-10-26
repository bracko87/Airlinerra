# Airlinerra — Expansion runway evidence, German Batch 01

**Completed 26 October 2026.** Private Supabase project `hwllkabgzaynalahvkpz`, schema `airlinerra`; archived to GitHub `main`. The owner's **3,140 original World 1 airports remain active and untouched**. This batch concerns a separate selection of **eight airports** from the 3,906 expansion candidates.

## Batch outcome

| Result | Airports |
| --- | ---: |
| Reviewed against independent third-party or airport-operator source | **8** |
| Current airport-operator paved runway confirmed; game release still pending | **6** |
| Secondary source only: more authoritative evidence required | **1 — Großenhain (EDAK)** |
| Older official AIP runway chart: 2026 revalidation required | **1 — Neubrandenburg (EDBN)** |
| Newly activated game airports | **0** |
| First-wave World 1 airports still active | **3,140** |

The expansion cohort's general **`HOLD_INDEPENDENT_VERIFICATION` backlog fell from 1,827 to 1,821**, because six cases advanced to `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`. The other two remain held. These are technical **paved-runway evidence** statuses, not legal approvals or a public game release.

## Airport-by-airport evidence

| Airport | Paved main runway (source) | Evidence result and important qualification |
| --- | --- | --- |
| **EDAB Bautzen** | **07/25, 2,200 × 50m concrete** | [Operator pilot information](https://www.flugplatz-bautzen.com/informationen-fuer-piloten/): PCN 44; separate 1,000m grass is ineligible; winter weekend and off-hours PPR. **Operator source confirmed.** |
| **EDAK Großenhain** | **11/29, 1,415 × 48m concrete** | [DULV secondary airfield directory](https://dulv.de/fmwebphp/Flugplatz/details.php?id=840) and [independent guide](https://tpm-mediashop.com/pages/edak-grossenhain) concur; separate 950m grass is short. **Current operator/AIP still needed; hold unchanged.** |
| **EDAV Eberswalde-Finow** | **10/28, 1,560 × 50m concrete** | [Current operator](https://edav.eu/) reports 1,560m versus **1,538m** in existing registry (22m discrepancy); older sources report other figures. **Physical qualifying paved runway operator-confirmed, AIP/direction data reconciliation pending.** |
| **EDAX Müritz Airpark** | **07/25, 2,380 × 50m concrete** | [Operator technical data](https://www.mueritz-airpark.de/flugplatz/daten/) states **RW07 LDA 1,301m, RW25 LDA 1,341m**, *not* 2,380m. Page states **5,700kg MTOW**, while a [history page](https://www.mueritz-airpark.de/flugplatz/geschichte) refers to previous 14t authorization; current limit requires clarification. **Operator-confirmed with major restrictions.** |
| **EDAZ Schönhagen** | **07/25, 1,510 × 23m asphalt** | [Operator runway data](https://www.flugplatz-schoenhagen.aero/piloten/verkehrslandeplatz/flugplatzdaten) lists **RW07 LDA 1,340m, RW25 LDA 1,270m** and corresponding TORA 1,270/1,340m, PCN 25. [Operator flight restrictions](https://www.flugplatz-schoenhagen.aero/piloten/verkehrslandeplatz) include commercial night limits. **Operator-confirmed with direction-specific runway limits.** |
| **EDBC Magdeburg-Cochstedt** | **07/25, 2,500 × 45m asphalt** | [DLR airport operator](https://www.dlr.de/de/ux/forschung-betrieb/flughafenbetrieb) confirms reopening in 2022; VFR up to 14t and 48h outside-hours PPR. [Airport page](https://cochstedt-airport.de/allgemeine_luftfahrt/) also lists runway but has **72h** PPR notice: verify the current rule. **Operator-confirmed with permission/notice holds.** |
| **EDBH Stralsund-Barth** | **09/27, 1,685 × 30m asphalt** | [Operator airport data](https://www.edbh.de/fuer-piloten/flughafen-daten) reports one directional pavement figure of 1,658m, **RW09 LDA 1,385m, RW27 LDA 1,450m**; no IFR currently, >5.7t PPR, seasonal hours. **Operator-confirmed, but actual flight restrictions outstanding.** |
| **EDBN Neubrandenburg-Trollenhagen** | **09/27, 2,293 × 45m concrete** | [Operator-hosted official AIP obstacle chart](https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf) depicts 2,293 × 45m but is **effective 2018**; a [recent directory](https://www.pilotcenter.app/flugplaetze/edbn) corroborates dimensions. **Current 2026 AIP/operator confirmation required, hold unchanged.** |

### Critical source-handling rule

The original registry's longest paved runway values were **not overwritten**. Each reviewed airport has a separate, provenance-linked record with the operator-published physical length, width, surface, any explicitly published direction-specific LDA, source URL(s), source credibility grade, review outcome and outstanding action. In particular, **EDAX gross runway length must not become LDA**, and EDAV's +22m discrepancy must remain visible instead of being silently reconciled.

Only **six** had sufficient current operator evidence to move the central `airport_access_reviews` runway and identity subfields to `VERIFIED`. The two weaker evidence records are still `UNVERIFIED`. All eight remain `NOT_APPROVED` for gameplay, and their civilian access, real airline commercial permissions, aircraft/load compatibility, weather and operational service checks have not been automatically passed.

## Applied database changes

- Created private RLS-protected `airlinerra.airport_expansion_independent_paved_runway_reviews` with exactly eight Batch 01 records, explicit source authority grades, a computed registry-versus-source length difference and a `NOT_APPROVED` / `simulation_world_active=false` constraint.
- Updated the six current operator-sourced expansion airports to `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`. Preserved two evidence holds, unchanged original registry runway values, unchanged 3,140 original airport membership and unchanged World 1 activation.
- Kept exactly six possible airport game-size tiers: **Local, Regional, Medium, Large, Major Hub, Mega Hub**. No size-tier or approved capacity was changed.
- Confirmed the new table's RLS and no `anon` or `authenticated` table read/write permissions.

## Reproducible SQL

- [Research evidence table, eight source-backed records and six guarded central status updates](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_01_2026-10-26.sql)
- [Regression test suite, executed PASS in Supabase](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_01_TESTS_2026-10-26.sql)

Final audit: 8 research records; 6 operator-verified pending release; 2 independent-source holds; **1,821** remaining in the expansion's generic independent-verification queue; **3,140 World 1 airports**, **zero expansion activations**, no World 2/3 activation, and no new airline/game registrations.

## Next batch

Continue with additional 2026 current airport-operator or national AIP sources, prioritizing the remaining **38** German airports still on independent-source hold (44 initially minus six advanced); two of these now have recorded secondary/historical evidence and 36 have not yet been reviewed in Batch 01. Use current published runway distances, special runway type, access status and permanent/temporary closures independently. Propose expansion activation only as a separate, explicitly authorized **simulated-game release**, after runway screening; do not confuse physical runway collection with airline-specific operating permissions.

**Status:** German expansion Batch 01 research completed, protected World 1 founding cohort intact.