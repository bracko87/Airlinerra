# Airlinerra — Phase 1 database release gate (consolidated current status)

**Audit date:** 23 November 2026
**Decision:** **BLOCKED — NOT AUTHORIZED FOR PRODUCTION MIGRATION OR COMMERCIAL FLIGHT RELEASE**

This report supersedes earlier interim migration-count and duplicate-version findings. It combines source-to-live reconciliation, actual disposable local Supabase replay, and READ-ONLY live database checks. No production SQL writes, cron changes or release toggles were performed.

## 1. Actual work completed

| Area | Result |
|---|---|
| Duplicate repository migration timestamps | **RESOLVED:** no duplicate versions among 418 checked-in SQL files |
| Recorded original SQL provenance | **259 files byte-for-byte identical** to one recorded applied migration SQL statement (Git blob SHA-1 comparison) |
| Wrong historical timestamps repaired | **200 files**: 14 initially proven, then 186 more; each content unchanged |
| Broken references after filename recovery | **144 references across 56 test/workflow files corrected** |
| Missing research/account foundations | **58 original applied SQL migrations restored** (three individually, then 55 in bulk), from immutable recorded SQL |
| Private Auth/owner history | **2 prelaunch migrations intentionally excluded** from public GitHub due to account-related data/logic |
| Source integrity check | **PASS**: https://github.com/bracko87/Airlinerra/actions/runs/45264125112 |
| Complete fresh local Supabase replay | **NOT YET PASSING**; diagnostic workflow: https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-full-migration-replay-ci.yml |

**Authoritative SQL immutable manifest:** `data/migrations/airlinerra_recorded_sql_provenance_2026-11-23.json`.

**Auditor:** `scripts/verify_airlinerra_migration_history.py`, run on relevant changes by `.github/workflows/airlinerra-migration-provenance-ci.yml`. It checks unique versions, recorded SQL Git blob hashes, and stale migration references. It is a static/provenance test, **not** a substitute for SQL deployment/replay.

## 2. Remaining repository–database differences

Connected Airlinerra database: **685** recorded migration versions.
Checked-in GitHub: **418** migration SQL files (all now unique versions).

| Repository classification | Files |
|---|---:|
| Exactly matching recorded version, name **and SQL body** | **259** |
| Same recorded name but **different SQL body** | **17** |
| No corresponding recorded migration **name** | **142** |
| **Total** | **418** |

Within the 17 SQL-content differences, **seven use the same version as the live history** (their checked-in SQL differs from the recorded applied statement), and ten also use a different timestamp. These are **real source drifts**, not something to correct by blindly renaming or marking migrations applied.

Seven same-version drift names:
- `grant_owner_signup_gate_reserved_email_read_to_auth_admin`
- `section5_timed_route_schedule_gate_20261105`
- `section5_airports_curfew_chapter_batches50_20261105`
- `section5_batch50_operational_reference_v1_20261105`
- `section5_batch50_capacity_season_source_v2_20261105`
- `section5_batch50_second_source_screen_evidence_20261105`
- `section5_batch50_preserve_all_conditional_capacity_records_20261105`

Ten other same-name SQL drift areas:
`section5_route_written_airport_permission_20261105`,
`section6_weekly_atomic_slot_reservations`,
`section9_retry_exhaustion_guard`,
`section9_queue_uuid_cursor_fix`,
`airlinerra_fleet_aircraft_nickname_v1`,
`airlinerra_cabin_services_owner_settings_v1`,
`section9_owned_aircraft_operational_position_resolver_v1`,
`section9_game_five_phase_fuel_preview_only_v1`,
`section9_shared_game_model_preliminary_route_suitability_v1`,
`section9_global_game_licence_fee_policy_draft_v1`.

**409 of 685 live-recorded migration names are still absent** as individual GitHub filenames. Some concern research/old operations and may not all need to be replayed in a new baseline; do not assume these migrations are missing in effect, or copy them all to a public repository without a privacy audit.

**142 GitHub-only named migrations** may already be functionally represented in the live database under different names or may contain new repo-only corrections. They require object-level or SQL semantic reconciliation, not bulk deployment.

## 3. Full fresh-database replay and authoritative bootstrap

The disposable CI job runs pinned local Supabase CLI (2.122.0), no production URL, no Supabase access token, no database write outside its temporary Docker environment.

