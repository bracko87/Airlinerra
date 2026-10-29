# Airlinerra - local World 1 setup review

This is a read-only **real Supabase** airport/manager preview by default. It uses
the actual approved World 1 catalog and the existing verified owner account.
No fake airports, fake users, database passwords, Docker, Netlify deployments,
or extra Netlify usage are involved.

## Windows / PowerShell

Open a *new* terminal, leaving other running services alone:

```powershell
cd PATH\TO\Airlinerra
git pull origin main
cd website
npm ci
npm run preview
```

Open `http://localhost:5188/account.html?screen=sign-in` in a browser.
Sign in with the **existing verified Airlinerra account**. Sessions on
`airlinerra.com` and `localhost` are different, so sign in locally again.
After sign-in, open `http://localhost:5188/player.html#overview`.
Existing airline owners will see their saved airline, home airport and cash.
Select World 1, Kosovo or Serbia, and a home airport. The real airport
category appears in the dropdown; the right panel shows saved runway
metadata, while passenger/cargo demand remains **Data pending** until
an approved demand model populates those metrics.

The local `Create my airline` button stays disabled. Logo selection previews
the image locally, and no logo is uploaded or airline created in this mode.
The command starts a loopback-only server on port 5188 and proxies only
three authenticated read routes to the live Supabase game API.
It rejects `/api/v1/airlines` and `/api/v1/legal/consents`.

Both `npm run preview` and `npm run preview:setup` use the same authenticated,
read-only production Supabase Edge API. No local database URL is required.
Only explicit developer `--local-db` mode can use a private PostgreSQL connection.
Never put credentials in GitHub or the browser.

## Safety and limitations

- Existing Supabase account and internet connectivity are required.
- The live private database is read **only**. This is not an offline data snapshot.
- The airport catalog includes Aleksandrovo Airport (LYAL), a **fictional**
  game airport with a proposed Local classification. It is never represented
  as a real airport.
- Kosovo (XK) is an explicit selectable **game** country and Pristina belongs
  to it. This is not a UN-membership assertion.
- No public world activation, Netlify deployment, airline creation,
  payments or flight simulation is triggered.

## Existing airline not shown?

1. Stop the previous Airlinerra terminal preview server with Ctrl+C.
2. Pull GitHub main and run `npm run preview` again. Refreshing the browser
   alone does not update the local server code.
3. The terminal must say `API mode: production Supabase game data, authenticated READ ONLY`.
4. Sign in with the existing verified account, open
   `http://localhost:5188/player.html#overview` and select **Retry connection**
   if data is unavailable. Do not register or create another airline.
