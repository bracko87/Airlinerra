# Group 2 airport directory — prepared-only display, Nov 10 2026

## Code on main
- `website/private-player-app.html`: separate Prepared airports (1,118) card below the existing approved-airport directory with informational-only text, search box and Load more. No home-base, airport-office, route, flight or booking action.
- `website/player-app.mjs`: read-only paginated prepared airport list, 50 results/page, explicit non-bookable response validation and safe `textContent` display. Loads on Airports navigation and after auth data arrives. Does not alter existing `airportSearch`, route planner or setup airport selection.
- `website/player-app.css`: visually distinct informational rows.
- `server/player-read-service.mjs`: prepared lookup supports all 1,118, including GL/TW; the operational country allowlist and approved-airport route search stay unchanged. Worldwide blank search is permitted **only** on the dedicated prepared endpoint.
- `tests/test_player_read_api.mjs`, `tests/test_player_app_prelaunch.mjs`: source regression checks for auth, pagination, non-bookability, territory codes and isolation from approved search.

## Hosted backend
The **airlinerra-game** Supabase Edge function was updated from v15 to v16 and subsequently **v17**. v17 readback: ACTIVE, 18 bundled files, prepared browse-all support, existing airport-office files retained. This was a narrow patch against the actual prior deployed bundle (rather than replacing it with the divergent repository canonical router). No flights, slot reservations, approvals or registrations changed.

## Verified database state
- Combined Section 1–8: **4,259**
- Group 1 approved: **3,141**
- Group 2 prepared: **1,118**
- Group 2 commercially activated: **0**

## Deployment and testing limitations
- Backend Edge function v17 **is deployed** and its source readback is verified.
- Frontend changes are committed on GitHub `main` but an external static-host deployment and authenticated live browser rendering have **not been verified**; the web reader could not access the protected player page.
- Automated tests are committed, but no passing GitHub Actions workflow was reported for the latest commit. Do not call the new player UI “live verified” until the hosting provider deploys and an authenticated browser test passes.
- Do not promote Group 2 to `approved_game_airports` or enable commercial flights based on prepared-only directory readiness.
