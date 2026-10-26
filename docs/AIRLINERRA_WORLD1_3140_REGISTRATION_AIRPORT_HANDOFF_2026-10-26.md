# Airlinerra — World 1 airport catalog -> registration backend handoff

**Date: 26 October 2026** · **Implemented against private Supabase airport research project** `hwllkabgzaynalahvkpz` · **Repository:** `bracko87/Airlinerra` (`main`).

## Outcome

The owner-authorized first cohort of **3,140 World 1 simulation airports** now has a stable **numeric-ID read model** matching the airline-creation code's `homeAirportSourceId` / PostgreSQL `BIGINT` contract. The private view is installed and independently audited. A separate backend-only JavaScript adapter, prepared post-authentication SQL synchronization and regression tests have been committed.

| Verified checkpoint | Count / state |
| --- | ---: |
| Active first-wave simulation airports | **3,140** |
| Distinct numeric original-source IDs in private registration view | **3,140** |
| Duplicate/invalid registration IDs | **0** |
| Geography/country source codes represented | **229** |
| Game categories | **6 existing proposed tiers** |
| Other 3,906 expansion candidates made available | **0** |
| World 2 or 3 activations | **0** |
| Commercial airport operating permissions certified | **0** |
| Live account registrations or airline creation performed here | **0** |

## Applied database change

`airlinerra.airport_game_world1_registration_source` is a PRIVATE, read-only `security_invoker=true` view, verified at **3,140 rows**. It joins the active owner-authorized game catalog to the stable `OURAIRPORTS:<id>` identity and exposes:

```sql
world_id                smallint   -- always 1
home_airport_source_id  bigint     -- numeric ID consumed by create_airline_once
airport_key             text       -- stable OUR AIRPORTS key
airport_code            text
airport_name            text
country_iso             text
municipality            text
latitude_deg, longitude_deg
provisional_game_category text     -- six proposals, not approved final category
admission_basis         text       -- OWNER_AUTHORIZED_SIMULATION_CATALOG
```

The view has **no read privileges for `anon` or `authenticated` roles**. A **trusted server-side backend** must use its authorized private database connection. Do not ship service-role keys, database connection strings or private-table privileges to the browser.

## Backend code for home-airport picker

[`server/game-airport-catalog.mjs`](../server/game-airport-catalog.mjs) provides a private service interface:

- `listCountries({worldId:1})`: returns country-code counts for the approved game catalog.
- `listAirports({worldId:1,countryIso:'DE',limit:100,afterSourceId:'0'})`: stable numeric-ID keyset pagination, strictly parameterized SQL, maximum 100 results.
- `lookupAirport({worldId:1,homeAirportSourceId:'5336'})`: checks a single stable numeric airport ID. Returns `null` if not released.

The service defaults to `enabled:false` and **registers no HTTP route or app endpoint**. It rejects World 2/3, invalid country codes, malformed/oversized integer IDs, mismatched `OURAIRPORTS:<id>` keys, duplicate lookups and out-of-order or cross-country pages. No Auth screen, user table, session, airline, trial or gameplay was changed.

## Critical game-account schema handoff — still not applied

The account workstream currently holds the separate **PRELAUNCH, NOT APPLIED** `airlinerra_game` migration. Its `create_airline_once` flow explicitly requires an entry in `airlinerra_game.approved_game_airports(world_id,source_airport_id)`. At this audit, **neither the `airlinerra_game` schema nor the game world's public directory had been installed in Supabase**. Thus the existing 3,140 research-world activation records do **not yet** create 3,140 rows in the account-side roster or make the live signup UI functional.

To bridge after **the separate authentication workstream** has installed and audited its game account/world schema, use:

[`docs/sql/AIRLINERRA_WORLD1_3140_TO_GAME_ACCOUNT_AIRPORTS_PRELAUNCH_2026-10-26.sql`](./sql/AIRLINERRA_WORLD1_3140_TO_GAME_ACCOUNT_AIRPORTS_PRELAUNCH_2026-10-26.sql)

That idempotent, transaction-guarded SQL imports precisely **3,140** World 1 numeric IDs into the account-side roster, sets an explicit `SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26` approval reference, and rolls back if any unexpected outside-cohort game approval or world activation exists. The migration intentionally **does not open a game world, enable public signup, create player accounts, launch trial subscriptions or approve airport commercial permissions**.

Keep `public.airlinerra_game_worlds.state='planned'` until the authentication/legal/email/abuse controls have been independently completed. The airline activation transaction must re-check the private account-side airport roster, not trust a client-supplied label.

## Archives and verification

- [Applied private registration-source SQL view](./sql/AIRLINERRA_WORLD1_3140_PRIVATE_REGISTRATION_SOURCE_2026-10-26.sql)
- [Server-side catalog adapter](../server/game-airport-catalog.mjs)
- [Backend adapter Node tests](../tests/test_game_airport_catalog.mjs)
- [Executed private database regression test](../tests/sql/test_world1_3140_registration_airports_2026-10-26.sql)
- [POST-AUTH only: guarded 3,140-airport roster sync — NOT APPLIED](./sql/AIRLINERRA_WORLD1_3140_TO_GAME_ACCOUNT_AIRPORTS_PRELAUNCH_2026-10-26.sql)

Supabase regression returned **PASS**: exactly 3,140 source IDs, no unapproved expansion identity, all six expected categories, 229 country codes, proper `security_invoker` privacy and no premature real-world commercial approval. Unit tests for the new Node module were added to the repository but **were not executed against a runnable website/server deployment in this session**.

## Next responsibilities

**Airport data workstream:** maintain a stable simulation catalog, continue separately auditing 3,906 expansion candidates, propose later owner-authorized additions in small batches. **Authentication/registration workstream:** deploy its independently controlled game schema when ready, execute the guarded post-auth airport roster sync, wire the backend-only lookup service and test the actual home-airport picker plus atomic airline creation. This handoff intentionally avoids modifying the other workstream's signup code or toggles.

**Summary:** initial 3,140 game-world airport database records are active and now have stable, safe numeric IDs for registration. The account-side airport roster and public website UI are still gated on the separate prelaunch authentication migration.