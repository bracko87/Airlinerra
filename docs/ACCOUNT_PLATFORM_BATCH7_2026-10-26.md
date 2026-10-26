# Airlinerra — Account Platform Batch 7 (2026-10-26)

## Scope and release state

**GitHub branch:** `main`, per `AGENTS.md`. **Trello:** owner-managed; untouched.

The private HTTP onboarding request handler is committed but has **no registered Node HTTP listener, Netlify function, Edge Function or deployed route**. Both its independent `enabled` switch and the existing activation service default off. The dormant PostgreSQL release gate defaults off in the unapplied SQL draft.

## New components

- `server/airline-http-handler.mjs`: injectable server-side handler for `POST /api/v1/airlines`. No dependencies beyond built-in Node; no direct API key, network listener, secrets or credentials in the file.
- `tests/test_airline_http_handler.mjs`: 10 committed Node test cases covering shut-off behavior, exact route and method, origin, JSON content type, bearer-only authentication, payload validation, body limit, returned monetary decimal strings, idempotent replay, provider error redaction and safe HTTP statuses.
- `website/package.json`: combined Node test command now includes `tests/test_airline_http_handler.mjs`. The existing manual-only account and isolated PostgreSQL workflows will pick up the added suite through `npm test`.

## Security and isolation

1. **No activation by default.** A normal request returns HTTP 503 and does not call the activation service.
2. Exact API endpoint `POST /api/v1/airlines` only. Other URLs return 404, other methods 405.
3. Requires a explicitly allowlisted `Origin`. It does not emit a CORS permit header.
4. Requires `application/json` and a bearer access token. Browser cookies alone do not authenticate the operation.
5. JSON body capped at 2,048 UTF-8 bytes, with only `worldId`, `airlineName` and `homeAirportSourceId` permitted; `userId/playerId` cannot be supplied as authority.
6. Passes the bearer token to the existing trusted activation adapter, which obtains player identity using the Auth server, then invokes the private PostgreSQL transaction using bound parameters. No ability to call a private SQL function is exposed in the public browser.
7. JSON response contains only airline id, created/replayed status, exact decimal cash string and trial expiry. Internal error messages and SQL details are not returned.
8. `Cache-Control: no-store`, `Content-Security-Policy: default-src 'none'`, `Referrer-Policy: no-referrer` and `X-Content-Type-Options: nosniff` on every response.
9. The same-world retry is designed to return HTTP 200 instead of another 201; actual exactly-once financial behavior still requires passing real PostgreSQL tests.

## Verification completed

- A native **Node.js 22** smoke test run executed 11 cases in the tool working container: **11 passed / 0 failed**. It covered disabled gate, accepted request, denied cross-origin, rejected extra player ID, oversized input, missing bearer, replay response, private error redaction, route/method and fixed JSON schema.
- The source tested with native Node had a **verified exact match** to the committed module: 4,695 UTF-16 characters, FNV-1a checksum `03c0d6cd`.
- The 10 actual committed regression test bodies were independently fetched from GitHub and exercised with a V8 assertion harness: **10 / 10 passed**. This is **not** a claim that the full native `npm test` run has executed from a GitHub checkout.
- No new real PostgreSQL integration or two-session concurrency run was performed this batch. The existing manual workflow for that remains at:
  https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml

## Release blockers and intended next task

Before this handler can be mounted in a host, the project needs a vetted server runtime with **TLS**, bounded incoming stream parsing, a provider-backed and rate-limited session-verification middleware, deployment secret storage, abuse protection (per-account/per-IP), useful privacy-safe operational logs, CORS/Origin policy reviewed against the production domain, legal terms and valid player consent.

Before player creation is enabled, the disposable PostgreSQL workflow must pass, the real Supabase Auth and email links must be tested, approved game airports must be explicit, and the world release gate must be separately authorized. A runnable Node adapter is **not** permission to change the Supabase Auth server-side registration settings.

`website/account.html` remains a disabled prelaunch preview; Worlds 01–03 remain planned; no production Supabase schema is modified; no live game currency, accounts, memberships or payments are created. Domain and SMTP configuration are still pending. Trello is left entirely to the owner.

### Manual verification commands

```bash
cd website
npm test
npm run build
```

GitHub manual workflow: `Airlinerra isolated PostgreSQL account validation`. Do not claim database-level success before its actual green run.
