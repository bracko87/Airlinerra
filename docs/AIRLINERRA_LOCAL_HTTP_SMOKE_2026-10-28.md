# Local preview HTTP acceptance checks

CI runs `node tests/test_local_preview_http.mjs` after the exact normal website build. It starts the 5188 loopback server, fetches the built player page, queries the real-world approved-airport snapshot over same-origin HTTP (3 worlds / 229 countries / 3,140 airports), searches Berlin, rejects forged Origin / malformed filters, and asserts `dev-data` is not copied to production output.

This verifies the localhost preview route only. No real Supabase Auth session, production database connection, airline creation, payments or Netlify deploy is involved.
