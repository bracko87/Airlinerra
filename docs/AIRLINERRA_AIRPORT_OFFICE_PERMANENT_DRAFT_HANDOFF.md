# Airlinerra — permanent airport office drafts: concrete release handoff

## User-facing result completed in source

Once the authenticated office API is **actually deployed and enabled**:

1. Hubs and Stations shows server-verified office proposals for the signed-in airline.
2. Selecting an approved airport and pressing **Save proposed location** persists a `draft` via the private account/world-scoped API.
3. A new login or different browser reloads the same saved draft via the server. No browser/session storage is needed for the permanent record.
4. **Remove server draft** removes only the signed-in airline's draft.
5. Pre-existing browser-only proposals stay separate. The explicit **Import browser proposals into my airline** button is shown only after a successful server read and only when unimported proposals exist. The user must click it. Each imported draft is verified by a subsequent server read before its browser copy is cleared; incomplete imports preserve the remaining browser entries and unrelated route/planning state.
6. Missing approved airports, conflicting hub vs station types, own HQ, unsupported world, unauthenticated account, bad API response and interrupted saves fail closed; no costs or staff transactions exist.

### Verified source tests

`tests/test_airport_office_ui_persistence.mjs` exercises real UI event handlers with a controlled browser DOM imitation:
- deliberate import followed by a completely new browser session
- persistent station displayed, then successfully removed via the UI
- an interrupted two-proposal import retains the unsaved browser copy
- direct office save from the approved airport search persists and displays

The separate full PostgreSQL E2E tests cover the canonical API, real queries, Netlify-in-process Edge path, owner/world isolation and financial invariants.

## What has NOT happened

There is only one connected Airlinerra Supabase project, which is production; no staging branch/project was found. This feature remains disabled on three boundaries:

- `server/supabase-game-edge-entry.ts`: `airportOfficeDraftsEnabled:false`
- `server/production-game-api.mjs`: `airportOfficeDraftsEnabled=false`
- `website/airport-office-client.mjs`: `AIRPORT_OFFICE_DRAFT_API_ENABLED=false`

The database migration exists only in GitHub and the production `airport_offices` table does not exist. The deployed Supabase Edge Function predates this route. All these pieces must be released together in an owner-approved window; changing only the static website flag will result in HTTP 503 by design.

## Required ordered go-live procedure

1. Create/authorize a dedicated non-production Supabase target, or explicitly approve a direct controlled production-only release after reviewing the risk.
2. Run a backup and compare live schemas and existing migrations. Apply ONLY the vetted draft-only SQL `supabase/migrations/20261029154000_airlinerra_airport_office_drafts.sql`; verify RLS, grants, uniqueness, FK constraints, no published exposed schema, and unchanged `airlines`/ledger row counts and amounts.
3. Build and deploy the updated `airlinerra-game` Edge Function including all new imports, **keeping the office flag false initially**. Run existing overview, readiness and onboarding smoke tests.
4. Publish the new Netlify function path, **keeping the independent Netlify office flag false initially**. Verify it returns 503 without upstream requests.
5. After backend authentication, two-account/world isolation, private writes, and old account flows have passed in the release target, enable the Edge office flag, enable the Netlify proxy office flag, then enable the static browser client flag in an owner-controlled release.
6. Verify a real approved station proposal saves, survives logout/new browser, and deletes; verify existing browser proposals never import automatically. Audit database status, balances and ledger remain unchanged.
7. If anything fails, revert both proxy and browser flags first; preserve database draft records for recovery. Do not drop the newly created table as a casual rollback and do not change the public release gate.

User's normal workflow is GitHub -> owner localhost review -> manual Netlify release. No automatic merge to main or deploy was performed.

**Explicit non-goals:** active hub/station opening, hiring staff, salary recurring charges, verified airport fees, demand/slots, flights and routes. These require separate later designs.
