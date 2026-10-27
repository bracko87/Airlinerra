# Airlinerra — Private Aircraft Performance Reference Foundation

**Date:** 2026-10-27  
**State:** Private database schema INSTALLED; server-only calculation/loader code COMMITTED AND TESTED; no real aircraft-performance numbers loaded.  
**World 1:** Exactly 3,140 game-approved airport keys. Game release gate disabled. No playable flights, aircraft performance API, airport promotions or public registration enabled.

## Scope and delivery

This completes a **foundation** for consuming real, independently verified aircraft flight manual (AFM/OEM) performance reference data in Airlinerra **once obtainable**, rather than inventing takeoff/landing requirements from runway length or simple aircraft weight.

**Private Supabase:** project `hwllkabgzaynalahvkpz`, private schema `airlinerra`. Installed migration `airlinerra_private_aircraft_performance_reference_grid_20261027` creates:

1. `airlinerra.aircraft_performance_reference_sets`: aircraft variant key, manufacturer/model/engine configuration, sourced minimum mass, MTOW, maximum landing mass, wingspan, authority, manual/reference ID, revision/effective date, reviewed-by/date and explicit approval to use a conservative higher-weight envelope.
2. `airlinerra.aircraft_performance_reference_points`: flight phase (takeoff/landing), aircraft configuration, operating mass, **pressure altitude**, outside-air temperature, signed headwind component, runway slope, DRY/WET condition, and phase-specific takeoff/landing reference distance(s), with independent row review status.

These are **reference/evidence tables**, not the full aircraft model marketplace/catalog. As of installation there are **zero real aircraft reference sets and zero manufacturer distance points**: the complete aircraft model database is a distinct project ticket, and AFM takeoff/landing data must be sourced and reviewed. Tests use explicitly marked synthetic points **only in Node memory** and never write them to Supabase. Database original airport records, approved World 1 keys and existing flight engine remain untouched.

**GitHub code:**
- [Aircraft reference evaluator](../../server/private-aircraft-performance-reference.mjs): validates variant/configuration, operating mass, effective source date and all environmental inputs, returns exact reviewed source-grid distances or a **next-higher-mass** conservative point only where that method is explicitly approved for the source. Detects duplicate or non-monotonic weight entries. Does **NOT interpolate, extrapolate, manufacture performance modifiers or assign legally required safety margins**.
- [Private source loader](../../server/private-aircraft-performance-loader.mjs): default-disabled, read-only parameterized SQL, most recent effective reference (including an unreviewed newer revision, which then blocks rather than falling back to stale approved documentation), client release in `finally`. Binds all nine parameters explicitly. Fails closed when the reference or scenario-specific points are absent.
- [Reference calculation tests](../../tests/test_private_aircraft_performance_reference.mjs) and [private loader/composition tests](../../tests/test_private_aircraft_performance_loader.mjs): synthetically cover exact / approved conservative mass selection, mass limits, incomplete weather/altitude/wind/slope/wet conditions, source freshness and provenance, numeric PostgreSQL strings, parameterization and fail-closed missing-source behavior.
- [Already installed schema SQL archival copy](PRIVATE_AIRCRAFT_PERFORMANCE_REFERENCE_SCHEMA_2026-10-27.sql), **not** a new migration to execute.
- Previous [private runway inspection adapter](../../server/private-runway-inspection.mjs) and [numeric runway screen](../../server/private-aircraft-runway-screen.mjs) remain default-disabled and never issue flight authorizations.

## Supported operating-condition logic (strict by design)

| Input | Current handling |
|---|---|
| Aircraft variant and configuration | Exact match to independently reviewed reference set and point |
| Operating mass | Exact reviewed row, or next higher mass **within** reviewed bounds and only if the source explicitly approves monotonic conservative-envelope use |
| Airport elevation/altimeter setting | **Not automatically converted.** Requires an externally derived and traceable **pressure altitude in feet**. No unsupported ISA/QNH shortcut |
| Outside-air temperature | Exact reviewed source grid value; unknown/mismatched source blocks |
| Headwind/tailwind | Signed **already-calculated runway headwind component**; no raw METAR/wind-direction estimation |
| Runway slope | Exact signed published/source condition; must apply to the intended runway-end and phase |
| Runway condition | DRY or WET only, each with independent reviewed performance values; contaminated/icy/snowy unsupported and therefore blocked |
| TORA/TODA/ASDA/LDA required | Separate certified/source distance values per phase; physical runway length is never substituted |
| Commercial scheduling | **Always disabled** even if numbers fit; owner/game admission, operating restrictions, NOTAMs/PPR and aircraft configuration/mass certification remain separate |

The engine is intentionally **not yet an actual certified aircraft-performance calculator**. Numerical outputs are trusted **only as source-derived research distance requirements**, and no operational/dispatch authority is generated. A random takeoff estimate, rough ISA correction factor, typical MTOW or manufacturer marketing brochure cannot be promoted as an AFM grid point.

## Installation and verification

- Supabase migration succeeded.
- SQL inspection confirms both tables exist with RLS enabled, no policies, and `anon`/`authenticated` do not have SELECT. The parent private schema is not usable by public clients.
- Both tables remain **0 records**, preventing synthetic data from being confused with certified manufacturer performance.
- The loader's generated private parameterized SQL successfully executes against the actual Supabase project and returns zero rows for an absent synthetic variant.
- Both new Node test suites were added to existing `website/package.json` non-deploying test command; the existing static build remains isolated from `server/`.
- [GitHub Actions Node+disposable PostgreSQL workflow](https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-account-node-ci.yml) successfully ran all test suites and the static website build.
- Supabase security advisor reports `rls_enabled_no_policy` **informational** for both new tables; that is intentional default-deny since no client role may access the private source. Performance advisor notes the new index has not yet been used because tables are empty.

## Next milestone: real aircraft reference acquisition

Select the first approved aircraft **model/variant and engine** from the separate aircraft database task. For each intended departure and landing configuration, collect authoritative revision-dated AFM/OEM reference points across relevant takeoff/landing mass and operating-condition grids, plus MTOW/MLW, wingspan and configuration restrictions. Trace every number to table/page/document/revision and review it before changing its status to `PRIMARY_SOURCE_REVIEWED`. Do not fill gaps using a generic guessed performance multiplier.

Only then can Airlinerra perform **reference-backed** numerical runway suitability screening on real aircraft. The flight scheduling gate must remain closed until a separately authorized game-world release, model certification and aircraft dispatch-policy implementation are completed.
