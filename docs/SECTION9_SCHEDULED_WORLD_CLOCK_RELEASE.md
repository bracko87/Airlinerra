# Airlinerra World 1 — real-time Berlin clock
**Current implementation verified 2026-11-11.**

## Correct game clock rule
World 1 follows **the actual real-world time in Europe/Berlin, 1:1**.
At 09:28 on 11 November in Germany, game time is also 09:28 on 11 November.
This is independent of the manager's local device timezone and does not
speed up, slow down or start over when a user logs in.

- UTC is kept as the underlying absolute instant.
- `Europe/Berlin` controls the displayed date/time and daily boundaries.
- Each second of real time equals one second of game time, including minutes
  and hours. The client interpolates from a trusted PostgreSQL time sample,
  not the device wall clock; it refreshes calibration every 60 seconds.
- A game date changes at **00:00 Berlin local time**, not at the old 17:40
  Berlin opening-anniversary time.
- PostgreSQL's timezone rules automatically handle 23-hour spring and
  25-hour autumn transition days. Do not add a fixed +1 or +2 UTC offset.
- The user-facing time continues to advance without database writes every
  second. The signed daily receipt is recorded at the first due cron run,
  normally within one minute of Berlin midnight.
- The approved World 1 opening timestamp, original 10 Nov receipt and
  immutable game history are preserved. Never rewrite old receipts.

## Components
- `airlinerra_game.section9_live_berlin_clock_v1(1)` — read-only server UTC
  sample, Berlin local date/time, fixed zone and 1:1 clock mode.
- `server/section9-world-time-edge-entry.ts` — dedicated public
  read-only `airlinerra-world-time` Edge function. GET only, no payments,
  player details, airline ledger, or mutable state.
- `website/world-time-client.mjs` — uses the trusted UTC sample and browser
  monotonic elapsed time to render the live clock; resynchronizes every 60 s.
  The `player.html` global header displays it on invited-account access.
- `airlinerra_game.section9_clock_producer_due_v1` — checks signed daily
  tick due based on Berlin *calendar date* and midnight in Berlin; still
  requires the approved active world/opening anchor.
- `airlinerra-section9-world1-clock-v1` — cron checks every minute. It uses
  the secure token in Vault and posts to the signed World 1 clock worker
  **only when a day is due**. Repeat events are idempotent and do not
  advance a date twice.

## Evidence and safety
On 11 Nov 2026:
- Live database server clock returned 09:31:55 Berlin on the same day.
- Daily due became 2026-11-11 at 2026-11-10T23:00:00Z (local midnight).
- The authorized worker accepted 11 November via HTTP 200, with 1 new
  immutable receipt, bringing recorded receipts to 2.
- A later due query returned `caught_up`.
- Spring and autumn DST check yielded 23-hour and 25-hour local dates.
- The public read-only time function returned HTTP 200 with the correct
  Berlin time through the live Edge function.
- The cron minute schedule was verified as active.
- No flight bookings, payroll, fuel settlement or airline cash transfers
  were activated by any clock changes. Independent flight activation
  remains `NOT_ACTIVATED`, with no active flight schedules.

## Deployment caveat
GitHub `main` contains the site header and client. The Supabase clock
endpoint and migrations were applied independently of Netlify. The public
Netlify site must build/publish the newest main commit before the new header
appears on airlinerra.com. A GitHub build success does not prove Netlify
production has refreshed.

## Historical note
The previous design advanced one date every 86,400 seconds **after the
world's opening time**, yielding a late-afternoon day switch. That model
was superseded by the owner's explicit 1:1 Berlin current-time requirement.
Do not restore the old elapsed-seconds behavior.

## Verification
- `tests/test_berlin_world_clock.mjs`
- `tests/sql/section9_berlin_realtime_clock_acceptance.sql`
- `supabase/migrations/20261111093000_section9_berlin_realtime_clock.sql`
- `supabase/migrations/20261111094000_section9_berlin_clock_minutely_dispatch.sql`
