# Airlinerra World 1 — Section 4 COMPLETE FOR GAME DATA
**Date:** 7 November 2026
**Scope:** all **3,141** airports
**Release status:** `game_complete_estimated` — fully populated and internally validated for the GAME. **Not** independently verified physical airport equipment or legal permissions.

## What was changed
User explicitly approved completing missing Section 4 airport facilities with means from other airports in the **same approved game category** instead of requiring exhaustive physical-airport research.

- Repaired **89** airports where the previous category correction had intentionally left the passenger gate and aircraft stand counts blank.
- Gate, contact, remote and cargo stands derived by rounding each category's mean from the **previously populated airports**. Total aircraft stands equals contact + remote + cargo stands, not an independently rounded inconsistent number.
- Resolved **16** NULL cargo-priority flags, preserving explicit owner cargo-majority decisions.
- Filled every airport's previously empty jet bridges, apron area, aircraft parking count, hangar/maintenance capacity, customs, international passenger eligibility, scheduled passenger service, cargo handling, ground handling, fuel and ARFF game-level fields with **explicit CATEGORY GAME DEFAULTS**, not invented airport sources.
- Preserved all original terminal counts, other previously populated facility values, airport category assignments, source URLs and owner customisations.
- Stored **3,141 original facility snapshots** in `airlinerra_game.section4_facility_game_completion_audit_v1`, including flags showing exactly which columns were originally missing.
- Created `airlinerra_game.section4_tier_facility_game_defaults_v1` with six auditable donor counts and rounded means.
- Extended constrained statuses for **facilities**, the **Section 4 master status**, and the **3,141 facilities work-queue records** with `game_complete_estimated`, deliberately NOT `verified` / `verified_complete`. No unrelated sections changed.
- New private `section4_game_facilities_completion_v1` view reports completed rows, missing game fields, split errors and sourced/verified counts.
- Committed idempotent SQL migration, regression test and this closure report in GitHub.

## Exact averages applied to the formerly missing 89 airports

| Category | Existing donor airports | Category total airports | Gates/contact | Remote stands | Cargo stands | Total aircraft stands | Airports repaired |
|---|---:|---:|---:|---:|---:|---:|---:|
| Local | 104 | 104 | 3 | 0 | 0 | 3 | 0 |
| Regional | 102 | 102 | 7 | 1 | 1 | 9 | 0 |
| Medium | 1,749 | 1,778 | 15 | 3 | 2 | 20 | 29 |
| Large | 876 | 887 | 32 | 7 | 5 | 44 | 11 |
| Major Hub | 187 | 229 | 60 | 13 | 12 | 85 | 42 |
| Mega Hub | 34 | 41 | 105 | 23 | 34 | 162 | 7 |
| **Total** | **3,052** | **3,141** | | | | | **89** |

The donors themselves are mostly **GAME MODEL values**, not measured physical airport gates or stands. These are consequently same-category game estimates, **not** statistical estimates of verified real airport inventory.

### Examples of affected airports
- DXB Dubai (Mega Hub): **105** gates, **162** aircraft stands.
- CPH Copenhagen (Major Hub): **60** gates, **85** stands.
- FCO Rome Fiumicino (Major Hub): **60** gates, **85** stands.
- BCN Barcelona (Major Hub): **60** gates, **85** stands.
- ZRH Zürich (Major Hub): **60** gates, **85** stands.
- MST Maastricht (Medium): **15** gates, **20** stands.

These game counts **must not be quoted as actual airport facts**.

## Explicit category-based defaults where NO historical values existed to average

For the following fields, a statistical mean was **impossible**: the entire World 1 dataset had no previously recorded values. The implementation applied game rules to enable uniform facility modelling without falsifying real-world evidence.

- **Jet bridges:** estimated ratio of *contact stands*, capped at contact stands: Local 0%, Regional 15%, Medium 35%, Large 60%, Major Hub 75%, Mega Hub 85%.
- **Apron area:** estimated m² per aircraft stand: Local 5,000; Regional 6,000; Medium 7,000; Large 8,000; Major Hub 10,000; Mega Hub 12,000.
- **Aircraft parking positions:** same as modeled total stands.
- **Hangar/maintenance capacity:** small tier-based numbers derived from stands; Local 0; Regional 1; Medium/Large/Major/Mega scaled by stand quantity with tier-specific minimums.
- **Customs and international operations:** a **game assumption** of available from Medium upward, unavailable for Local/Regional absent more specific data. **Must not be used as real regulatory permission.**
- **Scheduled passenger services, general ground handling and fuel:** assumed available for the game baseline.
- **Cargo handling:** assumed available when the modeled airport has cargo stands or an existing owner cargo-priority flag.
- **Fire/rescue:** strings such as `GAME_ESTIMATE_6` and `GAME_ESTIMATE_10`, explicitly not official ICAO/ARFF certificate classes.
- Section 4 did **not** overwrite operating-hour, curfew, noise or weather fields: those belong to **Section 5**. Formal movement/slots belong to **Section 6**. Cargo share percentage and annual cargo statistics belong to Section 7 and remain as supported source observations where available.

**Operational caution:** Game-estimated customs, fuel, ARFF, apron and handling values must **not** be treated as verified real permissions or safety ratings. Flight operations and scheduling remain separately gated.

## Final independent verification
The acceptance test `tests/sql/section4_game_facilities_completion_acceptance.sql` **PASSED** in the live database:
- 3,141/3,141 game facility statuses = `game_complete_estimated`;
- zero missing required Section 4 game fields;
- zero aircraft-stand breakdown errors, zero negative counts, zero impossible jet-bridge exceeds contact stand;
- 89 former gate/stand gaps resolved, 16 former cargo flag gaps resolved;
- all original terminal counts, original cargo flags, and original source URLs preserved, including the 10 original facility-source URLs;
- the Section 4 master status and all 3,141 facility work-queue statuses are `game_complete_estimated`;
- 3,141 pre-change audit snapshots remain available for inspection.

## Closure scope and next work
- **SECTION 4 GAME DATABASE: COMPLETE (ESTIMATED).** Do not say "all 3,141 real facilities have been verified".
- Real-world/source verification stays under **Section 10 — Evidence & Validation**, not as an unclosed Section 4 data-field task.
- Actual airport slots, movement constraints, infrastructure transaction checks stay in **Section 6** and Airlinerra operational-fleet/flight activation issue **#10**.
- No aircraft, schedules, flight operations, money or user accounts were created or modified as part of this closure.

## References
- SQL: `supabase/migrations/20261107155000_section4_game_facility_category_average_completion.sql`
- Acceptance: `tests/sql/section4_game_facilities_completion_acceptance.sql`
- Historical pre-closure audit: `docs/SECTION4_TERMINALS_FACILITIES_AUDIT_2026-11-07.md`
