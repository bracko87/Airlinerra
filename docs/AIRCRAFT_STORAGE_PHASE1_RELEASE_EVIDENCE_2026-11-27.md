# Phase 1 storage admission evidence — 2026-11-27

Status: evidence review, not activation. Connected Chromium/PostgreSQL inbound and return lifecycle passed run 46026020554 with synthetic operational inputs. Existing commercial airport profiles must be rechecked against the current game database before individual approvals. No production writes are authorized by this document.

## Phase 1 candidate decisions

| Airport | Operator and fuel evidence | Existing game runway (prior audit) | External review | Disposition |
|---|---|---|---|---|
| YBAS / ASP (OURAIRPORTS:26900) | APAS storage and Jet A-1 availability | 2438.1 x 45.1 m asphalt | APAS technical page lists 2438 x 45 m asphalt, continuous operation and prior arrangements for storage movements | First candidate for game approval; retain aircraft-specific limits, confirm live game snapshot and source rounding |
| LFBT / LDE (OURAIRPORTS:4073) | TARMAC Aerosave storage; airport lists Jet A-1 | 3000.1 x 45.1 m asphalt | French SIA AIP shows takeoff distance 3000 m in both directions; landing distance 2330 m on RWY 02 versus 3000 m on RWY 20 | Review directional runway constraints against existing game screen; do not silently widen authority |
| KROW / ROW (OURAIRPORTS:3856) | AerSale Roswell storage and airport fuel-service evidence | 3050.4 x 30.5 m asphalt | City describes a 13,000 ft main runway and a 10,000 ft cross runway; prior game runway appears to reflect the shorter runway | Keep conservative existing game limits until current runway identity and fuel source are reconciled; do not automatically expand commercial runway limits |

### Source references

- Alice Springs storage: https://www.apas.com.au/facility/
- Alice Springs operational reference: https://www.apas.com.au/facility/site-technical-data/ (operator summary, not a certified flight planning source).
- Tarbes storage: https://tarmacaerosave.aero/our-sites/
- Tarbes fuel: https://www.tlp.aeroport.fr/page-en/handling-services
- French SIA AIP, October 29 2026 edition, LFBT AD 2.13: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_29_OCT_2026/FRANCE/AIRAC-2026-10-29/html/eAIP/FR-AD-2.LFBT-fr-FR.html
- Roswell storage: https://www.aersale.com/products-services/airframe-mro/storage
- Roswell operator location: https://www.aersale.com/about/locations
- Roswell city airport overview: https://www.flyroswell.com/wp-content/uploads/2023/10/ROW-Business-more-Information.pdf (published runway summary, not directional declared distances).
- Roswell fuel-service minimum standards: https://www.flyroswell.com/wp-content/uploads/2023/10/Policy_ROW-Minimum-Standards-2020.pdf (service obligation, not proof of present supply).
- Roswell listed fuel: https://eflight.com/airports/ROW (secondary source, reconcile with live game fuel and primary airport data).

## Controlled release checklist

1. Re-read the live game data without writes: airport identity, approved commercial scope, geographic profile, selected runway and restriction data, slot capacity, fuel flag, movement tariff and expected storage prices.
2. Document game-only limitations and any source discrepancy. Never enlarge existing commercial permissions in a storage release. Unknown restriction defaults may be used only after reviewing known restrictions.
3. Stage existing commercial storage profiles in the reviewed isolated database. Obtain individual readiness snapshots and record evidence references; do not substitute synthetic review references for operational evidence.
4. Prepare a disabled-by-default production migration package and independently verify against a current schema clone. Reconcile review-only definitions and existing migrations; do not concatenate test fixtures into a production migration.
5. Obtain explicit production release authorization before deploying or enabling any facility, booking or background worker gate. Register the scheduler only after the migration is verified; enable facility and worker gates separately.
6. Preserve signed arrival, fee and crew history on emergency suspension. Do not delete in-flight requests or roll back settled ledger history.

## Game rules

Unlimited storage occupancy and duration. Monthly regional/narrowbody/widebody rates USD 4000/8000/15000. No real supplier quote implied. Existing commercial airport tariffs and admission remain unchanged. All figures here are game-reference inputs, not real-world flight clearance.

Phase 2 (LETL, KVCV) and Phase 3 (KMZJ, KMHV, EGBP, EGSY/EGDX) are still awaiting their final operational evidence review. St Athan remains blocked pending identity, fuel and access reconciliation. KAVQ remains excluded.
