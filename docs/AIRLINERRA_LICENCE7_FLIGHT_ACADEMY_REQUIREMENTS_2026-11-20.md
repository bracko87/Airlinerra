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
| Training aircraft requirement | **At least one purchased and operational small training aircraft, assigned to the academy, before Licence 7 can be approved**; not required merely to register the subsidiary |
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

## Training fleet, simulator and airline-aircraft assignment (confirmed design)
- Later introduce a curated catalogue of approximately **10–20 small dedicated training aircraft models** available for academy purchase. The exact models, specifications, availability, costs, operating costs, types of training and licences supported are to be chosen and researched later.
- **Mandatory Licence 7 approval prerequisite:** the academy must own/purchase or have delivered at least **one operational, eligible small training aircraft assigned to the academy**. A simulator alone or an ordinary passenger airline aircraft alone does **not** satisfy this initial aircraft minimum. Delivery, operational condition, location and valid training eligibility are verified on approval and periodically afterward. No requirement to own all 10–20 models.
- The academy can additionally buy/own eligible **flight simulators**. Their types, supported courses and whether a specific course requires a simulator will be defined later. Simulators are optional for academy company registration; they may be mandatory for particular advanced courses.
- A holding's operating airline may voluntarily **assign a larger passenger/cargo aircraft** (for example an **ATR 72**) to a training session without selling or permanently transferring the aircraft to the academy. The registered aircraft remains in the airline's fleet and on the same holding's ownership records. Training creates a temporary use/availability allocation, **not** duplicate inventory or an automatic ownership transfer.
- An ATR 72 type-training course requires a programme and instructors specifically approved for the ATR 72 (or applicable variant/rating) and the verified proper aircraft/simulator resources. One generic training aircraft does not automatically authorise ATR 72 type qualifications.
- Later support a **separate, explicit ownership transfer or long-term reassignment** from operating airline to academy, with real inventory/accounting movement and loss of airline operational availability, if the player chooses it. That is distinct from temporary calendar booking.
- A training reservation must occupy the real aircraft's **same canonical availability calendar** as scheduled commercial flights, maintenance and other holds. The training interval must include positioning, setup, training, turnaround and recovery where applicable; exact lengths come from the future course/scheduling model.
- **Atomic exclusivity:** training can book an aircraft only if no commercial flight, maintenance job, transfer or other training reservation overlaps the interval. Existing flight allocations cannot be silently overridden. Conversely a flight cannot be scheduled or dispatched while the aircraft is reserved for training. No double-booking, including multi-day training and time-zone/DST boundaries.
- Airline flight schedule, maintenance status, aircraft safety/airworthiness and readiness remain authoritative. Scheduling a training session does not override grounding, condition or permit checks. Cancelling the session releases only its own holds; no automatic cancellation of unrelated flights.
- For cross-company training (other player's airline), future commercial agreements must explicitly permit aircraft access; owning an academy does not allow reserving other users' aircraft without consent.
- Where simulator training fulfills a course requirement, simulator scheduling must use its own exclusive availability calendar, alongside instructor and trainee availability.

## Pilot training programme and individual qualification lifecycle (to define later)
- Separately model the **company's Licence 7** and the **individual pilot's qualifications**. The academy licence authorises the business to conduct specified courses; a pilot needs their own relevant game qualification to operate each aircraft type.
- Future courses may include first pilot qualification, multi-engine, instrument, transport/airline pilot levels, **aircraft family/type ratings** (including ATR 72), and recurrent/check training. Exact prerequisites, age/experience/hour requirements, training levels, simulator vs actual-aircraft requirements, pass criteria, course durations and costs must be designed later.
- Each pilot qualification record must identify qualification/rating code, supported aircraft family/type, issuer academy, training outcome, issue/expiry dates when applicable, suspension/revocation state and audit history.
- A pilot without the required valid aircraft type/rating must not be assigned to a flight requiring that qualification. Recurrent qualification expiry prevents assignment until renewed, but does not remove their unrelated qualifications.
- Qualification **renewal** means successful recurrent course/check and verified competence; expiry is not automatically a permanent revocation. Suspensions are reversible subject to retraining and re-check; revocation requires a separately logged justified action.
- Loss of an academy's Licence 7 must stop **new academy courses and new training certificate issuance**; it does **not automatically erase already issued pilots' valid qualifications**. Individual qualifications can separately lapse or be revoked due to pilot-specific reasons.
- Actual qualification validity durations, renewal windows, course costs and recurrent training frequencies remain **open design decisions**. Do not infer official real aviation pilot licences from game records.

## Licence 7 continuation, inspection, suspension, revocation and renewal policy
- **Validity:** proposed continuing organisational licence (no routine expiration date), subject to a **compliance inspection every 365 verified game days**; this is an inspection/revalidation, not a new paid licence.
- **Renewal:** after a successful annual compliance inspection, record a new valid-until-inspection date. No automatic annual licence renewal fee. An inspection failure should not be represented as an automatic arbitrary licence charge.
- **Temporary suspension:** an eligible authority/game process may pause a specific course or the whole academy if it lacks the mandatory training aircraft, qualified instructors, valid equipment/simulator rating, approved premises, safety standards, insurance or the resources needed for its approved courses. If the single mandatory small training aircraft becomes unavailable, the **company's licence is suspended until a qualifying replacement or repaired aircraft is verified**; no new training bookings or certifications while suspended.
- **Recovery:** fix the deficiency, verify all prerequisites and complete a reinspection/revalidation. Restore the same licence when appropriate, without an unnecessary second $40,000 initial issuance charge.
- **Expiry/lapse:** if the compliance inspection is overdue, place the academy under an auditable restricted/suspended state, not instantly delete its records. Define exact notice and grace period later.
- **Revocation:** reserve for serious fraud, falsified training completions or instructor qualifications, grave/repeated safety issues, intentional operation while suspended, or permanent loss/closure of the company. Require an independently reviewed reason and audit record, plus controlled notice and appeal workflow.
- **Reapplication:** after a final revocation, a new application and approval can be required, with the normal $40,000 proposed approval fee; do not permit direct self-reactivation.
- **Marketplace:** unpublishing a provider or its courses is a voluntary commercial choice and must **never count as a suspension or revocation**.
- The exact inspection notice timing, suspension grace periods, fines, appeals and recurring operating charges will be specified in a later policy review before live activation.

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
- Academy locations, classrooms, simulator facilities, training airfield access, the planned catalogue of 10–20 small training-aircraft models and their costs. The **one purchased eligible small training aircraft before academy Licence 7 approval** is already a confirmed minimum; the rest of the training fleet is not mandatory.
- Instructor and examiner roles, staffing counts, qualifications, class sizes, work schedules, training salaries.
- Training course curricula, durations, proficiency outcomes, capacity limits, **pilot type qualifications (including ATR 72), individual qualification expiration and recurrent training**, failure/retry rules.
- Course-specific equipment and aircraft compatibility, training and insurance expenses.
- Academy operating cash/reserve formula (must not pretend the proposed $40k fee alone provides full readiness).
- Implement the above academy licence inspection, annual compliance revalidation, reversible suspension, independently reviewed revocation and pilot-specific qualification renewal policies; exact grace/fine periods remain open.
- Relationships between the academy and existing airlinerra_game.section9_airline_crew_roster_v1, payroll and crew qualifications.
These remain decisions for the user. **Do not introduce fictional exact staff headcounts, training aircraft counts, reserve periods or facility build prices as confirmed licence requirements.**

## Planned application and lifecycle (not implemented)
1. Player creates a holding by existing company rules, then registers a **flight_academy** subsidiary (new company kind to be developed).
2. There is **no academy age waiting period**. Academy prepares premises, people, aircraft/simulators and specific programmes. **At least one purchased, delivered, operational, assigned small training aircraft is mandatory for Licence 7 approval.** Other readiness thresholds remain to be defined.
3. Once all training capability, insurance, compliance and finances meet the later approved policy, apply for Licence 7 **for free**.
4. After 7 verified game days, review the company and course capabilities. If eligible, atomically issue one Licence 7 and charge **$40,000** to the academy ledger exactly once. Otherwise issue nothing and charge nothing.
5. Run internal company training. Optionally publish specific approved courses to external airline players with a **user-selected price per course**.
6. Independently verify each booking, trainer/aircraft/simulator availability, course rating, classroom capacity, payment and actual training completion. Any temporary reservation of an operating airline aircraft (e.g., ATR 72) must atomically prevent overlapping commercial flights and maintenance in the canonical aircraft calendar.
7. Suspension stops affected programmes; unpublishing only hides future external sales and does not suspend the licence.

## Implementation backlog — future, not part of this specification
- [ ] Add registered `flight_academy` subsidiary kind and company finances to the holding company system.
- [ ] Define training course catalogue, curricula, pilot-specific aircraft-type qualification requirements, recurrent check/renewal validity windows, crew assignment gate, availability and cost.
- [ ] Introduce 10–20 researched small training-aircraft models in the aircraft catalogue; purchased/delivered/assigned eligible aircraft required (minimum one) for academy approval.
- [ ] Define academy infrastructure, simulator types and training-aircraft requirements for each programme.
- [ ] Build safe temporary holding-owned airline aircraft assignment to academy, including ATR 72 type training and optional actual fleet transfer/reassignment.
- [ ] Integrate training-session reservations into the canonical commercial aircraft schedule with atomic no-overlap maintenance/flight/training checks.
- [ ] Define instructor/examiner roles, training capacity and staff economy.
- [ ] Define insurance, course approval, site checks, annual academy licence inspection, recoverable suspension, independently reviewed revocation and separate pilot qualification expiry/renewal.
- [ ] Implement protected application + 7-day review + atomic exactly-once $40,000 approval charge.
- [ ] Verify each training booking against course, instructor, aircraft/simulator and academy capacity.
- [ ] Build private/public academy listings, programme-specific prices, booking and billing for other players' airlines.
- [ ] Add game and security tests, keep issuance and marketplace closed until independent end-to-end review.

## Existing Airlinerra context
- The current game planner has `FLIGHT_ACADEMY` as a future concept, with **$40,000** and **7 game days**, but suggests an airline training department rather than a dedicated subsidiary. This specification proposes updating that to one dedicated commercial subsidiary model consistent with Licence 6.
- The DB permission catalog currently has **no** `FLIGHT_ACADEMY` row and the holding's subsidiary type validation does not yet allow an academy; therefore this design is deliberately **not live**.
