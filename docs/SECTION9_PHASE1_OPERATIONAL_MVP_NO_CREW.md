# Airlinerra / World 1 — Phase 1 operational airline specification (crew deferred)
Status: **approved product rules; implementation in progress; NOT live-flight release**.
Owner decision: 12 November 2026.

## 0. What success means

A signed-in airline owner clicks **Create route** once. If the proposal is eligible,
the server creates an **actual operating schedule with at least one validated,
dated, saleable flight**, reserves game slots, checks the real aircraft's position,
initial maintenance/fuel readiness, airport rules and airline rights, and stores
everything in Supabase. The only user confirmation is **Route PA888 created.**
A route cannot be called created just because a planning row was stored.

If the proposed service is not yet eligible, the game must explain what is wrong,
preserve the completed form for corrections, make no bookings or charges, and
report **Not created**. Never silently downgrade the request to a planning draft.
Player-created routes do not trigger real-world reservations.

## 1. Explicit crew deferral

**Crew is not a prerequisite or a cost input during Phase 1.**
- Do not require a crew roster, qualifications, rosters, crew-duty attestations,
  assignment, duty/rest checks, wages or per-flight crew expense to create,
  certify, book, dispatch or settle a Phase 1 flight.
- Do **not** auto-create fictional employees or mark missing crews as certified.
- The independent activation gate requires **five non-crew proofs**: operator
  licence, traffic rights, departure/arrival airport slot capacity,
  trusted flight-execution service, commercial settlement service.
- Crew may be enabled in Phase 2 via `section9_activation_release_policy_v1.crew_mode
  = 'required'`, with a real roster and signed `crew_duty` certificate.
- Any earnings display during Phase 1 must explicitly label the result
  **operating contribution before crew costs**, not full net profit.
- All other requirements remain mandatory, independent and fail-closed.

## 2. Player route creation

Minimal form: flight number; owned/leased and in-service aircraft; origin and
destination; weekdays and LOCAL origin departure time (UI must clearly label
the zone and DST); destination arrival stand type; permitted turnaround
(minutes); ticket fares; saved cabin-service, baggage and cargo packages;
start preference (0, 3 or 7 game days). No technical approval fields, no
"planned" choice, no server-version fields, no passenger-sales forecast panel.

On Create route the same owner-authenticated server workflow validates:
1. Airline ownership, role, unique flight number and valid world/game clock.
2. Actual aircraft inventory, delivered location, condition/maintenance
   availability, configuration and fuel model provenance.
3. Actual origin/destination airport model, runway compatibility, game
   curfews, restrictions, stand suitability, in-game slot capacity and fees.
4. Operator game licence and international traffic rights, if applicable.
5. Flight duration, timezone/DST, chronological rotation, minimum turnaround.
6. Reserved slots and all five independent operation/cash/booking proofs.
7. Atomic creation of a versioned weekly schedule, origin-local dated
   occurrences, verified capacity and the seven-game-day saleable inventory.
8. Idempotent response returning exact active IDs and version. Any failure
   rolls back all schedule, slot, inventory and financial changes.

The current fail-closed `operational-create` API deliberately rejects until
real verification and atomic commit are connected. **Never** flip its response
to success based only on the existence of planning rows.

## 3. One-way services, return flights and aircraft position

- The first eligible one-way departure may be bookable and executed **once**.
  Its aircraft physically arrives at the destination.
- On booking another flight for that airframe, show any **missing return or
  repositioning flight** warning and actual position conflicts. The player can
  create a separate valid Tivat → Belgrade service (or another next leg).
- Future repetitions of the first service must **never** appear saleable
  unless the aircraft returns to the origin before each departure.
- Rotation must be checked in UTC for ordering but display the appropriate
  airport-local times. Daylight-saving gaps/ambiguities must be rejected or
  resolved explicitly; do not silently guess an offset.
- The authoritative position is a server ledger sourced from verified aircraft
  acquisition/delivery plus departed/arrived movement events. Neither the home
  hub nor a browser preference is proof the airframe is there.
- Turnaround and maintenance must block aircraft conflicts without requiring
  the player to understand an artificial planning-only status.

## 4. Slots, airport rules and permissions

Use World 1 in-game slot capacity, airport operating times, stands, aircraft
runway suitability, curfew/noise evidence and licences/rights. Automatically
allocate verified **game** slots when available. Slot reservations must be
atomic and checked again under locks on activation and edits; no double-use
under concurrent requests. An estimated airport restriction is not a proven
ban. Missing evidence must produce an intelligible, source-aware reason; it
must not become an invented approval. Airports, licence checks and traffic-right
proofs must be exact for the route and game date.

