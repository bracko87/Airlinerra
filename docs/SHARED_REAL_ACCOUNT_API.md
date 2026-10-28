# Airlinerra single canonical real-game API (no second test game)

\`server/canonical-game-api.mjs\` composes the same private Auth verification, approved-world/airport context, versioned legal consent, idempotent atomic airline creation and owner-scoped reads for both localhost and the eventual official host. Exact pinned origins: http://localhost:5188 and https://airlinerra.com. No mock identities or data.

Local preview constructs this module with a private PostgreSQL pool and the real Supabase Auth verifier. Future official hosting must instantiate it only in a secret-bearing trusted server-side runtime, with the same private PostgreSQL pool and Auth verifier; serverless deployment is not done by merely committing this module.

This code is NOT a production endpoint until explicitly deployed through the owner's final manual release process. No release gate, World 1 status, Auth signup setting, database money or legal approval is changed by this commit. The legal docs and secure host integration remain launch requirements.
