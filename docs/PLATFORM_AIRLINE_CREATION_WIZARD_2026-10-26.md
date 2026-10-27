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
- **The browser milestone is closed**. It does not certify hosted service readiness, production terms and privacy, or deployment of a game-account approval roster. The previously verified account UI journey is also documented in `docs/PLATFORM_CHROMIUM_ACCOUNT_UI_E2E_GREEN_2026-10-26.md`.

## Live database remains untouched

After the changes, read-only checks confirmed:
- Deployed `airlinerra_game` tables: **0**.
- Research World 01 active records: **3,140**. An explicit owner-authorized **simulation-only** foundation release also has exactly **3,140** member keys; the two sets match precisely with zero duplicates or mismatches (read-only SQL verified 2026-10-26).
- Website/game state: **`prelaunch`**.

No actual legal documents were approved, no airport research rows were mutated by this workstream, no live game-account tables or worlds were opened and no paid subscriptions were enabled.

### World 01 airport handoff (code prepared, deployment blocked)

The Airport Database Overview workstream **already recorded owner authorization** `FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26` for the original 3,140 airports as a **simulation game catalog**, explicitly not real-world commercial operating permission or production website launch. An owner-approved subset does not need to be reapproved for this same simulation purpose. The private source view is `airlinerra.airport_game_world1_registration_source`.

The existing unapplied migration `docs/sql/AIRLINERRA_WORLD1_3140_TO_GAME_ACCOUNT_AIRPORTS_PRELAUNCH_2026-10-26.sql` was repaired to use `(world_id,airport_key)` throughout, matching `airlinerra_game.approved_game_airports` and the `create_airline_once` API. The earlier draft incorrectly used bigint-style `source_airport_id` in an account schema that requires stable `OURAIRPORTS:<id>` text keys. A contract-drift regression was added in `tests/test_sql_contract_drift.mjs`. **This SQL has not been run against the live database; approval transfer awaits installed game-account tables and owner-authorized deployment.**

## World 01 airport roster — actual disposable SQL transfer and player-readable choices

- The ACTUAL (unapplied) World 01 airport bridge has now been exercised in disposable PostgreSQL with 3,140 synthetic source identities: first import, idempotent second import, incorrect source-count rejection, unchanged world states and release gate, and a clean restore to the disabled baseline. Both Node and PostgreSQL jobs passed in [GitHub Actions #40404162522](https://github.com/bracko87/Airlinerra/actions/runs/40404162522).
- A read-only check of the already-approved live research view confirmed 3,140 airports with **no missing names, source airport codes or country codes**. The longest observed name was 90 characters and the longest source airport code 8 characters.
- The REVIEW-ONLY account schema now stores optional airport name, airport code, country and municipality on `airlinerra_game.approved_game_airports` records. The guarded airport bridge copies these fields from the owner-approved World 01 view; it rejects missing or drifted identifying display metadata. Import still requires an explicit, authorized game-schema deployment.
- The private onboarding context now formats player-facing options such as **Bremen Airport (EDDW) — DE**, instead of showing just an opaque `OURAIRPORTS:<id>` key. The underlying chosen value, database foreign key, and server authorization remain the immutable airport key; no research schema becomes browser-accessible.
- The latest complete native Node and disposable PostgreSQL checks passed in [GitHub Actions #40405017760](https://github.com/bracko87/Airlinerra/actions/runs/40405017760). The additional real Chromium E2E assertion that verifies the visible synthetic airport name/code/country label **passed**, along with full signup, Mailpit email confirmation, profile, consent, $5m airline creation and recovery, in [GitHub Actions #40405209599](https://github.com/bracko87/Airlinerra/actions/runs/40405209599).
- No public registration was enabled, no actual game-account table was deployed, and no real production airport approval was applied by these changes.

## Remaining original launch work

1. **Complete:** Green actual-browser wizard result, including synthetic legal links, private consent transaction, approved test-airport selection and a $5,000,000 starting balance; independently verified in run #40401594030.
2. **Airport release already authorized; handoff pending deployment:** The first 3,140 World 01 simulation airports are explicitly owner-authorized in the private research database; use the guarded key-matched bridge after the game-account schema is installed and reviewed. Do not ask for duplicate cohort approval, import other candidate airports, infer commercial-flight permits or open the release gate.
3. **Real legal publication pending:** Publish owner-reviewed Terms and Privacy documents, with versioned links and retention/consent policy. CI synthetic pages are not player legal documents.
4. **Pending owner-authorized hosted integration:** Configure secure development hosting, identity/database/SMTP/domain, production release gates and payment integration; verify the complete flow in hosted staging before enabling public player registration. Do not deploy the private schema or open live accounts without explicit authorization.

**The source-code and isolated full-browser milestone is COMPLETE. Public registration and production onboarding remain BLOCKED by separate release dependencies.**


## 27 October 2026 — Game database installation completed

The actual Airlinerra Supabase prelaunch database is now installed: 8 protected `airlinerra_game` tables, 3 planned worlds, **3,140** authorized game-roster airport records for World 01 with all keys/metadata matching the approved research source. The dedicated gate is **disabled**, no player accounts/airlines or legal policy are present, and public onboarding is still unavailable. The earlier October 26 text above describing the live game database as absent is retained as **historical evidence**, not current status. See [the verified current state](PLATFORM_PRELAUNCH_ACCOUNT_DB_INSTALLED_2026-10-27.md).
