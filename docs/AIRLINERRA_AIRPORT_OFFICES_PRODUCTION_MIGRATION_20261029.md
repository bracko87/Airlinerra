# Airlinerra airport-office release — factual production status, 29 October 2026

## Production steps already completed (owner instruction: proceed)

- Project `hwllkabgzaynalahvkpz`, database role `postgres`.
- Applied **private draft-only** airport-office SQL from
  `supabase/migrations/20261029154000_airlinerra_airport_office_drafts.sql`
  using the Supabase migration tool, migration name
  `airlinerra_airport_office_drafts_20261029`.
- Post-migration checks passed:
  `airlinerra_game.airport_offices` exists and contains zero rows;
  RLS enabled; `anon` and `authenticated` have no direct SELECT privileges;
  two composite foreign keys are in place.
- Existing production business invariants verified unchanged:
  **one airline, total cash $5,000,000.00, one ledger entry, 3,141 approved airports**.
- Safely deployed Supabase Edge `airlinerra-game` **version 10**.
  Bundle was produced by preserving every existing v9 dependency byte-for-byte
  except the updated canonical routing module, and adding three narrowly scoped
  airport-office modules. The existing index entrypoint was preserved and still
  instantiates the API with `airportOfficeDraftsEnabled=false` (the default).
  Before deployment, the Node-only `Buffer.byteLength` in canonical routing
  was replaced with cross-runtime `TextEncoder` byte counting.
- After deployment the **live** Edge GET readiness route returned
  `{"registrationReady":false,"privateOwnerPilotAvailable":true,"requiresLegalApproval":true,"world1RegistrationOpen":false,"flightsEnabled":false}`.
  This confirms the original private-owner, closed-public-registration policy
  remained intact. It does **not** prove real user-authenticated draft writes.

## What is NOT released

- The production Supabase Edge office **write/list route is still disabled**.
- Netlify's new office route in GitHub source is independently disabled by default,
  and has not been manually published to Netlify.
- The website client flag `AIRPORT_OFFICE_DRAFT_API_ENABLED` remains false and
  its updated bundle has not been manually published.
- PR #2 remains draft and unmerged; unrelated airport-register validation fails.
- **No permanent office has been saved from the live website.** Existing browser
  proposals are untouched. No finance/staff/flight/office-activation mutations.
- Real hosted Auth end-to-end browser testing is still required before enabling.

## Exact remaining release sequence

1. Review the current PR head, unrelated CI failures, and owner normal
   GitHub-main -> localhost test -> manual Netlify production workflow.
2. For a manual deployment window, enable the Edge server route deliberately
   (`airportOfficeDraftsEnabled:true`) and verify 401, 400, 403, owner-only list
   and save with a **genuine hosted Auth test session**; do not fabricate an Auth user.
3. Enable the Netlify production proxy office flag and publish its updated
   `/api/v1/player/airport-offices` route; verify it forwards the real bearer
   only to the intended pinned Edge URL.
4. Enable `AIRPORT_OFFICE_DRAFT_API_ENABLED=true` only in the approved website
   release and manually deploy Netlify, after passing existing owner workflow.
5. Run real browser scenario: sign in, select airport, save station draft,
   log out/reopen with same owner, confirm persisted, remove, verify deleted.
   Confirm browser-only import is opt-in and financially inert.
6. If smoke check fails, disable both browser and proxy flags before making any
   further changes; do not delete draft table as a casual rollback.

No further production mutations have been authorized or performed as part of
this release record.
