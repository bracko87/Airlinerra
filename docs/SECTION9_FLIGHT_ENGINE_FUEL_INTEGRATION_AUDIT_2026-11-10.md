# Airlinerra — Flight engine ↔ Fuel engine integration audit
Date: 2026-11-10. Repo: bracko87/Airlinerra, main only.

## Verified code / database foundation

| Component | Concrete evidence | Status |
| --- | --- | --- |
| Player schedule creation | server/flight-schedule-service.mjs; Edge airlinerra-flight-schedule-drafts active | API / schema exists, activationAvailable:false |
| Game-day producer | server/section9-scheduled-game-day-producer.mjs; airlinerra_game.section9_clock_producer_due_v1() | private code / DB functions exist; World 1 returns not_configured |
| Clock HTTP handler | server/section9-clock-job-handler.mjs; Edge airlinerra-game-clock-job active | deployed but no corresponding active pg_cron job found |
| Flight candidate selection | server/section9-verified-flight-operations-dispatcher.mjs | reads verified active schedules; not the trusted flight engine itself |
| Trusted operated-flight decision | operationsAuthorizer.confirmActualOperation() required by dispatcher | independent provider not verified as deployed; the dispatcher explicitly fails closed |
| Per-aircraft worker | server/section9-aircraft-operations-worker.mjs, queue DB functions | source and DB exist; no deployed operations worker found in Edge list or pg_cron |
| Signed departures/arrivals | server/section9-operated-flight-movement-ingress.mjs; section9_record_leased_operated_flight_movement_v1() | durable physical state transition path exists but no records yet |
| Financial settlement | server/section9-settlement-preparation-runner.mjs; section9_route_posted_flight_financials_v1 | settlement preparation infrastructure, not automatic flight cash |
| Fuel model | website/flight-fuel-phase-engine.mjs; aircraft_game_fuel_family_v1 | 271 model-specific fuel rates, all game kerosene, no activation |
| NEW fuel/flight seam | server/section9-verified-flight-fuel-bridge.mjs | read-only, source-only adapter requires a database-confirmed arrival with correct occurrence/airline/route/aircraft/destination |

## Live database status (read-only checks)

- airlinerra_game.airline_flight_schedule_drafts_v1: 0 rows.
- airlinerra_game.section9_operated_flight_movements_v1: 0 rows.
- airlinerra_game.section9_route_posted_flight_financials_v1: 0 rows.
- airlinerra_game.section9_schedule_activation_preparations_v1: 0 rows.
- airlinerra_game.section9_schedule_operational_certifications_v1: 0 rows.
- airlinerra_game.section9_aircraft_day_operations_jobs_v1: 0 jobs at inspection.
- airlinerra_game.section9_clock_producer_due_v1(1::smallint): not_configured.
- airlinerra_game.holding_world_clock_v1 for World 1: clock_source not_connected, no confirmed date.
- No currently active pg_cron flight-operations or game-clock scheduler; active pg_cron jobs are weather refresh and used-aircraft auction settlement. Other schedulers cannot be categorically ruled out from this check.
- No fuel accounting enablement has been activated.

## Verified compatibility boundary

The movement ingress confirms:
- status operated_flight_arrival_recorded
- flightOccurrenceId = scheduleId:flightLocalDate:weeklyEntry
- movementRecorded true, replayed false, locationStatus grounded, lastVerifiedAirport matches arrival

The new *read-only* bridge checks the above and matches the flight/schedule/airline to an owner-scoped aircraft and origin, then calls estimateFivePhaseFuel and the universal game kerosene price preview. It returns ARRIVAL_FUEL_DRY_RUN_READY only when evidence is internally consistent.

The bridge deliberately performs ZERO database writes. A synthetic contract test succeeds under GitHub Actions but is not a live signed-flight integration test. This module is not imported into the production movement dispatcher, because doing so before trusted operations and idempotent settlement would be unsafe.

## NOT READY to claim fully operational

1. Independent trusted actual-flight operations authorizer / physical execution engine must be implemented, deployed and authenticated; no fabricated departure/arrival event allowed.
2. Set up signed game clock producer, real calendar schedule and release conditions; test game clock does not advance twice or before World 1 opens.
3. Get a test airline schedule safely prepared/certified/activated with actual permissions, slots, crew, aircraft position and flight timing; never bypass DB gates.
4. Deploy per-aircraft jobs runner, durable leases and real operated movement ingress, proving a complete departure→arrival sequence for one aircraft.
5. Add server-owned fuel stock/uplift/reserves and movement-linked consumption with idempotent once-per-occurrence transaction.
6. Add one-time aircraft/airline financial settlement; no charge should happen when merely saving a route.
7. Run true signed-flight end-to-end tests before activating player traffic or cash.

## Gate

Flight engine *infrastructure exists and supports an explicit integration seam*, but the complete trusted automatic flight engine is not active or proven. DO NOT state it is operating, fully connected or production ready. The new bridge and CI validate technical compatibility only; real aircraft movements and fuel charges are still blocked.
