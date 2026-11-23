#!/usr/bin/env bash
# Original private final finance writer, two independent disposable sessions.
# Verify advisory lock contention without finance preparation or any posting.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGPORT" = '5432'
test "$PGUSER" = 'postgres'
test "$PGDATABASE" = 'airlinerra_disposable'
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
flight='abababab-1212-4121-8121-abababababab:2026-11-21:1'
psql -X -qAt -v ON_ERROR_STOP=1 <<'SQL' >"$tmp/release.log"
UPDATE airlinerra_game.section9_flight_finance_posting_release_v1
 SET release_state='approved',approved_at=now(),
 approval_reference='disposable-finance-lock-review-20261123' WHERE world_id=1;
UPDATE airlinerra_game.section9_activation_release_policy_v1
 SET release_state='enabled',enabled_at=now(),
 crew_mode='deferred_phase1' WHERE world_id=1;
UPDATE airlinerra_game.section9_trusted_execution_release_policy_v1
 SET release_state='enabled',enabled_at=now() WHERE world_id=1;
UPDATE airlinerra_game.section9_flight_engine_readiness_audit_v1
 SET trusted_flight_execution_release='ACTIVATED',
 fuel_transaction_release='ACTIVATED',
 automatic_flight_and_fuel_settlement_enabled=true WHERE world_id=1;
SQL
cat >"$tmp/lock.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(583730,pg_catalog.hashtext('$flight'));
\echo FINANCE-POST-LOCK-HELD
SELECT pg_sleep(2);
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$tmp/lock.sql" >"$tmp/lock.log" 2>&1 &
locker=$!
for i in $(seq 1 80);do
 if grep -qx FINANCE-POST-LOCK-HELD "$tmp/lock.log" 2>/dev/null;then break;fi
 sleep .1
done
grep -qx FINANCE-POST-LOCK-HELD "$tmp/lock.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c "
 SELECT airlinerra_game.section9_post_completed_flight_finance_once_v1('$flight')->>'status';" \
 >"$tmp/overlap.log" 2>&1
grep -qx game_flight_finance_posting_busy "$tmp/overlap.log"
wait "$locker"
psql -X -qAt -v ON_ERROR_STOP=1 -c "
 SELECT airlinerra_game.section9_post_completed_flight_finance_once_v1('$flight')->>'status';" \
 |grep -qx blocked_missing_completed_ticket_preparation
psql -X -qAt -v ON_ERROR_STOP=1 -c "
 SELECT CASE WHEN (SELECT count(*) FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id='$flight')=0
 THEN 'PASS-NO-PREPARATION' ELSE 'FAIL-UNEXPECTED-PREPARATION' END;" \
 |grep -qx PASS-NO-PREPARATION
echo 'PASS: unchanged final finance writer rejects simultaneous same-flight posting and refuses missing finance preparation.'
