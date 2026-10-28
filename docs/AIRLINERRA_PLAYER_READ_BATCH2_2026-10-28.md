# Airlinerra Batch 2 — Protected, read-only game-data connection (28 October 2026)

### Delivered source
- `server/player-read-service.mjs`: server-only POST routes `/api/v1/player/overview` and `/api/v1/player/airports`. Both deny by default; when integrated into an authorized runtime, they verify Supabase Auth tokens server-side and use a private PostgreSQL pool. Read-only queries access precisely the three game world rows, approved World 1 airport roster, country counts, and only airlines owned by the verified player.
- `website/player-read-client.mjs`: same-origin, Bearer-token read adapter. Disabled by default until a securely deployed runtime exists. No Supabase private-schema grants or browser secrets.
- `website/player-app.mjs`: dynamic worlds, country filters, bounded airport search and player-owned airline cash placeholders become populated *only* when an approved read API is enabled and provides verified results.
- `website/invited-tester-auth.mjs`: read-only token retrieval after fresh getUser() identity validation and same-session owner checks.
- `tests/test_player_read_api.mjs`: default denial, verified ownership, bounded SQL and airport filtering, invalid-input rejection and browser token checks.

### Current live limits
**Not yet deployed as an active API.** Static site has no private PostgreSQL runtime; no secrets have been added to GitHub or Netlify. The client flag `PLAYER_READ_API_ENABLED=false` remains closed. As a result, locally the player pages still clearly indicate the game database is not connected. No real airport list is exposed yet and no airline is created.

To switch on read-only functionality, a separately checked serverless Function with secret configuration, rate limits, deploy identity checks and authorized private DB role must be deployed. Verify hosted Auth owner access and exact same-origin routing, then flip the client read API gate in a separate approved release. Do not enable signup, payments, legal acceptance or world gameplay as part of that step.

### Site navigation
The homepage now shows both **Sign in** and **Register**. Register leads to an informational page explaining invitation-only prelaunch; it does not create public accounts.
