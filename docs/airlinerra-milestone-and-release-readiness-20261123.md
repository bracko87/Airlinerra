# Airlinerra — development milestone and remaining-work overview
_Date: 2026-11-23. Development branch: `phase-14h-crew-integration`._

## What is confirmed by this branch's verification suite

- Certified synthetic FRA–MUC round-trip activation, rollback on either leg,
  replay and booking-capacity safety. Fixtures are synthetic; not operational
  certification of actual fleets or airports.
- Unchanged direct passenger booking and real two-leg demand-conversion
  workflows, including reviewed *undeployed* ticket-writer correction,
  worker locking and independent overlapping-itinerary races.
- Original connecting-passenger recovery function: permitted recovery,
  replacement of disrupted second leg, rollback on ticket insertion failure,
  replay, concurrency with a connecting-ticket issuer in both orders.
- Original unflown cancellation function: safely refuses operated,
  financially prepared, revenue-recognized and upfront-paid reservations.
  The player-initiated active-flight cancellation endpoint remains disabled.
- Original final financial posting: isolated full USD 300 revenue / USD 100
  expense / USD 200 cash-delta receipt, stable replay and transaction rollback
  on an injected receipt-write failure. Also tested posting mutex and original
  posting versus original cancellation on preclosed prepared flights in both
  session orderings.
- Owner-scoped read-only cancellation assessment surfaces booking/financial
  blockers; website and backend static builds and regression tests are green.

## Boundaries on what the tests mean

The CI database is disposable PostgreSQL 17 and uses synthetic signed
operational evidence for many cases. Passing tests does **not** imply
production deployment, working real-world flight/crew/fuel proof, or
complete player-facing gameplay. The candidate two-leg ticket bug fix is
in `supabase/migration_candidates/`, not an applied migration. No live
airline balances, flights or bookings were changed by these tests.

The latest verified CI run is
https://github.com/bracko87/Airlinerra/actions/runs/45210407030 .

## Prioritized outstanding work

1. **Signed movement versus cancellation:** independently test the real
   signed departure and arrival publication functions against unflown
   cancellation. Detect and correct any non-atomic boundary between state
   transition, signed movement, capacity and cancellation.
2. **Real arrival-to-money chain:** integrate signed engine events,
   measured fuel receipts, approved final costs, ticket reconciliation and
   the actual money writer, rather than mocked evidence. Include rollback,
   replay, mid-flight changes and interruption scenarios.
3. **Connecting-ticket deployment decision:** review the private writer
   correction, ensure production migration safety, reviewer approval,
   rollback procedures and security audit before installation.
4. **Refund eligibility:** trace actual collection/refund identifiers,
   design approved compensation journal and test idempotent passenger
   recovery. A quoted fare is not an actual refunded payment.
5. **Player-facing operations:** audit each UI entry point against real,
   authorized backend actions. Prioritize working schedule/route list,
   booking status, availability, operations and finance evidence in the
   game UI. Do not expose held/cancelled operational controls prematurely.
6. **Broader release validation:** airport group activation, fleet/crew/
   maintenance/fuel rules, security and permissions, live world-clock
   scheduling, economics and real player end-to-end journeys must pass
   acceptance. Verify independent features instead of inferring readiness
   from section-9 CI.
7. **Production release:** maintain a reviewed staging rollout, regression
   and reconciliation checks, operator approvals, deployment/rollback
   plan and monitored post-release game-control center.

## What is and is not ready to release

**Ready for continued development and review:** the verified isolated
regressions and the read-only owner-scoped safety evidence.

**Not approved for public activation:** player active-flight cancellation,
refund execution, the reviewed connecting-ticket writer migration and
the unverified real movement-to-settlement production lifecycle.

No reliable total-project completion percentage can be inferred without
a feature-by-feature production UI and gameplay acceptance audit.

## Newly identified signed-movement versus cancellation hazard

On 2026-11-23 the actual deployed source of
`section9_record_signed_operated_flight_movement_v1` was inspected.
It checks dated-flight cancellation through a plain `SELECT` of
`booking_status` and later inserts an immutable operated-movement
event. The original `section9_cancel_unflown_occurrence_v1`
locks capacity and occurrence `FOR UPDATE`, but has no common
aircraft lock with movement publication. The deployed movement table's
only user trigger protects UPDATE/DELETE, not INSERT based on the
current dated-occurrence status.

The disposable test
`tests/sql/section9_disposable_movement_vs_cancellation_gap.sh`
reproduced the unsafe **protocol** interleaving: a read of `open`
without a row lock, then a successful original cancellation, followed
by insertion of a synthetic departure record, leaving a cancelled
occurrence with a departure event. It then tested a proposed
`FOR SHARE OF o` occurrence read lock in both operation orders and
showed they serialize safely with the original cancellation
`FOR UPDATE` lock. The signed movement writer itself was not
invoked end-to-end in this reproduction.

All readiness tests passed including the expected unsafe-protocol
reproduction: https://github.com/bracko87/Airlinerra/actions/runs/45211678543

