# Airlinerra — Account and World Foundation: Batch 3
**Date:** 2026-10-26  
**Development branch:** main (as required by AGENTS.md)  
**Status:** Code and SQL review assets committed; Supabase production schema NOT changed  
**Trello:** Owner-managed; no board/card changes

## Outcome

This batch advances the account model without admitting players or airports into gameplay. Worlds 01/02/03 remain **planned** and the public Auth UI hard-off switch remains **false**. No user accounts, airlines, entitlements or financial balances were inserted in Supabase.

- `website/player-data-service.mjs`: prepared Supabase profile repository. Each operation reads the verified user using `supabase.auth.getUser()`; the caller cannot select an arbitrary user ID. Registration/sign-in gate remains off; no query reaches Supabase from the prelaunch account UI.
- `safeWorldDirectory()`: validates IDs 1–3, allowed states, unique IDs and the real-time rule. It is for display only. Being listed in an open world does not authorize joining it.
- `server/account-trial-policy.mjs`: pure, deterministic server-side helper for state display/testing, with seven real 24-hour days (168 hours), USD 5,000,000 starting capital and zero initial aircraft. No payment entitlement or balance changes can be authorized by this helper alone.
- `tests/test_player_lifecycle.mjs`: Node test suite covering the data layer, ownership, locked worlds, time boundary and SQL contract. It is wired into `website/package.json` via `npm test`, together with the existing Auth suite.
- `docs/sql/airlinerra_game_identity_schema_prelaunch.sql`: review-only SQL contract, strengthened as below.

## Database safeguards (not applied)

**Public read:** only the non-sensitive `public.airlinerra_game_worlds` directory. Three rows, all `planned`.

**Public writes:** only own `public.airlinerra_player_profiles`, protected by RLS ownership checks. Grants allow insert of `user_id/display_name/locale` and update of `display_name/locale` only. The database owns `created_at/updated_at`; a trigger sets update time. Users cannot change authorization, trial clock, cash or worlds through profiles. Display names/user_metadata must NEVER grant privileges.

**Private schema:** `airlinerra_game` is not exposed to `anon`/`authenticated`; RLS is enabled on each table. No API grants are created for `account_entitlements`, `world_memberships`, `approved_game_airports`, `airlines` or `airline_ledger`.

**No world/airport opening:** The game-airport approval table starts empty. A compound foreign key prevents creating an airline at an airport unless an operator has separately approved the airport for that particular world. A database trigger also rejects airline inserts where the world state is not `registration_open` or `active`.

**Exactly-once starting cash:** `airlinerra_game.credit_starting_cash_once(airline_id)`, private `SECURITY INVOKER`, atomically inserts the ledger's sole `STARTING_CAPITAL` entry and credits precisely USD 5,000,000. A partial unique index on `airline_id` allows exactly one startup entry; concurrent retries cannot add a second $5m credit. This function does **not** buy aircraft.

**Account-wide seven-day trial (proposed policy):** `airlinerra_game.start_account_trial_once(player_id)` has no anonymous/authenticated EXECUTE grants. It requires an existing airline created by the trusted backend. Its UPSERT changes an empty trial record only when `trial_started_at IS NULL` and membership is `none`; re-entry into any world cannot restart a started trial. The duration is exactly **168 hours**, not a calendar-day interval across daylight-saving shifts. Trial activation is a business-policy proposal until explicitly approved; this SQL has not been executed.

## Planned transaction contract (future trusted backend only)

1. Authenticate the real user; verify their email, account status, membership/trial eligibility and terms consent **server-side**. Never use `raw_user_meta_data` for authorization.
2. Lock/read chosen world and assert state permits new airlines. Confirm approved home airport for that world.
3. Within **one database transaction**, insert or find the single `world_memberships` record and insert the airline under the `UNIQUE(world_id,owner_player_id)` constraint.
4. For a newly created airline in that transaction, call `credit_starting_cash_once(airline_id)`; credit once. Call `start_account_trial_once(player_id)`; start only if the account's trial has never run.
5. Commit only after all validations succeed; on any error roll back **the membership, airline, ledger and trial changes together**. Do not rely on multi-step browser calls for this financial sequence.
6. Enforce active subscription or unexpired trial on the server for **every** sensitive game operation. Client previews are not access control; disabling session refresh is not a sufficient revocation method.
7. Test simultaneous double submits, parallel world joins, crashes/rollbacks, expired trials, already-active subscriptions, missing approved airports, closed worlds and cross-world access.

**Not implemented yet:** actual atomic airline-create endpoint; world operators/admin RBAC; legal-terms consent ledger; payment integration; persisted gameplay; production registration; sending verified emails. These require separate approvals/verification and cannot be inferred from the SQL draft.

## Testing and release gates

- Read-only database inventory was checked prior to work. Dedicated Supabase project has isolated `airlinerra` research and public site status, with no installed `airlinerra_game` schema.
- Code checks: source parse, safe profile queries, anonymous/disabled cases, malformed worlds, exact expiry and static SQL permissions. The combined Node runner is committed but has **not been executed in a full project checkout** in this session; a passing PostgreSQL migration test has also **not** been demonstrated.
- Local verification: `cd website && npm test && npm run build && npm run dev`.
- Manual-only GitHub Actions workflow: `.github/workflows/airlinerra-account-foundation.yml`; do not claim green without an actual run.
- For migration integration tests, use an isolated **non-production** Supabase/PG environment. Verify actual RLS grants, triggers, FK rejections, trial concurrency and ledger idempotency. Never execute a trial migration against the existing live research database to test it.
- Only later, with explicit owner authorization, generate/apply a versioned migration using Supabase CLI, configure server-side Auth settings, SMTP/domain, and promote the account UI. The SQL file is a draft, not a migration history entry or a claim of DB activation.

## Dependencies before a playable world

1. Official domain ownership, DNS/HTTPS and transactional email, including verification and password reset.
2. Legal privacy/terms publication and accurate versioned acceptance.
3. Verified SMTP plus Supabase Auth server-side signup confirmation/abuse settings; pinned and bundled Supabase JS dependency.
4. Dedicated trusted server endpoint for atomic airline creation and entitlements.
5. Explicitly approved gameplay airport roster; never promote the 8,153-airport research list or 3,140-source shortlist automatically.
6. Operator-controlled World 01 opening (Worlds 02 and 03 remain closed); separate release and payment approvals.
