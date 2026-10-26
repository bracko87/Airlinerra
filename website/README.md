# Airlinerra website

This is the original Airlinerra homepage design from October 19, 2026, restored to GitHub `main` with its artwork, interactive previews, and a public RLS-protected Supabase connectivity test.

## Develop on Windows

From the already cloned repository:

```cmd
cd C:\Users\Aleks\Desktop\Airlinerra\github
git pull origin main
cd website
npm run build
npm run dev
```

Then visit **http://localhost:5187/**. Airlinerra deliberately uses port **5187** so it does not conflict with Famioo on **5173**. Keep the development terminal open while testing. To stop the local server, press Ctrl+C. The port can be overridden with a `PORT` environment variable if necessary.

`npm run build` writes static deployment files into the repository-level `dist/` directory for local verification. Netlify uses the repository's **root `netlify.toml`** to publish `website/` directly, without a build command. The airport research data is not published.

The static `/health` page verifies hosting. The homepage footer checks the public `airlinerra_site_status` endpoint. It does not enable airline accounts, live gameplay, subscriptions, or payments. Never add Supabase service-role keys or other secrets to public frontend files.

## Account foundation preview (October 26, 2026)

The **prelaunch account experience** now exists at **http://localhost:5187/account.html** after `npm run dev`.
It includes previews for sign-in, registration, forgotten-password request, password reset, email confirmation and a three-world directory.

- **Public registration is NOT open**: all four forms use disabled fieldsets. There is no live Supabase Auth client, no account creation, no transactional email and no playable world enabled by this change.
- `auth-rules.mjs` contains input validation, explicitly allowed callback origins, world status and the hard-off `PUBLIC_AUTH_ENABLED` flag. This **client-side flag is not a security boundary**. Separately disable public signups through Supabase Auth's server-side configuration until SMTP, domain, callbacks, legal terms, rate controls and backend security are ready.
- `auth-service.mjs` is an injection-based contract for an official, version-pinned Supabase Auth client to be wired at a later approved gate. It requires both the caller and static gate to be enabled, so no Auth service calls are made now.
- `npm test` from `website/` runs the Node regression suite under `tests/test_account_foundation.mjs`.
- `npm run build` copies the account preview and auth modules into the static output. It does not deploy the site.
- Keep the current homepage's public seven-day-trial buttons as prelaunch notices until the owner authorizes a separate live authentication launch.
- **World 01 remains planned, not open**; Worlds 02 and 03 remain planned. No world registration, aircraft, airline balances or payments are created by account previews.
- Before activation: secure the chosen production domain; verify inbox/transactional SMTP; install a pinned `@supabase/supabase-js` dependency with lockfile; verify exact production and development redirect allowlists; implement working callback and reset UI; add RLS-backed profiles/world memberships, abuse controls and legal acceptance; test every account lifecycle; review Netlify deployment settings and get explicit launch approval.
