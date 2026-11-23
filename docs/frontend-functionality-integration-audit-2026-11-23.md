# Airlinerra — frontend functionality and deployment audit
Date: 2026-11-23
Scope: GitHub `main` versus `phase-14h-crew-integration`, `website/`, `server/` and the authenticated player API. This is a code-path audit, **not** browser proof of a production deployment or an end-to-end registered-user test.

## Status definitions
- **Connected in source**: an actual authenticated API client and backend handler exist. This does not mean a release passed a live player journey.
- **Partial**: some pages, draft flows, read-only previews or controls work; crucial actions or downstream records need further wiring.
- **Not connected**: placeholder or read-only output without the requested game action.
- **Deployed**: only when independently verified on the site, not inferred from a committed branch.

## Findings

| Area | Source audit | Evidence | Remaining user-visible functionality |
| --- | --- | --- | --- |
| Account and airline overview | Connected in source | `website/player-app.mjs`, `website/player-read-client.mjs`, `server/production-game-api.mjs` | Browser verification of real owner session and game state after deployment |
| Create a route | Connected but certification-gated | `website/route-planner.mjs` calls `scheduler.operationalSingleCreate`; `website/flight-schedule-client.mjs`; `server/flight-schedule-service.mjs` | One disposable-world genuine full create → signed activation → booking acceptance; show real blocker reasons to the player |
| My Routes and Route Details | Partly connected | `website/airline-operations-center.mjs`, `website/section9-route-details.mjs` | New Flight Readiness panel implemented on the development branch. It is a limited aircraft/airport check, **not** the complete five-source approval. Full certification progress and live cancellation still need a new authenticated API |
| Schedule and confirmed flights | Connected read path, no proven live flight | `website/airline-workspace.mjs`, `website/aircraft-dated-calendar.mjs`, server `aircraftCalendar` | End-to-end real flight event testing; no live flights currently recorded in World 1 |
| Crew / employees | Partial; hiring functionality is gated | `website/crew-hiring-panel.mjs`, `website/staffing-overview.mjs`, `server/persistent-crew-plan-worker.mjs` | Connect qualification, staffing and roster changes to visible weekly schedules and hiring confirmations. External crew and delayed recovery remain **read-only previews** until explicit authorization |
| Fleet and maintenance | Several API actions connected | `website/airline-workspace.mjs` calls `maintenanceProviderQuotes`, `maintenanceProviderBook`, job status and cancellation; backend maintenance policy | Player walkthrough of maintenance booking → grounding → settlement → release, preserving qualification and game-cost checks |
| Licences & permits | Partial, release gated | `website/game-permission-applications-client.mjs`, `website/licensing-planner.mjs` | Confirm per-licence application, payment and expiry UI for actually enabled licences; some entries explicitly say applications are unavailable |
| Cabin configuration / onboard services | Partly connected | `website/cabin-configuration-manager.mjs`, `website/cabin-services-manager.mjs` | Verify persisted configurations and per-flight application in the operational journey |
| Airline finances | Incomplete | `website/airline-workspace.mjs` labels transactions and operating profit **Not connected** while showing verified cash | Add authenticated ledger, revenue and expense detail and post-flight reconciliation display |
| Dashboard tracking and alerts | Incomplete | `website/airline-dashboard.mjs` labels flight tracking **Not connected**; workspace placeholders for disruption, notices and messages | Connect signed events, disruption and ledger streams; verify refresh and visibility |
| Cancelling a flight | Not complete for active flights | Operations Center cancellation is a local planning-draft action; Phase 14AA private certified-draft cancellation is not exposed to player | Implement authenticated private draft cancellation, and separately handle sold tickets/refunds and unflown active legs. **Do not wire an unsafe delete button to signed commercial flights.** |

## Deployment distinction

At inspection, `main` and `phase-14h-crew-integration` have different commits. Recent Phase 14T–14AA work is primarily backend SQL, server workers and acceptance tests; comparatively few `website/` files changed before this integration phase. A branch commit or database migration does **not** automatically publish frontend changes through Netlify.

The existing passenger base release policies are already enabled/approved in the database, while newer strict crew enforcement, atomic event isolation and dynamic turnaround switches are disabled. This mixed state must not be described as "everything disabled" or "all features live". No active schedule, reserved airport slot, signed flight movement or financial settlement was present in the World 1 live audit completed at the end of Phase 14AA.

## First frontend slice implemented on the development branch

- `website/section9-route-readiness.mjs`: fail-closed, human-readable summary of the **existing authenticated limited Section 5 readiness check**.
- `website/section9-route-details.mjs`: **Flight Readiness** panel for saved drafts with protected refresh and next-page navigation. Planning-only and active schedules have different messages. No activation/cancellation writes.
- `website/route-planner.mjs`: existing readiness button now explains the verified blocker instead of showing raw SQL codes.
- `website/section9-flight-readiness.mjs`: removes the inaccurate universal "Ticket sales remain disabled" claim.
- `website/player-app.css`: matching game template styling.
- `tests/test_section9_route_readiness_frontend.mjs`: six fail-closed and integration-contract tests; included in the web test scripts.
- All work committed to `phase-14h-crew-integration`, with `[skip ci] [skip netlify]`. No merge, Netlify deployment, live feature activation or player data mutation.

## Next slices in delivery order

1. Add a **modern authenticated route-certification status endpoint** that reads real five-source signed events, slot status, the verified game day, and maintenance evidence. The current `activation-check` is an older preliminary Section 5 check; **never** market it as full game readiness.
2. Make My Routes show the current certified/active/revoked/cancelled state with confirmed flight occurrences, booking totals and last refresh, based on owner-scoped server data; preserve the existing UI layout.
3. Complete secure draft cancellation via the Phase 14AA private backend under verified owner permissions, while keeping real active-flight cancellation separate until passenger refunds and crew/resource release are tested.
4. Connect crew assignment, salaries and actual maintenance booking/completion into visible operational workflows; add finance settlement display next.
5. Run focused Node/UI tests, full build and a true logged-in browser journey in a disposable environment; obtain explicit merge/deployment approval before exposing any new protected action.

## Release acceptance rule

A component is **Backend tested** when its source functions pass; **UI integrated** when the authenticated browser can use the real API; **Player tested** after the complete owner journey; **Production deployed** only after checking the actual website. No single one of these means the others.
