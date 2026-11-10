# Airlinerra Group 2 — 1,118 owner-pre-approved airports

**Date:** 10 November 2026
**Source:** `airlinerra.airport_candidate_preapproval_pool`, 1,118 unique `PRE_APPROVED` owner checklist records, joined to `airlinerra.airport_registry`.
**Group:** `GROUP_2_OWNER_PREAPPROVED_1118`, a *second airport data cohort*, **not World 2**.

## What was actually completed

- All **1,118** preapproved owner records were copied into a **separate protected Group 2 game-data cohort**. No duplicate airport keys with existing Group 1; all have registry names, country, coordinates, qualified runway lengths/surface and an owner-selected game category and intended passenger/cargo type.
- The original **3,141 Group 1** `airlinerra_game.approved_game_airports` roster, existing Section 1–8 closure statuses and all financial/airline/game-clock tables were **not changed**.
- Eight separately queryable, read-only, RLS-protected Group 2 section views were built, mirroring the **categories of data** previously collected for Group 1:
  1. `airport_group2_section1_identity_v1`: airport name, country/region, coordinates, source identifiers, unique game lookup code, game time zone/elevation and provenance.
  2. `airport_group2_section2_classification_v1`: the owner's existing Local / Regional / Medium tier and Passenger / Cargo / Both intention.
  3. `airport_group2_section3_runways_v1`: longest registry-qualified runway, source surface, detailed runway length/width when found, explicitly labeled game-only width fallback.
  4. `airport_group2_section4_facilities_v1`: category-derived provisional terminal, terminal/remote/cargo stand model matching Group 1's assumptions, adjusted for intended passenger/cargo use.
  5. `airport_group2_section5_restrictions_v1`: **unknown** curfew/night/noise and operating access are retained as `NULL`, not falsely turned into `NO`; cannot clear any flight.
  6. `airport_group2_section6_capacity_v1`: same category-based ten-minute movement and stand capacity model as Group 1, never presented as a published slot allocation.
  7. `airport_group2_section7_demand_v1`: modeled passenger and cargo daily pools from the existing Group 1 tier medians with a bounded stable game variation; neutral 100% monthly seasonality until sourced otherwise.
  8. `airport_group2_section8_economics_v1`: landing, daily parking, departing passenger fees from the approved Group 1 category model and **same** current Section 8 stand/handling/cargo/terminal ATC tariff policy. No new real-world fees invented.

- `airport_group2_source_runways_v1` preserves all **1,828** available detailed source runway observations. The source runway ID is nullable; its actual observation ID is the durable unique key. No duplicate fake source runway rows were created for missing detailed records.
- `airport_group2_game_data_section_acceptance_v1` records all eight modeled categories, without claiming factual source verification, real airline rights, actual flights or a player release.
- `airport_game_cohort_inventory_v1` shows Group 1 + Group 2 together as **4,259 game-data records**, explicitly distinguishing Group 1's approved World 1 roster from Group 2's prepared-only records.
- `airport_group2_progress_v1` tracks exact counts and research gaps.

## Verified composition

| Game-data item | Count |
|---|---:|
| Group 2 staged airports | **1,118** |
| Local | 754 |
| Regional | 338 |
| Medium | 26 |
| Passenger-intended | 953 |
| Cargo-intended | 43 |
| Both passenger and cargo | 122 |
| Source runway observation records | 1,828 |
| Separate Group 2 data sections modeled | 8 |
| Already overlapping Group 1 | **0** |
| Existing Group 1 airports changed | **0** |
| Source municipalities missing | **41** |
| Detailed source runway widths requiring labeled game fallback | **20** |
| Airports without a detailed runway observation | **9** |
| Ukrainian airport timezones without a same-country Group 1 sample | **11**, labeled Europe/Kyiv *game assumption*, not authority verification |
| Unknown curfew/noise/operating restrictions | **1,118** |
| Commercially playable Group 2 airports | **0** |

### Modeling rules and provenance

The source registry's country, coordinates and runway records are **source-reported, not source-verified current operational facts**. Source identifiers remain their original values. Separate game lookup codes `G2-<source airport id>` are only Airlinerra keys and must never be called official ICAO/IATA codes.

The game time zone is an explicitly labeled *nearest same-country Group 1 airport approximation*; for 11 Ukrainian airports lacking same-country Group 1 references, `Europe/Kyiv` is used as an **explicit game fallback**. In particular, this is NOT a claim about current airport operating conditions or contested legal time-zone status. Elevation uses same-country Group 1 game proximity and an explicitly labeled zero-altitude fallback if there was no reference, never a sourced physical elevation.

The 41 unknown municipalities stay `NULL` in the *source municipality* column. Game text may fall back to the airport name for display only. No fictional municipality was invented. The 20 missing detailed widths use Group 1 category median as a named game estimate; 9 missing runway detail records stay absent from the source-runway inventory. Existing registry-qualified runway lengths are retained for game planning and cannot independently authorize a real aircraft movement.

Category-median stand, demand and fee estimates are **game baseline models**, not measured terminal counts, actual passenger statistics, published airspace unit rates or publicly available permissions. Passenger-only/cargo-only labels are owner's intended game traffic types, not verified real commercial permissions or proof an airport lacks the other service.

## The release boundary matters

**Do not interpret 'Group 2 imported' as 'Group 2 can now operate flights'.**

The earlier owner-checklist decisions say **PRE_APPROVED**, not `PROMOTED_TO_WORLD1`. The user requested adding all 1,118 as Group 2, which this release accomplishes as a game-data cohort. It does **not** override explicitly protected Source/Commercial gates, and does not silently add those airports to `airlinerra_game.approved_game_airports` World 1. Group 1's verified roster remains exactly 3,141.

Before a specific Group 2 airport can become a game flight destination, independently complete/approve the relevant operating restrictions, runway/aircraft compatibility, evidence of permitted civilian use, and commercial/game-admission eligibility. Runway and airport source research must not be guessed from game-model estimates; some airports may be temporarily closed or unsuitable.

Once approved, a separately reviewed and regression-tested admission change can expand the live roster and adapt Section 5/6/7/8/9 runtime queries without breaking Group 1, the protected schedule lifecycle or game world constraints. No flight activation, money posting, tickets, licences or aircraft movements were enabled or generated by this import.

## Tests

1. All source IDs, categories, intended services and coordinates checked against original owner decisions.
2. Migration ran in a `BEGIN ... ROLLBACK` transaction before the production database migration was applied.
3. `tests/sql/group2_1118_airport_game_data_acceptance.sql` was executed **after** the migration and passed: exact 1,118/1,828 records, all 8 section views with 1,118 each, source gaps preserved, no commercial release, and Group 1 unchanged.
4. Private tables have RLS enabled; browser `anon` and `authenticated` have no direct access. Supabase may report *RLS enabled without policies*: this is intentional for admin-only staged research.
5. The combined inventory separately counts Group 1 **3,141** and Group 2 **1,118**; original World 1 remains `planned` with zero actual flights and no additional airline ledger entries.
