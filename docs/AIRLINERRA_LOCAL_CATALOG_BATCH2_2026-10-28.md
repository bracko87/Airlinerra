# Batch 2 — localhost approved-airport catalog and read integration

- 2026-10-28 operator-approved snapshot: 3,140 World 1 airports, 229 countries, and 3 named world records.
- Snapshot lives in `website/dev-data/world1-approved-airports-2026-10-28.json`, deliberately **not copied into production `dist/`**.
- `npm run preview` at localhost:5188 exposes only two local loopback same-origin, read-only endpoints. POST /__local_player__/overview and /__local_player__/airports; filters are bounded, no writes are accepted, no Supabase credentials required.
- Sign in through local demo first; World Selection, country filters, airport search and home-airport options now show real database-approved source records in a **dated snapshot**.
- This is **not** a live database connection. To pull updated airport approvals, a new snapshot must be verified and committed. Live Supabase access still requires a secure backend and verified Auth, and stays disabled on production.
- All three world registrations, real airline creation, real finances, payments and legal acceptance remain closed.
