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