## 5. Aircraft performance, fuel and maintenance

- Compute time with the selected aircraft configuration and modelled taxi,
  climb, cruise, descent and taxi-in phases, plus actual airports and route
  distance. Save the computed flight-time version and provenance in Supabase.
- Distinguish a **provisional game estimate** from an approved dispatch and
  settlement model. Model reference must be reviewed/released before it can
  drive automatic fuel deductions or final financial accounting.
- Maintenance validates delivered state, 0–100% condition, any grounded status,
  planned checks/refits, availability and airport capabilities where applicable.
- At verified departure record the fuel needed and phase-based operating
  usage once; avoid duplicate deductions on retries. At arrival apply actual
  game maintenance/wear policy once; never invent passenger load.
- In Phase 1 fuel, airport and maintenance costs are included when modelled
  and independently verified; **crew costs are not included**.

## 6. Booking and seven-day passenger sales

- A rolling **seven future game-day** window derived only from the signed
  World 1 clock. No public sign-up or real currency payment.
- Only real **dated, active and certified occurrences** can be offered.
  Booking capacity derives from the actual aircraft cabin refit/configuration,
  less already reserved/committed seats, per class.
- Passenger demand and willingness to pay are game estimates with versioned
  evidence: population/market demand, route, fare, competing services, day,
  seasonality and load rules. Never assume full occupancy or arbitrary buyers.
- Sales are in-game reservations **not prepaid**. Cash and realized fare
  revenue are NOT posted until the applicable flight completes.
- Baggage/cabin/ancillary and cargo income is recorded only when supplied,
  consumed or carried as specified by the applicable game contract.
- A single booked seat must not appear in two flights. Owner must only see
  their airline's bookings and counts; protect unrelated passengers' privacy.

## 7. Game-clock flight execution

- World 1's authoritative game-clock instant, timezone conversion and active
  schedule revisions drive due departures and arrivals; server must not use
  the browser clock as its source of truth.
- Durable per-aircraft leases and ordered idempotent operation events. Before
  departure recheck aircraft position, sufficient fuel, maintenance, approved
  slots, rights, non-crew clearances, saleable occurrence and booked capacity.
- Actual departure and arrival are separately verified events. No invented
  movement based on a timer alone. Each event updates server position once.
- Stop or cancel missed/blocked departures; do not skip a failed movement and
  then operate the next flight from an impossible airport. Handle 0/3/7 launch
  delays and cross-day/season-boundary flights.

## 8. Economics and cancellations

- Authoritative per-flight realized ticket, baggage, cargo and onboard revenue,
  plus fuel, airport movement/stand/navigation/handling and relevant
  maintenance/wear expenses. Post only through verified game flight events.
- Exactly-once ledger posts, deterministic reference IDs and resumable
  retries; no duplicate cash credit/debit. Every item has a source and game date.
- Label Phase 1 contribution **before crew costs**. Never use zero crew wages
  to present an artificially complete net profit.
- Cancel a specific future dated flight, cancel all future unstarted flights,
  or retire route after a selected seven-day booking window. Only server
  transactions can change operational records or free dated slots.
- Protect every affected reservation; 48-hour cutoff escalates assistance/
  rebooking, not an invented automatic paid refund on an unpaid ticket.
- Never cancel an already departed/completed flight or modify posted
  revenue history. Keep previous game seasons' financial history queryable.

## 9. Source of truth and protections

Supabase is the **only** player game-state persistence. Local/session storage
are not fallback databases. Account Auth sessions and cached artwork are not
game progress. Owner-scoped API, RLS, signed/verifiable independent source
events, exact revisions, atomic Postgres transactions and a complete audit log
are mandatory. Protected APIs must return an honest result if any dependency
is not yet connected. No mock flight data in the live World 1 game.

## 10. Build order and definition of done

**Milestone A — operating aircraft** (first to build):
- Delivery/physical location provenance -> authoritative aircraft position.
- Versioned aircraft performance, fuel/maintenance readiness, local timezone
  and DST flight times; aircraft rotation and return/reposition warning.
- Game airport/slot/licence/rights verification + five non-crew signed sources.
- One atomic owner-authenticated `operational-create` that creates a real
  eligible schedule/first dated flight or writes NOTHING.

