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

## 2026-11-10 continuation: real flight-phase core and release evidence groundwork

The following was implemented on GitHub `main`, not deployed as a
production flight operator:

- `server/section9-flight-phase-timeline.mjs`: deterministic five-phase
  *simulation projection* (taxi out, climb, cruise, descent, taxi in). Takes
  an aircraft/schedule identity, model-specific fuel rates and scheduled UTC.
  Provides projected phase boundaries, burn and optional game-time progress.
  Handles short routes and UTC rollover, but never issues a physical
  movement certification or charges money.
- `server/section9-independent-flight-operation-authorizer.mjs`: HMAC verifier
  for an *independent* trusted flight engine's signed attestation. It plugs
  into `section9-verified-flight-operations-dispatcher`'s existing
  `operationsAuthorizer.confirmActualOperation` contract. Without signed
  independent proof it returns `unverified_operation`.
- `server/section9-independent-operation-evidence-reader.mjs`: strictly
  identity-scoped SELECT-only SQL adapter that looks up durable independent
  attestations in the private DB. It cannot sign, insert or invent proof.
- `server/section9-verified-flight-fuel-bridge.mjs`: if a trusted route
  provides scheduled departure UTC, its read-only arrival inspection now
  attaches a projected five-phase timeline.
- New **private read-only** operational audit view:
  `airlinerra_game.section9_flight_engine_readiness_audit_v1` (migration
  `20261110235950_section9_flight_engine_readiness_audit_v1.sql`).
- New **private, currently empty** attestation table:
  `airlinerra_game.section9_independent_operated_flight_evidence_v1`
  (migration `20261110235955_section9_independent_operated_flight_evidence_v1.sql`).
  Table uses exact occurrence/phase identities, event uniqueness, phase-time
  constraints and row-level security. Anon/authenticated have **no SELECT**;
  service_role can **SELECT**, but has **no INSERT**. No signer deployed.
- CI: `Airlinerra flight phase execution (isolated)` run 42869308110 passed,
  including syntax, phase timeline, signed attestation/dispatcher mock
  composition, evidence read, arrival/fuel bridge and protected web build.

### Live DB observation after this continuation

- World 1 `state=active` with official opening 2026-11-10 16:40:21 UTC,
  **but** World 1's clock remains `not_connected` and
  `section9_clock_producer_due_v1(1)` reports `not_configured`.
- 0 saved / active flight schedules; 0 operational certifications;
  0 aircraft operation jobs; 0 verified movement events;
  0 settled flight transactions; 0 attestation records.
- 271 positive fuel-planning profiles and 271 universal kerosene GAME categories.
- `trusted_flight_execution_release=NOT_ACTIVATED`, and
  `fuel_transaction_release=NOT_ACTIVATED`.
- The existing world producer configuration expects a release reference
  and starting in-game date. None was guessed or invented, and the
  production game clock was not advanced.
- NO schedule was activated, no flight actually departed/arrived, and
  no fuel or airline finances were changed.

### Blockers to operational launch (do not bypass)

1. Approve and configure the authoritative World 1 game-clock starting
   date, release reference and recurring protected scheduler.
2. Activate independently verified schedule/crew/licence/slot/capacity
   certifications and a real trusted flight-operations producer. The
   verifier/empty evidence store must **not** be treated as the producer.
3. Connect a private durable aircraft-day worker and phase executor to
   independently certified real game-time events, with lease safety and
   idempotent evidence production; it must not turn a schedule alone into
   an operation.
4. Demonstrate an actual signed departure/arrival in an isolated authorized
   game test before enabling World 1 production operations.
5. Only after genuine flight events exist, add server-owned tank
   balances/refuelling, idempotent flight occurrence fuel posting and
   finance settlement. Never charge based on a route preview.

## Final integration proof — deterministic full-flight dry run

- New test: `tests/test_section9_full_flight_dry_run.mjs`.
- Tests one *synthetic*, server-owned A319 route through all five phase
  timestamps and modeled fuel burns, then separately authenticated mock
  departure and arrival operations through the real dispatcher's contracts.
- The existing arrival→fuel bridge accepts the signed mock arrival only
  once and attaches the full five-phase planning timeline. A duplicate
  movement is treated as a replay, with **no extra arrival/charge**.
- No independent operational evidence means the dispatcher processes **zero**
  mock movements despite a valid simulated phase timeline.
- CI `Airlinerra flight phase execution (isolated)`: run **42869878872**
  PASSED, including independent HMAC attestation checks, private evidence
  reader, flight/fuel compatibility, duplicate replay and protected website
  build.
- This is **not** a production executed flight. Do not claim that production
  trusted flight-execution signers or background operation workers are
  connected. The live readiness audit still reports those release gates OFF.

## 2026-11-10 private queue worker deployment (next integration step)

New GitHub `main` components:
- `server/section9-aircraft-operations-job-handler.mjs` — private
  POST-only, parameterless job handler with constant-time token comparison;
  refuses to claim *any* aircraft job unless the World 1 readiness view
  confirms an authoritative game clock, enabled producer, active verified
  schedule(s), operational certificates and explicit trusted-flight release.
  Runs at most 20 already queued jobs per invocation. It cannot enqueue
  arbitrary jobs from an HTTP request.
- `server/section9-aircraft-operations-edge-entry.ts` — the private
  assembly of the existing leased aircraft-day worker, verified flight
  dispatcher, independent signed-attestation reader + verifier, and signed
  operated-flight movement ingress. Uses separate HMAC secrets for
  independent flight attestation and movement events.
- `tests/test_section9_private_operations_job_handler.mjs` — covers
  negative release states, no clock, no schedules, wrong token, user body
  rejection, bounded batches and unsafe-count responses.

**Deployed** Supabase Edge function:
`airlinerra-flight-operations-worker` version **1**, ACTIVE hosting state,
`verify_jwt=true` (not a player-facing endpoint), deployed with **no
cron job**. Runtime remains **dormant** unless explicitly enabled using
`AIRLINERRA_FLIGHT_OPERATIONS_DEPLOYMENT_APPROVED=true`, independent
runtime DB/secret values, a separate private job token, and an official
DB release. No such release was granted this turn.

CI `Airlinerra flight phase execution (isolated)` run **42871683663**
passed, including private job authorization tests and protected website
build. Deployed function metadata and database readiness were checked
after deployment. **No authenticated live job invocation** was performed.

Post-deploy World 1 DB verification: active world, **clock not connected**,
producer not configured, 0 active flight schedules, 0 certified operating
approvals, 0 aircraft-operation jobs, 0 recorded movements, 0 settled
flight finances, 0 stored independent-flight proofs, fuel release disabled.
`cron.job` had **no flight/clock/operation schedule**.

Remaining to become a live engine (do not skip):
1. Choose/approve the game's starting in-game date and clock release
   reference, configure the official producer, and install a protected
   scheduler. The game's world opening timestamp alone does NOT define
   the desired in-game starting date.
2. Implement/configure six independent operational clearances and real
   schedule activation. Verify aircraft whereabouts and capacity.
3. Implement the **independent flight execution producer** that advances
   phases using an *authoritative* game time and writes immutable, signed
   independent evidence; the verifier intentionally cannot manufacture it.
4. Enable the private worker only after evidence and release conditions
   have passed a true test-flight run. The readiness view's release status
   is intentionally `NOT_ACTIVATED`, so production calls cannot pass today.
5. Fuel inventory, uplift and single-posting airline expenses must be
   implemented and validated separately before enabling money movement.
