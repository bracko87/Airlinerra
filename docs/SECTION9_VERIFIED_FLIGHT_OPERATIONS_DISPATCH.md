# Section 9 — verified flight operations dispatch foundation

## Implemented — 9 November 2026

The private read-only Supabase function `section9_operated_day_candidates_for_aircraft_v1(airline, aircraft, game_date)` identifies possible departure and arrival events for one physical aircraft and a verified game day.

It refuses an unopened World 1, unverified/future game dates, unavailable fleet, schedules that are not BOTH active and operationally verified, missing version-matched capacity, unapproved delivery, unknown timezone, malformed timetable and ambiguous/nonexistent departure times. It expands a bounded origin-local window covering the requested UTC game day, including flights lasting up to 72 hours, and sorts events chronologically for that aircraft.

**A candidate is not an actual movement.** The function neither signs nor inserts events, and only private backend database roles can execute it.

A new source-only Node module, `server/section9-verified-flight-operations-dispatcher.mjs`, accepts these candidates only after a separately provided trusted flight-operations authority confirms **each actual departure or arrival**. A verified decision must identify the same physical occurrence, include a durable reference and an actual in-game UTC event timestamp. It signs each event with the distinct flight-operations HMAC secret and submits it to the existing private signed movement ingestion. Missing or invalid decisions, misordered events, wrong-day timestamps or rejected database movements halt processing of that aircraft. It does not activate flights, sell tickets, post expenses or credit revenue.

There is no player API, browser access, Cron job, automatic operations authorization or deployed dispatcher.

## Tests and status

- Rollback-only SQL acceptance tested unopened world, draft-only aircraft and unverified future game day. All produced zero candidate movements; no ledger, active flight or aircraft location write occurred.
- Unit tests verify individually authorized departure and arrival, signed-event data, retry idempotency, rejection when a departure is blocked, forged candidate identity, reordered events, absent actual evidence and wrong-day timestamps.
- Focused route planner CI now checks the module syntax and tests; GitHub PR carries the file until verified and merged.
- The live draft-only schedule constraint is deliberately untouched. No positive, real operated-flight SQL transaction was manufactured.
- Source batches are capped at 250 schedules / 500 event candidates per aircraft per game day. This is **not** proof of production 500-player throughput.

## Necessary next dependencies

1. Genuine engine-owned commercial flight activation with atomic verification of game crew, licences and route permissions, airport capacity, aircraft position and rotation and explicit release.
2. A trusted game flight-operations decision source, recording durable per-flight decisions, delays, cancellation/recovery and properly handling cross-UTC-day events.
3. Durable per-aircraft worker leases and sharded retry queues, to prevent different workers from processing a physical aircraft out of order.
4. Passenger and cargo bookings, flight operating costs, exactly-once ledger settlement, failure/replay tests and 500-player full system load testing.

Until those exist, this code is a protected execution *foundation* only, not live commercial flight execution.
