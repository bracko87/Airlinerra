# Airlinerra — Account Foundation Batch 9: Trusted Legal Consent

**Date:** 2026-10-26  
**Development branch:** `main`, per `AGENTS.md`  
**Release state:** Prelaunch. The consent service is deliberately disabled and not connected to an HTTP endpoint. No SQL draft was applied to Airlinerra's live Supabase project. Trello remains owner-managed.

## Delivered

1. `server/legal-consent-service.mjs` implements a **trusted backend-only** `acceptPublishedPolicy` method. Its default `enabled=false` switch prevents any database or Auth calls.
2. The trusted service uses `verifiedPlayerId` from `server/airline-activation.mjs` (now exported for server-module reuse), deriving identity from a fresh Supabase Auth server `getUser(token)` result—not user-provided `playerId`, email, or editable JWT metadata.
3. The request must explicitly accept both published Terms and Privacy Policy and supply both displayed document version identifiers. No extra request keys are accepted. Version IDs have a restricted 1–50-character format.
4. Within one PostgreSQL transaction, the service locks the current published legal policy row using `FOR SHARE`, checks its approval and exact versions, and inserts the consent only if `auth.users` is verified, non-anonymous, not deleted and not currently banned.
5. The consent table's existing composite primary key `(player_id,terms_version,privacy_version)` makes acceptance idempotent. Repeated acceptance preserves the original `accepted_at`; a race/duplicate may read an existing record, with the user-status criteria checked again. No client role has privileges to write the private consent table.
6. `tests/test_legal_consent.mjs` adds **10** committed test cases for hard-off behavior, explicit acceptance, spoofed identity rejection, valid recording, idempotent replay, unpublished/revised policies, revoked accounts, transaction rollback and parameterized SQL. The test runner in `website/package.json` now includes this suite.
7. `tests/sql/legal_consent_isolated.sql` adds **real database assertions**, to be run only against throwaway PostgreSQL: permission isolation, synthetic accepted/unaccepted accounts, no acceptance timestamp reset, and old-consent invalidation when a published terms version changes.
8. The manual-only `.github/workflows/airlinerra-postgres-isolated.yml` now runs those consent assertions after loading synthetic fixtures and before the airline-activation rejection and concurrency tests.

## Current legal and onboarding sequencing

```text
Account created → Email verified via Supabase Auth
     ↓
Player sees the exact CURRENT published Terms + Privacy Policy
     ↓
Explicit accept both documents
     ↓
Trusted consent endpoint validates server Auth, current published versions
     ↓
Private append-only-style consent record (new version => new record)
     ↓
Choose an authorized, open game world + approved home airport
     ↓
Trusted create_airline_once transaction checks SAME current policy/consent,
activates one airline with $5m and starts at most one 168-hour account trial
```

There is still no approved legal document text, consent HTTP endpoint or real playable-world activation; this is a **prelaunch implementation contract** only. Legal texts, exact version IDs, storage-retention policy, and accessibility must be finalized separately.

## Verification

- The **10 actual committed Node test bodies** passed in an isolated V8 compatibility harness with mock PostgreSQL and Auth dependencies. This is not a native full-checkout `npm test` or real PostgreSQL run.
- The extra SQL integration assertions and workflow wiring were committed; **not executed against PostgreSQL yet**.
- The environment cannot currently execute a disposable PG instance or dispatch a new workflow run using the connected GitHub actions. The trusted policy service is not wired to the public website.
- Latest production read-only checks must continue showing **zero game tables and zero activated gameplay airports**, with `game_state=prelaunch`. Never use the airport research database as the throwaway integration test database.

## Manual test gate

**Run the existing manual-only workflow** on GitHub `main`:

https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml

Do not migrate schema, enable Auth signup, open World 01, publish a legal policy, or authorize payments until the real PostgreSQL tests pass and the owner explicitly approves the respective release steps. The API handler for recording legal acceptance, rate limiting, audited Supabase Auth session checks, actual domain/SMTP and subscription verification remain future implementation items.