An **undeployed review-only** patch was created at
`supabase/migration_candidates/20261123_section9_signed_movement_cancellation_row_lock_review.sql`.
It changes the source read to take `FOR SHARE OF o`, verifies an
exact old-source segment before replacement, and revokes browser-role
execute privileges. It is not merged into the migration directory.
The candidate still requires full signed-event, aircraft lock-order,
capacity, event replay and cancellation/recovery transaction audit
before it can be approved for production.

**Release consequence:** signed movement/cancellation consistency is a
known blocker. Do not enable player active-flight cancellation or
claim complete live flight publication safety until this is resolved.

## Signed movement candidate: original function compilation verified

Additional verification completed 2026-11-23: the unchanged, read-only
retrieved production function is preserved in
`tests/sql/section9_disposable_original_signed_movement_writer.sql`.
In a disposable PostgreSQL 17 acceptance test,
`tests/sql/section9_disposable_signed_movement_patch_compile_acceptance.sql`,
the exact reviewed source patch was applied to that original function.
The test confirmed:

- The original booking-status SELECT is replaced with exactly one
  `FOR SHARE OF o` occurrence-row lock.
- The cancellation exclusion, movement replay conflict and movement
  storage logic remain present in the patched function.
- Client-facing `anon`, `authenticated`, and `service_role` roles
  have no function execution privileges.
- All previous transactional booking, recovery, accounting and
  frontend regression suites remain green.

CI: https://github.com/bracko87/Airlinerra/actions/runs/45212956436

**Status:** patch *compilation and original-function source integrity*
are verified, but this still does **not** exercise an authenticated,
signed, end-to-end live aircraft departure/arrival with HMAC and
movement event insertion. The earlier concurrency proof exercises
the row-lock/INSERT protocol using a simplified movement publisher,
not the entire original signed writer. The candidate remains
`supabase/migration_candidates/` only; it has **not** been deployed.
Aircraft/occurrence/capacity lock ordering and complete signed
movement interactions require additional end-to-end approval.

## Real signed-movement HMAC authorization acceptance (2026-11-23)

The test `tests/sql/section9_disposable_signed_movement_hmac_acceptance.sql`
now invokes the actual production-derived signed movement function **after**
the review-only occurrence-row-lock candidate has been compiled into the
disposable test database. The fixture sets up a synthetic 80-character
secret in a disposable `vault.decrypted_secrets` view, with `pgcrypto`
`extensions.hmac` so the function's real canonical event signing path
executes, not a mocked HMAC procedure.

The regression proves that an event ID changed after signing is rejected
as `SECTION9_MOVEMENT_EVENT_SIGNATURE_INVALID`, while a correct
canonical signature is accepted past the HMAC check and receives
`blocked_unreleased_movement_engine` because the operational release
remains intentionally disabled. Neither case records any flight movement.
All readiness regressions and the static website build pass.

Verified CI:
https://github.com/bracko87/Airlinerra/actions/runs/45214067133

**Remaining limitation:** the release gate is purposely disabled. This
does not yet run a fully released signed movement through authoritative
clock, aircraft availability, verified timetable, delivery position,
movement event insertion or cancellation competition. The candidate
must not be applied to production solely based on HMAC and source-patch
tests; a full signed operational acceptance and lock-order review remain
open release requirements.

## Signed departure/arrival and actual cancellation concurrency — completed lab milestone

On 2026-11-23 two new disposable PostgreSQL 17 acceptance tests
successfully invoked the **production-derived private signed movement
writer** with the review-only occurrence-row-lock correction installed
in the disposable test schema:

- `tests/sql/section9_disposable_real_signed_departure_arrival_acceptance.sql`
  supplies only synthetic world clock, airport timezone, approved
  aircraft-location evidence, capacity verification and flight-dispatch
  helpers, while the original movement writer itself validates the
  canonical SHA-256 HMAC and writes **actual two-phase departure and
  arrival records** and aircraft-position updates. Replays of both
  signed events produce no duplicate movements; the aircraft ends
  grounded at its verified synthetic destination.
- `tests/sql/section9_disposable_real_signed_departure_vs_cancellation_race.sh`
  exercises the **actual private movement writer and actual private
  unflown cancellation writer** from separate PostgreSQL connections.
  Both row-lock orderings were tested. Movement-first records exactly
  one signed departure and refuses subsequent cancellation as
  `flight_already_operated_or_settled`. Cancellation-first creates
  exactly one cancellation receipt, then the signed movement writer
  raises `SECTION9_CANCELLED_OCCURRENCE_MOVEMENT_FORBIDDEN` and
  creates **no** signed departure. Final assertions forbid a cancelled
  and departed state for either test flight.

Both jobs passed in
https://github.com/bracko87/Airlinerra/actions/runs/45217264962

These tests substantially strengthen confidence in the guarded
`FOR SHARE OF o` candidate and resolve the previously demonstrated
protocol gap **under the tested synthetic conditions**. They do not
make the patch a deployed production migration: full deployment
approval still needs aircraft/fuel/crew lock ordering review,
production-schema staging with actual signed sources, operational
worker replay and rollback strategy, and live-flight diagnostics.
The reviewed correction remains in `supabase/migration_candidates/`
and player-initiated active-flight cancellation remains disabled.

