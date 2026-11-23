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
