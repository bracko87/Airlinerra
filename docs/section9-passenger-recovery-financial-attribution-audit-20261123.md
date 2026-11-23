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

## Actual finance-preparation row-lock protocol versus cancellation (2026-11-23)

Follow-up inspection found that the private finance-preparation writer
`section9_prepare_actual_ticket_postarrival_finance_v1(text)`
acquires an advisory key `(583729,hashtext(physical_flight_id))`, then
reads the flight occurrence, schedule and flight-capacity inventory with
`FOR SHARE OF o,s,cap`. It requires the flight's
`booking_status='closed'` and validated signed arrival, burn,
postarrival ticket reconciliation and game-cost proof before inserting a
finance preparation.

The unchanged private cancellation writer uses the independent
disruption advisory key `(583729,10041)`, locks the capacity and
occurrence rows `FOR UPDATE`, and permits only open, unflown,
financially unrecognized, uncharged reservations. Thus *the row locks
and mutually exclusive booking statuses*, not their advisory keys, form
the relevant shared safety boundary for these two operations.

The new disposable PostgreSQL regression
`tests/sql/section9_disposable_finance_preparation_vs_cancellation_race.sh`
models the finance writer's **exact shared-row-lock and closed-status
protocol** against the **unchanged cancellation function**, with two
independent database sessions and a real wait at the contended capacity
row:

- **Preparation first:** holds `FOR SHARE` on capacity and occurrence
  while transitioning the synthetic flight to closed and recording a
  synthetic preparation. Waiting cancellation observes the closed
  flight and returns `flight_not_cancellable`. The original two seats,
  reservations and preparation remain; no cancellation receipt appears.
- **Cancellation first:** holds the capacity row `FOR UPDATE` and
  executes the unchanged cancellation writer. The preparation protocol
  waits; after the cancellation commits, it reads the cancelled status,
  refuses preparation and does not insert a finance record. Original
  cancellation receipt is present and booked/held seats are zero.

The regression checks both flights' seat counts, reservation statuses,
finance preparation records and cancellation receipts after commit.
It does not post money or calculate refunds.

Verified with all other readiness regressions green in
https://github.com/bracko87/Airlinerra/actions/runs/45204701613

**Important limit:** the finance-preparation side in the new race is a
faithful, deliberately scoped *row-lock/status simulator*, not a live
invocation of the complete finance-preparation writer with real signed
movement, fuel receipts and financial proof. The final
`section9_post_completed_flight_finance_once_v1` writer uses a
separate per-flight advisory lock and is not exercised in this test.
Full real settlement-versus-cancellation and signed movement
publication races remain open review gates. Production schema, player
money, bookings and settings were not changed.

## Actual final financial posting writer: isolated release and mutex tests (2026-11-23)

Retrieved the unchanged deployed
`section9_post_completed_flight_finance_once_v1(text)` definition
read-only and stored a database-guarded snapshot at
`tests/sql/section9_disposable_original_final_finance_writer.sql`.
The snapshot is solely a test asset, not a deployment migration.

The original writer was installed in disposable PostgreSQL 17 and
tested using
`tests/sql/section9_disposable_original_final_finance_guards.sql`.
It rejected execution when the approved release evidence was absent,
preserved private `postgres` execution privileges, and returned
`blocked_missing_completed_ticket_preparation` when given a
synthetic correctly gated flight without a finance preparation. All
testing was confined to the disposable environment; approval policy
changes were rolled back inside the fixture.

A second two-session test,
`tests/sql/section9_disposable_original_final_finance_mutex.sh`,
held the real flight-specific posting mutex
`(583730,hashtext(physical_flight_id))` in one session while the
other attempted the **unchanged posting function** with the same
physical flight identifier. The competing invocation returned
`game_flight_finance_posting_busy`. After the lock was released,
it retried, reached the missing-preparation refusal, and performed
no posting or preparation. This verifies one specific exactly-once
entry gate for the finance writer, not the actual money-posting path.

