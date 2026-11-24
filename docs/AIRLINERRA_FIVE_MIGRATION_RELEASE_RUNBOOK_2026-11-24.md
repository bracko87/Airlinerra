# Commercial flight release: five-migration gate (2026-11-24)

Scope: issue #63. This is a release preparation, not production approval.

## Live read-only precheck
- All five exact target versions absent from live migration history. Do not bulk db push or mark unrelated historical IDs applied.
- All five relevant function source/version checks matched current expected deployed definitions (movement, dispatcher, candidate, issuer, restriction guard).
- Each of those functions is inaccessible to anon, authenticated and service_role for EXECUTE.
- Unified catalog and combined catalog each returned 4,259 airports, with zero duplicate (world_id, airport_key) Section 5 simplified-rule keys.
- Current unified airport view has 36 columns, no security_invoker reloption, and no SELECT for anon/authenticated/service_role. The proposed migration explicitly sets security_invoker=true and must preserve column types/order and private access. The new alignment view is private.
- These checks are structural/preflight evidence only, not complete rehearsal or release permission.

## Fixed allowlist (ordered)
1. 20261123200000_section9_signed_movement_cancellation_guard.sql — guarded in-place movement source patch.
2. 20261123210000_section9_dispatch_traffic_permission_binding_fix.sql — fail-closed assertion; current dispatcher must remain byte-identical.
3. 20261124123000_section9_conservative_game_airport_restriction_alignment.sql — two airport read-model views, preserve columns and keep private.
4. 20261124134500_section9_candidate_game_gate_vs_research_review.sql — guarded candidate preflight correction.
5. 20261124135500_section9_game_clearance_issuer_prelock_schedule.sql — guarded issuer pre-lock.

## One isolated rehearsal
Manually dispatch the existing private schema baseline workflow on the reviewed release branch. Do not add a pull_request/push trigger to the production-connected workflow. It restores schema definitions only into local Supabase, checks seven structural fingerprints, applies only the above five migrations twice, tests idempotence and source guards, and checks unchanged dispatcher and airport columns plus invoker views and restricted grants. No player rows or credentials in artifacts. The earlier script checked an obsolete movement guard name; the revised script checks the current guard. Source grants were independently checked read-only; the dump intentionally excludes ACLs, so schema-only restoration is not full live ACL/role parity or a data backup.

## Recovery and controlled production decision
- Owner/operator verifies a usable current database backup and recovery options in Supabase dashboard; record restore point and scope, retention, expected downtime and potential lost writes. Do not treat a successful schema-only dump as a recoverable full database backup.
- Before writes, verify live targeted source definitions/permissions and recorded IDs have not drifted since rehearsal, and capture protected rollback definitions and original grants for affected views/functions. Preserve working modern dispatcher.
- Review migration SQL and approved isolated workflow result, security checks and any remaining migration parity discrepancies impacting this set. Explicit release approval required before any production DDL or history writes.
- Apply only reviewed allowlisted versions using controlled migration recording; re-check each version, grants, invoker option, catalog count and key uniqueness, dispatcher unchanged, issuer and movement guards. Halt on any failure; no blind retry or unrelated migration replay. Use recovery plan if required.
- No activation/maintenance/financial mutation as part of this schema package. Verify live Daily/Weekly maintenance and explicitly authorize first owner flight separately.
- Close issue only after real player route/booking/departure/arrival/fuel and exactly-once finance acceptance, not just green schema CI.
