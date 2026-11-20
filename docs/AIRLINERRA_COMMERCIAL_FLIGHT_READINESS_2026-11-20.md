# World 1 commercial airport and flight readiness — 20 November 2026

## Scope and decision
Resume the paused **commercial flight operations** process after freezing Airlinerra's eight-licence catalogue. This is a **read-only, production-grounded status snapshot**, not a release authorization, a new Licence 1/2 audit, or permission to bypass current airport safety evidence. Do not reactivate any existing airline/game release flag from this report.

## Production findings (verified directly with `airlinerra_game`)
| Evidence | Group 1 | Group 2 |
| --- | ---: | ---: |
| Airport models in combined sections 1–8 catalogue | 3,141 | 1,118 |
| Runway, slot capacity, operating restriction inputs in integrated systems | 3,141 | 1,118 |
| Airports in World 1 player game roster | 3,141 | 1,116 |
| Simulation/World 1 admissions | 3,141 | 1,116 |
| `operationally_authorized` in World 1 roster | 3,141 | **0** |
| Airport-level operational release records | Not applicable to Group 1 | **0** |
| Ready for independent owner release review | Existing approved operating registry | **0** |

The two Group 2 airports not present in the World 1 player roster are **not missing imports**. They are explicitly held as documented commercial-airline prohibitions:
- `OURAIRPORTS:29484` Brumowski Air Base (Austria)
- `OURAIRPORTS:4436` Hinterstoisser Air Base (Austria)

The other **1,116** have `EVIDENCE_INCOMPLETE_NOT_PLAYABLE` status in the independent admission-readiness view. Their simulation-admission entries permit preparation in the game model but **do not confer commercial-flight authorization**. The independent gates cover current airport identity, paved runway, civilian access, aircraft/facility compatibility, operating restrictions and passenger/cargo commercial use as applicable. Neither `admitted_to_world` nor `dispatch_eligible_by_airport_admission` alone is a safe launch switch for Group 2.

Operational Group 2 release ledger `airport_group2_operational_releases_v1` is empty. Existing verified Group 2 schedule-save path intentionally raises `SECTION6_GROUP2_NOT_YET_ADMITTED` before draft/slot mutation. **Do not remove it to achieve 1,118 activated airports.**

At audit time there was **1 planning route draft** and **0 flight schedule drafts** across the queried drafting tables. These counts are not proof that live bookings or financial settlement operate.

## Existing preparation that does not need repeating
- Combined Sections 1–8 profiles and integrations for both groups are complete as *game-model inputs*: runway, airport capacity/slots, restrictions, demand and airport fees.
- Group 2 has a prepared 54-week route/aircraft preview; the actual owner-verified schedule-save guard remains fail-closed.
- Section 9 has a composite read-only commercial activation preflight, documented in `docs/SECTION9_COMMERCIAL_ACTIVATION_PREFLIGHT.md`.
- AOC and foreign-network licences already have substantial foundations, tests and UI. Do not restart the policy design.

## Specific remaining work in order
1. **Resolve Group 2 release policy, not airport-model research again.** Review the real evidence-gate status for individually eligible airports; preserve two prohibitions and only issue granular signed independent review receipts after actual evidence exists. Do not fabricate verification events or blanket-authorize the 1,116.
2. **Retain the schedule-save guard** until there is a tested controlled admission mechanism that checks the actual airport-specific authorization (and airport-to-aircraft operating restrictions), not merely game-simulation readiness.
3. **Complete the commercial flight engine** as already scoped by Section 9: atomic schedule release/slots/turnaround and position, qualified crew/duty-rest, verified operator and traffic rights, trusted flight movement execution, bookings and exactly-once airline financial settlement.
4. **Isolated end-to-end test** on an existing Group 1 authorized-airport route with a genuine eligible airline and aircraft fixture. Check no duplicate slot/aircraft use, no unauthorized AOC/route bypass, and rollback or idempotent handling on errors. No production bookings, game money changes or public schedule activation during test.
5. **Controlled release** only after the previous gates are verified independently. Keep Licence 6–8 infrastructure deferred, consistent with the eight-licence decision.

## Repeatable audit and its caveat
Use `tests/sql/airlinerra_group2_commercial_release_readiness_readonly.sql` to recheck current roster/catalogue counts, independent holds, simulation admissions versus operational releases, and current drafts. It is SELECT-only and does not create records or authorize anything. A green catalogue count is **not** proof of live commercial operability.

**Result:** Airport-data preparation is substantially complete. **Group 2 commercial admission remains blocked**, and the commercial schedule/execution/revenue engine is not yet demonstrated end-to-end. This is a concrete integration/release backlog, not a reason to restart completed licence reviews.
