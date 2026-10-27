# Airlinerra — official domain is also the prelaunch testing site
**Owner direction — 27 October 2026**

## Current decision

The correct Airlinerra domain is **https://airlinerra.com/**. Until the game itself is launched, use the **existing** public Netlify site, connected to GitHub `main`, for frontend development, visual review and controlled hosted tests. **Do not create a second Netlify project, paid staging host, or separate testing subdomain just for development.**

The site's marketing/prelaunch pages may be public; that does not mean the game is released. Reuse the exact domain after launch, with public features enabled only through separate launch approval.

## Step 2a — Real isolated invitation test PASSED (27 October 2026)

- **[GitHub E2E run #40513518775 — PASS](https://github.com/bracko87/Airlinerra/actions/runs/40513518775)**. This test uses Supabase CLI 2.122.0 to start *temporary local* GoTrue, PostgreSQL, Kong and Mailpit. It exercises synthetic signup/confirmation, verified login, password recovery, an **administrator-created invitation**, one-time `type=invite` OTP, identity-bound initial password, second-use denial, and login using the invited account. It also executes the full Chromium account UI/local player flow. It never touches the hosted Airlinerra Supabase project.
- Local CLI may provide modern `sb_secret_...` administrator keys instead of service-role JWTs. The test now accepts both *only after validating that the local API URL is `127.0.0.1:54321`*; it never prints credentials. The admin invite uses the proper administrator key as the API key, not the anonymous/publishable key.
- The invitation flow is **working under a disposable local stack**. That does not demonstrate that the hosted Airlinerra Auth provider has signup disabled, real email templates configured, verified SMTP, or a deployed public-domain test UI.
- `server/hosted-auth-readiness.mjs` was hardened to require an explicit `external.anonymous_users === false` in addition to `disable_signup === true`, confirmed-email settings and enabled email provider; missing information is rejected, not assumed safe.
- Resend usage is **three sender domains out of three allowed**; **two are failed to verify** (`nextqueststudio.net`, `tennislegacygame.com`), while `propelotonmanager.com` is verified. Read-only diagnostics confirm the two failed domains have unresolved verification records. Neither failed domain can be assumed obsolete; do not delete either without owner approval. Adding `airlinerra.com` through the connected email API was rejected with HTTP 403 `domain limit reached`. Existing mail volume also draws against the same shared sending quota.
- **No external invitation emails were sent, no live Supabase Auth settings were changed and no new hosting or email subscription was purchased** during this milestone.

## Step 2 — Auth invitation and confirmation code prepared (27 October 2026)

**Code/test milestone completed; real public-domain email delivery and account login are NOT yet active.** No new Netlify site, Supabase project or hosting subscription has been created.

- `website/auth-rules.mjs` now allows the exact canonical **`https://airlinerra.com`** for future verification and recovery redirects while keeping `PUBLIC_AUTH_ENABLED=false`. `www` or other domains do not qualify as account callback origins. The old localhost-only test harness was updated to preserve the existing local workflow.
- `website/invited-tester-auth.mjs` is a **source-only, non-published** invited-user sign-in client pinned to the existing Airlinerra Supabase Auth project. It can sign in, verify an invitation, recover passwords and sign out, but exposes no signup method. It is intentionally omitted from the static site's `dist/` allowlist.
- `server/hosted-auth-readiness.mjs` queries the Auth service's public `/auth/v1/settings` endpoint using the publishable key before the **canonical operator-test** backend creates a PostgreSQL pool. Startup fails closed unless `disable_signup=true`, `mailer_autoconfirm=false`, email authentication enabled and anonymous signup not enabled. **These settings have not yet been confirmed on the real hosted Auth service.** They must be configured in the Supabase Dashboard; a UI-side flag is not an authentication-provider security control.
- `website/auth-service.mjs` handles Supabase `type=invite` OTP confirmation and permits exactly one password setup tied to the freshly verified invited user. The existing prelaunch UI uses the password setup screen after the invite succeeds. Ordinary signup confirmation and arbitrary PKCE links cannot authorize the reset screen.
- `supabase/templates/invite.html` and the local `supabase/config.toml` include a dedicated Airlinerra invitation email with a one-time `token_hash` callback to `https://airlinerra.com/account.html?screen=verify&type=invite`. The normal confirmation and recovery templates were also tested against the official-domain URLs. **These templates are source assets, not yet installed into hosted Supabase Auth.**
- The GitHub account Node/disposable Postgres regression [#40511157414](https://github.com/bracko87/Airlinerra/actions/runs/40511157414) passed; a separate local Auth/Mailpit workflow [#40511007507](https://github.com/bracko87/Airlinerra/actions/runs/40511007507) also passed. The pinned Netlify ZIP with synthetic invite-only Auth readiness passed earlier in [#40510463006](https://github.com/bracko87/Airlinerra/actions/runs/40510463006).

### Real hosted setup still blocked

1. **Supabase hosted Auth:** Using the existing Airlinerra project, set *Allow new users to sign up* to OFF, email confirmation ON, anonymous accounts OFF, email provider ON. Set Site URL to `https://airlinerra.com` and allow only the necessary `/account.html?screen=verify` and `/account.html?screen=reset` callbacks. Deploy the reviewed invite, confirmation and recovery templates through Supabase Auth Dashboard. **Do not send invites until the callback page is actually operational.** Only the Supabase Dashboard/Auth Admin API may create invited tester users.
2. **Resend domain verification:** Read-only list of the connected sender account showed no `airlinerra.com` domain. Attempting to add it returned a **403 domain-limit error** (the plan has reached its limit). No domains were deleted, no plan upgraded and no DNS records touched. Sender-domain capacity must be resolved before a dedicated Airlinerra Resend SMTP sender can be verified. Do not reuse another game's branding/domain without approval. Existing local Mailpit remains available for test emails without a verified production sender.
3. **Existing Netlify project:** Production account API is still undeployed and the public website still has `PUBLIC_AUTH_ENABLED=false`; an authenticated host-management session plus secure host environment setup is needed. The operator-only canonical backend needs a separately approved deployment using the tested esbuild→Netlify Functions packaging chain.
4. **No user/game launch:** Invited Auth identity testing does NOT approve game account registration generally, airline creation, World 01, payments or game trial activation. Keep `airlinerra_game.platform_release_gate.enabled=false` and world states `planned` throughout setup.

## Step 1 implementation — source complete, NOT deployed

The same-domain operator testing mode is now implemented as **source-only code**:

- `server/hosted-runtime-config.mjs` recognizes the exact server-only `AIRLINERRA_HOSTED_RUNTIME_MODE=canonical-prelaunch-test` setting. It requires `AIRLINERRA_HOSTED_BACKEND_ENABLED=true`, `AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED=true`, a Netlify **production** deployment context, and the pinned `AIRLINERRA_CANONICAL_TEST_ORIGIN=https://airlinerra.com`. These do **not** authorize public registration, payment collection or unlocking a game world.
- `server/netlify-preview-template/airlinerra-accounts.mjs` checks the trusted Netlify `context.deploy.context='production'`, `context.deploy.published=true` and Airlinerra site identity. It refuses canonical requests without the separate mode and opt-ins; preview-only flags are explicitly insufficient.
- `server/preview-access-guard.mjs` uses `AIRLINERRA_CANONICAL_TEST_ACCESS_SECRET` **only** in canonical mode; the prior private-preview credential is not valid on the official domain. The `X-Airlinerra-Preview-Access` header is required and removed before forwarding to verified user handlers. Requests failing operator authentication cannot read the database connection URL, load PostgreSQL or call Auth.
- Keep the existing Netlify code-based 30/IP/minute rate limit and four in-flight per-instance limit.
- `tests/test_canonical_prelaunch_account_api.mjs` uses entirely synthetic credentials and a stub database to exercise the official-domain approval switches, preview credential isolation, real Auth-style verification, and rejection by the still-closed `platform_release_gate` without reading the airport catalog or writing airlines.
- The existing GitHub Actions packaging workflow tests the **real compiled Netlify Function ZIP** in a completely offline, synthetic official-domain test.

**No new Netlify project or separate staging domain is needed.** Do not move `server/netlify-preview-template/airlinerra-accounts.mjs` into a discovered Functions directory: the prior verified packaging workflow needs to prebundle the pinned `pg` dependency first.

### Remaining for a functioning test account at airlinerra.com

1. Obtain access to the **existing Airlinerra Netlify project** for secured host environment configuration; never commit secrets, require them in chat or add them to frontend JS. The current connected tools do not have an authenticated Netlify management session.
2. Separately approve and deploy the validated operator-only Function artifact on the existing site, retaining full public marketing access and default-closed backend switches.
3. Verify Supabase Auth provider-level testing eligibility, allowed redirect URLs and secure SMTP/email confirmation behavior; do not enable unrestricted public signups.
4. Publish reviewed legal Terms and Privacy documents, configure approved test accounts, and implement a controlled test-data path if account/airline mutations are desired; the **live private game release gate remains disabled**.
5. Activate browser test UI only behind explicit operator authorization, without setting `PUBLIC_AUTH_ENABLED=true` for all visitors.

## What is already active

- https://airlinerra.com/ is the public prelaunch website with Namecheap DNS and Netlify HTTPS.
- https://airlinerra.com/account.html is a non-submitting account-interface preview.
- GitHub `main` publishes the static `website/` build automatically to the same site.
- Live hosted `/api/v1/airlines` and other account endpoints **are NOT yet deployed**.
- Browser public Auth remains disabled: `PUBLIC_AUTH_ENABLED=false`. The database account release gate is disabled; worlds remain closed. Live player registration, payments and airline activation are **not** authorized.

## Implementation plan for SAME-DOMAIN backend testing

1. Keep all public-facing prelaunch content and the official `airlinerra.com` DNS/hosting unchanged. Use this domain for manual responsive/browser validation now.
2. **Refactor or replace the staged Netlify API source before any deployment:** today's `server/netlify-preview-template/airlinerra-accounts.mjs` and `server/hosted-runtime-config.mjs` **deliberately reject published production contexts and the canonical domain**. That was correct for the earlier isolated-preview design. **Do not try to enable it by merely toggling `CONTEXT` or bypassing trusted host checks.**
3. For controlled tests on the canonical site, implement an **explicit prelaunch-test-only server mode** with a dedicated opt-in that defaults to off, Netlify's trusted production deployment/site identity, pinned canonical HTTPS Origin and path, a high-entropy **server-only** operator credential, Netlify edge IP rate limiting, per-instance throttling, and full Supabase Auth token verification. Test it offline first, including a real ZIP bundle smoke and production-without-opt-in rejection.
4. Keep the existing **database** release and legal consent gates independent: an operator API test credential is **not** permission to create airlines, open worlds, accept nonexistent legal agreements, allow public signup, or use customer payments. Default to nonmutating read-only tests until a separate controlled test-data plan is approved.
5. Netlify dashboard access and secure environment values may still be necessary **later** for an actual hosted backend. That is configuration of the **existing** Netlify project, not creation of any additional site or paid subscription. Never put passwords, tokens, database URLs or user data in GitHub, `netlify.toml`, browser JavaScript or chat.
6. When the account system is reviewed and approved for launch, explicitly switch only the relevant public functionality on at the same official domain, rather than performing a hosting or DNS migration.

## Supersedes earlier preview-only plan

Prior handoffs in `docs/PLATFORM_NETLIFY_API_STAGE_2026-10-27.md` and `docs/PLATFORM_PREVIEW_ACCESS_GATE_2026-10-27.md` described separate Netlify deploy previews. Those source-only tests and their security lessons remain useful, **but a separate preview site is no longer a project requirement**. Do not describe the old preview-only backend as deployable to `airlinerra.com` until its explicit same-domain prelaunch mode is implemented, reviewed, and verified. This is a project-plan decision only; this document does not deploy or enable account code.
