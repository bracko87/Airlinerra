# Airlinerra — non-binding cabin refit quotes, release status (2026-11-10)

## Completed (verified)
- Created `airlinerra_game.cabin_refit_prepared_quotes_v1` and `prepare_owned_cabin_refit_quote_v1` in Supabase project `hwllkabgzaynalahvkpz`; additive migration `20261110212000_airlinerra_refit_preparation_quotes_v1.sql`.
- Each quote is calculated on the server from **the airline's own saved cabin design**, supported seat types, model space and approved *planning* facility; estimated new equipment and removal/installation are separate, including site multiplier. The snapshot, estimate, 24/48-hour downtime and client retry/request ID are retained.
- A valid, authenticated, current airline owner must request it through protected Fleet API action `cabin-prepare-quote`. Player ID is taken from verified bearer token, never the request body. Database function uses SECURITY INVOKER, ownership and active membership checks; the table and function are denied to public/anon/authenticated direct access.
- Aircraft-profile dialogue now offers **Prepare refit quote (no booking)** after the user saves the cabin proposal and picks a type-matched facility. It sends only aircraft/airline/site/request IDs, **never a claimed price**. Existing save-proposal behavior remains.
- New refit quote table stores only `prepared_not_booked` status: cannot charge airline cash, create a maintenance appointment, ground aircraft, alter installed seats, or post to airline ledger. No cron or automatic processor is attached.
- Deployment: `airlinerra-fleet-acquisition` Supabase Edge function **v16**, ACTIVE; JWT is freshly checked by the hosted verifier in application logic, as in the previous deployed version. The dedicated cabin and aircraft-profile GitHub workflows passed on commit `7dd658eb09c76b428072a1b1cfc86003f34c88d2`.
- Direct role ACL checks returned false for authenticated INSERT, anonymous SELECT and authenticated EXECUTE. Unauthorized owner test was rejected. Live verification immediately afterward: 0 prepared quotes, 0 refit planning records, 1 existing installed cabin, 0 EXPENSE ledger entries. No test-plane live changes.

## NOT completed (do not mark as live)
1. **Browser acceptance test:** log in as the invited account; select A319; save a design; choose a type-specific facility; prepare quote; reload and verify. This has not been independently browser-tested in the user's session.
2. **Provider appointment capacity and scheduling:** the current `cabin_refit_facility_types_v1` list means model-level *planning* compatibility, not confirmed availability or real approval. Need time slots and collision protection with maintenance checks and booked flights.
3. **Trusted aircraft positioning:** only accept current position from independently verified movements. Require physical arrival at that provider; no teleport or phantom flight.
4. **Authoritative game-minute clock:** the clock producer is configured but the World 1 readiness view still says `clock_source=not_connected` and `authoritative_clock_connected=false`. A calendar date alone is not enough to complete 24/48 in-game hours.
5. **Atomic paid refit transaction and completion:** before activation, confirm operator/aircraft/draft/source, freeze price, reserve slot, lock aircraft and funds, debit exactly once, ground for validated duration, validate work completion, apply the saved seat-type/count/legroom to `aircraft_installed_cabins_v1`, update fleet status and release. Roll back entire transaction on failures and make retries idempotent. None of this currently runs.
6. **Passenger booking effects:** `section9_installed_cabin_comfort_v1` and the Section 9 network passenger allocation simulation already implement a verified installed-cabin-only ±1.5% adjustment, with no cargo/draft effect. Real booking requires trusted verified flight operations, currently not released.
7. **World 1 release:** live flight readiness still reports 0 active schedules, unconnected clock, no trusted flight execution release and no automatic settlement. Do not force these flags or invent flight evidence.

## Acceptance needed before calling the full feature complete
- Tests for two airlines (owner vs non-owner), no-slot, wrong location, schedule conflict, insufficient funds, duplicate booking request, repeated worker completion, quote changed after drafting, interrupted worker, post-refit seat/comfort changes, no unrelated account or flight changes.
- One controlled end-to-end flight into an approved facility, real refit with **one** expense ledger debit, exactly one completed installation, correct in-game downtime, and restored operability. Followed by one trusted passenger allocation where a newly installed comfort rating changes allocation, while drafts do not.

No payment or refit was activated in this work.
