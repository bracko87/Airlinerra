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
- Every matching airport can be **considered at least Level 1 (Local)**. This is a MINIMUM technical eligibility flag, NOT its final category. Longer runways do not imply a final higher level.
- Airport-only collection does NOT require civilian access, military-use assessment, permissions, aircraft restrictions, operator hours, capacity, financial data, terminal facilities, ICAO validation or other operational information at this stage.
- Do not reject runway-qualified airports for those future considerations. Record uncertain runway surfaces separately; do not assume plain "paved" means asphalt/concrete.
- Canonical master: `data/airports/airport_register.csv`, containing only airport identifiers, runway length/surface, minimum_eligible_level=1 and runway_status=RUNWAY_QUALIFIED. Generated data under `data/airports/generated/group4/` supplies technical source evidence. Never count duplicate screens as additional airports.
- Group 4 first full screen yielded 307 qualifying airport records across France, Georgia, Germany, Greece and Hungary, plus a separate queue for four uncertain-surface records. All 14 previously discovered examples are included in the 307.
- Groups 1–3 were previously reported as 110 historically approved, but current canonical runway records from those groups have NOT been recovered. 56 historical Local names are preserved separately and must not be added to the master without checking the runway rule.
- No Supabase/game import, playable activation, final six-category classification or production release in this phase. Database/schema work is deferred.
- Always validate on staging before claiming technical-collection completion.
## Game rules
- Real-time worlds: one real day is one in-game day. No historical eras.
- New airlines start with USD 5,000,000 and zero aircraft.
- Initial architecture supports three worlds; launch with one.
