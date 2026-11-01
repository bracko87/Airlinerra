# Airlinerra — one prelaunch build

All normal Airlinerra development commands use **one assembled application**:
the homepage, invitation-only Supabase sign-in/password recovery, private player
dashboard, airline setup screens, and game UI. There is no separate player app
to install or second game to operate.

## Windows CMD: run the same site that is deployed

From your Airlinerra GitHub clone:

```cmd
git pull origin main
cd website
npm run dev
```

- Open **http://localhost:5188/** for the homepage.
- Open **http://localhost:5188/account.html?screen=sign-in** to sign in.
- `npm run dev`, `npm start` and `npm run preview` all run the **same**
  `npm run build && node dev-scripts/dev.mjs --built` pipeline.
- `npm run build` alone creates the static deployment output in
  **repository-root `dist/`** without starting a server.
- Keep CMD open while testing. Press **Ctrl+C** to stop. Restart `npm run dev`
  after changing source files; the static built copy must be regenerated.
- **Port 5188 is the only normal local player-facing development URL.**
  The former source-only preview on 5187 is no longer launched by
  `npm run dev` or `npm start`.
- An advanced, explicitly named `npm run dev:source` remains for developer-only
  inspection of raw source files; it is not the deployable game and its old
  disabled account mockup is NOT a sign-in page.

## Aircraft Library (private Settings menu)

The prelaunch player application now includes **Settings → Aircraft Library**
directly after **Airports**. This is a read-only search/filter/details page for
the **188 configurations across 69 aircraft families** held in the Airlinerra
Supabase catalog. It covers passenger, cargo and combi variants; all fuel
capacities are shown in kilograms, distances in km or m, and aircraft technical
figures retain research / fictional-game labels. Conditional float-runway
values are shown ONLY with the explicit amphibious-equipment warning; no
flight or purchase authorization is implied.

- Browser entry: `http://localhost:5188/player.html#aircraft-library`
  (requires confirmed private account).
- Source page: `website/private-player-app.html`.
- UI module/styles: `website/aircraft-library.mjs` /
  `website/aircraft-library.css`.
- Authenticated read route: `/api/v1/player/aircraft-library`.
- Dedicated Supabase Edge function: `airlinerra-aircraft-library`, deployed
  in project `hwllkabgzaynalahvkpz`. It independently verifies the
  confirmed user session and reads the DB; neither Netlify nor the browser
  receives private database credentials.
- Netlify `main` commits are **not deployed automatically**: manually upload
  the latest built `dist/` content when you want the hosted website updated.
- Run `npm test` for the aircraft-library regression tests; `npm run dev`
  rebuilds and opens the same player-facing application.

The database provides **100% conditional GAME DATA COVERAGE**, not 100%
manufacturer-verified specifications. The broader factual checklist is still
182/188. The library cannot buy/lease aircraft or dispatch flights.

## What goes to Netlify

The root `netlify.toml` builds from `website/` with `npm run build`
and publishes **`../dist`**. This is the **same** `dist/` content served
by the unified local command. The build overlay intentionally replaces the
obsolete source `account.html` mockup with the invited-user sign-in page
and includes `player.html` and `tester.html`.

If manually uploading a site to Netlify, upload **the contents of the built
`dist/` directory**, not the raw `website/` directory. Uploading raw
source would bring back the disabled mockup. GitHub `main` changes do not
automatically change a manually published Netlify site: build and upload
the latest `dist/` when you want to update the hosted prelaunch version.

The local built preview can proxy authenticated **read-only** game data through
the existing Supabase Edge API; it does not itself activate airline creation
or live flight operations. The Netlify host must have its supported game API
deployed/configured separately for authenticated hosted operations.

## Private prelaunch, not public game launch

- Public Supabase signup and commercial player registration remain controlled
  by independent hosted provider, database, legal and onboarding gates.
- Private sign-in requires an invited/authorized, email-confirmed account and
  working Supabase Auth. The browser build contains only the public publishable
  key, never a service-role secret.
- World 1 commercial operations, payments, and real flights are **not** enabled
  simply because the sign-in page or dashboard is visible.
- A site deployed to a public domain can still be visited by anyone; **invite-only
  sign-in is access control for the player area, not password protection for
  the public homepage**. An entirely private website would require a separate
  hosting-level access control.
- The original airport research and server credentials are not included
  in the published static bundle.

## Validation

```cmd
cd website
npm test
npm run build
npm run dev
```

Build/host tests are in `tests/test_invited_tester_manual_bundle.mjs`.
For the owner, the **single normal command is `npm run dev`** and the
**single local address begins with `http://localhost:5188/`**.
