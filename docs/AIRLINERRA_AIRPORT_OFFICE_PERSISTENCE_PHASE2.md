# Airlinerra Airport Operations — Phase 2: Private office persistence

Status: **implemented as a draft backend, not migrated or deployed**, 29 October 2026.
PR: #2, `feature/airport-office-persistence-foundation` targeting `main` (draft review).

## What this branch adds

- `airlinerra_game.airport_offices`: one additional office per airline/airport, keyed to the correct game world, with two roles (`hub` and `station`), **draft-only** status and timestamps. Registered headquarters stays in `airlines.home_airport_key`, not in this new table.
- Composite world/airline and world/approved-airport foreign keys, uniqueness, HQ exclusion trigger, RLS enabled, no public or authenticated direct table permissions.
- `server/airport-office-persistence.mjs`: private server-side `list/save/remove` service. Uses hosted Auth `getUser` verification, derives the airline from the verified owner and world, validates approved airports, serializes draft writes against the airline row, and provides idempotent saves and draft-only deletions.
- `server/airport-office-domain.mjs`: pure role/world/duplicate rules and inactive activation preconditions.
- Unit tests for owner isolation, invalid worlds, duplicate types, idempotency, HQ protection, RLS migration contract, quote/staff requirements.
- Focused non-deploying CI workflow with a disposable PostgreSQL 17 database. No Supabase project or production credentials in CI.

## Deliberately not done

- No production Supabase migration, Edge Function, new API endpoint, frontend switch, or Netlify release.
- No activated hubs/stations, employee hiring or salary payment, airport slot reservations, ledger movements or recurring fees. The migration forbids every status other than `draft`.
- No fake airport-category pricing, data enrichments or traffic statistics.
- Current browser UI still stores proposals in sessionStorage; it **does not** read/write this server table yet. There is no automatic browser-to-server migration.
- Do not set a feature gate to true until an authenticated HTTP route and deployed schema have been validated against the owner’s private pilot.

## Follow-on implementation order

1. Review migration in disposable PostgreSQL; resolve unrelated pre-existing repository CI failures separately.
2. Add a narrow authenticated office HTTP adapter to the canonical private API, with strict origins, payload limits, fail-closed feature flag, owner checks and error redaction.
3. Wire the existing hubs/stations UI to authenticated list/save/remove only after the database and API are deployed; keep local drafts visually distinct until safely migrated with explicit consent.
4. Add official airport data, six-category-dependent fee quotations, real assigned employees and a single atomic ledger activation transaction. Only then extend status beyond `draft`.
5. Add multi-airline airport movement/flight-board read models; never infer data from local proposals.

## Security acceptance

- Every read/write is scoped to verified `auth.getUser(accessToken)` user ID, airline and world.
- No client-selected `airline_id` is accepted.
- Additional HQ office prevented at both app and DB layers.
- Minimum one active assigned station employee before activation, with actual employee tables pending.
- New service constructor defaults `enabled=false`; no public listener is registered.
- Published money amounts must come from authoritative server quotes and be committed atomically with the ledger, never from draft UI fields.
