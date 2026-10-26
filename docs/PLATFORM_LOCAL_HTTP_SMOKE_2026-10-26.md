# Airlinerra — Account platform local HTTP validation (2026-10-26)

**Responsibility:** Player account and airline-creation infrastructure only. Airport reviews/approval/categorization remain owned by **Airport Database Overview**. No Trello edits.

## Measurable outcome

**Original task 14 (backend integration validation): Partially complete, improved.** A Node.js **localhost-only, default-disabled** transport now exists for exercising the two previously unmounted protected HTTP adapters. It is not a production backend and is not connected to live Supabase Auth or game-account tables.

### Source code committed to GitHub `main`

- `server/local-account-gateway.mjs` — exports `startLocalAccountGateway({createHandlers,enabled=false,port=0})`. Only binds `127.0.0.1`; no accepted external bind address. Returns the randomly allocated port and an explicit close method. It handles **only** `POST /api/v1/airlines` and `POST /api/v1/legal/consents`, delegating to trusted application handlers passed from the local test harness. It makes **no DB, Auth or email connection itself** and never enables public registration or world admission.
- The transport defaults to **HTTP 503 disabled**; rejects incorrect local `Host`, cross-origin requests, non-POST methods and unknown paths before forwarding to any sensitive handler. It applies a **2,048-byte stream/body limit** even without `Content-Length`, bounded request timeouts, no-store/CSP/nosniff response headers, and redacted generic errors. This is local smoke infrastructure; public hosting would additionally need TLS, secure ingress, rate limiting, environment-scoped secrets, audit logs and independent security review.
- `tests/test_local_account_gateway.mjs` — nine native Node HTTP smoke tests, including two actual POST routes, disabled gate, unknown path/method, cross-origin rejection, oversize known-length and chunked payload rejection, exactly-at-limit payload, and error redaction.
- `website/package.json` — `npm test` includes the new native HTTP tests, which are therefore also included in the existing manual-only GitHub Actions PostgreSQL workflow's `npm test` step.

## Tests and limitations

- **9/9 actual native Node.js 22 HTTP smoke tests passed** in a local loopback server. This exercised real TCP/HTTP and synthetic handler responses. The tests were first created locally, with a standalone chunked transfer test; the nine matching cases were later committed and re-fetched from GitHub `main`.
- **10/10 structural repository checks passed**, confirming disabled-by-default, loopback-only binding, byte/stream limit, local same-origin guard, timeouts, no credentials, the nine tests and GitHub CI script inclusion.
- The tests **do not** establish that Supabase Auth works, account database migrations compile, legal consent persists or $5 million transactions execute concurrently. They use injected fake private handlers.
- No isolated PostgreSQL workflow run was observed among the 100 recent repository Actions runs. The GitHub connector cannot dispatch a fresh workflow; the available TinyFish browser profile has no recorded GitHub sign-in; local PostgreSQL, Docker, and outbound GitHub network access are not available. Therefore **database integration validation remains blocked**. We did not use the live research project as a disposable SQL database.

## Read-only live project verification

As of this audit:
- `airlinerra_game` account tables: **0**.
- World 01 airport activation rows with `active=true`: **3,140**.
- `public.airlinerra_site_status.game_state`: **prelaunch**.

**No deployments, airport approvals, profile writes, public registration, account creation, payments or changes to airport research were made.**

## Original task status after this change

| Original task | Status |
|---|---|
| Registration/login/recovery | **Prepared code**, disabled, not verified against real Auth |
| Consent + airline creation + 7-day trial + starting funds | **Private code and review-only SQL**, disabled, not run against PostgreSQL |
| API networking | **Local smoke transport and nine tests done**, no public host |
| Game-account migration / concurrency | **Not complete**; needs isolated PostgreSQL workflow |
| World 01 airport handoff | Stable registry key recognized; approvals governed by separate airport workstream; not approved for gameplay |
| Domain/email/payments/deployment | **Not complete** |

**Next blocker:** Operator triggers and passes the [manual isolated PostgreSQL 17 workflow](https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml) on `main`. Once real logs exist, fix only evidenced SQL/runtime failures. A development-only Supabase Auth setup then needs genuine email recovery and signup verification before opening the player portal.
