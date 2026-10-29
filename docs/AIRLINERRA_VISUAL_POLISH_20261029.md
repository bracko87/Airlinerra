# Airlinerra - visual polish: financial palette, company news, typography and navigation

Updated 29 October 2026. Scope: UI and source tests only.

## Requested layout updates
- Cash/breakdown doughnut uses visible Airlinerra blue `#1976bf` for actual available airline funds, orange `#ff741f` for verifiable operating expenses, matching the income (blue) / expenses (orange) graph. No invented expense slice is shown when only the real initial capital is recorded.
- The company news card now has exactly two rows: first real event date, a normal hyphen and the company-news title; second a short summary limited to two displayed lines. No leading letter/icon, no redundant status paragraph. Dates are shown in `Europe/Berlin`; no false date is generated if an event is unavailable.
- Consistent lighter font hierarchy: medium navigation labels, normal copy, modest card-heading weight; bold remains for the principal page title, important airline values and financial figures.
- Reduced excess whitespace and card padding on game pages, public homepage, account, registration, Terms/Privacy/Legal/FAQ/Pricing, shared footer, and private tester pages. Global UI rhythm is 18px between game cards on desktop and 16px mobile, retaining responsive and readable minimums.
- Operations dropdown order is **Hubs and airport operations -> My routes -> Create a route -> Flight schedule -> Cabin services -> Ticket prices and analysis -> Personnel and staff**. `My airline` remains under Settings, not duplicated under Operations.

## Technical changes and safety
- `website/airline-finance-charts.mjs`: centralized `FINANCE_CHART_COLORS` in static client module, SVG drawing updated and net-worth classes unchanged.
- `website/airline-dashboard.mjs`: self-contained safe DOM creation for news, date before headline, one short description. Exported `renderCompanyNews` for regression testing. No user-supplied HTML string interpolation.
- `website/private-player-app.html`: adjusted nav order, renamed chart subtitle to Cash and cost breakdown, removed static news footnote.
- CSS changes on game, public, registration, account, legal, studio footer, private tester sign-in and tester dashboard.
- Tests `tests/test_airlinerra_visual_polish.mjs` (5 focused cases) added to website test command and CI. Navigation tests updated for hub-first ordering and new palette.
- No change to database schema, authentication, cash, other game systems or release gates. No Netlify deployment.
- The exact npm build and browser visual regression still require localhost testing because this environment cannot access the owner's browser or download the whole repository.
