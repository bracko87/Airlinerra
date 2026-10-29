# Airlinerra - player pages and feature connection audit
Updated 29 October 2026. No public gameplay release or automatic Netlify deployment.

## Source and architecture

- `website/private-player-app.html`: 19 verified routes, horizontally grouped Dashboard, Manager, Operations, Fleet, Finance, Account and Settings.
- `website/player-app.mjs`: verified Supabase session, real airline/cash/airport read endpoints, authenticated World 1 onboarding, navigation.
- `website/airline-workspace.mjs`: richer views, safe DOM rendering, locally stored player preferences and browser-only planning drafts.
- `website/player-app.css`: responsive tables, cards, accessibility, compact display, reduced animation and optional dark theme.
- `website/player-app-model.mjs`: allowlisted routes and cash formatting.
- `server/player-read-service.mjs`: read-only owned airline and approved-airport API, home airport label, approved fictional airport keys; Supabase Edge game API v6.

## Pages, real functions and pending engines

| Page | What is usable in the first pass | Must be connected before live gameplay |
| --- | --- | --- |
| Dashboard | Real airline name, logo, cash, company status, navigation to work areas | Live operating KPIs, notifications, routes, aircraft |
| Airline setup | Verified existing registration, world/home airport, name, private owner airline activation | Public game release remains closed |
| My airline | Company info, registered world/home airport, actual starting cash | Airline management policies, branding edits, subsidiaries |
| Manager profile | Verified account details, recovery link | Server-side profile editing if desired |
| Personnel | Roles and staffing workflows explained | Hiring, wage policies, payroll, crew qualifications and rest |
| World rankings | Ranking dimensions and world context | Competitor database, score calculation and leaderboard |
| Game worlds | Three independent world cards, World 1 owner access | Activation of future worlds on approval |
| Airports | Live approved search and six airport categories | Actual route-specific demand, capacity/slots, additional rules |
| Routes | Verified airport-pair selection, 1-28 flights/week local draft | Route opening, legal traffic rights, demand and pricing |
| Flight schedule | 7x24 visual grid, local departure drafts, duplicate/limit checks | Tail assignment, turnaround and gate slots, execution engine |
| Passenger/cargo service | Economy, premium economy, business and first class brief, service option | Aircraft-specific seat layout, fares, catering, cargo contracts |
| Fleet | Fleet acquisition brief with family, range, capacity, financing | Real registered tail inventory and assignment |
| Aircraft marketplace | Acquisition requirements and seller/deal structure | Aircraft variant catalog API, new/used offers, purchase/lease |
| Maintenance | Service, condition and grounding workflow content | Maintenance records and aircraft availability engine |
| Finances | Live owned-airline cash, monthly budget scenario, estimated runway | Revenue, costs, cash flows, lending, ledger and reporting |
| Settings > General | Working local per-account distance, time, date and timezone display settings | Other languages only when translated |
| Settings > Interface | Working local light/dark, comfortable/compact, reduced motion, starting page | Cross-device synchronized preferences if desired |
| Settings > Notifications | Essential account notice status and on-screen guidance toggle | Real notification types, preference filtering before delivery |
| Settings > Help | Getting-started guide, FAQs, links to game areas and legal/support | A guided, interactive product tutorial if approved |

## Planning-data safety

- Fleet, cabin, route and financial briefs use authenticated player's browser tab storage only. They do not create aircraft, routes, book flights or mutate the database.
- General/interface settings persist per verified account in the current browser only, using browser storage. A blocked storage environment keeps session behavior without breaking login.
- Public world release, auth and finance write authorization remain server-controlled.
- Passenger and cargo demand is not invented. Real market offers/prices are not fabricated.
- The existing World 1 airport roster, including Kosovo as separate game country and the fictional Aleksandrovo Airport, remains owner-approved.

## Next implementation milestones (backend, separate work)

1. Canonical aircraft variant and individual airframe inventory API, then secured purchase/lease and fleet ownership.
2. Airport-pair passenger/cargo demand, traffic rights, route costs and creation authorization.
3. Per-tail 7x24 schedules, crew/turnaround/slot validation and game-clock flight execution.
4. Fares, cabin layouts, ticketing/booking, cargo and quality/satisfaction.
5. Fuel, maintenance, staff, payroll, financial transactions, reporting and loans.
6. Multiplayer rankings, inbox/alerts, marketing, alliances and operational statistics.
7. Local and hosted end-to-end tests, gameplay balance, security and manually authorized public release.

References for feature coverage: AirlineSim and AirwaySim, as supplied by the owner.
