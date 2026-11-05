# Airlinerra strategic management menu — phase 1

Status: player-facing navigation and informational planning pages only, **not economic gameplay**.

## Main menu order

Dashboard | Holding (locked) | Operations | Fleet | Infrastructure | Employees | Marketing | Finance | Statistics | Account | Settings.

- **Operations:** Hubs and airport operations, routes, schedules, cabin services, ticket pricing.
- **Fleet:** Fleet, aircraft market, and maintenance for aircraft already operated.
- **Infrastructure:** Overview, airline headquarters, maintenance facilities, passenger lounges and airport services.
- **Employees:** Employee overview, pilots, cabin crew, ground crew, technical staff, board and management, wages and salaries.
- **Marketing:** Airline reputation, advertising campaigns, and commissioned route research.
- **Statistics:** Overview, airlines, airports, aircraft, rankings.
- **Holding:** visible but disabled. Does not allow creation, purchase, or legal operation.

## Future Holding rules — design proposal

Minimum eligibility: **60 completed in-game days** since the original airline started operations. This is a floor, not automatic approval. The actual company creation flow must also check:

1. A material one-time holding formation charge, cash reserve and ongoing administration costs. Final amounts are undecided.
2. Verified safety and operational record, plus a minimum amount of operating experience.
3. Country registration, business licensing and any applicable aviation approvals.
4. No existing compliance or insolvency restriction.
5. Server-side ownership and company-management authorization.

Holding company should have a verified owner, parent-child company relations, separate ledgers, capital transfers and audit logs. Possible subsidiaries: passenger airline, low-cost airline, regional airline, cargo carrier, executive/VIP airline, and maintenance/repair/overhaul (MRO) provider. Each subsidiary must have its own licensed operating rights, airline/brand identity, staff, fleet, financial accounts and reputation; shared assets or services require an explicit priced and audited contract. The holding should not automatically inherit unrestricted route rights from any subsidiary.

MRO services for the owner's or other players' aircraft will require airport facility access, certified mechanics, hangar capacity, equipment and a secure contract/payment flow. This is distinct from the existing Fleet > Maintenance planning page.

## Infrastructure planning

- **Headquarters:** executive offices, operations center, HR, finance, training and regional offices. Levels/capacity/costs to be balanced later.
- **Maintenance facilities:** line and base maintenance hangars, workshops, spare parts, servicing capacity, compatible aircraft types, training and third-party work.
- **Lounges and airport facilities:** lounges, counters, staff rooms, cargo handling, ground equipment and local offices. Each location must have permits, costs, capacity and airport-specific constraints.

## Employees planning

Distinct departments: pilots, cabin crew, ground operations, licensed technical staff, board/managers and payroll. Pilot records will track nationality, age, accumulated flight hours, aircraft type rating, experience and required rest. Salaries will eventually be adjustable via department/position sliders; changes must be validated and written by the server, update company costs, and not alter historical pay.

A practical initial board structure is CEO, COO, CFO, safety director, commercial/marketing director, and HR director. Technical/MRO director and separate subsidiary managing directors are optional as the company grows. Numbers and salaries are not final.

## Brand, reputation and marketing

Each airline or subsidiary has an **independent** reputation. Proposed starting score **50/100**, not currently stored or displayed as a live value. Positive signals may include punctuality, safety, passenger satisfaction, completed reliable service, and fair value. Incidents, cancellations, complaints and poor reliability may reduce scores; serious safety events should not be erasable by ad spend. Campaigns will have target audience, market, dates, budget, measured impact and diminishing returns. Route market research may be commissioned from an agency for a defined airport pair and time window, with transparent fees, competition/demand estimates, and uncertainty.

Reputation computation, actual salaries, agency purchasing and subsidiaries are intentionally **not** activated by these UI pages.

## Statistics principles

Separate airline, airport and aircraft measures. Rankings should be limited to verified within-world records and real operators. Do not invent airlines, aircraft holdings, finances, safety incidents, passenger traffic, routes or scores. Display a clear unavailable status until a secure reporting endpoint is implemented.

## Enforcement and migration notes

- Holding is a visible, grey, non-clickable navigation label; planning page is informational if opened by a direct URL.
- Existing user accounts, airline creation, flight scheduling, payment, aircraft release gates, RLS and official results are unchanged.
- Never turn client-side time-in-game estimates into permission checks; holding eligibility needs authoritative server game time and original airline start date.
- No frontend form may create daughter companies, debit funds, alter salaries, purchase buildings or change reputation until vetted authenticated server endpoints exist.
- Do not use airline aircraft test fixtures as live inventory.

## Release sequence

1. UI scaffolding and informational pages (this change).
2. Decide licenses, prices, eligible countries, requirements and entity relationships.
3. Build and test server-side permission, ownership, inventory, payroll and finance contracts.
4. Wire actual operational events into reputation/statistics with auditable calculations.
5. Enable specific controls only after backend, security, migration and UI integration tests are satisfied.
