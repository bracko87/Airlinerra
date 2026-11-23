# Airlinerra — existing automatic disruption recovery and refund triage (2026-11-23)

## Production read-only findings

Airlinerra already contains private server-side recovery components that must
be reviewed before introducing a replacement recovery/refund subsystem:

- `section9_cancel_with_passenger_recovery_v1(uuid,text)`:
  checks private `postgres` context; uses the automatic-disruption release
  gate; calls connecting passenger recovery before unflown occurrence
  cancellation; returns a rollback-blocked receipt if recovery fails
- `section9_recover_connecting_passengers_v1(text,text,integer)`:
  existing recovery function for connecting itinerary allocations
- `section9_cancel_unflown_occurrence_v1(uuid,text)`:
  locks flight capacity before occurrence, refuses already-operated /
  finance-prepared flights, refuses paid or recognized-revenue reservations,
  and on its successful uncharged path reports `refundUsd:0` and
  `ledgerPosted:false`
- `section9_connection_recovery_receipts_v1`: keyed by
  `source_allocation_key`, uniquely records replacement allocation and a
  JSONB recovery result

At the time of inspection, the `section9_disruption_release_v1` row for
world 1 had all seven flags **true**, including
`automatic_disruption_enabled`, `cancellation_enabled`, and
`connecting_recovery_enabled`.

**Distinction:** the production game may therefore run internally approved
automatic disruption cancellation/recovery. The *player-initiated operational
route cancellation UI* remains explicitly disabled. Do not confuse the two.
The existing internal functions were **read only** inspected here and no
disruption, refund, cancellation or flight movement was triggered.

## Limitations

The existing unflown cancellation function intentionally blocks money-risk
cases: `paid_upfront` or `recognized_revenue_usd != 0` on any reservation.
Its `foregoneTicketQuoteUsd` is not a collected cash amount.
No observed function in this audit establishes a safe automatic cash refund
for such cases. Existing airline financial flight-posting attribution is
insufficient by itself to establish passenger-level payment entitlement.

## New disposable-only research fixture

`tests/sql/section9_disposable_recovery_entitlement_journal.sql`
models a separate, explicitly non-posting decision receipt:

- Unpaid/unrecognized reservation: `no_cash_refund_unpaid`
- Paid upfront or recognized revenue: `requires_manual_payment_audit`
- Same reservation and stable decision key: idempotent replay
- Changed decision or wrong airline: refused
- `authorized_refund_usd` is CHECK-constrained to **zero**,
  `payment_posted` and `ledger_posted` must remain **false**

This is **not a new production table or an authorized refund flow**. The test
runs exclusively on disposable PostgreSQL and performs no live financial
writes. Before any production proposal, reconcile this design with the
existing `section9_connection_recovery_receipts_v1` and internal
cancellation receipt model, define exactly which records are immutable,
and test monetary authorization separately.

## Follow-on release gates

1. Audit the complete existing connecting-passenger recovery worker and
   receipt replay conditions.
2. Verify automatic-disruption concurrency with ticket issuance and actual
   payment posting, including the existing `583729,10041` lock domain.
3. Identify *actual* passenger payment and reversal identifiers, not merely
   quoted fares or an airline's total cash balance.
4. Design an explicit, individually authorized refund process and immutable
   compensating ledger postings, with cross-airline ownership protection.
5. Keep player active-flight cancellation and rescheduling UI disabled until
   separate product release approval.

No live database schema, settings, balances, tickets, or flight schedules
were modified.

## Production recovery writer snapshot and isolated verification (2026-11-23)

The **actual deployed function definition** was fetched read-only with
`pg_get_functiondef` and checked in as
`tests/sql/section9_disposable_original_connection_recovery_writer.sql`.
This is a guarded test snapshot, not a production migration. The function
explicitly:

- Requires `current_user='postgres'`, validates its wait interval,
  checks `connecting_recovery_enabled` and uses
  `pg_try_advisory_xact_lock(583729,10041)`, sharing the disruption lock
  domain with `section9_cancel_unflown_occurrence_v1`.
- Returns a previously stored `section9_connection_recovery_receipts_v1`
  result with `replayed:true` before attempting new passenger changes.
- Rejects missing, non-preflight or cargo-mixed two-leg holds, and
  validates both original flight occurrences and transfer policy.
- Locks affected capacity rows before dated flight rows and checks ticket
  state. If one leg has a ticket and the other does not, it fails closed.
- Uses a replacement flight only after readiness checks. If no replacement,
  it can release eligible unflown seats, preserving the first flown leg.
- Returns `refundUsd:0`, `additionalChargeUsd:0` and
  `ledgerPosted:false`. This is **passenger journey recovery**, not a
  cash refund processing function.

New disposable acceptance
(`tests/sql/section9_disposable_original_connection_recovery_acceptance.sql`)
installed that unchanged function and verified release-disabled behavior,
invalid input refusal, unknown allocation refusal, existing receipt replay,
zero refund posting and revoked browser-facing execution privileges.
A separate two-session regression
(`tests/sql/section9_disposable_original_recovery_disruption_mutex.sh`)
holds the disruption advisory lock in one session and confirms recovery
returns `connection_dispatch_busy`; after lock release it replays the
same previously stored receipt without producing another result or money.

**Scope limitation:** these tests exercise safety gates, concurrency exclusion
and receipt replay. They do **not** certify a full successful rebooking through
all actual flight/transfer-policy/dispatch dependencies, simultaneous
ticket-issuer-versus-recovery races, or cancellation transaction rollback.
Those remain next acceptance milestones. The connected production database
was not mutated.

## Complete second-leg recovery rebooking regression (2026-11-23)

The unchanged, deployed `section9_recover_connecting_passengers_v1` source
was exercised through a successful rebooking transaction on disposable
PostgreSQL 17. The new regression creates controlled original
first/second flight occurrences, a compatible later replacement flight,
transfer policy, timing proof and held capacity. The tested original
itinerary already has two-leg tickets alongside another independent itinerary.

The regression tests two paths:

1. A trigger deliberately rejects insertion of the replacement-flight
   reservation. The original recovery writer raises an exception. PostgreSQL
   rolls back all of its preceding updates: original two-leg bookings and
   seat counts survive, replacement held capacity remains unchanged, and
   no recovery receipt is committed.
2. With that trigger disabled, the writer successfully returns
   `connection_rebooked` and preserves the original first-leg booking,
   cancels only the disrupted second-leg booking, decrements its two
   booked seats while keeping the unrelated two passengers, and issues
   one replacement reservation for the two disrupted passengers. A
   single recovery receipt is stored. Repeating the same allocation
   returns `replayed:true` without additional ticket changes.

No additional fare, refund or ledger posting is created. The original
writer's source is unchanged; its timing, transfer and operational
dependencies are isolated fixtures, not certifications of actual
flights or game policies.

CI run with both jobs passing:
https://github.com/bracko87/Airlinerra/actions/runs/45198144160

Files:
- `tests/sql/section9_disposable_original_recovery_rebooking_acceptance.sql`
- `.github/workflows/airlinerra-readiness-verification.yml`

**Still outstanding:** competing live ticket writer versus recovery
(including both lock-order directions), refund/settlement authorization
and production integration. No live database changes or deployments.
