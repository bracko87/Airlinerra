# Airlinerra — Account Platform Batch 10: Legal HTTP API and onboarding flow
**Date:** 2026-10-26  
**Development branch:** `main` (Airlinerra's `AGENTS.md` policy)  
**Release:** PRELAUNCH — no HTTP listener, migration, account signup, world admission or payment enablement  
**Trello:** owner-managed; no edits

## What was committed

- `server/legal-consent-http-handler.mjs`: protected, unmounted `POST /api/v1/legal/consents` handler. The handler's `enabled` option **defaults to false**, independently of the underlying `createLegalConsentService` default-off gate. The live site does not route to it.
- `tests/test_legal_consent_http.mjs`: covers disabled operations, path and method restrictions, exact Origin allowlist, JSON-only and bearer-token checks, unknown payload keys, explicit consent for both documents, UTF-8 byte limits, idempotent consent receipts, stale legal versions, and redaction of provider/SQL errors.
- `server/onboarding-flow.mjs`: pure, server-oriented *display/readiness* state classifier for account setup. **It does not grant gameplay access.** All real session, world, airport, subscription, terms, cash, and trial decisions must be repeated by the trusted backend/database transaction.
- `tests/test_onboarding_flow.mjs`: covers unverified/anonymous accounts, unavailable policy, changed legal version, expired trials, open/closed worlds, unapproved airports, existing airline, and invalid evaluation clock.
- `website/package.json`: the existing `npm test` runner includes the two new suites. Both manual-only account and disposable PostgreSQL GitHub workflows execute `npm test` when separately triggered.

## Account onboarding sequence

| Phase | Player-visible state | Backend authorization requirement |
|---|---|---|
| 1 | Sign up / sign in | Supabase Auth; signup remains disabled by server configuration until approved |
| 2 | Confirm email | Fresh verified Auth identity and server-side account status |
| 3 | Review Terms and Privacy | Versioned **published legal text**, owner-approved and legally reviewed; no text has been published yet |
| 4 | Accept both documents | Protected consent HTTP request, exact published versions, verified player ID and immutable consent timestamp |
| 5 | Membership check | Server validates unexpired account-wide trial or active paid subscription; expired, past-due and suspended accounts cannot create another airline |
| 6 | Select world | 01 Founding World, 02 Expansion World, 03 Future World; all initially **planned**; World 01 must be separately authorized to open |
| 7 | Choose home airport | An explicitly approved game-airport roster **for that world**; research-only/source-qualified airports do not count |
| 8 | Create airline | One trusted atomic PostgreSQL transaction, one airline per player/world, precisely **$5,000,000** starting balance and **zero aircraft** |
| 9 | Trial or subscription | Proposed **168-hour account-wide trial** begins only after first authorized airline activation and never restarts in another world |
| 10 | Enter management game | **Separate server-side session, entitlement and world-admission checks**, not client-side onboarding state |

The onboarding state classifier emits `sign_in`, `verify_email`, `account_restricted`, `status_unavailable`, `legal_unavailable`, `accept_legal`, `subscription_required`, `worlds_unavailable`, `select_world`, `world_unavailable`, `airports_unavailable`, `select_home_airport`, `ready_to_request_airline`, or `airline_ready`. Its clock must be supplied by the trusted server; absent/invalid clock returns `status_unavailable`. It is not an access-control token and never issues funds or entitlements.

## Protected consent endpoint (prepared, NOT DEPLOYED)

`POST /api/v1/legal/consents`, with JSON fields `termsVersion`, `privacyVersion`, `acceptTerms: true`, `acceptPrivacy: true`. Requests must use an approved exact `Origin`, `application/json`, and a bearer Auth token. The body is limited to **2,048 bytes** after the request body is received; a real hosting adapter must impose the same limit on the *incoming stream* before buffering. Cookies and client-supplied `playerId` are not accepted as identity.

A valid response is HTTP 200 containing only the versions and original `acceptedAt` timestamp; a repeated acceptance does not reset its timestamp. A stale legal version returns 409; bad/missing Auth 401; disallowed Origin 403; unsupported media type 415; oversized body 413; disabled endpoint/provider problems 503. No real email, user ID, Auth token, SQL error or connection detail is returned.

**Security limitations before deployment:** no live route, listener or legal document content; no request rate limiting, TLS/server hosting configuration, verified Auth credentials, secret store, audit logs, legal retention policy or independent security testing. The legal service's database SQL is a **draft**, and neither SQL draft has been installed in the existing Supabase project.

## Verification

- The two newly committed test suites were independently fetched from GitHub. **19 of 19 committed test bodies passed** in a V8 JavaScript compatibility harness, with a Node Buffer UTF-8 byteLength equivalent and mocked Auth/DB backends. This is **not** a full native `npm test` or real PostgreSQL run.
- Both suites were verified present in the committed `website/package.json` `npm test` command.
- These tests validate only logic and guards; they do not establish database concurrency safety, live email delivery, actual browser origin handling or completed legal acceptance in production.
- **Outstanding gate:** Run the existing manual-only disposable PostgreSQL 17 workflow from GitHub Actions. No successful run has been observed in this session:
  https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml

## Launch requirements that remain

1. Resolve domain ownership, HTTPS/DNS, verified SMTP, SPF/DKIM/DMARC, legal text and versioned terms.
2. Confirm production Supabase Auth email confirmation, rate limits, anti-abuse and server-side signup gate.
3. Replace external ESM Supabase SDK with vetted pinned bundled dependency and committed lockfile.
4. Pass full native Node + disposable PostgreSQL tests, including **simultaneous airline creation** and row-level security.
5. Build and securely host the trusted Auth/consent/onboarding API with logged, rate-limited verification.
6. Activate actual airport roster and World 01 only after operator approval; keep Worlds 02/03 closed.
7. Approve the account-wide trial and payment model separately.

**Production unchanged:** Airlinerra's `public.airlinerra_site_status` remains prelaunch, `airlinerra.airport_world_activation` empty, and no `airlinerra_game` account tables applied. Trello was not modified.
