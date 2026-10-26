# Airlinerra — Account Foundation Batch 14: Safe password-recovery intent

**Date:** 2026-10-26  
**Branch:** `main`, per `AGENTS.md`  
**Scope:** Platform authentication only. No airport research, classifications, approvals, Trello or live database changes.

## Security problem resolved

The prelaunch Auth service previously treated `exchangeCodeForSession(code)` as sufficient evidence to enable the **reset-password screen** if the URL contained `screen=reset`. A PKCE code can establish an authenticated session without proving that the link was issued for **password recovery**, so a generic email-confirmation callback must never grant a recovery-specific action.

According to Supabase's Auth documentation, password-recovery state is distinguished from ordinary sign-in, including the `PASSWORD_RECOVERY` event, while PKCE code exchange by itself establishes a session:
- https://supabase.com/docs/reference/javascript/auth-onauthstatechange
- https://supabase.com/docs/guides/auth/sessions/pkce-flow
- https://supabase.com/docs/reference/javascript/auth-resetpasswordforemail

## Committed implementation

- `website/recovery-intent.mjs`: a per-service, in-memory **one-use recovery authorization**. It is created only after a completed `verifyOtp({token_hash,type:'recovery'})` response. It requires the OTP response session's user ID to match a fresh Supabase `auth.getUser()` result, and checks that the same account still owns the session immediately before calling `updateUser`. The authorization is consumed even if a password update fails. `clear()` invalidates it.
- `website/auth-service.mjs`: `parseAuthCallback` now refuses `screen=reset&code=...` with no verified recovery-specific purpose. `completeCallback` also defensively rejects manually constructed `{kind:'pkce',purpose:'reset'}` calls **before** attempting code exchange. Only `verifyOtp` with `type='recovery'` can mark recovery intent. Successful signup verification, ordinary login, another callback, sign-out, registration and a new forgot-password request clear any prior recovery authorization. `updatePassword` requires and consumes the gate.
- `website/dev-scripts/build.mjs`: copies `recovery-intent.mjs` into the static build output, avoiding missing-module errors.
- `tests/test_recovery_intent.mjs`: six native Node tests for unverified intent rejection, one-time consumption, identity switching, explicit clearing, missing user verification, and mismatched OTP session identity.
- `tests/test_account_foundation.mjs`: tests deny forged reset-purpose PKCE, prevent password changes after email verification alone, require real recovery OTP, verify identity stability, consume the gate exactly once and clear it when signing in again. An earlier test assumption that recovery intent survives a new malformed callback was corrected to fail closed.
- `website/package.json`: existing `npm test` now includes the new recovery-intent suite alongside all previous account/consent/airline tests.

## Important behavior and release limitation

**This does NOT enable public password reset or registration.** The site stays `PUBLIC_AUTH_ENABLED=false`. Supabase's standard PKCE password-reset link may return a generic `code`; in the current **prelaunch-only** implementation, a reset-screen PKCE callback is intentionally rejected instead of silently treated as recovery proof.

**Before enabling actual signup/reset**, the team must implement and test an authenticated recovery-specific PKCE intent using the provider's documented recovery event, or configure and verify an official Supabase recovery `token_hash` email template that redirects with `type=recovery`. This must be proven in a separate approved development environment and end-to-end using actual SMTP. Do **not** open signup with a nonfunctional password-reset channel. Do not bypass this guard to make the UI appear complete. Confirm Supabase Auth and SDK version behavior again before release.

## Verification performed

- **6/6 native Node.js 22 gate tests passed locally** (standalone gate implementation with mocked provider, no network or real account).
- **18/18 committed account-foundation plus recovery-gate test bodies passed** in a separate JavaScript V8 compatibility harness, using freshly fetched files from GitHub `main`, including build/static preview/source-level assertions. This is **not** the full native checkout `npm test` and **not** a real Supabase Auth integration test.
- GitHub `main` build-copy list and `npm test` runner were checked after updates. The main site and all three worlds still default closed.

## Remaining release gates

1. **Actual disposable PostgreSQL workflow run**: https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml
2. Actual Supabase Auth email template/SMTP, recovery flow, redirect validation, expired/replayed token handling and session-revocation tests on an owner-approved nonproduction environment.
3. Private API deployment with rate limiting, audit logs and secure backend credentials.
4. Owner review of domains, data retention, published legal texts, pricing and payment provider before public release.

No game database migrations, paid services, domains or public registration were initiated.
