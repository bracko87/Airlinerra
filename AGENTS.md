# Airlinerra repository instructions

These rules apply to all contributors, automated agents and connected development tools.

## Branch safety
- All normal development, bug fixes, data curation, migrations, tests and documentation MUST target `staging`, explicitly.
- The `main` branch represents production. NEVER commit or push ordinary changes directly to `main`.
- Before a production release, compare `staging` to `main`, run required validation, and open a reviewed pull request.
- Merge or deploy to `main` ONLY after explicit owner approval for that release.
- Standard releases are grouped into two owner-operated manual release windows per day: morning and evening. Neither is automatic.
- Urgent releases may happen outside those windows, but still require testing and explicit owner approval.
- Never touch ProPeloton Manager or Game Control Center as part of Airlinerra changes.

## Airport data — current phase: runway-only collection
- Airlinerra retains EXACTLY six eventual airport categories: 1 Local, 2 Regional, 3 Medium, 4 Large, 5 Major Hub, 6 Mega Hub. Never substitute four categories.
- CURRENT OBJECTIVE: collect airports with at least one runway that is NOT recorded as closed, is >=1200 m long, and whose surface is explicitly asphalt or concrete.
- Never split Russia into European/Asian regions. RU includes the entire country for collection, naming, totals and gameplay design.
- Every matching airport can be **considered at least Level 1 (Local)**. This is a MINIMUM technical eligibility flag, NOT its final category. Longer runways do not imply a final higher level.
- Airport-only collection does NOT require civilian access, military-use assessment, permissions, aircraft restrictions, operator hours, capacity, financial data, terminal facilities, ICAO validation or other operational information at this stage.
- Do not reject runway-qualified airports for those future considerations. Record uncertain runway surfaces separately; do not assume plain "paved" means asphalt/concrete. Official aeronautical source evidence can override specific raw surface values, recorded in `data/airports/runway_surface_overrides.csv` (Group 9: LENE concrete and LEDA asphalt).
- Canonical master: `data/airports/airport_register.csv`, containing only airport identifiers, runway length/surface, minimum_eligible_level=1 and runway_status=RUNWAY_QUALIFIED. Generated data under `data/airports/generated/group1/` through `group9/` supplies source evidence. Rebuild the master from ALL groups, never from only the most recently processed group. Never count duplicate screens as additional airports.
- Groups 1–9 have 1,157 source-screened runway candidates PLUS 1 explicitly fictional Level-1 Local airport (LYAL Aleksandrovo, 2,200m asphalt), for 1,158 records in the canonical master: Group 1 = 30, Group 2 = 58, Group 3 = 74, Group 4 = 307, Group 5 = 91, Group 6 = 11, Group 7 = 47, Group 8 = 397 (Poland 35, Portugal 29, Romania 21, Russia 312, San Marino 0), Group 9 = 142 (Serbia 6, Slovakia 7, Slovenia 5, Spain 63, Sweden 61). Treat Russia as a SINGLE country with ALL territories, European and Asian, with no longitude/continental filtering. The 14 older Group 4 examples are within Group 4's 307. The older 110 Group 1–3 selections are not the same as the new runway-only pool of 162.
- Historic Groups 1–3 selected 110 airports (21/30/59); the CURRENT runway-only screening produces 162 candidates (30/58/74) and those ARE now in the permanent master. Keep 56 separately recovered historical names without treating them as extra records. The other 54 historical names remain unrecovered.
- User-owned fictional airports may be added through `data/airports/fictional_airports.csv` and MUST be included when rebuilding the master. Their `source_type=FICTIONAL` must stay distinct from real screened airports. Aleksandrovo Airport, Serbia, code LYAL, has 2,200m asphalt and an explicitly assigned category Local (Level 1); do not lose it in a future group refresh. Source-screened real airports keep `assigned_category` blank.
- No Supabase/game import, playable activation or production release in this phase. Final categorization of real screened airports is deferred. Database/schema work is deferred.
- Always validate on staging before claiming technical-collection completion.
## Game rules
- Real-time worlds: one real day is one in-game day. No historical eras.
- New airlines start with USD 5,000,000 and zero aircraft.
- Initial architecture supports three worlds; launch with one.
