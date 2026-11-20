# Airlinerra — positive FRA–MUC / MUC–FRA certified pair activation, 20 November 2026

## Verification

**GitHub Actions result: success.** https://github.com/bracko87/Airlinerra/actions/runs/44806462333

A fresh PostgreSQL 17 disposable database `airlinerra_disposable` executed the **exact production** SQL body of `airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1`, extracted unchanged from `supabase/migrations/20261117130000_section9_atomic_certified_pair_ticket_activation_v1.sql`. The database preflight requires localhost PostgreSQL with an empty schema and the expected database name.

### Actual real-function behavior tested

- Two saved synthetic schedules: **Frankfurt Main (OURAIRPORTS:2212 / FRA) → Munich (OURAIRPORTS:2218 / MUC)** and **MUC → FRA**, assigned to the same in-service owned aircraft.
- Verified synthetic passenger configuration exposes 110 simultaneously serviceable seats, 120 maximum seats, 110 released passenger seats per dated occurrence.
- Synthetic game World 1 release flags and clock are approved and the game-day fixture matches `2026-11-20`.
- Ten **fixture** operational certification receipts, five on each saved schedule, with independently referenced synthetic event identities; no actual issuer HMACs or independent route-rights / AOC / slot authority is exercised.
- The unchanged production function correctly rejects a pair when one certification receipt is set to pending (nine instead of ten).
- **Atomic rollback injection 1:** Return-leg schedule activation denied after outbound activation → zero active schedules and zero seats/tickets.
- **Atomic rollback injection 2:** Return-leg verified seat capacity denied after both schedules activated → zero active schedules and zero capacity/tickets.
- **Atomic rollback injection 3:** Return-leg ticket-inventory open denied after outbound inventory opened → zero active schedules and zero capacity/tickets.
- **Positive path:** Both schedules activated, **one synthetic saleable dated occurrence on each leg** in the seven-day window, with 110 certified seats on each, zero tickets actually sold, zero ledger posting, zero movements.
- **Replay:** A second activation attempt is rejected as a stale/not-draft pair and does not open duplicate inventories.

## Scope and limitations

This is a **real production orchestration function** verified against genuine PostgreSQL transactions and controlled disposable dependency implementations. It establishes atomic two-leg behavior, rollback and idempotent replay with synthetic approvals. It is **not** a complete real signed operational-certification proof, actual two-direction traffic permissions, AOC issuance, airport slots, maintenance or fully integrated flight execution. It does not populate the live database or authorize game players to fly.

The prior independent negative-path activation test passed: https://github.com/bracko87/Airlinerra/actions/runs/44803158297 . The separate authentic (but synthetic-data) flight-HMAC + ticket reconciliation + financial concurrency tests passed: https://github.com/bracko87/Airlinerra/actions/runs/44801467387 .

### Implemented files

- `tests/sql/section9_disposable_positive_fra_muc_pair_bootstrap.sql`
- `tests/sql/section9_disposable_positive_fra_muc_pair_acceptance.sql`
- `.github/workflows/section9-positive-pair-disposable-ci.yml`

## Next substantive task

Replace synthetic activation-service approvals **one dependency at a time** with actual private game evidence readers and signed certification issuance: verify AOC, both directional route rights, airport Group 1 slots/curfews and maintenance/aircraft readiness. Then run genuine activation-to-departure-to-arrival-to-finance in one unified disposable integration harness. Do **not** activate production release switches or bypass Group 2 holds.

**Status:** Positive atomic two-leg activation + inventory passes real-function disposable PostgreSQL tests. Authentic independent operational certification and full combined lifecycle remain pending.
