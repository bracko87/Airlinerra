# Airlinerra — official domain is also the prelaunch testing site
**Owner direction — 27 October 2026**

## Current decision

The correct Airlinerra domain is **https://airlinerra.com/**. Until the game itself is launched, use the **existing** public Netlify site, connected to GitHub `main`, for frontend development, visual review and controlled hosted tests. **Do not create a second Netlify project, paid staging host, or separate testing subdomain just for development.**

The site's marketing/prelaunch pages may be public; that does not mean the game is released. Reuse the exact domain after launch, with public features enabled only through separate launch approval.

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
