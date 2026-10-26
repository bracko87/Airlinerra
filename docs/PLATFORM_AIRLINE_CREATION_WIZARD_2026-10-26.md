# Airlinerra — Approved-airport airline creation wizard (2026-10-26)

**Original task:** Player onboarding / airline creation in the browser.
**Branch:** GitHub `main` (Airlinerra `AGENTS.md` policy).
**Status:** **Source code implemented and native Node + isolated PostgreSQL checks green. Final new Chromium wizard click-through has not yet returned a successful result.**

## Implemented

- The existing `website/account.html` has a sixth **default-disabled** form for airline onboarding. A verified manager can choose a game world, select an approved home-airport key, name the airline and explicitly accept separately linked current Terms and Privacy documents.
- `website/account.js` now keeps the wizard hidden until a fresh trusted onboarding context is returned, renders eligible worlds and airports via DOM text/options (not HTML injection), calls `acceptLegal` and `createAirline` through `website/onboarding-api-client.mjs`, and displays the backend's creation/replay result and starting capital.
- `server/onboarding-context-service.mjs` reads only operator-owned `airlinerra_game.approved_game_airports`, open `public.airlinerra_game_worlds`, and `airlinerra_game.legal_release_policy`. It checks a freshly verified Auth account, release gate and explicit same-origin published-document paths. **No query to the airport research schema and no airport mutation.** Missing official documents or approval leave the wizard unavailable.
- `server/onboarding-context-http-handler.mjs` exposes a private, authenticated, same-origin, default-disabled `POST /api/v1/onboarding/context` handler. Existing protected endpoints record legal acceptance and create the airline.
- `website/dev-scripts/dev-local-auth.mjs` can **only in an explicitly enabled loopback test** receive injected private local API handlers; public Airlinerra remains locked.
- `tests/test_onboarding_context.mjs` adds five context/authorization/approval regressions. The account foundation tests cover six default-disabled forms.
- The Chromium E2E script `tests/e2e/browser-account-ui.mjs` now tests a real browser airline submission using synthetic legal documents, synthetic operator-approved airport rows and real local PostgreSQL, in addition to registration/profile/recovery.

## Bugs found and corrected

- The first browser runs identified a JavaScript parse error in `account.js`. A source-text replacement had mishandled the dollar sign adjacent to a quote in the starting-balance display, corrupting the remainder of that branch. The entire branch was rebuilt with a safe slice-based replacement.
- The first attempt to add a regression assertion had the same replacement issue; the unintended duplicated tail of `tests/test_account_foundation.mjs` was removed.
- Browser parser diagnostics now report source location; they pinpointed the defect at `account.js` line 223.

## Verified results and outstanding gate

- The native Node and disposable PostgreSQL jobs in [GitHub Actions #40399231610](https://github.com/bracko87/Airlinerra/actions/runs/40399231610) **both completed SUCCESS** after those fixes.
- The full local Supabase Auth / Mailpit / account database steps in [GitHub Actions #40398820250](https://github.com/bracko87/Airlinerra/actions/runs/40398820250) completed successfully up through the isolated PostgreSQL backend tests and SDK bundling. When last inspected, this run was **still installing disposable Chromium**; the new wizard click-through is **not yet independently certified green**. Do not call that UI test complete based only on the green backend.
- The previously verified browser registration, email confirmation, profile and recovery journey remains documented in `docs/PLATFORM_CHROMIUM_ACCOUNT_UI_E2E_GREEN_2026-10-26.md`; this new wizard is an additional test gate.

## Live database remains untouched

After the changes, read-only checks confirmed:
- Deployed `airlinerra_game` tables: **0**.
- Research World 01 activation records: **3,140**.
- Website/game state: **`prelaunch`**.

No actual legal documents were approved, no airport research rows were mutated, no live game worlds were opened and no paid subscriptions were enabled.

## Remaining original launch work

1. Obtain a green **actual browser wizard** result, including legal links, private consent transaction, approved airport selection and exact $5,000,000 single-credit airline creation.
2. Agree real published Terms/Privacy documents and trusted operator-approved airport handoff, exclusively from the **Airport Database Overview** workstream.
3. Set up owner-authorized hosted development backend/SMTP/domain and payment integration before any public registration or live-account database migration.

**Source-code milestone complete; new browser verification remains outstanding.**
