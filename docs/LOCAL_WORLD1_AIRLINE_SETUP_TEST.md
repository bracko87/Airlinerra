# Airlinerra - local World 1 setup review

This is an opt-in, read-only **real Supabase** airport/manager preview. It uses
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
npm run preview:setup
```

Open `http://localhost:5188/account.html?screen=sign-in` in a browser.
Sign in with the **existing verified Airlinerra account**. Sessions on
`airlinerra.com` and `localhost` are different, so sign in locally again.
After sign-in, open `http://localhost:5188/player.html#onboarding`.
Select World 1, Kosovo or Serbia, and a home airport. The real airport
category appears in the dropdown; the right panel shows saved runway
metadata, while passenger/cargo demand remains **Data pending** until
an approved demand model populates those metrics.

The local `Create my airline` button stays disabled. Logo selection previews
the image locally, and no logo is uploaded or airline created in this mode.
The command starts a loopback-only server on port 5188 and proxies only
three authenticated read routes to the live Supabase game API.
It rejects `/api/v1/airlines` and `/api/v1/legal/consents`.

The separate normal `npm run preview` command remains unchanged; its
backend requires private PostgreSQL configuration. Do not put credentials
in GitHub or the browser. If port 5188 is occupied, first check which
process owns it instead of stopping unrelated work.

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
