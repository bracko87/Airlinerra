# Airlinerra — Approved-airport airline creation wizard (2026-10-26)

**Original task:** Player onboarding / airline creation in the browser.
**Branch:** GitHub `main` (Airlinerra `AGENTS.md` policy).
**Status:** **Code implemented, isolated Node/PostgreSQL checks passed, and complete local Chromium airline-creation click-through PASSED on 2026-10-26 (GitHub Actions #40401594030). This is a verified test milestone, not a public deployment.**

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

## Verified results — browser gate passed

- The native Node and disposable PostgreSQL jobs in [GitHub Actions #40399231610](https://github.com/bracko87/Airlinerra/actions/runs/40399231610) **both completed SUCCESS** after the original fixes. A later [Node validation run #40400685468](https://github.com/bracko87/Airlinerra/actions/runs/40400685468) also **completed SUCCESS**.
- **Full local Auth, Mailpit, isolated PostgreSQL and Chromium browser E2E** completed **SUCCESS** in [GitHub Actions #40401594030](https://github.com/bracko87/Airlinerra/actions/runs/40401594030) (commit `e04324d92f556c5f2b603358e194912321c37300`). The job log explicitly confirms registration, email confirmation, profile persistence, synthetic legal-page navigation, airport selection and airline creation against real private disposable SQL, password recovery, and successful sign-in with the new password.
- The backend E2E also verified separate legal consent, denied unapproved airports, idempotent retry, per-airline $5,000,000 starting capital and an account-level seven-day trial. All synthetic data remained in the disposable test environment.
- **The browser milestone is closed**. It does not certify hosted service readiness, production terms and privacy, or live game approval. The previously verified account UI journey is also documented in `docs/PLATFORM_CHROMIUM_ACCOUNT_UI_E2E_GREEN_2026-10-26.md`.

## Live database remains untouched

After the changes, read-only checks confirmed:
- Deployed `airlinerra_game` tables: **0**.
- Research World 01 activation records: **3,140**.
- Website/game state: **`prelaunch`**.

No actual legal documents were approved, no airport research rows were mutated, no live game worlds were opened and no paid subscriptions were enabled.

## Remaining original launch work

1. **Complete:** Green actual-browser wizard result, including synthetic legal links, private consent transaction, approved test-airport selection and a $5,000,000 starting balance; independently verified in run #40401594030.
2. **Pending operator/legal decisions:** Publish approved real Terms and Privacy documents (synthetic CI documents are not publishable), and receive an explicitly authorized playable-airport roster from the **Airport Database Overview** workstream. Neither the 3,140 research activations nor provisional categories automatically authorize `approved_game_airports` entries.
3. **Pending owner-authorized hosted integration:** Configure secure development hosting, identity/database/SMTP/domain, production release gates and payment integration; verify the complete flow in hosted staging before enabling public player registration. Do not deploy the private schema or open live accounts without explicit authorization.

**The source-code and isolated full-browser milestone is COMPLETE. Public registration and production onboarding remain BLOCKED by separate release dependencies.**
