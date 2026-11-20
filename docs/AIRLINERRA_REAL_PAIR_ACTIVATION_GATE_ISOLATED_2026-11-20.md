# Airlinerra certified FRA–MUC activation gate — isolated PostgreSQL, 20 November 2026

Successful CI: https://github.com/bracko87/Airlinerra/actions/runs/44803158297

## What was actually tested

The real, **unchanged** production SQL source `airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1` was extracted from `supabase/migrations/20261117130000_section9_atomic_certified_pair_ticket_activation_v1.sql` and installed into disposable PostgreSQL 17. The fresh test database was guarded by `tests/sql/disposable_database_preflight.sql` and required `PGHOST=127.0.0.1` and `PGDATABASE=airlinerra_disposable`.

A minimal isolated stand-in supplies World 1 release policy rows, engine-readiness fields, an independently verified-game-hour *fixture* and airline ownership. Tests call the actual production activation function, not a copy rewritten for test use.

- All release flags paused: returns `blocked_operating_or_finance_release`, zero activated pairs, zero tickets and no ledger posting.
- Activating schedule release alone is insufficient; trusted execution and game finance gates must also be independently approved.
- Activating execution release without finance release is still blocked.
- Approving finance without trusted execution and fuel-transaction readiness remains blocked.
- Even with simulated enabled release rows, an unavailable or stale game-hour receipt blocks.
- Once mock release rows and game-hour are made valid, a forged airline owner is refused with SQLSTATE 42501.
- Reusing the outbound schedule ID as the return leg is refused as invalid input with SQLSTATE 22023.
- The acceptance runs within `BEGIN; ... ROLLBACK;` and checks a zero-effects fixture table. No real tickets, flights, cash, ledger or player changes were created.

## Source files

- `tests/sql/section9_disposable_activation_gate_bootstrap.sql`
- `tests/sql/section9_disposable_real_pair_activation_gate_acceptance.sql`
- `.github/workflows/section9-real-pair-activation-gates-ci.yml`

## What this does **not** prove

This was a **negative-path release and ownership gate test** of the production activation function. It did **not** perform a successful activation, validate the five independently signed per-leg certifications, exercise weekly slot inventory, record real movement events, or create sellable tickets. It did not run the full live Airlinerra schema or a real clock receipt; it did not load actual AOC and directional traffic-right proof services.

Earlier separate isolated tests verified true cryptographic HMAC + ticket reconciliation and six-concurrent one-time financial settlement: https://github.com/bracko87/Airlinerra/actions/runs/44801467387 . They are separate tests; combined real activation-to-settlement certification is **still outstanding**.

## Next milestone

Build a fuller disposable round-trip fixture with actual Group 1 FRA/MUC schedule records, verified AOC and both directional route permissions, certification receipts, slot-capacity and aircraft readiness. Test that **both legs activate and both booking inventories open in one atomic transaction**, and that a failed second leg or slot capacity roll back **everything**. Only then combine with signed departure, arrival and financial settlement.

Production World 1 commercial release, flight execution, booking and finance flags remain off. Group 2 operational restrictions remain in force. The eight-licence design is not reopened.
