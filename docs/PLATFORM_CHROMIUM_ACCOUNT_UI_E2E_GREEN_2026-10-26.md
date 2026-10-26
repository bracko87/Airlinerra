# Airlinerra — Actual Chromium account UI integration: GREEN

**Date:** 26 October 2026  
**Owner:** Airlinerra player platform, independent of Airport Database Overview.  
**Verified run:** https://github.com/bracko87/Airlinerra/actions/runs/40392106880  
**Tested commit:** `0a5541f17715a42a166a8522efe57516d75e526c`  
**CI status:** **completed / success**, including local-stack cleanup.  
**Environment:** GitHub-hosted temporary Docker Supabase (GoTrue, PostgreSQL, PostgREST and Mailpit) plus headless Chromium (Playwright). No hosted Airlinerra, Tennis Legacy or ProPeloton Supabase project was used.

## New completed scope

Actual browser clicks and page navigation on the existing `website/account.html`, backed by real local GoTrue and Mailpit:

1. Open the real account page, select Register, fill synthetic manager name/email/password, check the test-only legal checkbox and submit.
2. Read the real confirmation email captured by local Mailpit. Open the confirmation link in Chromium. Email verification completes and the sign-in screen displays.
3. Sign in with the verified account. Actual `website/account.js` transitions to the manager-profile page.
4. Save a manager display name and `de-DE` locale through the existing player data service and real PostgREST row-level security.
5. Reload the page. The saved profile persists and is repopulated from PostgreSQL. The game-world directory renders from its database state.
6. Open Forgot password, send recovery email, follow the real Mailpit recovery link and update the password through the browser.
7. Attempt the previous password; sign-in is denied. Sign in with the new password and verify the same saved manager profile is retrieved.
8. No unhandled browser JavaScript exceptions. The browser test and local Supabase stack were shut down afterward.

**Exact green log evidence:**
- `PASS: registration form submitted through a real Chromium browser.`
- `PASS: browser email-confirmation callback from real Mailpit link.`
- `PASS: verified player profile survives real browser refresh and RLS.`
- `PASS: real browser recovery callback and one-time password update.`
- `PASS: previous password denied; new password signs into same saved profile.`
- `ALL REAL CHROMIUM ACCOUNT UI CHECKS PASSED; no public deployment.`

### Other real development tests in the same successful workflow

The preexisting real-local Auth test and authenticated backend onboarding E2E passed again: verified identity, owner-scoped profile RLS, private legal acceptance, release/airport gates, two independent airlines ($5 million per airline), safe idempotent replay and a **single shared 168-hour trial**. These **backend** transactions were tested with synthetic policy, synthetic airport approvals and operator switches **only inside the temporary database**. They were **not** performed through a browser airline-creation wizard.

## Source changes

- `website/auth-client.mjs`: accepts legacy JWT-style anonymous public Auth keys **only when targeting local Supabase** and only if their parsed JWT role is exactly `anon`; hosted clients still require publishable keys. This blocks accidentally exposing a service-role key through the development browser.
- `website/account.js`: explicit local Auth preview can load a locally bundled SDK rather than downloading a browser SDK from an external CDN. Production `PUBLIC_AUTH_ENABLED=false` remains unchanged.
- `website/dev-scripts/dev-local-auth.mjs`: injects the local-only SDK flag into the virtual development Auth configuration. It remains loopback-only, opt-in and isolated.
- `tests/e2e/package.json`: pins the isolated test versions of Playwright and esbuild.
- `tests/e2e/browser-sdk-entry.mjs`: bundles the public Supabase JavaScript SDK for local Chromium use.
- `tests/e2e/browser-account-ui.mjs`: real Chromium page-interaction test.
- `.github/workflows/airlinerra-local-auth-e2e.yml`: bundles a local browser SDK, installs disposable Chromium and runs the browser UI after actual backend Auth/onboarding tests. No deployment jobs or project credentials are added.
- A first browser test run failed on an **incorrect CI assertion**: the preceding backend test deliberately opened synthetic Worlds 01/02, so the UI correctly rendered them as open. The assertion was corrected to expect those synthetic worlds open and World 03 closed. The follow-up run **passed all steps**.

## Status against ORIGINAL Airlinerra tasks

| Original deliverable | Evidence-based status |
|---|---|
| Account page registration UI, email verification, login | **Actual Chromium + real local Auth: PASSED**, not deployed |
| Forgot password/reset UI | **Actual Chromium + real local Auth/Mailpit: PASSED**, not deployed |
| Player profile read/write and refresh persistence | **Actual Chromium + PostgREST/RLS: PASSED**, not deployed |
| Legal consent backend | **Actual local PostgreSQL and verified Auth: PASSED**, not through browser onboarding |
| Backend airline activation, home-airport key, exact $5m, single seven-day trial | **Actual local PostgreSQL: PASSED**, not through browser onboarding |
| World selection, legal approval and airline-creation wizard in account UI | **NOT COMPLETED**; browser currently displays informational world directory and editable profile only |
| Actual World 01 gameplay airport roster | **Approval handoff pending in Airport Database Overview**; no automatic approval based on `active=true` |
| Hosted development environment, domain, SMTP, legal documents, payment and public registration | **NOT COMPLETED** |

## Live research/database status checked after successful CI

- `airlinerra_game` account tables: **0 deployed**.
- World 01 `airport_world_activation.active=true` records: **3,140**.
- Website site state: **`prelaunch`**.
- No live player signups, subscriptions, policy records, airplane purchases, airport classifications or operator approvals were changed.

## Next original platform task

**Build a real, guarded browser onboarding wizard** to consume a server-supplied **explicitly approved** airport roster, display the current *published* policy versions for affirmative acceptance, select an authorized world, and submit airline creation through the trusted server API. The wizard must remain hidden/disabled on the public prelaunch site and must not expose synthetic CI airports or provisional legal versions to real users. Add browser E2E coverage against the same isolated local stack and only then consider an owner-authorized hosted development deployment.

**Do not confuse passing development tests with production readiness.**
