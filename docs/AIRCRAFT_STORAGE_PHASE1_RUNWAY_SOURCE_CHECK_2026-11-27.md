# Phase 1 storage runway source check — 2026-11-27

Review only. No operational certification, live runway update or airport activation.

CI run 46037998815 passed actual storage leg screening with synthetic Section 5 evidence, including exact directional limits, mismatched runway identities, missing performance and unchanged ordinary commercial endpoints. The real minute scheduler billing test also passed in that run.

| Airport | Existing game runway ID (prior read-only audit) | Published runway | Conservative game TORA / LDA cap (m) | Evidence |
|---|---|---|---|---|
| Alice Springs (YBAS) | 233325 | 12/30 | 2438 / 2438 | Airservices Australia runway distance supplement dated 04 Sep 2025; both ends have TORA and LDA 2438 m, published width 45 m |
| Tarbes-Lourdes (LFBT) | 235930 | 02/20 | 3000 / 2330 | SIA France 26 Nov 2026 AIP cycle visual landing chart (03 Sep 2026): physical length 3000 m, TODA/ASDA 3000 m both directions, LDA 2330 and 3000 m; cross-check AD2 declared TORA before final approval |
| Roswell (KROW) | 244235 | 17/35 | 3050 / 3050 | AirNav FAA-derived listing: TORA and LDA 10008 ft both directions, 100 ft width, asphalt; use existing game's selected shorter runway rather than silently switching to 03/21 |

Sources checked:
- https://airservices.gov.au/aip/current/ersa/RDS_YBAS_04SEP2025.pdf
- https://www.apas.com.au/facility/site-technical-data/ (storage operator requires coordination of arrivals/departures)
- https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_26_NOV_2026/Atlas-VAC/PDF_AIPparSSection/VAC/AD/AD-2.LFBT.pdf
- https://airnav.com/airport/ROW (FAA-derived page; retrieved full page indicated July 2026 data; not a current operational status certificate)
- https://www.airnav.com/airport/KROW (search corroboration)

PDF extracted text was available; PDF screenshot requests failed with cache misses. The figures support game proposals, not final approvals. Published baseline dimensions are not current NOTAM status, access permission, pavement suitability for a specific aircraft or proof of storage servicing. Existing game runway operational status was unknown in the prior live audit. The phase 1 read-only preflight and exact approved readiness snapshots are still required. No change to existing commercial rights, aircraft eligibility, or storage release gates.

The private integrated schema rehearsal is still outstanding. Automatic scheduling has been exercised in an isolated PostgreSQL service only.