## Production-source compatibility and migration drift guard (2026-11-23)

The review-only signed-movement occurrence-lock correction now requires
the **full original `pg_get_functiondef` MD5 fingerprint**
`b796a2705d3a9eda3de5208cbbd6f77a` before applying its precisely
anchored `FOR SHARE OF o` change. This fingerprint was obtained through
a **read-only** query of the currently deployed original function. It
does not rely on a target substring alone; any unrelated source change
must cause the candidate to refuse execution pending review.

The new disposable two-session/DDL safety regression
`tests/sql/section9_disposable_signed_movement_source_drift_guard.sh`
confirms that:

- The reviewed original function installs and the patch still applies.
- Attempting the same patch a second time fails closed, and the
  previously patched function remains unchanged.
- An unrelated but syntactically valid edit to the original function
  outside the targeted cancellation-status `SELECT` is detected and
  rejected with `REVIEW_CANDIDATE_MOVEMENT_ORIGINAL_SOURCE_MISMATCH`.
- Rejected patches leave function source untouched. Restoring the
  expected original source allows the reviewed patch again.

The same CI run passed full synthetic signed departure and arrival,
HMAC verification, real cancellation-versus-signed-departure races
in both lock orders, financial settlement and all website/API
regressions:
https://github.com/bracko87/Airlinerra/actions/runs/45220614399

Lock ordering inspected from the currently deployed source: the
signed-movement function takes a verified schedule `FOR SHARE`, then
the aircraft inventory `FOR UPDATE`, then (with this **candidate**
only) the dated flight occurrence `FOR SHARE`. Unflown cancellation
takes the disruption advisory key, capacity inventory `FOR UPDATE`,
then the dated occurrence `FOR UPDATE`. Their common dated-row lock
serializes the two direct cases proven by CI. This is **not** a proof
of an acyclic global lock graph for all dispatch, crew, fuel,
maintenance and itinerary workers; that review remains outstanding.

The migration candidate and all test-only modifications remain on
`phase-14h-crew-integration`. No production deployment, activation,
booking change, cash movement or live cancellation occurred.

## Aircraft/maintenance-style lock versus signed departure and cancellation (2026-11-23)

A new three-connection disposable PostgreSQL 17 regression
`tests/sql/section9_disposable_fleet_lock_vs_signed_movement_cancellation.sh`
exercises a cross-worker ordering not covered by the prior direct
signed-movement-versus-cancellation races.

An independent transaction simulates an aircraft maintenance writer's
`airline_aircraft_inventory FOR UPDATE` lock, held through a scheduled
critical section. The **actual patched signed movement function** is
then invoked with a canonical synthetic HMAC and valid fixture
operational evidence; the test observes it **blocked server-side** on
the aircraft row via `pg_blocking_pids`. While it remains blocked,
a third connection invokes the **actual private cancellation writer**,
which succeeds and creates its cancellation receipt. After the fleet
row lock is released, the original signed-movement writer rechecks
the occurrence using the reviewed `FOR SHARE OF o` lock and raises
`SECTION9_CANCELLED_OCCURRENCE_MOVEMENT_FORBIDDEN` without inserting
a departure record. Final assertions require the flight to be
cancelled with exactly one cancellation receipt and zero movement
records.

The same run included all previous signed departure/arrival and
accounting, booking, recovery and frontend tests, all green:

https://github.com/bracko87/Airlinerra/actions/runs/45222941422

### Source-based lock-order notes

The read-only deployed source review shows:

- `section9_record_signed_operated_flight_movement_v1`: schedule
  `FOR SHARE`, aircraft inventory `FOR UPDATE`, existing movement
  replay check, then reviewed candidate occurrence `FOR SHARE`,
  followed by aircraft-position `FOR UPDATE`.
- `section9_cancel_unflown_occurrence_v1`: advisory disruption lock
  `(583729,10041)`, capacity inventory `FOR UPDATE`, occurrence
  `FOR UPDATE`, and then guarded booking/receipt changes.
- `section9_verify_game_fuel_before_departure_v1`: locks the
  aircraft fuel-custody row `FOR UPDATE` after verifying the flight,
  aircraft and available capacity context; this is called by the
  automatic dispatch worker prior to movement publication.
- `section9_capture_dispatched_crew_v1`: locks the airline record
  `FOR UPDATE` during crew capture. The automatic dispatch worker
  calls it after signed movement publication within its flight-event
  workflow.
- `section9_owned_game_maintenance_job_v1` and
  `section9_book_ai_maintenance_v1` acquire the aircraft inventory
  row `FOR UPDATE`. The latter may also lock the airline row.

The maintenance-style row-lock test proves **one actual blocked fleet
lock order**; the maintenance holder itself is deliberately a row-lock
simulator, not an invocation of a full paid maintenance job. No real
crew rotation, refueling, maintenance charge or production movement
was performed. A complete deadlock graph still requires checking
nested helper calls, fuel-custody and airline lock interactions,
rollback triggers and real scheduler transaction boundaries.
Neither the candidate movement patch nor player-initiated active
flight cancellation is released to production.
