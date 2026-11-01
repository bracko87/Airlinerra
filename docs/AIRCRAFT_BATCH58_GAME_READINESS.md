# Airlinerra aircraft readiness — Batch 58 (1 Nov 2026)

## Scope

This batch connects **private, read-only aircraft research** to the Batch 57
Supabase catalog-readiness view. It does **not** open commercial flights, public
aircraft assignment, aircraft purchasing, or route scheduling. Public route
planning remains a browser-stored airport-pair draft with no aircraft assigned.

## Sources and code

- Supabase project `hwllkabgzaynalahvkpz`, schema `airlinerra`.
- Live source view:
  `airlinerra.aircraft_configuration_game_readiness_v1` (security invoker).
- Private checker: `server/private-aircraft-game-readiness.mjs`.
- Existing optional private integration:
  `createPrivateAircraftPerformanceRunwayResearchService` in
  `server/private-aircraft-performance-loader.mjs`.
- Regression tests:
  `tests/test_private_aircraft_game_readiness.mjs` and
  `tests/test_private_aircraft_performance_loader.mjs`.
- No new public HTTP route, credentials, Netlify deployment, or autonomous
  operation was added.

## How the private gate works

1. An authorized private caller supplies an exact **configuration ID** and
   **aircraft variant key**, which must match in the database.
2. The checker performs a parameterized, read-only PostgreSQL lookup.
3. If the aircraft has a hold, the private performance composition stops
   **before** loading aircraft-performance points or inspecting runways.
4. A complete catalog row with no special hold may proceed to **research**
   screening; every result still has `schedulingAllowed: false`.
5. Disabled readers, unknown configurations, invalid or conflicting statuses,
   or failed database queries fail closed.
6. To apply the new gate, private callers must explicitly inject
   `readinessService:createPrivateAircraftGameReadinessService({database,enabled:true})`
   and pass `configurationId` into `evaluate`. Legacy unguarded research
   call paths remain research-only and cannot authorize flights.

At the Batch 57 snapshot: **188 configurations**; **173 provisional-data-only**;
**10 combi loading holds**, **2 Grand Caravan passenger approval holds**,
**2 older Twin Otter paved-runway holds**, and **1 747-200C maintenance hold**.
Only **186/188** have all simplified essential field values; model evidence
can still be fictional or under research. Even provisional-data-only means
**NOT certified, NOT released**.

## Next integration, not done by Batch 58

Before real aircraft purchase, assignment or route activation, wire a
separate authenticated server-side transaction to enforce fleet ownership,
current aircraft availability, service/maintenance state, passenger/cargo
loading mode, weight/fuel tradeoffs, actual airport runway (including TORA,
TODA, ASDA, LDA, NOTAM and applicable clearance), eligibility by registration
and country, and release gates. Re-check within the transaction; do not trust
a browser-provided readiness result. Avoid reusing provisional runway
distances for certified real-world performance.

## Windows CMD validation

```cmd
git pull origin main
cd website
node --test ../tests/test_private_aircraft_game_readiness.mjs ../tests/test_private_aircraft_performance_loader.mjs
npm run build
npm run preview
```

The login page at http://localhost:5187/account.html is the source-only disabled mockup. The built invite-only sign-in is served at http://localhost:5188/account.html?screen=sign-in after `npm run preview` (which runs the build itself). Only confirmed Supabase accounts can sign in, and the hosted provider must allow invited-user authentication. No public signup is enabled by this command.

The AI-side checks executed the 15 committed JavaScript test assertions in
a compatible V8 runtime, **not** the full Node-native test runner or a local
website build. CMD verification on the user's clone is still required.
