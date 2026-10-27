# Airlinerra — Private runway inspection bridge (server source only)

**Completed:** 27 October 2026  
**Code:** [server/private-runway-inspection.mjs](../../server/private-runway-inspection.mjs)  
**Unit tests:** [tests/test_private_runway_inspection.mjs](../../tests/test_private_runway_inspection.mjs)  
**CI:** [GitHub Actions run 40485317882](https://github.com/bracko87/Airlinerra/actions/runs/40485317882)

## Exactly what was implemented

A **read-only, server-only, disabled-by-default inspection adapter** now composes the private `airlinerra.runway_source_versions` and physical/directional/permission facts with the **owner-approved `airlinerra_game.approved_game_airports` World 1 roster** and the existing `airlinerra_game.platform_release_gate`.

The adapter:
- accepts only `worldId=1`, canonical airport keys and explicit valid `YYYY-MM-DD` source inspection dates;
- uses parameterized SQL, binding the world, airport key and source effective date;
- uses the latest `source_effective_date <= asOfDate` per runway pair; sources with no known effective date are excluded rather than accepted indefinitely;
- requires the airport to be in the 3,140-key private game catalog **before** returning any source runway rows;
- keeps physical runway length, material verification, airport operations, directional TORA/TODA/ASDA/LDA, and scheduled-passenger permissions as separate fields;
- releases a private PostgreSQL connection even if queries or validation fail;
- returns `mayScheduleFlights:false` in **every** state, including hypothetical enabled release-gate fixtures; this source is **not** the flight scheduling engine;
- does not perform any database writes, change owner airport approvals, expose an HTTP/Netlify Function, or import a backend module into the public static `website` build.

**Important scope:** This is a safe *source-level handoff/inspection*, **not** permission for a new French airport to enter World 1, and **not** integration with an actual aircraft flight timetable.

## Evidence from live project

Supabase `hwllkabgzaynalahvkpz` read-only SQL checks performed during development:

| Assertion | Result |
|---|---|
| Runway source-version rows stored privately | **18** across 14 French airports |
| Runway-source records matching already-approved World 1 airport keys | **0** |
| Approved World 1 keys | **3,140** |
| `platform_release_gate.enabled` | **false** |
| Legally closed Creil `LFPC` in approved game roster | **0** |
| Query executed with real approved World 1 key `OURAIRPORTS:3471` | One approved airport row, **no runway pair**, release disabled |
| Same read-only query with French research-only `OURAIRPORTS:4195` | **0 rows**, no accidental admission |

The official source data is intentionally invisible to the *currently approved* game-roster lookup until airport approval AND private runway publication are separately authorized. The game can continue its current catalog and account preview functionality without this module.

## Automated testing

The new `tests/test_private_runway_inspection.mjs` suite is included in the repository's existing `website/package.json` Node tests. [Automated GitHub Actions run 40485317882](https://github.com/bracko87/Airlinerra/actions/runs/40485317882) successfully completed:
- `node-account-regressions`: PASS, including the new inspection validation tests and the prelaunch static website build;
- `postgres-disposable`: PASS, using CI-local disposable PostgreSQL, no production secret or Supabase mutation;
- existing public `PUBLIC_AUTH_ENABLED=false` checks: PASS.

This CI success tests the Node source and isolated account schema, **not an end-to-end airline scheduling system**. Live SQL read-back covers the private existing runway joins and release-gate states.

## Public website and deployment boundary

The static prelaunch website is already on Netlify from GitHub `main`. No files in `website/` other than its **npm test script** were modified, and no Netlify Functions or backend routes were added. The static build copies only an explicit allowlist from `website/`; `server/private-runway-inspection.mjs` and the test files are excluded. Automatic Netlify rebuilds after a main push should therefore not introduce new browser capabilities.

No account registration, airline activation, paid products or public game release was enabled by this change.

## Remaining implementation stages

1. **Evidence completeness:** For every proposed playable airport, verify currently effective source revisions, exact asphalt/concrete material, every runway direction used by the aircraft, displacement, pavement/capacity limits and airfield operating restrictions. Explicitly model NOTAM/PPR validity separately.
2. **Owner release boundary:** Create a separately authorized, reviewed **gameplay runway publication** tied to existing approved game airport keys, not raw research state. Require operator and gameplay category approvals.
3. **Aircraft performance:** Match each aircraft's takeoff/landing requirements to the relevant direction-specific TORA, TODA, ASDA, LDA and current runway status; no default from physical length.
4. **Controlled flight engine:** Only after testing and owner authorization, wire a distinct scheduling service to released airport/runway and airline-specific gates. Never use this inspection service as authorization.

Six airport categories remain exactly **Local, Regional, Medium, Large, Major Hub, Mega Hub**. World 1 remains **3,140 approved game airports**. The 14 French corrected-runway proposals are still research-only, original imported source records preserved.
