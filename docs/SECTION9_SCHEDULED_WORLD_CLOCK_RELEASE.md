# Airlinerra World 1 – Scheduled Game-Day Producer

**Status:** Code and private database schema implemented. World 1 stays **planned**
with no official opening date and no active game clock until intentionally
released by the game operator. No crew salaries, live flight activation,
ticket issuance or commercial settlement is enabled in this integration.

## Clock model

The game operator must first legitimately open World 1 (`state='active'`,
`opens_at` is the real official UTC opening time). The operator then chooses
the first **in-game** calendar date and records a private release reference.
These are distinct from an airline registration date or the date on the
server/browser clock.

Each 86,400 elapsed real seconds after the approved opening timestamp advances
the game by one calendar date. The algorithm uses exact seconds, not local
calendar days, so summer/winter time changes cannot cause double or missed
ticks.

The producer reads the next due day from PostgreSQL only. It signs the
canonical `airlinerra-game-engine-day-v1` HMAC event and calls the existing
signed ingress through the *due-time-checked* SQL function. The clock and
an optional **read-only** demand forecast queue are recorded atomically.
There is no live booking, airline ledger write or payroll posting.

### Actual release checklist (NOT performed automatically)

1. Open World 1 officially, with a verified `opens_at`; do not change
   World1 to active merely for testing.
2. Select its first in-game date and internal game release reference. This
   is a product decision and must be made before opening. The migration
   intentionally does **not** invent either one.
3. From a trusted administration database connection (not the player API)
   configure and review the immutable anchor:

   ```sql
   SELECT airlinerra_game.section9_configure_clock_producer_v1(
     1::smallint, DATE '<approved-in-game-start-date>',
     '<operator-release-reference>');
   ```

   An initially configured producer is **paused**, not automatically active.

4. Set distinct, strong secrets in the hosted function configuration:
   `SUPABASE_DB_URL` (existing private DB URL),
   `AIRLINERRA_GAME_ENGINE_HMAC_SECRET` (dedicated game-engine signing
   secret), and `AIRLINERRA_CLOCK_JOB_TOKEN` (separate scheduled-job
   authentication token). Both secret strings must be at least 32 characters
   and must **not** be committed, displayed to players or logged.
5. After launch approval, enable the schedule through the private
   administration database:

   ```sql
   SELECT airlinerra_game.section9_enable_clock_producer_v1(
     1::smallint,'<operator-release-reference>');
   ```

6. Configure an authenticated Supabase Cron POST to
   `/functions/v1/airlinerra-game-clock-job` with the header
   `x-airlinerra-clock-job-token` read from Supabase Vault.
   A 15-minute schedule is suitable for retries; PostgreSQL will allow a
   tick only when its exact 24-hour opening-relative deadline is due.
   **This deployment does not create a Cron job or set secrets**, because
   no official launch has been approved.
7. Monitor `section9_clock_producer_due_v1(1::smallint)`, verified game
   tick receipts, failed requests, and read-only forecast jobs. Compare
   the private 24-hour elapsed time with the in-game date for multi-day
   and DST boundaries. Only later wire worker execution and salary posting,
   once flight operations and game economy are certified.

## Idempotency, downtime and concurrency

The event ID is stable:
`horizon-world1-day-YYYY-MM-DD`. Repeated deliveries use the same ID and
signature. PostgreSQL has a unique receipt per game day, strict sequential
game-date advancement, and another due-time check inside the transaction.
If two workers race, one commits; the other returns an idempotent replay.

One worker request processes **at most three** due dates, oldest first.
If the scheduler is down for weeks, each later request can catch up in safe
chronological chunks without skipping dates or treating a missed tick as a
second commercial settlement. The private HTTP handler accepts only an empty
body or `{}`; the caller cannot pick a world, date, batch size or wage payment.

World `opens_at` is pinned in the private schedule. Any later change to
this authoritative world-opening timestamp blocks the producer for
administrator reconciliation rather than shifting game time silently.

The hosted handler returns 503 without a private DB URL, signing secret or
Cron token. Unauthorized requests return 401; GET returns 405.

## Source files and tests

- `supabase/migrations/20261109133000_section9_clock_producer_schedule.sql`
- `server/section9-scheduled-game-day-producer.mjs`
- `server/section9-clock-job-handler.mjs`
- `server/section9-clock-job-edge-entry.ts`
- `tests/sql/section9_scheduled_clock_producer_acceptance.sql`
- `tests/test_section9_scheduled_game_day_producer.mjs`

The database fixture uses `BEGIN/ROLLBACK` to simulate an opened world,
approved start date, two-day outage, three sequential dates, refusal of a
fourth early date, replay and changed opening anchor. No fixture survives.

**Separate release blockers:** real flight activation and operating licences,
actual passenger/cargo bookings and ledger settlements, authorized game
salary processing, scheduled read-only demand worker, and 500-player
production concurrency tests.
