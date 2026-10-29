# Airlinerra - reference video UI review (29 October 2026)

The owner supplied two videos plus screenshots of AirwaySim and AirlineSim.
These are design and workflow references only. Airlinerra must retain its navy,
orange and white visual identity, its own page structures and its game rules.
Do not copy third-party code, screenshots, proprietary graphics or wording.

## AirwaySim video - approximately 99 seconds

- Office dashboard: compact airline selector, world status, cash, company
  image, finance and transported passengers/cargo views.
- Income Statement: selectable weekly/monthly/quarterly/yearly periods,
  financial rows separating operating revenue and expenditure.
- Route management: search and filters by country, airport and route state,
  route list with dates and contextual edit/status controls.
- Aircraft market: individual aircraft detail with model, age, configuration,
  condition and operating specifications, plus procurement actions.
- Route opening: approved destination airport selection with additional
  geographical and operational filters.

## AirlineSim video - approximately 67 seconds

- Dashboard: dense airline status, operating KPIs and financial snapshots.
- Navigation: grouped game features for route evaluation, staff, fleet,
  accounting and operational reports.
- Route evaluation: criteria and analysis table before establishing a route.
- Fleet: aircraft inventory, airframe data and configuration actions.
- Aircraft specification/detail: aircraft images, range/performance information,
  availability and acquisition controls.

## Airlinerra design decisions

Implemented in the current UI pass:
- Consistent card-to-card spacing and responsive layouts throughout the player
  game and common website/account/registration card collections.
- Airline logo positioned within the unused right side of the company KPI card.
- Removed completed registration calls to action and temporary verification
  headings from the dashboard, while preserving login/security handling.
- New airline name, three-letter ICAO code, two-character IATA code and
  uploaded logo in the creation flow and summary. Codes are server-validated
  and unique per world, with an atomic database creation function.
- The real airline detail view displays the persisted code values, or
  "Not assigned" for pre-existing companies - no invented values.

Next functional work (requires canonical data and server-side engines):
1. Aircraft model variants and individual physical aircraft inventory.
2. Marketplace price/condition and buying/leasing transactions.
3. Route evaluation with approved passenger/cargo demand, cost and rights.
4. Real 7x24 per-airframe flight scheduling, crew slots and route execution.
5. Live revenue/expense ledgers with weekly/monthly/yearly reporting.
6. Customer satisfaction, passenger transport, cargo and rankings.

Avoid fabricated financial reports, aircraft offers, flight histories or
demand levels until those engines and real data exist. Browser-only planning
drafts must continue to be labelled explicitly.