Both CI jobs passed:
https://github.com/bracko87/Airlinerra/actions/runs/45206485210

**Remaining release boundaries:** full final-settlement success and
atomic airline-cash/ledger writes (including rollback injected after
ledger insertion), final finance approval/replay protection with
nonzero signed-arrival fixtures, signed movement publication racing
cancellation, and real posting-vs-cancellation interleavings. These
are not certified by a missing-preparation test or by an advisory
mutex test. Player-initiated active-flight cancellation remains
disabled; the reviewed ticket correction remains undeployed.

## Actual completed-flight financial posting, replay and forced rollback (2026-11-23)

The **unchanged original** `section9_post_completed_flight_finance_once_v1(text)`
was executed to completion with separate synthetic flight records on
disposable PostgreSQL 17. The test
`tests/sql/section9_disposable_real_final_finance_atomic_acceptance.sql`
provides isolated placeholders for source HMAC verification, arrival
and ticket totals, external crew costs and onboard release; therefore
this is **an atomicity test, not signed source certification**.

Successful settlement confirms the original function:
- Inserts a `REVENUE` ledger entry for **USD 300** and an `EXPENSE`
  ledger entry for **USD -100**, in the same transaction.
- Changes synthetic airline `cash_usd` by **USD +200** and creates one
  `section9_route_posted_flight_financials_v1` record holding the
  actual revenue and expense ledger IDs.
- On replay returns `complete_game_flight_finance_already_posted`
  with `cashChangedNow:false` and adds no ledger entries or money.

The rollback test installs a synthetic BEFORE INSERT failure trigger
on the flight financial receipt for a **second, independently
prepared and approved** flight. The function attempts to write
revenue and expense ledger entries and update airline cash, then
the receipt insertion raises a deliberate exception. PostgreSQL
rolls back the entire operation; ledger count, airline balance and
flight posting history are unchanged.

All existing database, API, static website and concurrency tests
passed in https://github.com/bracko87/Airlinerra/actions/runs/45208816893.

**Still not certified:** actual signed operated events, fuel burn and
tariff evidence, operational source validation, final settlement racing
against cancellation in a real game-state transition, cross-airline
concurrency and passenger-specific refund authorization. The live
financial tables, money and bookings were not modified. Player
operational cancellation remains disabled.

## Original final settlement versus original cancellation, concurrent on closed flights (2026-11-23)

The disposable PostgreSQL two-session regression
`tests/sql/section9_disposable_real_final_post_vs_cancellation_race.sh`
uses two independently **closed and prepared** synthetic flight occurrences
with valid fixture final-cost approvals. It runs the unchanged
`section9_post_completed_flight_finance_once_v1` and unchanged
`section9_cancel_unflown_occurrence_v1` against the same physical flight
in two scheduling orders:

1. Final finance session begins first, holds the preparation row and
   posts revenue and expense while a concurrent cancellation request
   correctly returns `flight_not_cancellable`.
2. Cancellation attempt begins first, locks the closed occurrence and
   returns `flight_not_cancellable`; the concurrent final writer still
   posts the flight once.

The test verifies **two** new posted flight receipts with matching
USD 300 revenue and USD -100 expense ledger references, original
closed/2-booked occurrences, two intact reservation batches, zero
cancellation receipts and exact cash-versus-ledger balance equality.
All previous full-posting and rollback tests remain green.

CI: https://github.com/bracko87/Airlinerra/actions/runs/45210407030

**Scope:** the original posting and cancellation procedures are executed,
but their signed flight events, fuel, ticket proof and operational approvals
are synthetic. Both flights start already closed, so cancellation is
ineligible from the outset. The test does **not** establish safety for
signed departure/arrival publication competing with an otherwise valid
unflown cancellation, or real operational authorization. Player-triggered
active-flight cancellation stays disabled. No production changes.
