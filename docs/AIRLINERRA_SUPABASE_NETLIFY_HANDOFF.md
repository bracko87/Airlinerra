# Airlinerra — Supabase database and Netlify website setup (23 October 2026)

## Confirmed connection
- Dedicated existing Supabase project: **Airlinerra**, `hwllkabgzaynalahvkpz`, Frankfurt.
- Status: project healthy; airport research data imported to a private `airlinerra` PostgreSQL schema.
- GitHub airport source remains `bracko87/Airlinerra` `main`.
- Public Supabase REST endpoint for static frontend test: `public.airlinerra_site_status` with read-only anon/authenticated RLS and no public write access.
- Existing approved **Airlinerra-Website.zip** dated October 19 recovered from user file library. Site remains entirely prelaunch with marketing preview, no signup/payments/game engine.
- Netlify website target: full original source **under `website/`**, Netlify publish directory `website`; no build command.
- Netlify/GitHub OAuth connection and actual remote deployment **not yet established**.

## Database inventory (real counts confirmed)
| Table / object | Rows |
|---|---:|
| `airlinerra.airport_registry` | 8,153 |
| `airlinerra.airport_cohorts` | 8,153 (3,140 original, 3,906 expansion, 1,106 other real, 1 fictional) |
| `airlinerra.airport_game_profiles` | 7,046 provisional, zero approved final categories |
| `airlinerra.airport_codes` | Source and FAA-reported, code type preserved; no invented official IATA/ICAO |
| `airlinerra.airport_evidence` | 2,077 FAA reviewed airport rows |
| `airlinerra.airport_runway_observations` | 2,045 source-reported qualifying FAA runway observations |
| `airlinerra.airport_access_reviews` | 7,046, all non-playable |
| `airlinerra.airport_world_activation` | zero active |
| `public.airlinerra_site_status` | 1, anon readable with RLS |

### Schema and security
The migration named `airlinerra_private_research_and_public_site_check` was applied to the newly created user-owned Airlinerra project, not the unrelated Tennis Legacy or ProPeloton projects. It created 11 research tables under the non-exposed `airlinerra` schema and one public RLS-protected website test table. The private schema has no anonymous/authenticated access; a simulated anon test confirmed permission denied. Public status read as anon returned `ready / prelaunch`.

The source airport codes and game-only codes are distinct types and cannot be inadvertently confused. Stable source keys are `OURAIRPORTS:<source ID>` or `FICTIONAL:fictional:RS:LYAL`. Airport runway qualification, FAA site access, Part 139 status, commercial permission and gameplay activation remain **independent**. No airport is activated.

## Deployment handoff
The exact October 19 homepage, including original artwork and `styles.css`, has been repackaged as `Airlinerra-Netlify-Ready.zip` in the ChatGPT conversation with added:
- `site-config.js`: Supabase **publishable** API key only; never any service-role secret.
- `health.html` and `health.js`: read-only database check, no airport data exposed.
- `netlify.toml`: static host security headers.

**Required human GitHub step:** upload the ZIP's *website directory contents* into `bracko87/Airlinerra/website/`. Upload the original binary images as real image files. The GitHub API text-only file workflow did not transfer the original image bytes automatically; don't claim the homepage lives in GitHub until the upload is confirmed.

**Required human Netlify step:** Sign in to Netlify, import GitHub repo `bracko87/Airlinerra`, select production branch `main`, publish dir `website`, no build command. Then open the site homepage and `/health` and ensure it reads `Connected to Airlinerra Supabase`.

## Tests actually completed
- Database schema exists and is queryable by the admin connection.
- Eight-thousand-one-hundred-fifty-three master airport rows and 8,153 cohort links verified; LYAL protected.
- 3,140 original and 3,906 expansion membership mutually exclusive; source six tiers are provisional only.
- 2,058 matched FAA LIDs; 1,929 FAA runway-and-public-use physical passes, 148 other US holds.
- 8,152 real-airport geographic coordinates; fictional LYAL coordinates intentionally blank.
- Public site status anon SELECT succeeds; private research anon SELECT denied (expected).
- Static homepage and health page parse, JS passes `node --check`, local HTTP request returns 200 for index, health, scripts, original logo.
- Not yet verified: actual Netlify deployment, real browser cross-origin REST fetch, user account login, aircraft/game simulation, commercial approvals.

Use GitHub for controlled source code/data versioning and Supabase private schema for querying/verifying airport records. Never expose the research schema via the public API or activate airports from source flags. Additional commercial eligibility research is pending.

## Additional safety migration (same day)
- Applied `airlinerra_block_unapproved_world_airport_activation`: server-side PostgreSQL trigger rejects attempted activation without independently verified identity/runway/civilian/commercial access **and** owner approval **and** a reviewed final airport tier.
- Negative test attempted to activate unapproved source airport `OURAIRPORTS:5230`; PostgreSQL returned the expected error, and the active airport count remained **zero**.
- Supabase migration history now contains both schema/setup and activation-guard migrations. This does not implement authentication, registration, paid memberships, or simulated flights.
