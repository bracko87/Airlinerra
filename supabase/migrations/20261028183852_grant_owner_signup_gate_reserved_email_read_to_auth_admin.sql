-- Airlinerra owner-only self-service signup: allow the Supabase Auth hook
-- to read the preapproved email reservation table. The hook runs as
-- supabase_auth_admin (SECURITY INVOKER) and already has EXECUTE permission.
--
-- The existing RLS SELECT policy owner_signup_hook_read_reservations is
-- restricted to supabase_auth_admin. Do not grant SELECT to anon,
-- authenticated, or PUBLIC. This DOES NOT enable Auth signup or activate
-- the hook in the Supabase Dashboard.
GRANT SELECT ON TABLE airlinerra_game.owner_premium_email_reservations
TO supabase_auth_admin;
