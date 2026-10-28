# Airlinerra — Player Application Batch 1 (28 October 2026)

**Purpose:** Build the actual player navigation and onboarding-ready application before any airline is created. The source of truth is GitHub `main`; owner manually reviews localhost and triggers Netlify deployment.

## Implemented
- `/player.html`: verified invitation-only player interface with **Overview, Airline setup, Manager profile, Game worlds, Airports, Fleet, Routes, Schedule, Finances and Settings**.
- `/tester.html` has a new **Preview player application** link.
- Production player pages use the same Supabase Auth provider security checks and fresh verified identity as the existing invitation dashboard. Unauthenticated visitors are sent to `/account.html?screen=sign-in`. Localhost `http://localhost:5188/player.html` is explicitly visual only.
- Navigation uses safe allowlisted fragments (`#overview`, `#onboarding` etc.), which never authorize data access.
- The manager profile reads the verified Auth email and optional display-only profile name / account creation date. No profile update or database write occurs.
- World names are visibly prelaunch planning labels, **not a claim of live directory synchronization**. Airports are intentionally not embedded or exposed; the private API is not deployed.
- Every game activity is explicitly unavailable. No fake fleet, route, finance or airline records are shown. No public registration, world activation, legal acceptance, trial or $5m ledger credit occurs.
- Hosted API for account and airport catalogs is still disabled. Next batch must connect and test authenticated read-only world/airport/profile data through the private server, then authorize actual player onboarding separately after reviewed legal documents and backend gates.

## Acceptance and release
1. GitHub CI must pass `test_player_app_prelaunch.mjs`, existing private invite tests and production static bundle tests.
2. Owner pulls main and runs `cd website && npm run preview` (port 5188). Review `/player.html`, sidebar navigation, responsive layout, setup, world and airport states.
3. After manual Netlify deployment, owner opens `/tester.html` while signed in, selects **Preview player application**, and checks verified email and sign-out.
4. Do not mark **database-connected gameplay** or **airline onboarding** complete; these remain Batch 2/3.

Security note: Static HTML cannot protect itself. All account information is hidden until verified client-side; any private future game data needs independent **server-side** ownership checks and no direct browser grants to `airlinerra_game`.

## 28 October update — horizontal grouped navigation
- Replaces the sidebar with a full-width horizontal, scrollable-on-mobile section bar.
- Five permanent groups: Manager (Overview, Airline setup, Profile); Operations (Game worlds, Airports, Routes, Schedule); Fleet (Aircraft); Finance (Finances); Account (Settings).
- Public website, tester account, verified email/local demo identity and sign-out remain in the top header.
- The existing hash allowlist, active view state, localhost sign-in demo and production Auth guard remain unchanged.
- Mobile navigation scrolls horizontally rather than hiding pages in a drawer. No server or Netlify changes.
