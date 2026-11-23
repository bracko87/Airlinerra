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

## Correction: existing flight-to-ledger attribution table found

A subsequent read-only inspection of the actual settled-flight writer,
`airlinerra_game.section9_post_completed_flight_finance_once_v1(text)`,
found an existing flight-specific posting index:

`airlinerra_game.section9_route_posted_flight_financials_v1`

For each completed flight, the trusted writer inserts revenue and expense
entries into `airline_ledger`, then stores their generated IDs in a single
posted-flight financial record, in the same transaction as the airline cash
update. That record carries `physical_flight_id`, `schedule_id`,
`airline_id`, `arrived_event_id`, ticket income and itemized operating
costs, `revenue_ledger_id` (nullable when no revenue) and the mandatory
`expense_ledger_id`. Unique constraints protect both ledger ID references
and the physical flight ID; foreign keys reference `airline_ledger(id)`.

**This corrects the earlier conclusion that no flight-to-ledger link exists.**
The base ledger has no flight ID, but this protected financial posting table
provides explicit attribution for completed, posted flights.

The read-only owner-scoped schedule assessment now exposes:
- `postedFlightFinancialCount`: number of completed flight posting records;
- `postedFlightTicketIncomeUsd`: ticket-income portion of those records
  (not cash owed to any particular passenger);
- `postedFlightLedgerMismatchCount`: checks referenced ledger existence,
  airline ownership, entry types and expected signed revenue/expense totals.

The review remains *fail closed*: posted history blocks cancellation and a
posting mismatch triggers a distinct review blocker. The response signals
`postedFlightLedgerAttributionIndexAvailable:true` while retaining
`flightLedgerReconciliationAvailable:false`, because cancellation compensation,
refund eligibility, collection methods and payment attribution are **not**
established by posted flight financials.

**Validation limits:** the production table had zero posted rows at inspection
on 2026-11-23, so only schema constraints and SQL compilation were verified on
the connected database. No actual financial postings, ledger balances or
customer claims were changed. Full integration needs synthetic nonzero posting
fixtures and a later real-world data audit.

### Corrected implementation priority

Use the existing `section9_route_posted_flight_financials_v1` attribution
first rather than immediately introducing another flight posting ledger.
Verify source-to-payment/refund entitlement independently. Only propose a new
append-only compensation journal if existing journals cannot represent
cancelled/passenger-refunded states safely.

## Original cancellation writer financial exposure acceptance (2026-11-23)

The production source of `section9_cancel_unflown_occurrence_v1(uuid,text)`
was captured unchanged using read-only `pg_get_functiondef` as
`tests/sql/section9_disposable_original_unflown_cancellation_writer.sql`.
A new disposable regression
`tests/sql/section9_disposable_real_cancellation_finance_guards.sql`
installs the unchanged function and verifies four **independent** refusal
scenarios against a synthetic two-seat reservation:

1. A stored actual-ticket finance preparation returns
   `flight_already_operated_or_settled`;
2. An operated departure movement returns
   `flight_already_operated_or_settled`;
3. Nonzero occurrence recognized revenue returns
   `flight_not_cancellable`;
4. An upfront-paid reservation returns
   `reservation_reconciliation_required`.

For each refusal, the protected fixture keeps both booked seats, both
held seats, the original reserved batch and zero cancellation receipts.
These cases produce no finance or ledger mutations.

The **two private writers are not proven mutually serialized**:
`section9_cancel_unflown_occurrence_v1` uses advisory lock
`(583729,10041)`, shared with disruption recovery, whereas
`section9_post_completed_flight_finance_once_v1` uses a
`(583730,hashtext(physical_flight_id))` advisory lock, and locks
the finance preparation and approval records. The distinct advisory
locks do not independently prevent simultaneous settlement/cancellation;
further tests must model settlement preparation and flight-movement
publication racing the cancellation's post-lock checks, as well as a
fully approved completed-flight posting transaction.

Both CI jobs passed in
https://github.com/bracko87/Airlinerra/actions/runs/45201136498

This is **not** a full live settlement-versus-cancellation transaction
verification and does not authorize active-route cancellation, refund
processing, production migration, or deployment.
