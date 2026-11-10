# Airlinerra Group 2 — Section 8 Airport Economics game-data completion
Date: 10 November 2026

## Production acceptance
The Airlinerra production Supabase migration for Section 8 was applied successfully and independently queried afterwards.

- **1,118 of 1,118** Group 2 airport game-economics profiles meet the `game_complete_estimated` standard.
- **23 of 23** previously fixed batches accepted: batches 1–22 contain 50 airports, batch 23 contains 18.
- **Zero** failed batches or mismatched airport-category/base fee records.
- Category counts: **754 Local, 338 Regional, 26 Medium**.
- All **1,118** fee schedules use `GROUP1_CATEGORY_MEDIAN_GAME_RATE_NOT_REAL_TARIFF`.
- Base game landing fee, parking-per-day fee, departing passenger fee, stand multipliers, terminal navigation unit, cargo handling charge, ground handling fraction, security charge, and international processing charge have valid game values.
- All game airport backgrounds are present, but **zero** are independently verified.

## Illustrative game-fee ranges only
Amounts in USD; these are assigned game values, not actual airport fee quotes.

| Category | Airport count | Landing fee | Daily parking fee | Departing pax fee |
| --- | ---: | ---: | ---: | ---: |
| Local | 754 | 146–164 | 70–79 | 4 |
| Regional | 338 | 303–341 | 131–147 | 6 |
| Medium | 26 | 708–796 | 276–311 | 9–10 |

These fee levels are model assumptions. They must never be represented as actual commercial tariff agreements, regulatory fees or verified charges.

## Data objects
- `airlinerra_game.airport_group2_section8_game_registry_v1`: per-airport game economics and estimate provenance.
- `airlinerra_game.airport_group2_section8_batch_completion_v1`: batch-level live status.
- `airlinerra_game.airport_group2_section8_batch_acceptance_v1`: 23 immutable RLS-protected acceptance records.
- `airlinerra_game.airport_group2_section8_overall_status_v1`: consolidated complete/estimated status.

Views are private `security_invoker` read models with anonymous/authenticated grants revoked. Batch acceptance has RLS protection and an append-only trigger.

## Preserved safeguards and outstanding work
Section 5 operating restrictions remain **unresolved for all 1,118 airports**; no Group 2 airport was approved for dispatch. Group 1 remains **3,141 airports**, Group 2 commercial enablement remains **zero**, and World 1 state remains `planned`.

Section 8 is complete **only for game-data estimation**, not real-world source certification. Real airport tariffs, airport operating rules, and other source-research records remain separate.

The next decision should address the outstanding Section 5 research and repository-wide failing CI checks; do not label the whole Group 2 as operationally complete.