**Milestone B — seven-game-day bookings**:
- Dated occurrences, class inventory, simulated demand, reservation rules,
  cancellation/rebooking with owner and seat-consistency checks.
- Rolling saleable window and visible booking counts from Supabase only.

**Milestone C — execution and finance**:
- Clock worker + durable per-aircraft leasing, verified departure/arrival,
  position/turnaround, fuel, maintenance and idempotent expense/revenue ledger.
- Detailed cost breakdown with Phase 1 crew exclusion accurately labelled.

**Milestone D — complete test sign-off**:
- One real invited airline can create a flight and return leg, book seats
  in the seven-day window, operate both legs through game time, see aircraft
  at correct airports, observe correct expenses and revenue and recover all
  data across logout and a second device.
- Failure cases: non-owner, runway too short, curfew, no airport capacity,
  licence/rights missing, maintenance, fuel, DST, incorrect position,
  double-booking, retry, clock change, cancellation near departure and
  conflict between two airline users. No partial writes or fake success.
- Crew roster empty is **not** a blocker in Phase 1; the other five
  certificates missing **are** blockers. Verify no wages included or
  misstated as zero full cost. Test required-mode crew restoration.
- Full focused and broader CI; actual signed-in localhost/production visual
  checks; independent Supabase DB audit. Do not call operational booking live
  until every release criterion succeeds.

## Current verified blockers — 12 November 2026

World 1 clock connected. PA888 only a planning route; no active schedules,
certifications, crew roster, operated-aircraft movement, game slot reservations,
dated flights or passenger reservations. Panonian's A319 has a VERIFIED original
game starter allocation at Belgrade (LYBE), 10 November 2026; this is sufficient
as its initial game location before any flight but is not an operated arrival.
The protected position resolver returns to signed movements once aircraft flies.
A319 configuration 16 fuel source is provisional and not approved for
dispatch/accounting. Section 9 commercial
release has no enabled row; trusted execution and settlement are disabled.
These are **real incomplete integrations**. Crew was removed from the Phase 1
required-certificate logic in the database on November 12 without unlocking
any other requirement or creating any fake flight.

**Never mark this file complete merely because its specification is approved.**

## Implementation update — 12 November, second milestone

- The original airline starter allocation already exists and is verified by
  `section9_starter_origin_evidence_v1`. **Do not** create a fictional
  acquisition order or inspection for this aircraft.
- Private `section9_owned_aircraft_operational_position_v1` was installed and
  verified against PA's actual starter proof. It resolves the starting airport
  only while there are NO operated movement records or current-position rows,
  then requires a matching signed latest movement. Wrong game day is refused.
  Browser/anonymous roles cannot directly execute it.
- Protected flight-schedule API **v23** uses the resolver and checks the proposed
  departure origin; PA has `startingLocationVerified=true`, `atOrigin=true`
  for LYBE. Fuel dispatch/accounting approval remains false. The API also
  checks the real aircraft maintenance condition, hours and cycles baseline,
  which remains unverified for YU-PAN01. Neither unknown condition nor unknown
  age is silently initialized as 100%. Operational creation is still blocked
  until the remaining independent systems are working.
- Phase 1 commercial preflight now also uses the same position source, defers
  crew-only blockers, and retains restrictions, slot, licence/rights, execution
  and commercial release blockers. No crew employee or fake flight created.
- Verified production count: active schedules 0, movements 0, reservations 0.
  The seven-day booking engine and settlement are NOT yet live.

## Further implementation — 12 November, fuel and usage-baseline integration

- **Verified original starter usage baseline:** For PA-owned A319 YU-PAN01,
  private `section9_initialize_verified_starter_usage_v1` used the trusted
  original game allocation (2026-11-10 08:44:08 UTC) to initialize **0 hours
  and 0 cycles since this allocation**, NOT lifetime hours/cycles. Production
  read-back confirmed those values; a repeat request changed nothing.
  Manufacture year and condition remain NULL/unverified, and there are no
  created maintenance completions, flights, movements or ledger posts.
- **Versioned game fuel input snapshots:** New private
  `section9_game_fuel_model_snapshot_v1` freezes exactly 271 existing
  source-labelled fuel model configurations for future server calculations:
  270 have a reference tank and usable game calculation inputs; Jetstream 32
  (configuration 98) lacks tank capacity and is flagged incomplete.
  Research-derived peer estimates remain clearly distinguishable from the
  existing provisional consumption rates. The game-only universal kerosene
  assumption is explicit. **No model is released for dispatch or settlement.**
