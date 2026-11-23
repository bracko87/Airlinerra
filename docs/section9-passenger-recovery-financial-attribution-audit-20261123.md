# Flight cancellation passenger recovery and accounting — read-only audit (2026-11-23)

## Current implementation

The authenticated `schedule-change-assessment` operation is strictly
read-only and owner-scoped. It never approves live cancellation, changes a
booking, releases an airport slot, posts a ledger entry or calculates a refund.

The current evidence distinguishes:

- Reserved passenger batches and seats
- Upfront-paid reservation records (`paid_upfront=true`), **regardless of current reservation status**
- Non-reserved reservation states, which may represent historical claims
- Reserved quoted ticket fare `sum(seats_requested * quoted_fare_usd)`, which is
  a **commercial quote**, not collected money, recognized revenue or refund liability
- Two separate revenue fields: recognized revenue on dated occurrences and
  recognized revenue on reservation batches, which may overlap
- Prepared ticket-finance records and prepared settlement records
- Operated flight movements and pending two-leg itinerary holds

The UI explicitly flags that quoted ticket totals are **not refund amounts**.
The service returns `flightLedgerReconciliationAvailable:false`,
`quotedFareIsRefundAmount:false`, `canCancelOperationalFlight:false`,
and `canRescheduleOperationalFlight:false`. These flags must remain false
until separately reviewed release gates exist.

## Verified schema limitation

Production `airlinerra_game.airline_ledger` columns are
`id`, `airline_id`, `entry_kind`, `amount_usd`, and `recorded_at`.
There is **no schedule_id, occurrence_id, physical_flight_id, payment_id,
or reservation_id** on this table.

By contrast:

- `section9_passenger_reservation_batches_v1` carries `occurrence_id`,
  `reservation_key`, `paid_upfront` and `recognized_revenue_usd`
- `section9_actual_ticket_finance_preparations_v1` carries
  `physical_flight_id`, `schedule_id`, `airline_id` and
  `preparation_status`, but is a preparation—not proof of posted money
- `section9_prepared_occurrence_settlements_v1` carries
  `physical_flight_id`, `schedule_id`, `airline_id`,
  `ticket_revenue_usd`, and `status`, but is likewise a prepared record

Therefore **do not infer specific ledger postings, collected payments or
refund obligations from the quoted fare or ledger balance**. Do not sum
occurrence and reservation recognized-revenue fields as distinct cash receipts.

## Required recovery design before any production cancellation endpoint

1. Audit source-to-ledger accounting and idempotency proofs to identify each
   posted amount by physical flight, reservation, business event and airline.
   If references exist in separate protected journals, demonstrate and test
   their referential integrity. Otherwise propose a new private, immutable
   posting attribution ledger with controlled migration and backfill rules.
2. Define approved policy for each state: unused uncharged reservations,
   paid upfront, already operated, partially flown connecting itinerary,
   prepared-only finance and committed settlement.
3. Preserve booked-seat, passenger movement, and financial history. Perform
   refunds or compensating entries only under validated transactional
   authorizations; never erase posted accounting or paid claims.
4. Use deterministic idempotency keys for cancellation decisions, recovery
   entitlement, compensating journal entry and final receipt.
5. Acquire compatible locks across multi-leg bookings, flight capacity,
   occurrences, schedule versions and posting ledgers; recheck after locking.
6. Create disposable end-to-end tests for booking-first and cancellation-first,
   cancellation vs settlement, double refund, retry, timeouts, partial
   flight operation, charge reversal and protected historical reporting.
7. Keep player-facing cancellation controls disabled until the actual
   production writer has passed an independently reviewed release gate.

## Verification

The read-only PostgreSQL `EXPLAIN` of the owner-scoped assessment query
confirmed compatibility with the existing schema on 2026-11-23. No
production write was executed. Frontend/API regression tests are in
`tests/test_section9_schedule_change_assessment_api.mjs`.

This audit and response evidence are **not** a refund engine and cannot
authorize active-flight cancellation or rescheduling.
