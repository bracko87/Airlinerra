# Airlinerra — World 1 Home Airport Integration QA: 3,140

**Date:** 2026-10-26 · **Scope:** airport-side prelaunch registration handoff only · **Database:** private Supabase `hwllkabgzaynalahvkpz` (`airlinerra`) · **Source:** GitHub `main`.

## Outcome

The first-wave game catalog remains **3,140 World 1 airport identities**. The account-side `airlinerra_game.approved_game_airports` table is still **not installed** by the parallel authentication task. No public login, new airline, membership, payment, world 2/3 or live airport rollout was performed.

| Control | Verified |
| --- | ---: |
| Active World 1 airports | 3,140 |
| Private registration source rows | 3,140 |
| Distinct numeric BIGINT home-airport IDs | 3,140 |
| Country-code groups | 229 |
| Distinct visible airport codes | 3,140 |
| Missing geocoordinates | 0 |
| Optional municipality fields missing | 52 (the private backend returns `null`, not a guess) |
| Game account schema installed | No |
| Expansion candidate airports activated | 0 |
| World 2/3 activated | 0 |

## Backend test execution

Source verified by GitHub blob IDs:

- `server/game-airport-catalog.mjs` SHA `a691113d79457f87600d9fd2d25245e77d1d9924`
- `tests/test_game_airport_catalog.mjs` SHA `47218a44cc3be348878de59189c16f6fa3216b9a`

Executed **all seven existing test bodies** against the corresponding source code in an isolated JavaScript harness, with assertion-method shims to emulate the Node `assert` interface. Result: **7 passed / 0 failed**. Coverage included default-off behavior without a database call, country/scope validation and parameterization, numerical ID and airport-key consistency, country directory response handling and connection release, cursor pagination, prevention of cross-country or out-of-order results, duplicate identity rejection and failures. This was **not** an execution of `node --test` or `npm test`, and should not be represented as one.

For a native Node regression run in the checked-out repository:

```bash
node --test tests/test_game_airport_catalog.mjs
```

The account workstream owns `website/package.json` and the global `npm test` suite. The dedicated airport tests can be run using the command above; package-script inclusion has not been independently confirmed here.

## Real database dry-run (no permanent game account tables)

The repeatable SQL file [`tests/sql/test_world1_3140_game_roster_sync_dryrun_2026-10-26.sql`](../tests/sql/test_world1_3140_game_roster_sync_dryrun_2026-10-26.sql) was applied against a **temporary table only**. It:

1. Checks that the actual `airlinerra_game.approved_game_airports` table is not installed, so that the test cannot masquerade as the real account migration.
2. Imports all 3,140 numeric game airport IDs plus the explicit `SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26` scope into an isolated temporary roster.
3. Repeats the import and confirms that the count stays **3,140**, exercising idempotent conflict handling.
4. Independently compares the temporary roster to the owner-authorized source to ensure no outside-cohort entries.
5. Drops the temporary table, leaving the permanent account database untouched.

**Result:** `PASS`, `3140`, account schema not installed.

## What is still required for actual registration

The [prepared post-auth roster synchronization](./sql/AIRLINERRA_WORLD1_3140_TO_GAME_ACCOUNT_AIRPORTS_PRELAUNCH_2026-10-26.sql) must only be executed by the separate authentication workstream **after** it applies the game-account identity schema, confirms the three worlds' configuration and completes its own consent/email/login security checks. At that point its trusted private backend can use [`server/game-airport-catalog.mjs`](../server/game-airport-catalog.mjs) to support country/page/selected-airport lookups. The airline-creation transaction itself must revalidate the `airlinerra_game.approved_game_airports` world-specific source ID.

**No shortcut:** 3,140 airports are active in the private simulation catalog, but a public user still cannot register, create an airline or select a home airport through an operational application until the independent game account and website integration is installed and tested.

## Next airport data task

Keep the original 3,140 stable and shift new airport research to the **3,906 unactivated expansion candidates**, with source-backed increments and an owner-reviewed inclusion release. Do not confuse new research-review statuses with activation. Continue exactly six game classification levels.

**QA finished for this airport-side handoff; game activation remained restricted to the original first cohort.**