# Airlinerra — Account foundation batch 2 (2026-10-26)

**Code branch:** `main` only. **Release:** prelaunch; NOT production authentication or playable game.  
**Trello board (owner managed):** https://trello.com/b/ijD9YgZb/airlinerra

## What is committed

- `website/auth-client.mjs` holds the browser adapter for the **official Supabase JavaScript client v2.118.0**, version-pinned for this development evaluation. The runtime import is an external ESM URL and is NOT used in prelaunch because `PUBLIC_AUTH_ENABLED=false`; before production launch it must be replaced with a secure bundled dependency and a verified committed npm lockfile. No CDN script is requested from the preview.
- `website/auth-service.mjs` implements registration, sign-in, recovery request, verification callback, password change and logout through the documented Supabase Auth API. It is injectable and can be tested with a fake Auth client; it cannot reach the provider while the public gate remains closed.
- `website/account.js` handles forms when the separately approved release gate opens; until then all forms remain disabled. Auth callback parameters are removed from browser history immediately. The reset-password form is only enabled after a successful recovery verification.
- `website/account.html` and `website/account.css` continue to show a clearly marked prelaunch preview.
- `tests/test_account_foundation.mjs`: Node's built-in test runner; no network/npm dependencies needed.
- `docs/sql/airlinerra_game_identity_schema_prelaunch.sql`: **review-only, not applied** draft isolated game schema. Owner approval and independent SQL integration tests required before migration.

## Explicitly blocked on launch gates

1. **Choose and own a domain**, complete trusted DNS and HTTPS.
2. Configure **verified transactional SMTP**, incoming support mailbox/aliases, SPF/DKIM/DMARC; email confirmations must be delivered before signup is open.
3. Confirm the Supabase Auth **server-side** `Allow new users to sign up` control is disabled before testing and that `Confirm Email` is ON. A JavaScript flag on the static website is NOT a server-side access control. Disable anonymous signups, review rate limits and CAPTCHA.
4. Configure the Auth Site URL and allowlist only the exact deployed auth callback URL plus `http://localhost:5187/account.html` for authorized local testing (consider separating local and production Supabase projects). There is currently NO production domain allowlist.
5. Email templates: ensure signup confirms with either a **PKCE code** redirect to `?screen=verify` or a **token_hash/type=email** callback. Password recovery must redirect to `?screen=reset` and use PKCE code or token_hash/type=recovery. Default templates/implicit URL fragments MUST NOT be mixed with this explicit PKCE callback adapter. Test real email clients and expired/replayed links; beware prefetching of one-time links.
6. Review legal terms, privacy policy and actual user consent recordkeeping. Display-name user metadata is for presentation only, never authorization. For production use server-validated terms version/consent.
7. Apply the DB schema only after review, using the Supabase CLI migration workflow (the CLI was not available in this working session). The SQL draft is intentionally NOT a migration history entry. It does not alter `airlinerra.*` airport research tables.
8. Add a server-side, idempotent airline-create transaction and a curated approved airport roster. Do not rely on client-selected `world_id`, `airline_id`, trial start or cash balance. No table permits anonymous or authenticated users to create airlines or start trial clocks.
9. Keep Worlds 01–03 planned; later **separately approve** World 01 opening. Account-wide seven-day trial should start only at the first actual airline activation, if that policy is accepted.
10. When changing `PUBLIC_AUTH_ENABLED` in a reviewed release, replace CDN with vetted package bundle, exact origin allowlist and operator-reviewed auth flags, run the full test matrix and verify production deployment remains gated.

## Local verification

From the Airlinerra repository checkout on `main`:

```bash
cd website
npm test
npm run build
npm run dev
```

Visit `http://localhost:5187/account.html`. Expected outcome: disabled forms; no actual identity session, new airline, confirmation email or transaction. `npm test` exercises mocked service operations and callback validation while the published frontend remains hard-off.

A manual-only Actions workflow `airlinerra-account-foundation.yml` is also provided. No GitHub Actions success has been claimed without an actual green run.

## Security boundaries

The `airlinerra_game` schema is private; no Data API privileges for anonymous/authenticated users. The only public reads in the SQL draft are a non-sensitive world directory. Players can insert/read/update only their own profile, with RLS `auth.uid()` checks; private entitlement, membership, airline and finance tables have RLS enabled without client policies, and startup funds are only allowed via a future trusted server transaction. Anonymous users should remain disabled in Supabase Auth. `auth.users` and session tokens stay with Supabase managed auth.

No private credentials, SMTP secrets, service-role keys or customer records belong in the repository. The existing publishable frontend key is public by design and confers no administrative privileges.