- **Flight Schedule API v24** now independently reports
  `gameFuelEstimateReady`, `maintenanceUsageTrackingStarted`,
  `fuelDispatchModelApproved`, `fuelAccountingModelApproved` and
  `maintenanceBaselineVerified`. Live PA query returned respectively
  true, true, false, false and false. Starter origin LYBE remains verified.
- Operational activation, airport slot allocations, saleable seven-day
  bookings, flight movement and finance remain **OFF**. Crew remains
  deliberately excluded. This milestone cannot be mistaken for flight release.
- Dedicated Phase 1 CI includes regression checks for starter source,
  idempotent usage counters, preserved unknown airframe condition and
  untouched financial/dispatch locks.

## Implementation update — 13 November: private five-phase fuel estimate (no dispatch)

- Added the **private, read-only** PostgreSQL function `section9_game_five_phase_fuel_quote_v1`. It interpolates the versioned existing per-100-km aircraft game fuel rate at an explicitly supplied load percentage and calculates taxi-out, climb, cruise, descent, and taxi-in fuel from explicitly supplied phase minutes.
- **Critical provenance:** phase multipliers (taxi = 0.18, climb = 1.35, descent = 0.40 of cruise-hour rate) are clearly tagged **unverified GAME assumptions**, not aircraft/manufacturer fuel evidence. This is not a dispatch, reserve-fuel, refuelling, or aircraft-specific fuel certification model. Real route phase durations, approved coefficients, load and airport fuel tariffs have NOT been connected.
- A319 configuration 16, illustrative input 50% load/10+15+40+15+10 minutes: 2,819.28 kg estimated; this is **a test input**, not PA888's actual distance, flight load, or fuel burn. All five phase values add to the returned total.
- Jetstream 32 configuration 98 still has no tank-capacity reference and returns `model_incomplete` with NULL total rather than a guessed result.
- Live audit across 271 models: 270 `game_estimate_only`, one `model_incomplete`, zero phase-total mismatches, zero unsafe release flags. Out-of-range input rejected; anon, authenticated and service_role have no direct function execution grant.
- GitHub migration, focused regression tests, and Phase 1 CI workflow updated on `main`. These are **code and database checks**, not proof of browser use, passenger bookings or live flight execution.
- Actual production state after migration: zero active schedules, zero dated occurrences, zero operated movements, zero settled finances. PA888 is preserved and still NOT operating. Crew remains deferred.
- **Next blockers:** trusted airframe condition; approval-quality fuel phase and reserve model; game airport slot and rights allocation under one transaction; activation with dated saleable flights; clock-driven movements and exactly-once financial settlement. Do not enable operation merely because preview fuel totals exist.

## Jetstream 32 complete game fuel-input repair — 13 November 2026

