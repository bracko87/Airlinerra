# Airlinerra — Account Foundation Batch 8: Profile Persistence/RLS Fix
**Date:** 2026-10-26  
**Branch:** `main`, per `AGENTS.md`  
**Production:** prelaunch; no game schema migration, signup activation, email sending or game currency changes.

## Concrete bug fixed

The previous `website/player-data-service.mjs` implemented `saveMyProfile` with Supabase `.upsert({ user_id, display_name, locale })`. The SQL schema correctly restricts `UPDATE` grants to `display_name` and `locale`. PostgreSQL's `INSERT ... ON CONFLICT DO UPDATE` may update `user_id` as well, which is prohibited by the column-level grants. Accordingly, existing profile updates could fail even for the rightful owner.

**Replacement:** `saveMyProfile` uses only an owner-filtered `UPDATE { display_name, locale }`; if no row exists, it performs `INSERT { user_id, display_name, locale }` with the owner ID obtained from `supabase.auth.getUser()`. If two concurrent first saves race, a PostgreSQL duplicate key (`23505`) is handled by retrying the same owner-scoped `UPDATE`. The user ID is never editable. Client-provided `user_id`, `created_at`, `updated_at` and other authorization fields are ignored. Production release remains disabled.

The change does **not** weaken RLS to make an upsert succeed. Private game entitlements, airlines and financial grants remain inaccessible to normal browsers.

## Modified, committed files

- `website/player-data-service.mjs`: no `upsert`; owner-only update, safe insert, narrowly scoped duplicate-key recovery.
- `tests/test_player_lifecycle.mjs`: updated fake Supabase client to model insert/update; added explicit tests for existing-profile changes and racing first-save collisions. Complete profile suite: **11 tests**.
- `tests/sql/player_profile_rls_isolated.sql`: explicitly checks authenticated users have no `UPDATE` privileges on `user_id`, `created_at`, or `updated_at`, and verifies an attempted ownership reassignment is denied.

## Actual verification

1. All **11/11 committed lifecycle regression test bodies** were executed in a V8 compatibility harness with mocked filesystem/assertions and passed. This is not a full native `npm test` run of the complete repository.
2. The current `website/player-data-service.mjs` was copied byte-for-byte into a local Node.js test folder and compared with the fetched GitHub source using **FNV-1a 32-bit**; both sides were **4,608 characters, `4f8c4e93`**.
3. **7/7 actual native Node.js 22 tests passed** against that identical source copy, using an independent mocked Supabase client and a minimal stub providing only the imported validation helpers. Tested release-off default, new owner profile insert, existing owner update without `user_id`, duplicate-insert `23505` recovery, unverified account rejection, input validation, and sorted read-only worlds.
4. Actual PostgreSQL column-grant and RLS tests remain **unexecuted** because this execution container has no PostgreSQL, Docker, or working package registry. The existing manual-only GitHub workflow remains the correct release gate:
   https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-postgres-isolated.yml

## Production-safety checkpoints

- Frontend account registration remains hard-off with `PUBLIC_AUTH_ENABLED=false`.
- Three planned worlds are not activated.
- The dedicated `airlinerra_game` schema still has NOT been deployed to the Airlinerra research Supabase project.
- No payment, SMTP, domain purchase, user records or live airline created.
- Owner manages Trello; it was not changed.

**Next engineering gate:** execute the isolated PostgreSQL 17 Actions job against its throwaway test database, inspect any failures, and repair exact RLS and concurrency bugs before approving a real migration. After that, finish real Supabase Auth email verification and the secure backend deployment configuration. Do not open the game's world or trial entitlements merely because the JavaScript tests passed.
