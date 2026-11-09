# Section 9 — Route Details: financial forecast and last-seven actual flight balances
**Decision confirmed:** the owner accepted the existing Section 8 airport/takeoff/stand/ATC/passenger/cargo game fee model on **9 November 2026**. The source of truth is the existing six-tier/category/background pricing in Supabase. The acceptance is recorded in the Section 8 game-data audit. No rates were changed, no commercial flight was activated and no money was charged.

## Requested route behavior

Every saved **Route Details** page shows a financially useful overview:

1. **Before operation (clearly marked estimate):** Current game airport movement, landing, selected terminal/remote/cargo stand, airport ground handling, terminal/tower ATC, weight+distance-based en-route ATC, departing passenger facility/security/international processing and cargo handling **itemized separately**. Values come from the Section 8 database quote, not browser math. User can compare **25/50/75/100%** assumed load and **1/3/6/24 hours** of destination parking. Uses assigned aircraft MTOW and currently selected stands.
2. **Projected income:** Uses the *saved route commercial economy fare* × assumed actual passenger seats and *saved cargo rate* × assumed cargo tonnes, if configured. **No fare is invented** if none is configured. Displays the resulting **partial margin before fuel, crew, maintenance, ownership, insurance and other costs**, never labels it final profit. Saving a new fare automatically refreshes route economics.
3. **After actual operation:** One chronological row per **latest seven** financially finalized flights, expanding to show ticket/cargo/other revenue and ALL eleven airport+navigation cost components plus fuel, crew, maintenance, ownership/lease and other expenses, with final positive/negative balance.
4. **Older flights:** The UI shows **only aggregate older-flight revenue, costs, final balance and count**. Across all historical flights it also shows posted total revenue, expenses, profit/loss and completed-flight count. No artificial seven-flight history or zeroed forecasts are produced.
5. **Zero-passenger/zero-income flights:** Legitimate fully settled aircraft operations with zero income and real expenses are included as **negative balances**. Revenue-ledger row is optional ONLY when full revenue is exactly 0; expense ledger and signed arrived event are mandatory.

## Private data model and security

- `airlinerra_game.section9_owned_route_financial_dashboard_v1(player, airline, schedule, load_pct, parking_minutes)` — owner-checked, **SECURITY INVOKER** and private. Uses existing saved configuration and `section8_quote_flight_operating_fees_v1`, stored actual capacity, saved commercial fare/cargo rate. Rejects unknown route ownership and invalid load/parking assumptions.
- `section9_route_posted_flight_financials_v1` — immutable private per-flight financial statement, one row per physical operation; references a **signed ARRIVED** flight movement event and its real **REVENUE (if positive)** and **EXPENSE** airline-ledger transactions. Detailed airport fee JSON must contain **all eleven fee lines** and sum precisely to its posted airport total. Expenses include independent fuel, crew, maintenance, ownership and other categories, all mandatory for a *final* result. No write API or producer was installed, so there are **zero real finalized flight statements** at this time.
- The source query **reconciles** signed-arrival ownership, schedule, game date, and exact source ledger amounts and entry types on every read. Prepared revenue intents, forecast demand, incomplete bookings and unsupported records are never counted as posted/actual results.
- `row_number() OVER(ORDER BY flown_game_day DESC, recorded_at DESC, physical_flight_id DESC)` ensures deterministic most-recent-seven. `FILTER (WHERE sequence>7)` accumulates all older flight stats; the private source retains auditable older records rather than permanently deleting accounting evidence.
- The table uses RLS and direct browser-role revocations. Existing signed flight-activation constraints remain untouched.

## API and UI

- Adds existing authenticated flight-schedule POST action `route-financials` with bounded `loadPercent` and `parkingMinutes`. The server supplies **verified Supabase user identity**, not browser-supplied owner credentials. Database checks the user owns the airline AND schedule.
- `website/flight-schedule-client.mjs` adds the user-only `routeFinancials` read action, no financial write.
- `website/section9-route-finance-panel.mjs` supplies a route financial forecast and actual posted history. All text is inserted as `textContent`, not untrusted HTML.
- `website/section9-route-details.mjs` mounts the panel adjacent to existing commercial planning and rotation details. `website/section9-commercial-plan-editor.mjs` refreshes it after saved route fare changes; CSS follows existing game panels.
- The panel validates all eleven quoted cost lines, totals and actual flight statements before display and refuses unsupported or suspicious responses.
- Frontend and server have no endpoint to post tickets, settle payments, create synthetic movement events, approve routes, or activate a flight.

## SQL/CI verification

- The migration ran successfully in rollback mode then was installed to production Supabase. A second hardening migration supports **zero-income losses** and strictly requires the eleven fee lines to reconcile.
- A rollback-only SQL test creates one synthetic owned 737-8200 route and commercial plan, checks 197 seats at 100%, $150 economy fare, expected $29,550 gross potential income, **$14,306.25** current full-load Section8 airport+ATC fees, and $15,243.75 partial margin. At 50%/60-minute parking, the model computes 99 seats and zero parking fees.
- That same test creates **eight synthetic signed arrivals with matched airline-ledger expenses** and income for seven; one completed flight earns zero and loses $10,000. The reader displays 7 detailed flights, 1 older total and full-route $60,028 net, then excludes one flight deliberately made financially unreconciled. **All synthetic data is rolled back.**
- Focused Node tests cover browser payload constraints, server auth/owner arguments, negative responses, fee sum integrity, actual results, last-seven limit and fare-save UI wiring. GitHub CI and website build must pass before merge.

## Remaining Section 9 work (do not misstate)

World 1 remains **planned** and has no actual route schedules, executed flights, demand bookings or settled revenues. This implementation makes route finances **visible and ready to consume trustworthy future entries**, but it does NOT create the independently signed operating-flight producer or protected multi-category financial-settlement writer.

Before the UI can display actual positive/negative results:
- Complete crew, game licence, slot and activation authority, real flight event producers and bookings.
- Write a trusted, atomic, idempotent finance settlement transaction that posts source-verified income and all associated expenses and inserts its matching **posted_complete** snapshot only after both the signed arrived event and airline ledger payments commit.
- Integrate actual fuel purchasing, crew duty/payroll, maintenance, aircraft cost allocation and all other billed charges in the same trust boundary.
- Reconcile all sums and make compensation-only corrections, never mutate immutable settled flight history.
- Prove normal, zero-revenue loss, cancellation, duplicate event, retry, recovery, and hundreds-of-airlines/many-flights load scenarios.

**Current decision:** Section 8 is accepted and should not be reopened to guess additional fees. Future economic tuning must be measured against actual flight profitability, not interpreted as missing Section 8 airport data.
