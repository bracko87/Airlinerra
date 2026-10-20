# Airlinerra

Private Next Quest Studio repository for Airlinerra, a real-time airline-management browser game.

## Controlled GitHub workflow
- `staging`: all normal changes, tests and airport-data collection.
- `main`: production only, after validated reviewed PR and explicit owner approval.
- Standard releases: two **manual** windows each day (morning/evening). Validated urgent releases require explicit approval.
- ProPeloton Manager and Game Control Center remain unaffected.

Read [AGENTS.md](AGENTS.md) and [CONTROLLED_RELEASES.md](docs/CONTROLLED_RELEASES.md) first.

## Airport collection — runway-only phase

**No deeper airport research or final level assignments yet.**

1. Minimum **1,200 m** runway.
2. Asphalt or concrete.
3. Runway and airport not recorded as closed.
4. Qualified airport receives **minimum eligible level 1 (Local)**; its **final category is not assigned**.

Exactly six game levels remain in the design: Local, Regional, Medium, Large, Major Hub, Mega Hub.

[Permanent runway-qualified airport register](data/airports/airport_register.csv) stores **307 Group 4 records**, not merely the two earlier operator-reviewed airports. The master contains no civilian-access approval or game-activation status.

[Raw Group 4 screening](data/airports/generated/group4/group4_technical_candidates.csv) and [country totals](data/airports/generated/group4/group4_country_counts.csv) preserve the 307 candidates (FR 151 / GE 10 / DE 93 / GR 42 / HU 11), and [surface-review records](data/airports/generated/group4/group4_surface_review.csv) track four additional uncertain surfaces.

[Historical Group 1–3 recovery](data/airports/historical_approved_recovery.csv) preserves 56 names of 110 previously discussed airports; these **do not count toward the current technical master** until runway-screened. The remaining 54 names still require recovery.

[Airport data scope and reproducibility](data/airports/README.md) explains the current collection stage. [Previous 14-airport cross-check](data/airports/group4_14_reconciliation.csv) confirms those examples are already included in the 307.

Validate with:
```sh
python scripts/validate_airports.py && python scripts/validate_historical_airports.py
```

**Later, not now:** civilian/military operations, restrictions, advanced airport information, final six-level assignments, and Supabase/game deployment.

## Other game decisions
Real-time worlds (one real day equals one in-game day); new airlines begin with $5,000,000 USD and zero aircraft; three-world architecture launching one world first.
