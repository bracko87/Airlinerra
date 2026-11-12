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
certifications, crew roster, aircraft position, game slot reservations, dated
flights or passenger reservations. A319 configuration 16 fuel source is
provisional and not approved for dispatch/accounting. Section 9 commercial
release has no enabled row; trusted execution and settlement are disabled.
These are **real incomplete integrations**. Crew was removed from the Phase 1
required-certificate logic in the database on November 12 without unlocking
any other requirement or creating any fake flight.

**Never mark this file complete merely because its specification is approved.**
