# Section 9 — consolidated commercial flight activation preflight

## Implemented

- New private `airlinerra_game.section9_owned_commercial_activation_preflight_v1(player, airline, schedule, date, days)` composes existing current airport restriction, weekly aircraft rotation, provisional turnaround, recorded slot reservations, inspected aircraft delivery and latest operated-flight location, crew roster proposals, provisional duty/rest conflicts, licence and route-rights evidence, and World 1 signed game-clock readiness.
- The existing authenticated `operations-preview` action now calls this function. It retains the existing operational-preview fields and adds `activationChecklist`, `activationBlockers`, `crewRest`, `aircraftDeliveryPosition`, `aircraftMovement`, `worldClock` and `currentAirportRestrictionCheck`.
- Each request validates airline/schedule ownership and game date, then fails closed if any dependency reports that activation was enabled or mutating.
- Existing `activation-check` API fails closed if its database result unexpectedly says activation is allowed.
- A rollback-only SQL acceptance script tests an actual synthetic draft schedule, ownership rejection and denial of direct browser-role execution. Node tests cover the API wiring and both fail-closed response paths.

## What remains explicitly disabled

This is a **read-only diagnostic**, not an actual activation engine. The following must be independently built and verified before removing `status='draft'` and `operationally_verified=false` database constraints:

1. An engine-owned, atomic schedule release workflow that rechecks the schedule version and ownership, the real game clock, the aircraft's correct current position, all weekly occurrences, runways, curfews, airport slot capacity and minimum ground turnaround (including weekly rollover and DST).
2. A **game** crew qualification, duty and rest certification system with atomic conflict prevention across all weekly routes, not just planned assignments.
3. Grant and revocation policies for operator licences and actual route traffic rights; recorded game evidence is not automatically an operational grant.
4. A private trusted operated-flight event producer, synchronized with the signed clock and the existing signed movement ingestion. No browser departure/arrival endpoint.
5. Bookings, physical occurrence capacity reservations, expenses and exactly-once airline ledger settlement; production-safe recovery, idempotent retries and end-to-end 500-player / large-fleet concurrency tests.

The existing draft-only constraint is unchanged. No fake activated flights, fabricated departure or arrival, bookings or financial postings are introduced.

## Verification

- Applied new function in production in 2026-11-09, with private `SECURITY INVOKER` execution.
- Browser roles `anon` and `authenticated` have no direct EXECUTE privilege.
- Unowned schedule rejected.
- Temporary draft + aircraft tested inside `BEGIN ... ROLLBACK`; preview returned `readOnly=true`, `canActivateNormalFlight=false`, `flightActivated=false`, `movementRecorded=false`, `ledgerPosted=false`.
- After test: zero active schedules, zero movements and zero current positions; existing airline ledger row count unchanged.
- This does **not** validate a real flight activation, successful departure/arrival or multiplayer throughput.
