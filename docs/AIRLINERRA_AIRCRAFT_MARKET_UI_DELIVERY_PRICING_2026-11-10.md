# Airlinerra aircraft marketplace — selectors, delivery and sellers (10 Nov 2026)

## Implemented (GitHub main + Supabase World 1)

Two separate shared-design pages:
- `#aircraft-new-orders` — current-production manufacturer → family → model → configuration selectors, cash/credit/lease selector, registration, selected offer price and indicative delivery.
- `#aircraft-market` — used-aircraft search, manufacturer/family/model/configuration selectors, purchase/lease filter, cash/credit/lease selector, auction listings with seller, build year, age, condition, maintenance estimate and price evidence. Actions use the My Routes text-action style.

**No different page theme, no oversized grid of offers.** One existing workspace panel per page, compact controls.

### Factory supply
- 39 current-production configurations seeded in factory stock/queue foundation, including 2 configurations not currently released to player offers.
- Stock: 0–2 model-specific game units; stocked orders use a provisional 7- or 14-day delivery duration.
- No stock: the order waits for manufacturer capacity, at least 14 days from acceptance.
- 10 manufacturers have independent, row-locked capacities of **2 or 3 aircraft per real-calendar day**. This is a game mechanic, not an actual manufacturer production schedule. Server-confirmed purchase orders allocate delivery slots atomically with the already-protected purchase and airline cash debit.
- Replayed purchase request IDs do not reserve a second aircraft or slot.
- The estimated date shown before purchase is a quote, not reserved capacity.
- This release still uses the server's real calendar. A future authoritative game-time engine must determine the date policy before operational launch.

### Funding methods
- Cash factory purchases: server owner verification, released offer, funds and World 1 market release gates.
- Cash used-aircraft auction: server-controlled bid, full amount held/refunded, 15-minute rolling deadline and protected settlement.
- **Credit**: visible option, **not bookable**. There is no safe loan principal/interest/instalment ledger yet.
- **Leasing**: visible catalog and used listings, **not bookable**. Recurring billing and contract closeout not yet approved; `lease_enabled=false`.
- All purchases/bids are also blocked by `release_state=disabled` and World 1 `state=planned`. No world/market release was changed.

### Used sellers
- Six **fictional in-game dealer companies**; not claims about real businesses.
- Every one of the initial 633 listings has a seller; new fictional replacement inventory gets a deterministic dealer via insert trigger.
- Unsold lots persist indefinitely; valid first bid starts a 15-minute window, and each higher bid renews the 15 minutes.
- Per eligible used configuration: 2 purchase lots, 1 lease lot. Existing 211 configurations, 633 initial lots.
- Player-owned aircraft listing, transfers and player-to-player agreements are **future**; do not claim supported now.

### Reference prices and evidence
- 271 model configurations have a game reference value.
- Twelve applicable configurations have historical **2018 published manufacturer list-price reference** entries, explicitly not prices actually paid by any airline.
- Other models retain **2026 weight-based game price estimates**, explicitly *not* verified original factory sale prices.
- Used-aircraft opening prices are estimated from reference new value, build year/age, overall condition and approximate next C check. Every listing is game-generated fictional stock.
- New cash/lease figures come from existing protected factory offers; 2018 historical list values are context, not the amount charged.
- Sources: https://www.marketscreener.com/quote/stock/AIRBUS-SE-4637/news/Airbus-2018-Price-List-Press--25807080/ and https://finance.yahoo.com/news/boeing-raises-2018-commercial-jet-132016203.html
- Pricing needs real operator data/market calibration before launch. Do not treat estimates as accurate market appraisals.

### Release and verification
- Supabase migrations:
  - `20261110170000_airlinerra_market_selectors_sellers_factory_queue_v1.sql`
  - `20261110171000_airlinerra_factory_order_stock_queue_reservation_v1.sql`
  - `20261110172000_airlinerra_used_market_seller_restocks_v1.sql`
- `airlinerra-fleet-acquisition` Edge function deployed as version 7.
- Dedicated market CI (syntax, ownership, request validation, preview gates and full invitation-only website build): https://github.com/bracko87/Airlinerra/actions/runs/42843612248 (passed)
- Read-only DB verification: 6 sellers, 633 available listings, 0 null seller IDs, 39 factory models, 27 stocked configurations, 10 manufacturers, 271 price references (12 historical public lists), 0 live used bids, 0 allocated factory order slots.
- World 1 remains planned, market disabled; cannot claim live trading or browser-side acceptance without an actual verified release.

### Remaining implementation
1. Design and implement owner-verified credit/lease contracts with fully reconciled monthly instalments, deposits, maturity, missed payments, defaults and asset return; test billing before enabling.
2. Complete signed game clock and World 1 operational release. Keep approval explicit.
3. Add actual player aircraft resale/lease listings and seller balances, provenance and double-spend prevention.
4. Calibrate reference values with more real published/historical sources and aircraft size, type, age, maintenance/condition market effects.
5. Run real-browser acceptance tests for the new selectors, same styling and no payment on disabled options.
