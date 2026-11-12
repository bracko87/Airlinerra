# Airlinerra — database-only game-state persistence policy (2026-11-12)

## Non-negotiable rule

**A browser cache is never the authoritative game database.**
For a signed-in owner, every player-visible **Save** must wait for an owner-verified
database success response. If the database is unreachable, a save fails visibly.
Do not create shadow data in localStorage, sessionStorage, IndexedDB or a service
worker that could appear to be persisted gameplay.

Only in-memory form inputs may remain temporary until Save is clicked.
Supabase Auth may manage its own short-lived sign-in session, and the image
service worker may cache public aircraft artwork. Neither is game progress.

## Primary data source of truth

| Player data | Authoritative store | When operational |
| --- | --- | --- |
| World membership, airline identity and cash | Existing World 1 server tables and owner-authenticated account APIs | Only after protected account creation and ledger posts |
| Fleet ownership, configuration, nickname, aircraft media | Fleet inventory and protected cabin/refit/image APIs | Only when independently confirmed |
| Cabin service packages | `airlinerra_game.airline_cabin_service_settings_v1` | Service design only; not passenger consumption |
| Route planning | `airlinerra_game.airline_route_planning_drafts_v1` | Never operational by itself |
| Certified flight timetable, reserved airport slots | Server schedule/certification/slot tables | Only after independently verified approvals |
| Game clock and weather | Supabase World 1 clock and verified source tables | Not local browser clock authority |
| Passenger reservations, dated flights, flight movements, settlements | Protected Section 9 tables and controlled jobs | Currently gated: cannot infer movements or bookings from a plan |
| Player preferences | `airlinerra_game.airline_player_drafts_v1`, `kind='preferences'` | UI only |
| Budget, staffing, fare calculations, inactive route ideas, hub and office proposals | `airlinerra_game.airline_player_drafts_v1`, `kind='workplan'` | Draft scenarios ONLY; no real hiring, hub opening, revenue or flight movement |

The two `airline_player_drafts_v1` kinds are inert JSON planning records. The
isolated function `airlinerra-player-workspace-drafts` checks the signed-in owner,
World 1 airline identity, input types and version before reading/saving.
Its table has RLS and no direct anon/authenticated table privileges.
Its responses must never imply a payment, employment, activation or booking.

## All game writes through trusted endpoints

- Production browser: same-origin `/api/v1/player/*` on `https://airlinerra.com`.
- Localhost preview: the same allowed API calls via authenticated
  `http://localhost:5188`, never an untrusted origin.
- Server: verify Supabase Auth user and airline ownership; enforce record
  constraints; confirm a committed database version; return a clear success
  or error. Never fall back to a browser-only success.
- Concurrent sessions: version conflicts return a failure; do not silently
  replace newer server data.
- Drafts: maintain an explicit separation between planning scenarios and actual
  live game records.

## Legacy browser recovery

Older versions stored drafts at
`airlinerra.local.workplan.v1.<user-id>`,
`airlinerra.ui.preferences.v1.<user-id>`, and
`airlinerra.cabin.services.v1.<user-id>.<airline-id>`.

New versions READ these keys only to transfer them to the verified owner's
database if the corresponding server record is empty. Never invent data or
overwrite a newer server record. The shared draft store retires an old copy
only when the complete legacy object matches the saved server object.
Unmatched old data remains for manual recovery and must not appear as a
server-confirmed save. Cabin-service recovery is handled by its own protected
manager and server endpoint.

## Explicit exceptions, never legitimate game state

- Supabase's own Auth SDK session may be stored by the SDK to remain signed in.
  It is authentication, not airline game data.
- Public aircraft artwork may be cached for performance.
- Source-only fake demo account and pre-registration mock forms still use
  developer-demo storage. These may never be treated as owner-authenticated
  game records. Do not use fake demo mode for acceptance testing.
- Editing unsaved form fields in memory is expected; navigate away without
  saving and the changes are not promised as persisted.

## Regression and acceptance requirements

1. `tests/test_no_browser_game_state_contract.mjs` scans the complete
   site and prevents browser game-state writes outside the explicitly isolated
   developer-only mock modules.
2. `tests/test_player_drafts_db_only.mjs` verifies owner-only endpoints,
   no operational effects, legacy recovery, version conflicts and localhost
   bridging. Both tests run in
   `.github/workflows/player-drafts-database-only-ci.yml`.
3. Browser acceptance must use a real invited test user with a real airline:
   save a cabin package, planning route, budget, office proposal and settings;
   reload, sign out/in, and compare with fresh Supabase reads.
4. Test a second browser/device and a rejected/stale/conflicting save.
   No success label may appear without server confirmation.
5. Retest flight schedule and route cancellation independently; drafts must
   never generate passenger reservations, movements or financial entries.
6. Do not label the complete game release-ready until browser end-to-end
   testing, the affected broader CI workflows and a production deployment
   check pass.

## Evidence status at policy authoring

- New isolated protected storage migration applied in Supabase World 1.
- Isolated Edge API deployed; no production flight or finance releases.
- Dedicated database-only regression workflow passed.
- Real logged-in `localhost:5188` and Netlify production UI acceptance
  still require observation after the updated code is installed.
- Other Airlinerra workflows still have failures; the dedicated workflow
  being green does not replace complete system readiness.
