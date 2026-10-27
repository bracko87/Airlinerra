# Airlinerra — official domain is also the prelaunch testing site
**Owner direction — 27 October 2026**

## Current decision

The correct Airlinerra domain is **https://airlinerra.com/**. Until the game itself is launched, use the **existing** public Netlify site, connected to GitHub `main`, for frontend development, visual review and controlled hosted tests. **Do not create a second Netlify project, paid staging host, or separate testing subdomain just for development.**

The site's marketing/prelaunch pages may be public; that does not mean the game is released. Reuse the exact domain after launch, with public features enabled only through separate launch approval.

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
