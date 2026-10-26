# Airlinerra — Real isolated Supabase Auth + Mailpit E2E validation
**Date:** 2026-10-26
**Responsibility:** Player registration, email verification, login and password recovery only.
**Status:** SUCCESS in isolated GitHub-hosted local Supabase; **NOT a live player-facing release**.

## Verified GitHub test
- **URL:** https://github.com/bracko87/Airlinerra/actions/runs/40387868074
- **CI SHA:** `90ca387588c5c406268391865c7c9392eb14d922`
- **Workflow:** `.github/workflows/airlinerra-local-auth-e2e.yml`
- **Test:** `tests/e2e/local-supabase-auth.mjs`
- **Result:** Completed **SUCCESS**; local Supabase stack shutdown completed **SUCCESS**.

GitHub Actions ran a disposable Supabase CLI **2.122.0** local stack (PostgreSQL, real GoTrue Auth and Mailpit), with no Supabase Cloud access token or hosted project link. All identities were synthetic `@example.test` records; the test generated random passwords and did not reveal tokens, passwords or verification hashes in the log.

### Actual tested flow (not mocked)

1. **Signup** via real local Supabase Auth created a synthetic unverified user and triggered a real confirmation message in Mailpit.
2. **Email confirmation** parsed the actual Mailpit message's `{{ .TokenHash }}` link, used the real `verifyOtp(type:'email')` HTTP endpoint through the adapter, and confirmed the Auth user.
3. **Password login** authenticated the verified user using the original password and matched the same user ID.
4. **Recovery email** was delivered into Mailpit after the real Supabase reset request; its link had `type=recovery`.
5. **Recovery authorization and change** verified the actual recovery hash, required a fresh Supabase `getUser()` for the same user ID, updated the password using the real Auth API, and signed out the recovery session.
6. **Post-change security:** the service rejected a repeated local `updatePassword` without a new recovery intent, rejected the old login password and accepted the new login password.

Log excerpts (safe; no credentials):
- `PASS: real signup and Mailpit confirmation (synthetic account).`
- `PASS: real verified password login.`
- `PASS: real recovery OTP and one-use password update.`
- `PASS: old password denied, new password accepted.`
- `All local Supabase Auth + Mailpit stages passed. No cloud services used.`
- `Stopped supabase local development setup.`

The first run demonstrated that the Docker-based local Supabase stack could start but uncovered a test-helper mistake parsing the newer CLI's nested `env` map in JSON status. This was fixed; the green run is **the corrected verified run**. For local-only compatibility the REST test runner can fall back to the local *public anon key* where no modern publishable key is supplied. No key is committed, and the browser-development Auth client still insists on a modern publishable key.

## Source changes
- `tests/e2e/local-supabase-auth.mjs`: real HTTP end-to-end test using existing `createAuthService` and `parseAuthCallback` with an HTTP adapter for actual local Auth endpoints; Mailpit REST API inbox verification.
- `.github/workflows/airlinerra-local-auth-e2e.yml`: separate non-deploying CI workflow using `supabase/setup-cli@v3` and pinned Supabase CLI version `2.122.0`, read-only checkout permission, explicit local project checks and cleanup. The workflow is limited to changes to the E2E script or workflow itself (and has a manual dispatch option), rather than burdening every airport-data commit.

## Live production state verified **after** E2E
Read-only SQL on central Airlinerra research project:
- `airlinerra_game` account tables deployed: **0**.
- World 01 `active=true` research airport activation entries: **3,140**.
- Site/game status: **prelaunch**.
- No production Auth user, email, account, airline, trial, airport approval or payment was created by this test.

## Status against original tasks
| Original feature | Evidence-based status |
|---|---|
| Email registration + confirmation | **PASS with real local GoTrue and Mailpit**, not deployed |
| Verified password login | **PASS with real local GoTrue**, not deployed |
| Password recovery | **PASS with real local GoTrue and Mailpit**, not deployed |
| Website form interaction in browser | **Code prepared**, separate browser-driven UI test outstanding |
| Player profile persistence with real Auth and RLS | **Still outstanding in development**, only SQL isolation/model tests passed |
| Current published legal consent, world membership and airline creation | **Still outstanding in integrated development environment**; separate disposable SQL tests previously passed |
| $5m starting balance and 168-hour account-wide trial | **Verified in isolated PostgreSQL**, not activated |
| Public domain/email/SMTP, payment and player onboarding | **Not deployed**; no signup enabled |
| Airport eligibility/approvals | Managed separately in **Airport Database Overview**, untouched here |

**Next original milestone:** Integrate local Auth with *development* game account schema, owner-scoped profile RLS, private policy acceptance and airline-creation API, then test a single synthetic signup → verify → profile → legal acceptance → approved test airport → airline with exactly $5m and one 7-day account-wide trial. This needs an explicitly development-only roster and must never auto-admit airport research activations.
