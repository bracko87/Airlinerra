# Airlinerra — Server-owned flight schedule drafts (6 November 2026)

## Completed in this pass

- New private RLS-protected table: `airlinerra_game.airline_flight_schedule_drafts_v1`. Its CHECK constraints permit **draft only**, never `active`. It is not readable or writable by `anon` / `authenticated` directly.
- Atomic private database function `section5_save_owned_aircraft_schedule_draft_v1`. It verifies server-trusted player UUID owns the airline, airline is in an active World 1 membership, flight number matches assigned airline IATA code, and an actual **owned or leased in-service fleet record** is present. Catalog-only aircraft or nonoperational test fixtures are not treated as owned.
- Mandatory `section5_weekly_route_restriction_gate_v1` check runs *inside the saving transaction*, covering selected weekly departures at four weeks with local airport clock, 28 max occurrences, runway, curfew and matching certified noise rules. Any confirmed hard prohibition rejects the write. Review-only cases can be stored as drafts but never activated.
- Private `section5_schedule_activation_readiness_v1`: revalidates ownership, aircraft fleet status and airport rules; explicitly returns blockers for crew, slot, traffic-rights, fleet position, flight duration/recurrence and operational dispatcher. No live activation transaction exists.
- Supabase Edge Function `airlinerra-flight-schedule-drafts` **ACTIVE v2**. It validates a fresh Supabase Auth session and supports scoped `list`, `save`, `delete`, `activation-check`. No `activate` action.
- Netlify same-origin proxy route `/api/v1/player/flight-schedule-drafts` uses a pinned Edge endpoint; no Netlify database or service role secrets are needed.
- Browser client `website/flight-schedule-client.mjs`; manager app loads it on the production origin. Existing private route planner now lists truly owned/leased fleet aircraft separately from catalog/test previews, saves those schedules on the authenticated server with another mandatory check, and shows cross-device server draft list and activation readiness reasons. Catalog-only previews remain local.
- Existing game release gates remain unchanged. No purchase, lease, crew, slot, air transport rights, income, real flight, or game-clock changes were made.
- Owner, fake-aircraft, curfew, revision, and direct-status-update tests passed inside a rolled-back production database transaction. No test records persisted.
- GitHub Action route planner workflow **#118 passed** (syntax checks, focused Node tests, full player-site build). Earlier failures from a strict UTC validator and obsolete test assertions were fixed and the Edge service redeployed.

## Database verification

- Production operational airline aircraft: **0**.
- Production server-owned schedule drafts: **0**.
- Table RLS enabled; direct `anon` SELECT, `authenticated` INSERT and public function execution are all disabled.
- All new backend records remain in the private schema.
- Security advisors were reviewed; an informational RLS-no-policy finding is expected for an intentionally private server-only table. No public access was opened.

## Honest limitations and release blockers

1. **No live operational flights** can be activated. The only owned-fleet inventory is currently empty. The server's `status='draft'` CHECK and activation-readiness endpoint intentionally disallow pretending to operate.
2. Crew assignment, verified aircraft position and rotation, real travel duration and turnaround, slots, traffic rights, dispatcher/game clock, flight execution and revenue are separate missing systems. Do not remove the activation lock merely because four-week restrictions pass.
3. The existing four-week restriction test uses an entered reference flight duration. The final operational scheduler must compute actual trips and screen the *full* schedule horizon, including future rule revisions.
4. Airport research cases requiring individual scoped normalization remain (last verified: 1,246 cases). Unknown aircraft noise certification follows the approved no-additional-game-Chapter-ban rule, not fabricated official certification.
5. GitHub build/test success does not prove a real signed-in production-browser end-to-end session succeeded; that remains to be tested after normal hosting deployment.

This is a **real persisted server-owned schedule-draft backend** and not the complete commercial flight execution engine.
