# Airlinerra — Real local player-onboarding integration: GREEN

**Date:** 26 October 2026  
**Scope:** Platform account registration, profile, legal consent, airline creation, seven-day trial and $5m bankroll.  
**GitHub Actions:** https://github.com/bracko87/Airlinerra/actions/runs/40389689446  
**Run commit:** `2cfc7c78b14beeb575639f26f61af05b1eaad9e9`  
**Verified status:** Completed, **success**.  
**Environment:** GitHub-hosted runner; Docker local Supabase CLI 2.122.0, GoTrue, local Mailpit, local PostgreSQL and PostgREST. **No hosted Supabase project was used for the integration test.**

## Original tasks proven in actual isolated integration

1. **Email signup and verification:** real synthetic `@example.test` account created, confirmation email captured by Mailpit, token verified against GoTrue, user identity freshly verified by Auth.
2. **Login:** existing password successfully authenticated. The separate real Auth test also verified a password recovery email, one-use recovery token, one-time update, old password denial and new-password acceptance.
3. **Profile:** owner-scoped profile was created and read using the actual `createPlayerDataService`, Supabase JS and PostgREST with RLS, including persisted `display_name` and `de-DE` locale. Anonymous reads of the saved profile were denied by real RLS.
4. **Closed by default:** real private game schema drafts were applied **only inside local disposable PostgreSQL**. All worlds began `planned`, and the release gate blocked airline creation. No airline or bankroll existed before the test explicitly opened its synthetic operator-controlled state.
5. **Legal acceptance:** the test explicitly inserted a **synthetic CI-only** approved legal policy in the temporary DB, then proved airline creation still failed before acceptance. Verified legal-consent service saved the exact test policy versions; replay was idempotent.
6. **Airport/world approval:** the temporary database received exactly two explicit test admissions — World 01 `OURAIRPORTS:101` and World 02 `FICTIONAL:fictional:RS:LYAL` — plus test-only open worlds. An unapproved key `OURAIRPORTS:202` was denied. **These are not approvals of the central research database.**
7. **Airline creation:** the real `createAirlineActivationService` called the actual private `airlinerra_game.create_airline_once` PostgreSQL transaction after verifying the user's real Auth session.
8. **Financials:** two test airlines in two worlds each had exactly **$5,000,000 starting capital** with exactly one `STARTING_CAPITAL` ledger entry per airline. Retrying activation returned the same airline rather than another credit.
9. **Subscription trial:** the user had exactly one entitlement row with a shared `168-hour` trial across both worlds; no second free trial was started.

## Evidence from GitHub's real CI logs

- `PASS: real signup and Mailpit confirmation (synthetic account).`
- `PASS: real verified password login.`
- `PASS: real recovery OTP and one-use password update.`
- `PASS: old password denied, new password accepted.`
- `PASS: local-only Auth PostgreSQL preflight (no research schema).`
- `PASS: real signup, Mailpit confirmation, login and server-side identity verification.`
- `PASS: verified Auth account persists its profile through real PostgREST RLS.`
- `PASS: game-world and platform release switches deny first creation.`
- `PASS: real published-test-policy consent, replay and airport approval gates.`
- `PASS: real SQL two-world airline activation, one trial, $5m per airline, safe retry.`
- `PASS: anonymous profile read denied by real Supabase RLS.`
- `ALL REAL LOCAL FULL ONBOARDING CHECKS PASSED; CI-only state discarded.`
- `Stopped supabase local development setup.`

## Changes committed

- `tests/e2e/package.json`: fixed-version `@supabase/supabase-js@2.118.0` and `pg@8.16.3`, used only by isolated CI tests, not the published site.
- `tests/e2e/local-player-onboarding.mjs`: genuine authenticated registration, PostgREST/RLS profile test, trusted private legal and airline transactions, and SQL postconditions.
- `.github/workflows/airlinerra-local-auth-e2e.yml`: adds guarded local PostgreSQL preflight, applies the previously review-only game-account SQL drafts in a disposable local database, installs the pinned test-only dependencies, executes the real complete-player-journey script and always shuts down the test stack. The original real Auth + Mailpit test still runs first.

## Live Airlinerra Supabase verification

A read-only query **after** the green CI run confirmed:
- `airlinerra_game` deployed account tables: **0**.
- World 01 central research airport activation rows with `active=true`: **3,140**.
- Website/game state: **`prelaunch`**.

No hosted account records, active worlds, operator airport approvals, game credits, legal policies, domain records, email delivery settings or payments were created or changed by the test.

## What is **not** complete

- The published website account UI has not undergone a full browser-driven click-through E2E; this test exercised the real service and data-layer implementations on a local runner.
- Real published Terms and Privacy Policy, a hosted development environment, secure hosted API, official game airport operator handoff and public payment/billing are still pending.
- The central 3,140 World 01 airport activation rows should **not** be copied into `airlinerra_game.approved_game_airports` merely because `active=true`; classification/admission reconciliation belongs entirely to Airport Database Overview.
- Public registration remains disabled. No live account schema has been deployed.

**Next original-platform milestone:** browser-driven account journey using the approved deployment configuration, followed by a separate owner-authorized hosted development environment and legal/payment release review. Do not deploy the review-only game schema to the existing research Supabase project without explicit authorization.

**Status summary:** **isolated technical onboarding E2E — completed and verified**; **publicly playable onboarding — not completed**.
