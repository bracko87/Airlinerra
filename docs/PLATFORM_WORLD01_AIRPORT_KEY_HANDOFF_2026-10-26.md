# Airlinerra platform: World 01 airport-key integration — 26 October 2026

**Owner of airport verification / classification / approval:** *Airport Database Overview* workstream.  
**This task's owner:** platform, player signup and airline-creation code.  
**GitHub branch:** `main`, per `AGENTS.md`.  
**Production:** no game schema deployment, no player signup, no airline activation, no airport write, no Trello changes.

## Executive status

**Platform airport-ID compatibility is implemented in undeployed code, not operational for players.**

The authoritative airport registry uses `airport_key text`, such as `OURAIRPORTS:101` and `FICTIONAL:fictional:RS:LYAL`. The prior game schema/API assumed a positive `bigint` source ID and thus excluded the fictional airport and did not faithfully match the actual research identity.

We changed the **platform side only** to use the stable registry key consistently. We did not modify any airport research, review, category, operator admission, or activation row.

## Implemented and committed to `main`

1. **Private game schema draft:** `docs/sql/airlinerra_game_identity_schema_prelaunch.sql` now stores `approved_game_airports.airport_key text`, `airlines.home_airport_key text` and the (world ID, airport key) foreign key. A strict key-format check accepts existing OurAirports numeric namespaced keys and the fictional `FICTIONAL:fictional:RS:LYAL` form. There are **no operator-approved game airports by default**.
2. **Private activation SQL draft:** `docs/sql/airlinerra_game_activation_prelaunch.sql` now accepts `p_home_airport_key text`, checks world-specific `approved_game_airports.airport_key`, rejects changed-airport retries and uses the same key for the new airline row. Existing fresh Auth verification, platform gate, current legal consent, world gate, one-per-world uniqueness, exact $5m ledger credit, and one account-wide 168-hour trial remain.
3. **Trusted server and HTTP layer:** `server/airline-activation.mjs` and `server/airline-http-handler.mjs` now use `homeAirportKey`. Client input cannot create an approval or inject a player ID. Both handlers remain **enabled=false**.
4. **Disposable SQL fixtures/guards:** Updated `tests/sql/airline_activation_disposable_fixtures.sql`, `airline_activation_negative_cases.sql`, `airline_activation_postconditions.sql`, `airline_activation_isolated_assertions.sql`, and the manual-only workflow. The synthetic test world uses `OURAIRPORTS:101`; its second-world transaction tests the fictional `FICTIONAL:fictional:RS:LYAL`. These fixtures are *not* approved production airports.
5. **Private, read-only verification bridge:** `server/world-airport-readiness.mjs` can query the existing `airlinerra` research schema and separately report:
   - active `airport_world_activation` entries;
   - missing registry keys;
   - entries with actual owner admission approval **and** an approved final category;
   - unresolved approval records.

   It is **disabled by default** and provides only aggregate diagnostics, never raw airport data, write/approval permissions, or an endpoint. It never populates the separate private `airlinerra_game.approved_game_airports` roster. No activation row becomes game-playable merely because `active=true`.
6. **Regression tests:** Updated `tests/test_airline_activation.mjs` and `tests/test_airline_http_handler.mjs`; added `tests/test_world_airport_readiness.mjs`; linked the last to `website/package.json` `npm test`.

## Verification results

- Fetched actual committed source/tests from GitHub `main` and executed **26/26** test bodies across the three affected suites using a V8 JavaScript compatibility harness and simulated Node/test and database interfaces. This is **not** a native `npm test`, real PostgreSQL test, or a real backend deployment.
- **10/10** targeted structural source checks passed, plus additional SQL integrity checks confirming exactly one approval table, one airlines table, one transaction, and no duplicate SQL. An intermediate GitHub draft patch accidentally duplicated a SQL suffix due to a JavaScript replacement string; it was corrected in a subsequent commit and verified before completion.
- Read-only Supabase checks verified **all 8,153 registry keys match** the new allowed namespace pattern (**0 unsupported**).
- Current World 01 research status: **3,140 active activation rows**, **0 fully owner/category-approved entries**, **3,140 NOT_APPROVED access-review rows**, and **3,140 without a final approved category**. The pending approval reconciliation is a responsibility of Airport Database Overview, **not an action this conversation will undertake**.
- The live project still reports **0 deployed `airlinerra_game` tables** and `prelaunch` website state. The new game schema drafts and private code have **not** been applied or enabled.

## Release responsibilities, kept separate

**Airport Database Overview:** verify/approve research admissions, finalize six categories, reconcile the World 01 activation flag with `game_admission_status` and `category_approved_at`, and provide an explicit operator-approved handoff.

**Platform/account system (this conversation):** run the manual isolated PostgreSQL 17 workflow and fix any real failures; connect the approval handoff to the separate trusted `airlinerra_game.approved_game_airports` provisioning process only after explicit owner approval; integrate secure Auth, SMTP, legal-policy, server deployment and eventual subscription billing. No automated promotion of the 3,140 activation records is permitted.

**Required integration validation:** <https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml> — manually trigger on `main`. The workflow still has not been observed running successfully; do not claim database concurrency safety until it passes.

## Next measurable milestone

**Account creation + World 01 airline activation, validated in an isolated environment** after the airport approval contract is agreed and the disposable PostgreSQL workflow is green. Until then, this is **completed source-code alignment**, not a working player-facing feature.
