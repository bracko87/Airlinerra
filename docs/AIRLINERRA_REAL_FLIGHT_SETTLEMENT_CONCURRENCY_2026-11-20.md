# Airlinerra — real completed-flight settlement concurrency acceptance (20 November 2026)

## Verified result

GitHub Actions successful: https://github.com/bracko87/Airlinerra/actions/runs/44798733296

The existing **unmodified** production implementation of `airlinerra_game.section9_post_completed_flight_finance_once_v1(text)` was extracted directly from `supabase/migrations/20261117095000_section9_once_only_final_flight_finance_guarded_v1.sql` and installed into a **fresh local PostgreSQL 17** `airlinerra_disposable` service running on the GitHub runner. It was not executed against Airlinerra production.

Six independent concurrent connections attempted to settle the same fabricated completed flight. Exactly **one** posting completed; other calls were rejected by the transaction lock or recognized as a replay. After the test, the same flight ID returned `complete_game_flight_finance_already_posted` without further money movement.

### Verified isolated example

- Original airline cash: $5,000.
- One revenue ledger entry: +$1,000.
- One expense ledger entry: −$500 (fuel $300 and itemized airport/navigation costs $200).
- Final cash and ledger sum: **$5,500**, with exactly one posted-flight identity.
- Both zero double charge and zero duplicate final posting checked.
- Additional negative tests confirmed release pause, denied mock flight evidence, unapproved final fuel costs, inadequate funds, and pre-existing ledger/cash drift block settlement without financial writes.

## Trust boundaries and limits

The function performing **financial writes** and locking is the exact production SQL source. The supporting tables are minimal disposable fixtures, and its required independent signed-movement verification, verified game hour and post-arrival ticket reconciliation services are **explicitly isolated stand-ins** configured to return synthetic positive or negative proofs. Consequently:
- This test **does** establish correctness of the core transaction, locking, revenue/expense entries, balance reconciliation and replay identity in this local fixture under six concurrent attempts.
- It **does not** verify real HMACs, airport slots, certificate issuance, ticket-demand generation, actual fuel-cost approval, live bank balances, full game schema constraints, or an authentic end-to-end FRA–MUC operation.
- It **does not** enable production World 1 finance, flight execution, licence releases or booking inventory; the live release controls remain unchanged.
- It **does not** verify 500-player scale/performance.

### Implementation files

- `tests/sql/section9_disposable_real_settlement_bootstrap.sql`: isolated tables, fake proof readers, three synthetic company balances, temporary delay trigger to force a posting race.
- `tests/sql/section9_disposable_real_settlement_negative.sql`: release, verification and funding failures.
- `tests/sql/section9_disposable_real_settlement_postconditions.sql`: exact ledger and cash arithmetic plus replay.
- `.github/workflows/section9-real-settlement-disposable-ci.yml`: disposable PostgreSQL 17 lifecycle, real function extraction, six parallel connections and postconditions.

## Next concrete implementation boundary

Integrate real, independently signed departure/arrival HMAC evidence and actual reserved passenger ticket receipts with approved game fuel/airport costs. Exercise a complete two-leg FRA–MUC route **inside a disposable database loaded with the real production dependency stack**; keep the currently paused production release flags and the restrictions on Group 2 unchanged. Once that passes, test larger concurrent fleets and explicit controlled activation.

**Status:** One-time money-writing concurrency verified in isolated PostgreSQL; full signed flight-to-finance integration remains unverified and not live.
