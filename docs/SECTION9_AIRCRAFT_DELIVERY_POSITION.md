# Section 9 – Aircraft initial position from approved delivery

This development closes one specific operational evidence gap:
**where was this aircraft first delivered?** It does not yet provide
**where is this aircraft now?** or activate flights.

## Private source of truth

A private, immutable database anchor
`airlinerra_game.section9_aircraft_delivery_position_v1` can be created
only if ALL of the following are true:

- World 1 has really opened and its game clock is authenticated and connected.
- Aircraft is in this airline's real fleet, in service, and its registration
  and configuration match the acquisition order.
- The acquisition order is for an offer released under the approved
  aircraft-market game pricing basis, and is in
  `delivered_pending_inspection` status after delivery due time.
- An existing matching delivery inspection is `approved`, with a
  reviewer reference and reviewed timestamp already in the past.
- The location is **copied from that order's approved delivery airport**.
  Neither a player nor a caller may supply or change an airport/game date.
  The source game date comes from the verified game clock.

Internal invoker-only functions:

```sql
SELECT airlinerra_game.section9_capture_approved_delivery_position_v1(
  '<actual-airline-id>'::uuid,'<actual-aircraft-inventory-id>'::uuid);

SELECT airlinerra_game.section9_sync_approved_delivery_positions_v1(25);
```

They are private/server-only. The bounded sync is a separate optional
worker and **is not scheduled** while the clock remains disconnected.
No browser direct SQL privileges, no public API and no fee/finance changes.

## First-departure validation

The protected existing `operations-preview` route now includes
`aircraftPosition`, computed by
`section9_owned_aircraft_delivery_position_preview_v1`:

- Finds the earliest scheduled departure across **all weekly routes
  assigned to the same physical aircraft**, starting from its immutable
  delivery game date, not an arbitrary later browser date.
- Checks that first planned departure's airport matches the approved
  delivery location; reports exact mismatches.
- Detects invalid weekly entries, unknown airport time zones and invalid
  daylight-saving local departures.
- Requires owner-scoped access to the underlying aircraft and schedule.
- Reports original delivery position separately from current position.
  `movementHistoryVerified=false` and
  `currentAircraftLocationVerified=false` remain mandatory.

The first-departure result is useful for validating game route plans.
It **never proves later flights operated or the aircraft moved**, and
`canActivateNormalFlight` remains false even for a matching airport.

## What remains before commercial activation

- Authoritative operated-flight events, each linked to physical
  aircraft, flight occurrence, airline, origin, destination, operating
  dates/times and verified final state; every accepted arrival must
  advance the same aircraft location without teleporting.
- Verified ground repositioning if the game will support it, with
  realistic travel time/cost/operational rights. No free relocation.
- Actual operating licence and traffic-rights approvals, crew
  qualification/rest and operational airport slots.
- Verified game-clock operations, passenger/cargo booking and
  exact-once ledger settlement, 500-player database load testing.

The Supabase production database currently has no acquisition orders
or approved deliveries, no owned aircraft and no flight schedules.
**Do not manufacture delivery approvals** merely to clear checks.
The SQL test uses an already released market offer and runs completely
inside a rollback transaction.
