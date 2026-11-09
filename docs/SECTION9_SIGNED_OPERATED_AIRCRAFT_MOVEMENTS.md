# Section 9 — signed operated-flight aircraft movements

## What this implements

The game must distinguish a **planned flight** (draft schedule),
a **forecasted flight** (read-only demand calculation), and an
**actually operated flight** (trusted departure or arrival evidence).

The new server-only movement pipeline:

1. Receives a signed **departed** event from a separate trusted
   flight-operations engine.
2. Verifies HMAC-SHA256 using an independently provisioned
   `AIRLINERRA_OPERATED_FLIGHT_ENGINE_HMAC_SECRET` (at least 32 chars).
   This is *not* the clock signing secret or a player JWT.
3. The private database requires an actually active, operationally
   verified schedule with matching version and verified capacity.
   The existing production **draft-only constraints are unchanged**
   and currently prohibit all real departure/arrival records.
4. Requires a verified world opening and game-clock receipt, genuine
   initial delivery inspection and immutable delivery airport,
   in-service physical aircraft, valid original local flight timetable,
   and a matching UTC timestamp within a provisional delay envelope.
5. Locks the physical aircraft row for the full movement transaction.
   It refuses a second departure while in flight, a departure from
   another airport, time reversal, a mismatched arrival, and an arrival
   without a recorded departure.
6. Inserts an immutable signed event and atomically updates the
   aircraft's private movement state. A departure has
   `location_status='in_flight'` and **no ground airport**;
   a verified matching arrival transitions to `grounded` at the
   destination. Source-event retries are idempotent.
7. Performs **no** flight activation, ticket booking, salary posting,
   fuel expense, airline cash/ledger write or real-life tracking.

## Event contract

Only the private game engine calls
`createSection9OperatedFlightMovementIngress({
database, operatedFlightEngineSecret
})`. There is **no browser/player endpoint**, Edge deployment or
public event producer attached.

Event parameters are restricted to:
`worldId:1`, `airlineId`, `scheduleId`,
`scheduleVersion`, `flightLocalDate` (YYYY-MM-DD),
`weeklyEntry` (1..7), `phase` ("departed" / "arrived"),
`actualEventUtc` (second-precision UTC ISO), `eventId`
(immutable unique game engine event ID) and `signature`
(lowercase 64-character HMAC SHA256).

The exact UTF-8 signature message is a newline-separated sequence:

```text
airlinerra-operated-flight-movement-v1
1
<airline-uuid>
<schedule-uuid>
<schedule-version>
<flight-local-date>
<weekly-entry>
<departed|arrived>
<actual-event-utc>
<engine-event-id>
```

The DB does not trust the supplied phase, airport or source blindly:
it derives the physical aircraft, origin/destination and occurrence
identity from the already activated schedule.

## Clock and aircraft semantics

`actualEventUtc` is an **in-game UTC timestamp**, not a real-world
wall-clock timestamp. The event's UTC date requires an actual verified
game-day receipt; it must not be in the in-game future.

Each occurrence identity is
`<scheduleId>:<localOriginDepartureDate>:<weeklyEntry>`.
The engine signs individual departure/arrival events with unique
`eventId` values; the same event cannot move an aircraft twice.

The first departure must originate at the independently approved
original aircraft delivery airport. The airport of each later
departure must match the last verified arrival. An aircraft is never
teleported for a scheduled route, an idle period or a forecast.
Repositioning/ground movement will need its own separately authorized
engine and economy rules; it is not implemented here.

The owner-scoped existing `operations-preview` now shows both
original delivery location and last signed movement:
`aircraftPosition` vs `aircraftMovement`. A last signed ground airport
is a **historical verified location**, not a real-time GPS reading.

## Verification limits

The private pure transition function is tested inside SQL using
synthetic state inputs to verify:
grounded → in_flight → grounded, duplicate departure refusal,
wrong-airport refusal, wrong-flight arrival refusal, monotonic event
timestamps, and no arrival without a departure.

The full database ingestion is tested against an actual *draft*
flight schedule, including a rollback-only simulated opened world
and game-clock receipt; the ingest **must refuse** this draft.
The tests intentionally DO NOT drop or bypass the production
`status='draft'` and `operationally_verified=false` checks.

The successful database commit of a genuinely operated departure and
arrival is **not yet live integration-tested**, because no certified
operational flight source or activated schedule exists. The private
Node signing interface is tested with simulated database responses.
This work alone is therefore NOT proof of full flight execution.

Next: implement genuine commercial flight activation, crew/licence and
traffic-rights authorization, live flight producer, itinerary
bookings and exact-once finance, launch the authoritative game clock,
and run real 500-player database concurrency tests.
