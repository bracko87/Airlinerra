# Airlinerra — Preview API access gate (27 October 2026)

**Milestone:** Source-only security layer implemented for a possible private account API preview. **Not deployed to Netlify, and no live player account or airline creation authorized.**

## Why a second preview gate was needed

Airlinerra's public website `https://airlinerra.com/` uses a Netlify Free site connected to GitHub `main`. A future public-facing preview URL can be discovered by strangers unless protected. Netlify's current [Project Visibility / password protection documentation](https://docs.netlify.com/manage/security/secure-access-to-sites/password-protection/) says password-protected previews require paid access on the credit-based Free/Personal plans. The goal is to keep the public site on its current plan, **not** buy an unnecessary second hosting package.

The preview API now requires both existing operator flags, `deploy-preview` or `branch-deploy` context, exact approved preview hostname and Origin, and a **separate 256-bit random operator access credential** before loading any private backend dependencies.

## Implementation

- `server/preview-access-guard.mjs`: exact allowlist of three POST API routes; HTTPS Netlify deploy-preview/branch-deploy hostname bound to the Airlinerra site; request URL Origin and `Origin` header match; `application/json` required; timing-safe digest comparison of a Base64URL-format operator secret; no credential in URL. Rejects absent/malformed/unapproved secrets without contacting Auth or Postgres.
- Credential header: `X-Airlinerra-Preview-Access`. It is **stripped before the request enters the trusted onboarding handlers**, which still receive the separate verified player's `Authorization: Bearer …` token.
- One warm Netlify Function instance accepts at most **4 concurrent requests** and **30 valid gated requests per 60-second window**, returning HTTP 429 if exceeded. Malformed requests do not count toward the warm-instance budget. These process-local limits are only an additional safety net; they are **not distributed** and **cannot replace Netlify edge/WAF limits**.
- `server/netlify-preview-template/airlinerra-accounts.mjs` integrates the guard **before** creating the app, pool or Supabase Auth verifier; it releases concurrency slots even if initialization or handlers fail.
- `tests/test_preview_access_guard.mjs` and `tests/test_staged_netlify_account_api.mjs` test bad/missing access keys, wrong Origin, wrong host/path/method/content type, header redaction, concurrent and per-minute limits, startup failure recovery, and no production app creation.

## Deployment is still withheld

The Netlify Function remains at `server/netlify-preview-template/`, **not in Netlify's discovered Functions directory**. There is still **no live `/api/v1/airlines` route**. Do not move the Function without a separate owner-authorized and rate-limited nonpublic preview launch. The entire public website must remain available anonymously.

On a future separately approved preview, generate a 32-byte high-entropy Base64URL credential **locally** with a secure generator, for example `node -e "console.log(require('node:crypto').randomBytes(32).toString('base64url'))"`. Place it in Netlify's secure environment UI as `AIRLINERRA_PREVIEW_ACCESS_SECRET`, never in the repo, `netlify.toml`, a URL, frontend JS, or ChatGPT messages. Only trusted operator test clients may send it in the preview header over HTTPS. Rotate it after any compromise, and do not store it alongside sample scripts or browser assets.

**Netlify Free nuance:** Netlify [documents](https://docs.netlify.com/build/environment-variables/overview/) that setting variable scope specifically to `Functions` is a **Pro/Enterprise feature**. On Free, environment values configured with available scope settings can also be accessible during builds. A safe future setup needs build-time non-disclosure checks and minimal privilege; do not mislabel it as Functions-only on Free. Environment values in `netlify.toml` do *not* become function runtime secrets. Contextual deployment values should be set in the host UI/API, not committed files.

Other blockers still apply: approve an isolated test deployment/branch workflow under Airlinerra's `main`-only policy; validate Auth's server-side signup restriction; publish real reviewed Terms and Privacy; set up approved SMTP and callbacks; configure real connection credentials securely; verify edge abuse protection; and run isolated hosted registration and airline-creation tests. A valid preview credential by itself does not override any game world, legal consent, or SQL release switch.

**Never describe source-only tests as a live, restricted Netlify deployment or a public account launch.**
