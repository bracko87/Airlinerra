# Real registration preflight (October 28, 2026)

GET /api/v1/registration/readiness is served by the same local trusted PostgreSQL runtime as the real airline API. It returns **only** the boolean readiness of the actual game release prerequisites (approved published legal policy, explicit platform gate, World 1 registration-open state, and at least one approved airport). The route is read-only, disallows credentials in its response, and fails with 503 without the private DB connection. Real Supabase Auth signup remains a separate provider check.

The /register.html form now refuses to offer genuine signup unless this private release preflight, the hosted email-confirmation provider, and approved legal HTML pages **all** pass. This avoids creating accounts that can never create airlines.

No legal approval, world opening, signup enablement, money, airline, Netlify deployment or new account has been performed by this change.