- Replaced the last NULL `fuel_tank_capacity_kg` for **Jetstream 32 configuration 98** with **1,477 kg USABLE fuel capacity**, not the 1,491 kg total including unusable fuel.
- **Authoritative source:** [EASA type certificate A.191, issue 3, 15 January 2015, page 12/15, Jetstream Series 3200 Section 3 III.9.1](https://www.easa.europa.eu/sites/default/files/dfu/TCDS%20EASA.A.191_Jetstream_3100_3200_Iss_03_20150115.pdf): usable 1,846 L / 1,477 kg, total 1,864 L / 1,491 kg.
- Exact source/provenance recorded in new private `airlinerra_game.section9_fuel_tank_capacity_evidence_v1`; the underlying catalog technical specification (id 136), its derived fuel-profile view, and the versioned Section 9 game-fuel snapshot now return the usable mass consistently. All previous Jetstream 32 fuel burn coefficients remain **peer-derived estimates**, not certified rates.
- Live verification: **271/271** snapshot configurations now have the inputs for provisional GAME fuel calculations, zero missing. A read-only five-phase Jetstream 32 quote now returns a modelled value. None of 271 snapshot rows has received dispatch or financial settlement release. Live active flights, movements, dated occurrences and financial posts remain 0.
- The first attempted migration was rolled back because the derived planning-profile VIEW is not directly editable; corrected version updates the actual `airlinerra.aircraft_technical_specs` table and the snapshot together in one transaction. Migration succeeded on retry; regressions added to Phase 1 CI.
- **Important distinction:** 271/271 calculation-ready does NOT mean 271/271 real-world performance validated, fuel reserves confirmed, actual airframe cleared, or operational flights released.

## Implementation update — 13 November: protected maintenance-readiness evidence (Flight Schedule API v25)

- Added `airlinerra_game.section9_aircraft_condition_assessments_v1` as a private, owner-bound aircraft-condition evidence ledger. **It starts empty**, with entries pending by default; no fake starter inspection, manufacture year, inspection certificate, wear or condition percentage was created. RLS and no anon/authenticated/service-role direct table privileges.
- Added read-only, owner-verified, exact-world-game-date `section9_owned_aircraft_maintenance_readiness_v1`. It checks recorded usage counters separately from condition inspection evidence, manufacture-year provenance, signed completion history across the six existing maintenance-check types, and missing due/grounding/availability execution connections. It explicitly refuses to treat a zero-hours starter baseline as an inspection or a completed check. Missing maintenance state fails closed.
- Production Flight Schedule Edge API **v25** now queries the independent maintenance gate in its `operational-create` preflight. It returns specific maintenance blockers, check-type counts, and condition/age evidence flags instead of a generic ambiguous statement. An unreadable or inconsistent result blocks with `MAINTENANCE_EVIDENCE_UNAVAILABLE`; there is still **no operational CREATE write** and no passenger bookings.
- Live YU-PAN01 readback: usage tracking verified; condition assessment false; manufacture year false; **0/6** check types with verified completion; independent maintenance due and grounding/availability integration missing. Result `maintenanceReady=false` and five explicit blockers. Signed inspection evidence rows **0**. No condition or age has been guessed.
- This phase does not invent a "factory new" 100% aircraft, fabricate an inspection, schedule maintenance, ground aircraft, or post money. World 1 still has **0 active schedules, 0 dated operating flights, 0 movements, 0 settled finances**. PA888 is preserved but not operational. Crew remains out of Phase 1.
- Added source-level regression tests to Phase 1 CI; the database readback and deployed Edge Function source/version were verified; a passing GitHub CI run and real signed-in browser route request have **not** been independently verified in this session.
- **Next:** build an actual authenticated game inspection/commissioning workflow that can create a reviewed condition/age baseline with real provenance, then authoritative game-time due/availability and maintenance-work execution. Integrate with slot/rights/release checks in one atomic route creation before opening flight bookings or finance. Do not close overall Issue #10.

## 13 November 2026 — starter aircraft commissioning request flow (API v26)

- Installed a **private, owner-scoped, idempotent** `section9_starter_commissioning_requests_v1` table and `section9_owned_starter_commissioning_v1` PostgreSQL function. It checks owner membership, the original starter allocation (matching registration/configuration and source fixture), signed world game date, operational eligibility, usage counters, and absence of operated movements before creating a single pending request.
- The existing authenticated Flight Schedule Edge Function is deployed as **v26**. It adds `commissioning-status` and `commissioning-request` actions, validates `airlineId` and `aircraftInventoryId` server-side, forwards the Auth-verified player identity to the private SQL function, and rejects unexpected/unsafe results.
- The actual YU-PAN01 commissioning request was created in Supabase on World 1 game date 2026-11-13, status **requested**, not reviewed. A second request returned the same request and `created=false`. There is one request in the table, **zero** condition assessment records and **zero** signed maintenance completions.
- Requesting **does not** imply that a real inspection was performed, a condition percentage or manufacture year is known, or the aircraft is approved for dispatch. No physical inspection evidence, age, condition, charges, flight movement or bookings were fabricated.
- The independent review/inspection event producer and atomic application of a reviewed condition/year to the maintenance state **are not implemented yet**. Neither is a player-facing commissioning button/status panel; the authenticated API actions exist and work against the DB function, but signed-in browser E2E validation has not been completed.
- Live operational counts remain zero active schedules, dated flight occurrences, verified movement events and settled financial posts. Crew remains deferred. PA888 preserved.
- [Migration](https://github.com/bracko87/Airlinerra/blob/main/supabase/migrations/20261113111500_section9_starter_commissioning_request_workflow_v1.sql) and [source regression checks](https://github.com/bracko87/Airlinerra/blob/main/tests/test_section9_starter_commissioning_workflow.mjs) are committed to `main`, with workflow trigger and test wiring. Passing CI status not independently confirmed.
- Next to build: **trusted in-game inspection/result review** with explicit game provenance and a real condition/year where available, plus game-time maintenance due/grounding policy, before any operational release.