Earlier first failures:
- `airlinerra_game` schema absent: original 27 October account foundation restored.
- `airlinerra.airport_registry` absent: original 23 October research foundation restored.
- `airlinerra_game.airport_reference_profiles` absent: original 29 October World 1 airport foundation restored.
- `airlinerra.airport_game_world1_catalog` absent in earlier diagnostic: bulk restoration of 55 additional prelaunch migrations now available.

Two early **private** applied migrations have intentionally **not** been published:
- `20261028153343_airlinerra_owner_single_email_unlimited_premium_on_activation_20261028` (contains an approved owner email)
- `20261028160620_airlinerra_selfservice_single_owner_signup_hook_20261028` (requires private Auth security review)

The CI workflow inserts an **empty, labelled, temporary owner-reservation table fixture** so a diagnostic replay can continue. This makes any CI replay a **diagnostic replay**, not proof that every private original migration was recreated faithfully.

**The full historical migration replay is therefore still blocked**, pending the complete foundational research schema/data, private historical Auth logic, and the remaining source-divergence reconciliation. Do not turn a sequence of synthetic fixture repairs into a claim of production readiness.

## 4. Critical READ-ONLY live operations observation

As observed in the connected World 1 database on 23 November 2026:

- World state: **active**.
- Game flight activation release: **enabled**; trusted execution release: **enabled**.
- Readiness view: `trusted_flight_execution_release=ACTIVATED`, `fuel_transaction_release=ACTIVATED`, automatic flight/fuel settlement enabled.
- **25 active scheduled Airlinerra cron jobs**, including the automatic flight dispatcher (every minute), passenger-demand worker, and final-finance worker.
- Readiness view reports **zero active flight schedules, zero verified flight movements and zero settled flights**.
- The three checked operational crons reported successful runs in the previous two-hour window; success means their scheduled SQL calls completed, not that a real flight happened.
- The current live signed-movement writer does **not** yet contain the repo-only `SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_OPEN` guard. The dispatcher already contains the `required_permission_code` fix through a differently recorded migration.

This means the release switches are **already on**, despite the incomplete release-safety proof. Do not assume the system is paused, and do not silently flip the release flags in either direction without explicit controlled-release approval. **No live flags were changed in this audit.**

## 5. Finite release blockers and acceptance criteria

**B1 — Complete authoritative bootstrap (PARTIAL).** The 58 safe original research/account/facility migration sources are restored. Finish reconstruction of historical private Auth logic **without publishing owner emails or credentials** and identify any pre-existing airport data import baseline. Require one reproducible local bootstrap, not per-error synthetic production schema.

**B2 — Migration timestamp collisions (CLOSED).** All 418 filenames have unique versions. Preserve 259 provenance-matched SQL bodies and the passing static audit.

**B3 — Source-vs-live reconciliation (PARTIAL).** Review **17 real SQL-body drifts** and **142 repo-only names**; map required authoritative sources among 409 other recorded migrations. Apply necessary differences only through reviewed forward-only migrations. Do not run `supabase db push` using the unreconciled folder.

**B4 — Complete fresh replay and access control (BLOCKED).** Require a successful isolated Supabase rebuild with appropriate account/research/airport data baselines; verify immutable writer, release grants, RLS, no unintended public access, replay/idempotency, and the repository-only cancellation guard.

**B5 — Realistic staging and production decision (NOT STARTED).** Stage the final schema, test finances and complete player flow, review the unexpectedly enabled live release posture, then obtain approval before any production schema/write/release changes.

## Latest verification sources

- Static migration integrity passing: https://github.com/bracko87/Airlinerra/actions/runs/45264125112
- First 14 verified retimestamps: https://github.com/bracko87/Airlinerra/commit/62eb8d4d0579cf0c9f7b90ba1202859266f78a65
- Additional 186 verified retimestamps: https://github.com/bracko87/Airlinerra/commit/5ce0a56d1a3c3747216a852cd3cb25ba0a5214f0
- 55 restored prelaunch migrations: https://github.com/bracko87/Airlinerra/commit/228b7118ea24849eab113eccef8d20017436d00f
- Diagnostic local migration replay: https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-full-migration-replay-ci.yml

**Release outcome: not approved. No live production migration or flag change performed.**
