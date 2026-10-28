# Supabase Edge API deployment source

This file is the future source of truth for the Edge Function deployed as
`airlinerra-game` in the existing Supabase project. The function deployment
also includes the canonical `server/*.mjs` imports and the pinned, **public**
Supabase publishable settings module.

The active function was deployed through the connected Supabase management
tool on 2026-10-28 and its readiness endpoint responded HTTP 200 with the
real World 1 reservation result. Updating GitHub source does NOT automatically
deploy an Edge Function; do not overwrite the live version without running
edge/integration checks.

Unlike the old Netlify backend, the current production API uses Supabase's
server-side, built-in `SUPABASE_DB_URL`, so Netlify requires no private DB
URL, no service-role key, and no API enablement flag. Netlify's API Function
is only a fixed-origin, no-secret proxy to this endpoint.
