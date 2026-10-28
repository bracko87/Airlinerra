# Airlinerra — Local game dashboard journey

## Why localhost previously could not sign in
The built-site preview at localhost:5188 deliberately disabled hosted Supabase Auth. On-screen email and password were editable for visual review but submits did not authenticate, so there was no page transition.

## Current behaviour
- Open `http://localhost:5188/account.html?screen=sign-in`. The primary action reads **Open local dashboard demo**. No password is required; do not enter any production password.
- Click it: the browser writes only a fixed, per-tab demo marker to `sessionStorage`, clears any typed credentials, and opens `/player.html#overview`.
- The player page requires that marker on the loopback port. It shows the real player UI and its ten page views with **Local Demo Manager**, using a reserved `.test` email. No actual Supabase identity is verified or created.
- **Sign out** clears the marker and returns to sign-in. Direct navigation to `/player.html` after logout also returns to sign-in.
- No network call or database read is made from the local demo. No production airline/game changes.
- The official-domain authentication and player access guards remain separate, unchanged and required.

## Read-only database step
The `server/player-read-service.mjs` and `website/player-read-client.mjs` contracts are already in the repository and covered by CI tests, but are not live; `PLAYER_READ_API_ENABLED=false`. A real local read requires a trusted local API runtime, verified Supabase Auth token and a separate read-only PostgreSQL connection. Do not confuse this demo with a real DB integration test. Keep the creation, billing and world release gates disabled.

## Workflow
GitHub `main` -> local `npm run preview` at port 5188 -> owner's manual Netlify deployment only after all required features are reviewed. No Netlify changes or automatic deploy.
