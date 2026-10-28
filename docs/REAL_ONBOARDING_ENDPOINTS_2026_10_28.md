# Real Airlinerra onboarding endpoints

The compiled production website now contains one actual protected player setup form. For local testing it uses real email-confirmed hosted Supabase Auth and the following same-origin routes, all backed by the private PostgreSQL pool:

- POST /api/v1/onboarding/context — verified user, released world(s), 100% approved airport records, approved Terms/Privacy versions and URLs.
- POST /api/v1/legal/consents — server-verified user, exact published document versions, idempotent consent insert.
- POST /api/v1/airlines — server-verified user, approved world/airport and legal consent; atomic create_airline_once RPC writes real airline, $5m starting credit and trial where eligible.
- POST /api/v1/player/overview — independently reads the newly created airline ledger balance.

All endpoints fail closed without a private PostgreSQL connection, approved published legal policy, and registration-open world. Game flights remain closed; no fake airline is created. Backend is wired for the localhost server, not deployed to Netlify. The legal policy's contents require the operator's actual business contact and approval; **do not populate approved_at with an invented approval**.
