# Section 7 — Conditional nearby-airport feeder demand (World 1)

**Status: backend rule implemented and approved on 2026-11-04; real flight-route activation integration pending.** This file documents deployed Supabase policy and the exact game-engine handoff. It does not assert that any real player flight is currently operating.

## Policy

Applies to proposed **Local/Regional satellite → Large/Major Hub/Mega Hub** passenger feeder markets within **100 km straight-line distance**, where the larger hub is materially busier. The initial automatic geographic screening includes only same-country pairs between **60 and 100 km**. Shorter/cross-border examples require special review; geographic proximity alone never activates traffic.

For a confirmed *operating in-game* feeder service, the additional satellite flight-leg boardings per day are the floored minimum of:

- The larger hub's **1% of baseline departing passengers per day**, shared among all its currently active satellite feeder airports in proportion to the satellite airports' baseline demand.
- **30% of the satellite airport's existing departing passenger pool**.
- The route's **available feeder seats/day × eligible connection fraction** (set by the flight schedule/route engine).

Only one operating primary hub per satellite is permitted; a hub may serve multiple satellites, sharing its single budget. Do not treat the 1% as a new allocation independently for each satellite.

**Accounting:** the local feeder flight creates a second flight-leg boarding for a traveler connecting onward at the hub. The hub onward segment is treated as already present in the existing hub passenger demand. This is one unique traveler and two boarded segments, **not two new unique travelers**. The approved airport baseline passenger/cargo research figures are never overwritten by this mechanism. Revenue, bookings, ticket prices, connected-journey market share, and dynamically induced new travelers belong to a later integration/Section 9.

## Supabase deployed objects

Project: `hwllkabgzaynalahvkpz`, schema: `airlinerra_game`.

- `section7_nearby_feeder_feasibility_policy` — World 1 approved; calculation enabled. This only permits eligible operating routes, not automatic traffic inflation.
- `section7_nearby_feeder_feasibility_candidates` — read-only geographic pre-screen. At 2026-11-04: 26 nearby pairs, 21 small airports, 14 suggested primary-hub matches. The selection prefers a source-backed active real-world direct service when evidence exists, but that alone does **not** activate game traffic.
- `section7_feeder_route_services` — **backend-only, RLS enabled** route-activation contract. Do not give browser users write access. A row may be `planned`, `operating`, `suspended`, or `closed`.
- `section7_active_feeder_leg_demand` — dynamic service-gated demand, shared hub 1% pool, local 30% cap, available seat cap. Also reports hub onward boardings *already included* in hub baseline, with zero new unique travelers assumed.
- `section7_feeder_airport_boarding_projection` — read-only all-airport view, original departures and additional feeder-leg boardings in distinct columns, alongside simulated departing boardings. This is the recommended hook for the future route engine's flight-boarding display, **not** the historical traffic research table.
- `section7_feeder_demand_status` — current status, operating services, and actual active feeder boardings per day.
- `section7_route_evidence` — dated real-world schedule evidence, not operational game service proof.

## Real route-engine handoff (not yet connected)

The current `website/route-planner.mjs` deliberately saves **account-local browser drafts only**; it does not create scheduled or operated flights. Therefore creating a draft MUST NOT register an operating feeder service.

Once real schedules/aircraft/airline operations exist, a trusted backend route lifecycle should:

1. On **actual airline route activation**, confirm the route serves the qualified satellite/hub pair; verify aircraft suitability/runway permissions, usable onward connection, and route's available daily passenger seats. Only then upsert the `section7_feeder_route_services` row with an authentic, stable `game_route_reference`, `route_status='operating'`, all three attestation flags true, verified timestamp, available seats and connecting-seat fraction.
2. On schedule/fleet changes, update daily available seats and the transfer fraction; never guess seat counts from the airport category alone.
3. On suspension, route closure, aircraft loss, or lost onward connection, change status to `suspended` or `closed`; the active view then immediately returns **zero** for that feeder service.
4. Read `section7_active_feeder_leg_demand` or `section7_feeder_airport_boarding_projection` for **flight-leg boardings**. Never add the matching hub connection passengers a second time to the hub baseline.
5. Airline ownership, booked passenger capture and multi-leg passenger IDs should be modeled in the future operational itinerary system before any passenger is called an actual booking. The current estimates are only potential market demand.

The operating-service table rejects unqualified 0–60 km/cross-border pairs without a separate feasibility process, and requires attested service/connection/aircraft and positive seat capacity. One operating primary hub per satellite is enforced.

## Quality checks (completed 2026-11-04)

Executed inside transactional SQL tests, with all temporary QA services removed:

| Test | Expected | Outcome |
|---|---:|---|
| Aleksandrovo (ALV) → Belgrade (BEG), active, 200 eligible seats/day | 122 feeder boardings/day | Passed |
| Same route with 20 seats/day, 50% for connections | 10/day | Passed |
| Planned or suspended route | 0/day | Passed |
| La Gomera (GMZ) → Tenerife North (TFN) with 150 eligible seats | 90/day (local 30% cap) | Passed |
| Ineligible ALV → Timișoara (TSR), only ~58 km | Operating rejected | Passed |
| Operating route with no verified air service | Rejected | Passed |
| No real operating services registered | **0 extra boardings at all 3,141 airports** | Passed |

**Illustration:** ALV has an owner-approved 500 daily departing-passenger base. BEG's departing base is 12,205. A hypothetical qualifying feeder route adds at most `floor(min(122.05, 150, available connecting seats))` daily *ALV feeder leg* boardings, not automatically 122 net-new people and not an increase to the historic 500 base.

**Remaining:** Connect the actual operating route/schedule system when it is implemented; test real airline route activation-to-suspension events end-to-end. Continue broader Section 7 market realism analysis separately. Section 7 stays **partially_populated** rather than falsely claiming all 81,085 ranked market estimates are verified schedules.
