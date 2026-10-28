# Airlinerra — private invited-tester dashboard (28 October 2026)

This change adds an **account-only tester destination** at `/tester.html` after a successful verified invited-account login. It does not enable gameplay.

## Approved workflow

- The existing GitHub `main` is the source of truth.
- Owner pulls to localhost and tests `http://localhost:5188/tester.html` with `cd website && npm ci && npm run preview`.
- Localhost is **visual-only**. It never initializes hosted Supabase Auth.
- Owner alone performs the normal **manual Netlify deployment**, with no ZIP, Netlify configuration changes, or auto-deploy.
- The public homepage at `/` stays unchanged.

## Guardrails

- `/tester.html` ships as static HTML, so the HTML itself is not an access-controlled server resource. The dashboard hides all account details until it verifies hosted signup/anonymous/confirmation settings, initializes the pinned publishable Supabase Auth client, and calls `getUser()` to verify a confirmed, non-anonymous identity. Unauthenticated users go to `/account.html?screen=sign-in`. Provider failures show a restricted error state.
- The only personal attribute rendered is the authenticated user's own verified email, inserted with `textContent`, never unsanitized HTML.
- Signing out invalidates the client session and returns to sign-in. The account recovery link uses the existing recovery flow.
- No public signup, new Auth provider keys, game actions, new database tables, RLS changes, world access, airline creation, subscription activation, or payments are introduced.
- Server-side authorization is still required before any future real game or privileged API action is added.

## Release acceptance

After main CI passes, owner previews sign-in `/account.html` and `/tester.html` locally, manually deploys main, then checks: invited user login routes to dashboard; direct dashboard URL while signed out routes to sign-in; sign-out clears session; password recovery still succeeds; all gameplay remains closed.
