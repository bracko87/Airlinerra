# Airlinerra network planner: coded UI and approved coordinate map

Date: 29 October 2026. Implemented directly on GitHub **main** at owner's request.

## Hubs and Stations

- Country selector displays a native flag emoji before the country name and verified count.
- Selecting a country immediately loads **every page of approved World 1 airports for that country** via the existing authenticated player-read endpoint (up to the catalog's bounded pagination limit).
- The airport dropdown is populated automatically. Typing in the filter narrows the already-loaded names, municipality and codes. An external "Search airports" click is no longer required.
- Stale requests cannot replace the airport list after a rapid country change.
- Existing HQ and browser-only hub/station proposal semantics remain unchanged. This UI patch does **not** enable permanent office saving, real opening fees or employee assignments.

## Route planning

- New real-code `website/route-planner.mjs` generates an interactive Route Definition and Route Map, side-by-side Origin/Destination country+airport selectors, and a swap control.
- Route overview shows the approved airport names, source code, municipalities and country flags.
- `website/route-map.mjs` draws real geographically projected points and a route line as SVG on self-hosted simplified Natural Earth (public-domain 1:110m) country outlines in `website/world-outlines.mjs`. No screenshots, remote mapping scripts, third-party tiles or API keys.
- Route distance is great-circle distance computed from actual source coordinates, NOT simulated block time. If an airport lacks coordinates, the map says so; it does not guess.
- Read-model source `server/player-read-service.mjs` can return optional latitude/longitude by **joining only the already-approved World 1 airports** to the existing private `airlinerra.airport_game_world1_catalog`, without exposing unapproved airports, runway/slot research or private database credentials.
- UI provides a deeper Airport Overview, Key Information, schedule entry point, optional draft flight number, fleet requirements note, and honest pending demand/slot/revenue panels.
- Route save remains per-account **browser-session draft only**. It does not activate routes, hire personnel, buy aircraft, reserve airport slots or charge airline cash.
- All new modules are explicitly copied by the invitation-only website build and loaded from Airlinerra source code.

## What still requires separate deployment

The code and geography are committed to `main`. The hosted Supabase game Edge Function (v10 at development time) still needs the changed player-read module deployed **in an approved backend release window** to supply latitude/longitude on localhost and the published site. Until then, the new map's country outlines / UI load, but individual route lines show a missing-coordinates message.

The Netlify production site remains unchanged until the owner follows their existing localhost QA and **manual** deployment workflow. Keep closed public registration and feature gates intact.

## Verification

Dedicated `.github/workflows/route-planner-ci.yml` checks:
- Node syntax for all new browser modules and the backend data model.
- `tests/test_route_planner_ui.mjs`: flags, country pagination, filtering, race cancellation, accurate geographic distance, DOM-safe SVG rendering, and source-only data safeguards.
- Existing focused airport-office and operations navigation regression tests.
- Full invitation-only site build `npm run build`.

Original general repository CI checks may still fail for unrelated account/navigation and airport-register issues; judge the feature by both its dedicated CI and manual browser review.
