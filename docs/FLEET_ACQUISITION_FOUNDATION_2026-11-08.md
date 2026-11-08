# Airlinerra: real aircraft acquisition foundation (2026-11-08)

## Implemented

- **Private World 1 game market** `airlinerra_game.aircraft_acquisition_offers_v1`: explicitly administrator-priced purchase or lease offers, with upfront charge, lease monthly term, delivery days, and draft/published/retired states. **No offers or prices were seeded**; no fake prices are displayed.
- **Private acquisition receipts** `airlinerra_game.aircraft_acquisition_orders_v1`: stable request ID, player and airline owner, fleet airframe UUID, price at order time, delivery home airport, pending-delivery status.
- **Atomic owner-verified purchase/lease transaction** `airlinerra_game.acquire_offered_aircraft_v1`: locks the airline's balance, checks active membership and current published offer, blocks Group 3 research-only aircraft, debits upfront USD balance, writes exactly one `AIRCRAFT_PURCHASE` or `AIRCRAFT_LEASE` ledger row and creates a unique-registration individual airframe. Duplicate request IDs replay without extra charges. Missing funds, spoofed player IDs and duplicate registration fail closed.
- New acquired fleet enters `fleet_status='stored'` / `order_status='awaiting_delivery'`; **not in_service**. Existing Section 5/6 draft scheduling denies stored aircraft. No live flight is created.
- New verified Auth Supabase Edge endpoint **`airlinerra-fleet-acquisition`** deployed, version 1 ACTIVE, fresh Auth user verification in request handler, no service-role credentials in browser and no client-controlled amount. SQL functions and tables are private/RLS-enabled.
- Netlify same-origin bridge `/api/v1/player/fleet-acquisition` now maps to the pinned Supabase Edge endpoint and is registered in `website/netlify/functions/airlinerra-game.mjs`.
- Browser fleet and aircraft market workspace now reads protected owned/leased airframes and published game prices. The confirm-order control is disabled when no approved offers exist. Cash and owned-aircraft state is re-read after a confirmed order.
- Latest focused route-planner CI after new client API tests was successful. Full account/onboarding CI still reports independent older assertions; treat project as not fully release-green.

## Tests

- Executed rollback-only SQL financial and fleet integration tests against the live Airlinerra production database. Purchase, lease, insufficient cash, forged owner, published offer, case-insensitive duplicate registration, idempotent replay and rejection of still-stored aircraft from flight scheduling passed.
- Committed executable suite: `tests/sql/player_aircraft_purchase_lease_atomic_acceptance.sql` — executed and passed; all fixtures rolled back.
- Added Node API/browser client/proxy contract suite `tests/test_fleet_acquisition_api.mjs` to focused route-planner CI. Covers verified user identity, strict path/origin, price tampering prevention, private cash and inventory, error mapping, and Netlify pinning.

## Post-test database snapshot

- Published offers: **0** (pricing not yet reviewed)
- Real player-aircraft inventory: **0**
- Purchase/lease orders: **0**
- Flight schedule drafts: **0**
- Slot reservations: **0**
- Existing airline balance remains untouched by the rollback tests

## Still required before any actual playable aircraft or flight release

1. Approve in-game economic **aircraft purchase and lease prices** and decide supply availability, condition/age, recurring lease charges and contract renewal rules. Do not invent prices based on model catalog.
2. Add protected individual aircraft delivery, inspection, home-base positioning and maintenance/availability transitions; do not auto-promote a purchased aircraft into `in_service`.
3. Build aircraft overlap/rotations, realistic trip durations/turnarounds and full recurring horizon verification, crew, traffic rights and slot lock revalidation.
4. Build server-owned live flight activation/game time/execution/economics before enabling revenue or flights.
5. Test real verified-owner production-browser acquisition and simultaneous financial requests. Current tests are rollback fixtures only.
6. Resolve older unrelated broad CI failures before calling the full release green.

No physical aircraft, customer billing, actual cash purchase or flight activation was triggered by this work. No source-backed game market price was assumed.
