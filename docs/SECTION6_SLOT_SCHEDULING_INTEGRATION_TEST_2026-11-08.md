# Airlinerra — Section 5 + Section 6 integrated scheduling acceptance (2026-11-08)

## Verdict
**Database integration tests PASS** against Airlinerra World 1 PostgreSQL. This verifies atomic **draft** reservations, not operational flight activation or a signed-in browser session.

## Test execution
- Connected production Supabase project: `hwllkabgzaynalahvkpz`.
- Disposable fixture: two individual in-service test aircraft linked to the existing active airline, ordinary schedule-draft writes and two temporarily reduced airport remote-stand capacity rows. These were created inside explicit `BEGIN; ... ROLLBACK;` transactions; no fixture was retained.
- Airports: LEJ `OURAIRPORTS:2220`, BIO `OURAIRPORTS:4001`; restricted KRN `OURAIRPORTS:2685`, ARN `OURAIRPORTS:2701`.
- Replayable regression: `tests/sql/section6_airport_slots_and_section5_restrictions_integration_regressions.sql`. Retrieved exact committed file from GitHub and **ran it against Supabase successfully**.
- Also executed a second rollback-only check of direction independence (simultaneous departure/arrival at the same airport), editing to another occupied time, reuse of vacated time, and 10-minute/hour capacity.

## Passed cases
1. Authenticated owner with a genuinely in-service fixture can save a recurring **draft**, reserve origin and destination weekly slots, and receives `canActivateNormalFlight=false`.
2. Two flights at the **same 10-minute bucket** cannot exceed that window's capacity.
3. Two flights at **different 10-minute buckets inside one hour** cannot exceed the stand/hour ceiling.
4. A second flight in an unused hour succeeds.
5. An edit to an occupied hour fails; the old draft timetable and old reservations survive the failed transaction.
6. A valid edit increases the draft version, releases the previous hour, and its vacated slots become bookable.
7. KRN prohibited local 02:30 departure fails the **Section 5 restriction gate** inside the same protected Section 6 save transaction, with no phantom draft/slots.
8. A passenger aircraft on cargo-only stands fails.
9. A different player UUID cannot create a draft for another player's airline.
10. A cancelled draft releases its slots through the server schema's on-delete cascade.
11. Arrivals and departures count against separate capacities, so opposite-direction movements in the same hour do not incorrectly collide.
12. No live flight activation is permitted.

## Read-only database state checked afterwards

| Check | Value |
|---|---:|
| World 1 airport capacity records | 3,141 |
| World 1 airport simplified restriction records | 3,141 |
| Airport research batch queue pending | 0 |
| In-service player aircraft | 0 |
| Persisted player schedule drafts | 0 |
| Persisted weekly slot reservations | 0 |

Every airport has a passenger stand model; 104 airports have no cargo stand capacity. This is a game model classification, not source-verified real-world stand availability.

## Remaining release blockers
- No actual purchased/leased in-service **player** aircraft exist yet. The test used rolled-back fixtures, so authenticated production-browser scheduling has not been confirmed.
- A server-backed `slot-check` only checks slots, whereas the protected `save` checks both slots and restrictions. The client must not treat `slot-check.available` as authority to activate a flight.
- Live aircraft position, rotation, turnaround, maintenance status at flight time, crew, traffic rights, long-horizon recurring restrictions, game clock, flight execution and economics are not connected.
- The hourly/10-minute capacity locks and PostgreSQL transactions were confirmed with sequential simulated writes; **real concurrent-client stress** and live authenticated website tests remain.
- The new SQL regression file was run against production DB; GitHub Node/website CI was **not separately run** for this SQL-only change, and no live service deployment or release was attempted.

Tracking: https://github.com/bracko87/Airlinerra/issues/10. Do not mark live activation ready from these database tests.
