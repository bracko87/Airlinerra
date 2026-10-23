# Airlinerra prelaunch website (Netlify)

Deploy repository `bracko87/Airlinerra`, branch `main` on Netlify. Root `netlify.toml` sets publish directory `website` with no build command. No secret environment variables needed for this public RLS-protected status test.

Open `/health` for frontend hosting verification, then `/` for the database connectivity card. The page uses Supabase project's public publishable key to read ONLY `public.airlinerra_site_status`; the airport research tables are in a nonexposed private schema with RLS enabled. Never put service-role keys or passwords into this folder.

**Important:** This is a deployable, lightweight prelaunch test built for the integration milestone. The complete original approved `Airlinerra-Website.zip` and its 5 large artwork assets were recovered from the user's ChatGPT library but have NOT yet been uploaded into this repository. Do not treat this integration test as an exact visual copy of that earlier website.

It does not contain airline login, game play, real route simulation, premium subscriptions or real-money payment flows.
