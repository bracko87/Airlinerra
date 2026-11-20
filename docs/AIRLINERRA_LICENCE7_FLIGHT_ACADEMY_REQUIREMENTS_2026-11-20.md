# Airlinerra — Licence 7: Flight Academy / Training Organization Approval
**Status: DESIGN PROPOSAL — not yet approved for live issuance or commercial training**
**2026-11-20. After Licence 6 MRO.**

## Purpose and single-licence decision
One player-facing **Licence 7 — Flight Academy / Training Organization Approval** belongs to a dedicated **flight_academy** operating subsidiary under an eligible holding. It covers training for the holding's own airlines **and** training sold to other players' airlines. **No second licence for public/commercial training.** The licence is company-specific, not shared across airlines, the holding, or other subsidiaries. It is a game certificate, not a real aviation training authorization.

IMPORTANT CURRENT SYSTEM GAP: The existing `holding_subsidiaries_v1.company_kind` check currently allows regional_airline, passenger_airline, cargo_airline, charter_airline and maintenance_mro only; it **does not include flight_academy**. A future company-model migration and actual subsidiary-registration flow will be needed before this licence can ever issue. The current aircraft crew roster and payroll systems are not academy infrastructure.

## Proposed commercial terms for user review
| Topic | Game design |
| --- | --- |
| Eligible organization | Registered `flight_academy` subsidiary under an eligible holding |
| Holding eligibility | Existing holding creation requirements are unchanged |
| Minimum age of academy | **None**; may apply immediately after registration once all later-defined training requirements are met |
| Application fee | **Free** |
| Proposed approval fee | **$40,000**, charged exactly once when approved |
| Processing time | **7 verified game days**, with final readiness recheck |
| Licence duration | Indefinite while compliant; periodic quality/safety inspection proposed every 365 game days |
| Customer scope | Internal group trainees and external player airlines under the **same Licence 7** |
| External marketplace | Optional, private/unlisted by default |
| Player pricing | Player chooses which approved training programmes to advertise and sets a price **per programme/course** |
| Training aircraft requirement | To be determined by the programme; no aircraft required merely to register the academy subsidiary |
| Renewal fee | None automatically; no duplicate external-service or programme licence fee |

The $40,000 price and 7-day review are existing planner **proposals**, not verified regulator prices and not activated.

## Programmes and licensing boundary
Potential future course categories, **not yet approved game curriculum**:
- Initial pilot/flight training (may require training aircraft, an airfield and instructors).
- Aircraft-family/type transition training (could require approved simulator or aircraft and type-qualified instructors).
- Recurrent/check training for existing airline crews.
- Cabin crew/safety and emergency procedures training.
- Ground operations, dispatch and safety-related training, if the later career/staff design makes those skills useful.
- Any new programme is a **course capability or authorization under Licence 7**, not another paid licence number.
- The game must only advertise and teach courses for which that academy has verified facilities, equipment, instructors and syllabus approval.
- A real pilot licence or real-world qualification is **not** created by earning a fictional in-game training certificate.

## Public directory and prices
- "Publish Academy Services" toggle, **off by default**.
- Player chooses eligible, approved courses to list and sets a separate price for each one.
- Each offer specifies programme, aircraft family or qualification type where relevant, training site, duration, seat capacity, availability and price.
- Academy can update future quotes, unpublish individual courses or turn off public listing; existing accepted contracts/prices are preserved under later cancellation/settlement rules.
- External airline users will eventually browse academies, compare prices and outcomes, schedule course places and book qualified employees for training.
- Internal group training need not be publicly listed. No added Licence 7 fee for teaching external trainees.
- Training revenue, instructor payroll, site leasing, simulator/aircraft expenses, insurance and consumables must be recorded in the academy's own company finances when that economy is implemented.

## Future prerequisites — explicitly NOT defined or built now
In a separate infrastructure/staff/economy design phase determine:
- Academy locations, classrooms, simulator facilities, training airfield access and aircraft procurement/leasing.
- Instructor and examiner roles, staffing counts, qualifications, class sizes, work schedules, training salaries.
- Training course curricula, durations, proficiency outcomes, capacity limits, expiry/recurrent checks and failure/retry rules.
- Course-specific equipment and aircraft compatibility, training and insurance expenses.
- Academy operating cash/reserve formula (must not pretend the proposed $40k fee alone provides full readiness).
- Inspection, course capability addition/removal, suspension/appeal and licence revocation/reinstatement.
- Relationships between the academy and existing airlinerra_game.section9_airline_crew_roster_v1, payroll and crew qualifications.
These remain decisions for the user. **Do not introduce fictional exact staff headcounts, training aircraft counts, reserve periods or facility build prices as confirmed licence requirements.**

## Planned application and lifecycle (not implemented)
1. Player creates a holding by existing company rules, then registers a **flight_academy** subsidiary (new company kind to be developed).
2. There is **no academy age waiting period**. Academy can prepare premises, people, aircraft/simulators and specific programmes. Exact minimum standards to be defined later.
3. Once all training capability, insurance, compliance and finances meet the later approved policy, apply for Licence 7 **for free**.
4. After 7 verified game days, review the company and course capabilities. If eligible, atomically issue one Licence 7 and charge **$40,000** to the academy ledger exactly once. Otherwise issue nothing and charge nothing.
5. Run internal company training. Optionally publish specific approved courses to external airline players with a **user-selected price per course**.
6. Independently verify each booking, trainer/aircraft/simulator availability, course rating, classroom capacity, payment and actual training completion.
7. Suspension stops affected programmes; unpublishing only hides future external sales and does not suspend the licence.

## Implementation backlog — future, not part of this specification
- [ ] Add registered `flight_academy` subsidiary kind and company finances to the holding company system.
- [ ] Define training course catalogue, curricula, crew qualification effects, availability and cost.
- [ ] Define academy infrastructure, simulator and training-aircraft requirements for each programme.
- [ ] Define instructor/examiner roles, training capacity and staff economy.
- [ ] Define insurance, course approval, site checks and safety inspections.
- [ ] Implement protected application + 7-day review + atomic exactly-once $40,000 approval charge.
- [ ] Verify each training booking against course, instructor, aircraft/simulator and academy capacity.
- [ ] Build private/public academy listings, programme-specific prices, booking and billing for other players' airlines.
- [ ] Add game and security tests, keep issuance and marketplace closed until independent end-to-end review.

## Existing Airlinerra context
- The current game planner has `FLIGHT_ACADEMY` as a future concept, with **$40,000** and **7 game days**, but suggests an airline training department rather than a dedicated subsidiary. This specification proposes updating that to one dedicated commercial subsidiary model consistent with Licence 6.
- The DB permission catalog currently has **no** `FLIGHT_ACADEMY` row and the holding's subsidiary type validation does not yet allow an academy; therefore this design is deliberately **not live**.
