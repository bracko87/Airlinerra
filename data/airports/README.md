# Airlinerra airport register — CURRENT PHASE: runway qualification only

## Approved scope (2026-10-20)
We are **collecting airports**, not evaluating whether they are currently usable by an airline. Include any airport with at least one runway that:
- measures **1,200 metres or more**;
- has **asphalt or concrete** as the explicitly reported surface (including accepted abbreviations);
- is **not recorded as closed**; exclude an airport recorded closed.
If a surface is merely "paved" or otherwise unclear, keep the airport in a separate surface-check queue.

Every matching airport is a **minimum Level 1 (Local) candidate**. There are still **exactly six** Airlinerra categories (1 Local, 2 Regional, 3 Medium, 4 Large, 5 Major Hub, 6 Mega Hub), but final categorization is NOT part of this phase. A candidate may later rank above Level 1.

## Permanent storage
- `airport_register.csv` — single permanent master register for runway-qualified airports. Holds only a source ID, country, airport name, identifiers, reported qualifying runway length and surface, a minimum-level flag (=1), and `RUNWAY_QUALIFIED` status. **It is not a list of active/playable game airports.**
- `generated/group4/group4_technical_candidates.csv` — reproducible runway-screen output for Group 4; tracks source identifiers and eligible runways.
- `generated/group4/group4_country_counts.csv` — screening totals by country.
- `generated/group4/group4_surface_review.csv` — uncertain runway surfaces, outside the eligible register until confirmed.
- `generated/group4/SOURCE.txt` — dataset provenance and checksums.
- `group4_review.csv` and `group4_14_reconciliation.csv` — historical cross-check for 14 examples, **not 14 extra airports**.
- `historical_approved_recovery.csv` — 56 earlier Group 1–3 airport names, kept separate from current runway-screened master until minimum-runway criteria are checked.

## Current group inventory
- Groups 1–3: previously discussed historical total **110** airports (21/30/59). **Not yet migrated into the runway-qualified master**. 56 names have been recovered separately; 54 not recovered.
- Group 4: **307 airports in the runway-qualified master** (France 151, Georgia 10, Germany 93, Greece 42, Hungary 11). The additional four uncertain-surface facilities are NOT counted among the 307.
- Group 5: pending.

The current count is a runway-only technical dataset, not a game-playability decision or a statement about civilian operation.

## Not doing now — later phases
We will later assess civilian/military access, operating permits, weight/aircraft restrictions, opening times, terminal/capacity/economic parameters, final six-category placements and any game activation. Do **not** exclude a runway-qualified candidate just because one of those future checks is missing.
No Supabase database migration has been applied or approved for these airport records.

## Reproducibility and release controls
- To refresh Group 4, run GitHub workflow `Refresh Group 4 technical airport screening` on **staging**; it downloads OurAirports, screens qualifying runways, rebuilds `airport_register.csv`, and runs validation.
- To validate locally, run `python scripts/validate_airports.py && python scripts/validate_historical_airports.py`.
- Staging is for development/data collection; `main` remains untouched until an explicitly approved production release.
