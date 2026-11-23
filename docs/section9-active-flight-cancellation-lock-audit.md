# Active-flight cancellation lock compatibility — audited 2026-11-23

## Finding

The production booking writers currently use **capacity-inventory-first** and
**dated-flight-occurrence** row locks. The synthetic cancellation transaction
test uses a *schedule-row-first* protocol. It only proves concurrency safety
between two synthetic writers that **both** take the schedule lock first.

Production database functions inspected with `pg_get_functiondef`:

- `airlinerra_game.section9_reserve_verified_game_passenger_seats_v1`:
  explicit `FOR UPDATE OF cap`, then `FOR UPDATE OF o`.
- `airlinerra_game.section9_issue_verified_demand_hold_tickets_v1`:
  deterministic capacity row locking, then `FOR UPDATE OF o`.
- `airlinerra_game.section9_auto_reserve_verified_flight_demand_v1`:
  capacity inventory `FOR UPDATE`, then calls the private seat writer.
- `airlinerra_game.section9_cancel_certified_draft_and_release_slots_v1`:
  schedule row `FOR UPDATE OF s`, but **only** for unactivated drafts;
  it explicitly refuses operated or active schedules.

The three checked booking writers have no explicit parent schedule-row lock.
That observation does not exclude other protections (such as database
constraints, triggers, or locks taken inside called routines). It means the
real concurrent booking/cancellation lock-order proof is incomplete.

## Mandatory gates before deploying any active-flight cancellation writer

1. Review **all** writers of itinerary holds, inventory, reservations, slot
   allocation, flight dispatch, departure movements and settlement, including
   triggers and worker paths.
2. Establish one transactionally consistent lock order across cancellation,
   direct booking, connecting itinerary booking and automatic demand workers.
   The schedule owner/version must be revalidated **after locks** and before
   any slot, occurrence, reservation or finance mutation.
3. Never delete settled flight history, actual movements, recognized revenue,
   tickets, or passenger claims. Develop an explicit recovery/refund/accounting
   journal and check idempotency keys.
4. Validate multi-leg itinerary and cross-airline effects, including race
   tests in **both** writer orders and injected failure between every stage.
5. Test with unchanged production SQL and realistic isolated fixture schemas
   on disposable PostgreSQL, not only `cancellation_lab` mock functions.
6. Keep server response `bookingWriterLockProtocolVerified:false`,
   `canCancelOperationalFlight:false`, and
   `canRescheduleOperationalFlight:false` until a separately reviewed
   production authorization procedure is proven end-to-end.

The current read-only `schedule-change-assessment` is for diagnostics only.
Its counts can change between query and action; it must never be used as a
transactional release approval or authorize editing active flight data.

**Not an approved migration. No production cancellation endpoint or release
toggle is authorized by this document or the synthetic CI tests.**
