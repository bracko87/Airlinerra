# Airlinerra restored website (October 23, 2026)

This is the complete October 19 original website design, NOT the minimal
Netlify prelaunch placeholder. It includes the original assets and interactive
previews, plus the RLS-protected public Supabase status check and `/health.html`.

## Update the existing GitHub checkout on Windows

1. Unzip this archive into:
   `C:\Users\Aleks\Desktop\Airlinerra\github\website`
   Choose to replace existing files when prompted.
2. From `C:\Users\Aleks\Desktop\Airlinerra\github` run:
   `git add website`
   `git commit -m "Restore original Airlinerra homepage and preserve status check"`
   `git push origin main`
3. Keep the local http-server running on port 800 and hard refresh with Ctrl+F5.

The root `netlify.toml` already sets `publish = "website"` and should remain
unchanged. This public site is *prelaunch* and has no account creation, live
gameplay, payments or real subscriptions.

The original design uses self-hosted artwork (not external stock assets).
The frontend Supabase key is publishable, not a service role secret.
