# Airlinerra World 1 — starter aircraft market and delivery lifecycle
Date: 2026-11-08

## Summary
Configured the first *game-priced* aircraft acquisition catalog around the $5,000,000 starting airline balance. These are explicitly Airlinerra balance prices for standardized reference airframes, NOT actual third-party aircraft sale listings or claims about the condition/age of a particular aircraft.

**Nine PURCHASE offers are published in the database. Nine matching LEASE price cards are drafted but deliberately NOT published** until a reliable game-clock recurring billing service exists. A protected database trigger prevents inadvertent publication of unbilled leases and prevents publication of research-only or Group 3 aircraft. The existing atomic purchase transaction and finance ledger remain the only order write path.

| Aircraft (game model) | Use | Game purchase USD | Draft lease upfront USD | Draft lease monthly USD | Delivery days |
|---|---|---:|---:|---:|---:|
| Beechcraft 1900C | Cargo | 2,100,000 | 150,000 | 38,000 | 3 |
| Beechcraft 1900D | Passenger | 2,400,000 | 160,000 | 40,000 | 3 |
| Fokker 50 | Passenger | 3,800,000 | 250,000 | 58,000 | 4 |
| Dash 8-300 | Cargo | 4,200,000 | 260,000 | 65,000 | 5 |
| ATR 42-500 | Passenger | 4,500,000 | 280,000 | 70,000 | 5 |
| Embraer ERJ 145 | Passenger | 7,200,000 | 450,000 | 118,000 | 6 |
| ATR 72-500 | Passenger | 7,800,000 | 475,000 | 125,000 | 6 |
| Cessna 408 SkyCourier | Passenger | 8,500,000 | 600,000 | 140,000 | 8 |
| Airbus A320-200 | Passenger | 19,000,000 | 1,100,000 | 260,000 | 10 |

All lease terms are 12 months *in the draft pricing catalog only*. Values are preliminary game-balance inputs and should be revisited together with daily operating cost, demand, financing, lease renewals and the flight economics engine. No loan facility or automatic capital is fabricated.

## Technical implementation
- Game prices: `supabase/migrations/20261108131000_airlinerra_starter_game_aircraft_market.sql`
- Delivery receipt, protected inspection queue and owner-only due-time check: `supabase/migrations/20261108133000_airlinerra_aircraft_delivery_inspection_pending.sql`.
- `airlinerra_game.check_owned_aircraft_delivery_v1(player_uuid,airline_uuid,order_uuid)` verifies actual airline ownership and order ownership; only when `now() >= delivery_due_at` can move `awaiting_delivery` → `delivered_pending_inspection`; creates exactly one pending inspection record; does NOT change `fleet_status='stored'`.
- `server/fleet-acquisition-service.mjs`: strict `check-delivery` action and server-only SQL with fresh verified Auth identity.
- `website/fleet-acquisition-client.mjs` and `website/airline-workspace.mjs`: player fleet page “Check delivery” button; no client-generated delivery or inspection status. Safe DOM text rendering, normalized manufacturer labels.
- Supabase protected Edge endpoint `airlinerra-fleet-acquisition` deployed as version 2 ACTIVE with server-side Auth verification; Netlify bridge for the fleet route already registered in GitHub.
- All purchases create unique individual fleet rows and debit verified airline cash atomically. Market has no player purchases by default; no preloaded player assets, fake proceeds or refunds.

## Passed tests
- `tests/sql/player_starter_prices_delivery_pending_acceptance.sql`: live connected Supabase, rollback-only, passed after correcting an ambiguous **test variable**; no permanent writes. Tests authorized purchase price, closed unbilled lease, foreign owner denial, once-only ledger/payment, replay request ID, insufficient money and duplicate registration; before-due delivery denial, after-due pending inspection, single inspection record despite retries, foreign order denial and refusal to schedule the uninspected stored airframe.
- Updated earlier `tests/sql/player_aircraft_purchase_lease_atomic_acceptance.sql` to run against the published game market without colliding with the seeded published offers.
- New Node API/DOM tests in `tests/test_fleet_acquisition_api.mjs` check the protected delivery route and prohibit forged inspection approval. Case-sensitive text test corrected; focused route-planner GitHub CI subsequently passed.
- Section 5 + 6 restriction and slot tests passed previously. This work does **not** claim live operational flight coverage.

## Status and known blockers
- 9 published game-priced purchase offers
- 9 unpublished game-priced lease cards
- 0 actual aircraft orders, 0 actual owned-airframe inventory, 0 inspection records, 0 draft flights; current airline balance still $5,000,000
- Delivery is not synonymous with operational service: no approved inspection/maintenance workflow, aircraft position, rotation or crew, rights, full billing, flight clock execution, activation or revenue is active. Customer checkout before these are live results in a stored, unusable aircraft. Keep this status explicit in the UI.
- Real authenticated production-browser purchase test and Netlify live endpoint validation have **not** been performed, and wider onboarding/account GitHub CI remains red from older tests.
- There is no warranty that preliminary used/reference prices match real individual aircraft condition, market prices or quotes. Pricing is game economy design.
