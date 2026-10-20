# Airlinerra

Private development repository for Airlinerra, the Next Quest Studio real-time airline management browser game.

## Branches
- **`staging`**: all normal development and testing; explicit target for code and data changes.
- **`main`**: production only; release by reviewed PR after owner approval, within two manual release windows daily (morning and evening), or following validation for approved urgent fixes.

Read [AGENTS.md](AGENTS.md) and [Controlled releases](docs/CONTROLLED_RELEASES.md) before making changes.

## Airport registry
- [Approved airport master register](data/airports/airport_register.csv): **2 approved Group 4 records** so far (LHBC and LHTL), with the previously approved Group 1–3 records pending verification. 56 of the previously approved 110 Group 1–3 airport names are now stored in the historical recovery file. The other 54 are still missing; source verification must precede importing any into gameplay.
- [Historical recovery register](data/airports/historical_approved_recovery.csv): 56 previous Local approvals preserved, pending verification, NOT currently playable.
- [Group 4 automated runway screening](data/airports/generated/group4/group4_technical_candidates.csv): 307 candidates, 4 uncertain-surface records in separate review file, no automatic gameplay import.
- [Group 4 fourteen-airport reconciliation](data/airports/group4_14_reconciliation.csv): all 14 previously reported additions are already included in the 307 candidates.
- [Group 4 review register](data/airports/group4_review.csv): **14 candidate records**, not playable until verified.
- [Airport data policy](data/airports/README.md): full status, eligibility rules and exactly six categories: Local, Regional, Medium, Large, Major Hub, Mega Hub.
- [Supabase schema](supabase/migrations/202610200001_airports_registry.sql): prepared, not deployed.
- Validate with `python scripts/validate_airports.py && python scripts/validate_historical_airports.py`.

The game runs in real time (1 real day = 1 game day), starts new airlines with $5,000,000 USD and zero aircraft, and supports three independent worlds architecturally, beginning with one.

**Isolation:** Nothing in this repository changes ProPeloton Manager or the Game Control Center.
