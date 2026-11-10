# Airlinerra Group 2 location planning — 2026-11-10

## User request and exact implementation boundary
The 1,118 Group 2 airports now have a **planned-location selection path** for existing, authenticated airline owners. Players may save one **future HQ** candidate and up to 20 **planned hub/station** airport choices using a new owner-only API and browser controls. These are **intentions**, not active HQ, hubs or stations. The existing operational airline home-airport foreign key and approved airport list remain unchanged.

This distinction is essential: the production `airlinerra_game.airlines` table and `airlinerra_game.airport_offices` table both reference `airlinerra_game.approved_game_airports` (3,141 Group 1), and changing that foreign key to allow Group 2 without first extending flight gates risks accidental commercial activation.

## Database
Applied migration `20261110153500_group2_airport_location_intents_v1.sql`:
- `airlinerra_game.airport_group2_location_intents_v1`, FK to an actual existing airline and Group 2 airport, required status `planned_only`, one future HQ candidate per airline, unique airport per airline, row-level security enabled, no anon/authenticated table access.
- Validates entries are Group 2 prepared airports and are not existing HQ/offices.
- `airlinerra_game.airport_group2_location_choice_status_v1` records overall preparedness and explicitly false active/flight permissions.

## API
`server/group2-location-plans-service.mjs` verifies the Supabase user freshly server-side; ownership is resolved from `owner_player_id`, never from a browser-supplied airline ID. Requests support `list`, `save` and `remove`, use parameterized SQL and bounded transactions, and check Group 2 game readiness and commercial ineligibility. Writes go solely to the planning table.

The active Supabase Edge `airlinerra-game` bundle was updated from version 17 to **version 18**, preserving the deployed airport-office modules; only the private canonical route was extended and the new Group 2 location planning service module added.

## Frontend
Updated the protected airport directory on GitHub `main`:
- **Plan future HQ**, **Plan hub**, **Plan station** buttons appear when a verified registered airline can load its existing plans.
- Saving produces a clearly labeled `planned_only` entry; owners can remove it.
- No buttons for actual flight bookings or airport-office activation. No activation APIs are called.
- Users without registered airlines are told they need an airline before saving choices.
- If owner plan API cannot be verified, controls fail closed.

## Checks completed
Production Supabase read-back:
- Prepared Group 2 airports eligible in new planner: **1,118/1,118**
- Combined 1–8 game-data catalog: **4,259**
- Group 1 existing approved airports: **3,141**
- Saved location intentions: **0** at validation time
- Group 2 active HQ records: **0**
- Group 2 active office records: **0**
- Group 2 commercially enabled: **0**
- Edge v18: `ACTIVE`, planning route and bundled service present, deployed airport-office files retained.

Owner-auth, no-write-to-operational-table and save/list/remove tests are committed in `tests/test_group2_location_plans.mjs`. CI was updated to include them, but a passing GitHub Actions run is **not verified**. A live authenticated browser session was unavailable. Frontend static hosting deployment is **not verified**.

## Outstanding for true active HQ/hubs/stations
1. Authorize and test Group 2 admission into operational airport engines (Section 5 restriction logic, Section 6 slots, runway and Chapter enforcement, licensing, actual airport eligibility).
2. Extend protected HQ and airport-office persistence and onboarding selection safely, without allowing a Group 2 airport to bypass flight gates. Group 2 currently remains outside their FK.
3. Verify deployed frontend controls with a real test account. Plan-only selection is a staging feature, **not yet an active location choice or live flight permission**.
