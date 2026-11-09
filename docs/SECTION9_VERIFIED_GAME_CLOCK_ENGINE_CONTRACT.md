# Section 9: verified game-clock event ingress (World 1)

## Purpose
World 1 ("Horizon") is still **planned**. Its `holding_world_clock_v1`
has `clock_source='not_connected'`. The demand engine needs the **game's**
current date from a trusted game engine before forecast queues and future
crew-payroll workers can operate. A browser clock, the server's wall-clock date,
a player's login date and an airline's registration timestamp are **not**
valid substitutes for the game's in-world date.

The implementation in
`server/section9-verified-game-clock-ingress.mjs` accepts a signed
trusted-engine day event and, in one SQL transaction:

1. Requires World 1 to be `active` with a real `opens_at` in the past.
2. Validates an HMAC-SHA256 signature *in the private Node backend*, using a
   dedicated engine-event secret delivered through protected server config.
3. Writes an immutable event receipt and advances the existing
   `holding_world_clock_v1` date by **exactly one game day** (except the first
   trusted anchor date). Exact retries do not advance again; altered
   signatures, event IDs, skipped days and backdated events are rejected.
4. Enqueues a **read-only** Section 9 demand forecast for the verified date
   only if the existing production flight-activation and capacity proofs are
   already present. The tick and optional enqueue are transaction-atomic.
5. Never posts payroll, credits or debits airlines, creates tickets, changes
   the flight-activation gate, or invents an active world.

All new DB tables/functions are private and RLS-protected. The clock ingress
is not a browser endpoint.

## Contract for an actual future engine producer

The trusted game engine, **not a player**, must supply:

- `worldId`: number `1`
- `gameDate`: strict `YYYY-MM-DD` in-game date from the engine
- `eventId`: unique immutable engine tick ID, 12–128 permitted characters
- `signature`: lowercase hex HMAC-SHA256 of the UTF-8 message below

```text
airlinerra-game-engine-day-v1
1
YYYY-MM-DD
engine-event-id
```

The private backend constructs
`createSection9VerifiedGameClockIngress({database,gameEngineHmacSecret})`
with a secret of at least 32 characters obtained from its dedicated secure
backend configuration (never sent to the browser, stored in SQL, logged, or
committed). It calls `acceptEngineTick(event)` when the authenticated engine
emits its day event. The adapter rejects invalid signatures *before* opening
a database connection.

The producer must also establish and test the agreed **one real day =
one game day** cadence, opening-day anchor, downtime catch-up policy, and
crash-safe delivery. The adapter guarantees sequence and idempotency but
does not invent a cadence, a launch date or an engine source.

## Current intentional release gate

There is no connected, authenticated engine producer yet, and all three
Worlds are planned without an opening date. This code **does not start a
clock** on deployment. Do not change `holding_world_clock_v1` or set a
fictional `opens_at` to make tests green.

Once World 1 is legitimately opened and the engine event source is connected,
verified game-day ticks may trigger **read-only** demand jobs. Processing those
jobs requires a separately deployed, scheduled Section 9 backend worker.
Automatic paid salaries, actual flight bookings, commercial settlement and
full 500-player real database stress tests remain separate release gates.

Use the private diagnostic
`SELECT airlinerra_game.section9_world_clock_dispatch_readiness_v1(1::smallint)`
to inspect current readiness without mutating the clock.

## Verification

`tests/sql/section9_verified_game_clock_acceptance.sql` runs entirely
inside `BEGIN/ROLLBACK`. It temporarily simulates an opened world, verifies
the first and next clock tick, refusal of altered/reordered ticks, and
zero money or flight-demand writes when no verified commercial flights exist.
The fixture never persists fictional world activation.

`tests/test_section9_verified_game_clock_ingress.mjs` exercises HMAC
validation, tampering, expected SQL parameters, replay, planned-world
blocking, rejected unsafe response claims and connection cleanup.
