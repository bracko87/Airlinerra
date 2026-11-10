# Airlinerra — Cabins and worldwide maintenance sites (2026-11-10)

## Scope and verified state

**Database foundation + protected cabin draft editing + visual top-down layout + MRO catalog — not aircraft reconfiguration activation.**

Supabase project `hwllkabgzaynalahvkpz`, GitHub `bracko87/Airlinerra` main only. Dedicated cabin/MRO CI passed on 10 November: https://github.com/bracko87/Airlinerra/actions/runs/42851172009 (including full website build).

- 11 seat types covering economy (3), premium economy (2), business (3) and first (3). Width/pitch, equivalent capacity footprint, installation-equipment game estimate. All numeric space factors are **game balancing values**, not approved layout dimensions.
- 271/271 passenger, combi and cargo model configurations have standard cabin records. Cargo has no passenger seats. Passenger/combi default to the existing catalog's passenger reference, entirely in standard economy.
- Existing YU-PAN01 Airbus A319-100 inventory id `a4547aef-e5a6-4362-8b2b-fbdf96d21907` has 156 *game-standard* installed economy seats. This does **not** assert its original historical real-world layout.
- Every *future owned or leased inventory insert* receives standard layout from an AFTER INSERT trigger. Used aircraft auction lots remain fictional individual sale offers and use their model's standard layout when awarded. Do not invent a previous-owner cabin configuration.
- The owner-only `cabin-overview` read action returns seat types, actual airline airframes, worldwide MRO site catalog and type-matched refit sites.
- The `cabin-save-draft` action checks real airline ownership and individually validates seat-class type + weighted capacity **on the server**, then saves **only** the draft. It does not modify installed seats, cash, aircraft position, operations, scheduling, or airworthiness. A valid sample A319 layout is 100 Economy + 20 Premium + 10 Business = 147/156 game units; standard 156 Economy = 156/156. Over-capacity drafts are rejected.
- Flight services menu is renamed from Cabin Services; Operations adds Cabin configurations in the former ticket-price-analysis menu position, preserving older page path separately.
- The cabin editor is one shared-panel interface matching My Routes: select a real owned/leased aircraft, choose 4 classes and styles and quantities, see a top-down SVG layout and indicative lavatory/galley zones, save planning draft.
- **Exact exit geometry, legal minimum aisles, accessibility, crew, lavatory/galleys, cargo floor restrictions, weight-and-balance and model-specific certification are NOT available.** They must be confirmed before any cabin installation is allowed.
- Factory new-order page has a passenger layout preview. Custom configurations are **not** yet attached to purchase contracts: a custom choice blocks checkout rather than silently charging for the standard cabin.
- Existing aircraft page has a separate "Change configuration" dialog with company saved layouts and refit site previews. This remains *draft only*. A full refit would take 24–48 hours with aircraft physically at an approved MRO, with booked downtime and a real flight back to hub.

## Maintenance network

Global `maintenance_facility_locations_v1` now has **35 provider records at 34 approved airports**:
- Europe 6 airports / 7 provider rows
- Asia 5 / 5
- Africa 5 / 5
- North America 6 / 6
- South America 6 / 6
- Oceania 6 / 6

Every site has a source URL, `provider_supported` or `research_pending` status, continent and provisional **game price location multiplier**. This does not mean every site may legally maintain every model.

Existing `maintenance_airport_capabilities_v1` remains the sole A/B/C/D game-approval source for a check / specific model / provider / airport. Daily and Weekly checks require only a grounded airframe at an approved game airport. For example A319 approved game checks occur at named providers in Singapore, Sofia, Shannon, Budapest, Johannesburg, Auckland, Christchurch and Santiago, but not every check at every site.

The aircraft profile maintenance cycle now lets the owner choose the check + eligible site and displays a provisional estimate (maintenance-category base × site cost factor), duration, and a warning that actual aircraft-age and unplanned work are excluded. **No maintenance booking, payment, forced grounding or positioning flight occurs.** Neither will the frontend invent usage history or claim current condition when unknown.

Cabin refits are separately type-matched using `cabin_refit_facility_types_v1`. A319 has five candidate game planning sites (e.g. Shannon, Sofia, Hong Kong, Auckland, Christchurch). Actual operating approval and slots are not live.

## SQL and code

Migrations:
- `20261110181500_airlinerra_cabin_standards_drafts_v1.sql`
- `20261110183000_airlinerra_six_continent_mro_locations_and_refit_v1.sql`

Server: `server/fleet-acquisition-service.mjs` provides strictly authenticated/airline-owned reads and draft writes; deployed in `airlinerra-fleet-acquisition` Edge function **v8**. RLS enabled and public/anon/authenticated grants revoked for all new tables. No payments or flight activation through this API action.

Browser modules:
- `website/cabin-configuration-manager.mjs`
- `website/airline-workspace.mjs`
- `website/private-player-app.html`
- `website/player-app-model.mjs`
- `website/player-app.css`
- `website/fleet-acquisition-client.mjs`
- `website/local-owner-fleet-reader.mjs`
- `website/dev-scripts/real-player-read-gateway.mjs` — preview allows only owner-checked cabin draft saves.
- `website/dev-scripts/invited-overlay.mjs` — includes both cabin manager and additional aircraft profile configuration dialog dependencies.

Testing:
- `tests/test_cabin_configuration.mjs` covers weighted space, 156-seat standard, owner authorization, overcapacity refusal, no live install, navigation and build assets.
- CI `.github/workflows/airlinerra-cabin-layout-mro-ci.yml` syntax + tests + complete player build passed 10 Nov.
- Additional wider legacy CI failures should not be represented as project stability proof. Actual browser verification on localhost and with a real account remains necessary.

## Future engineering before activating refits or custom factory orders
1. Model-specific certified (or explicitly researched game simplified) floor geometry, exits, lavatories, seat pitch and balance; do not confuse this visualization with a certified plan.
2. Factory purchase/order atomically stores selected custom layout, price and delivery time; installation and actual billing when delivered.
3. Real MRO provider aircraft-type check approvals and refit capacity/time slots; extend site research globally, distinguish projected from verified.
4. Authorized flight to eligible site, 24/48 hour grounded refit job, inventory seat plan update only on verified completion, return flight to hub.
5. MRO cost quote includes aircraft age, check category, site multiplier and any confirmed repairs. Safely settle exactly once.
6. End-to-end browser test of editing a layout then reloading, check no cached state for a different airline.

**World 1 market release remains disabled.** Do not flip the switch or claim these features live for payments or flights.
