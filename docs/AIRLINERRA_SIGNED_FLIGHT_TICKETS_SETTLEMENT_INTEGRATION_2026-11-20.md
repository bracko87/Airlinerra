# Airlinerra — signed movement + real ticket + once-only finance PostgreSQL integration

20 November 2026. Successful isolated PostgreSQL 17 CI: https://github.com/bracko87/Airlinerra/actions/runs/44801467387

## Completed and actually executed

The disposable `airlinerra_disposable` database executes **three unchanged production functions**, extracted directly from migrations:
1. `section9_verify_operated_flight_hmac_pair_v1` from `20261117095000_section9_once_only_final_flight_finance_guarded_v1.sql`;
2. `section9_postarrival_ticket_reconciliation_v1` from `20261113225000_section9_postarrival_ticket_revenue_reconciliation_v1.sql`;
3. `section9_post_completed_flight_finance_once_v1` from `20261117095000_section9_once_only_final_flight_finance_guarded_v1.sql`.

The HMAC verifier reads two real, correctly signed **synthetic** PostgreSQL movement records, departure and arrival, with a disposable key in a local mock of the Vault table; `pgcrypto` performs real SHA-256 HMAC operations. The ticket reconciliation reads a synthetic certified capacity row and two genuine reservation-batch records (10 passengers × $50 each). The post-arrival reconciliation verifies 20 boarded/reserved passengers, $1,000 ticket revenue, correct schedule/aircraft/flight identity and receipt order. Neither the ticket rows nor the cryptographic events are a mocked success JSON.

### Negative cases

- One-byte-class tampering of the arrival HMAC blocks finance posting with `blocked_unverified_signed_flight_movement`.
- Modifying one batch to nine instead of ten seats blocks finance posting with `blocked_real_tickets_not_reconciled`.
- Marking a ticket batch `paid_upfront=true` blocks finance posting.
- Previously verified cases remain: finance release paused, invalid separate fuel cost proof, insufficient funds and airline ledger-versus-cash drift.
- Restore a valid signed/booking fixture, then six independent concurrent connections call the unchanged real settlement function. Exactly **one** posts $1,000 revenue and $500 of expenses, airline cash and ledger total both finish at $5,500, and retry does not change either ledger or cash.

## Test files

- `tests/sql/section9_disposable_real_settlement_bootstrap.sql`
- `tests/sql/section9_disposable_signed_ticket_postlude.sql`
- `tests/sql/section9_disposable_signed_ticket_acceptance.sql`
- `tests/sql/section9_disposable_real_settlement_negative.sql`
- `tests/sql/section9_disposable_real_settlement_postconditions.sql`
- `.github/workflows/section9-real-settlement-disposable-ci.yml`

## Known limitations (do not treat as production release)

- The independent authoritative **game-hour proof is an explicitly labeled fixture**, not the signed World 1 clock source.
- Actual activation of the airline/schedule, airport slot rights, operator and route certificates, crew eligibility, and the final game fuel/airport cost approval chain are not run as real integrated proof producers.
- The local test has minimal schema tables, not all live constraints, triggers or user roles. A synthetic flight is inserted in an already-activated state; no real ticket sale engine or flight dispatch runs.
- This verifies money posting and independently checking actual HMAC + reservation evidence when synthetic preconditions are supplied. It **does not** release operating schedules, enable player bookings, move real aircraft or post money in production.
- Group 2 airport holds and the eight-licence design remain unchanged.

**Next:** Integrate genuine game clock, schedule-certification and airport/aircraft authorization evidence into a more complete disposable activation-to-flight simulation, then fuel/fee approvals with negative tests. Production World 1 release controls must stay off until independent verification and release approval.
