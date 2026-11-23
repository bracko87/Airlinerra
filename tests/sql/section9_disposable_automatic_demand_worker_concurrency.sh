#!/usr/bin/env bash
# Two independent sessions race the unchanged production auto-demand worker.
# Only the approved SQL candidate is installed; disposable local PostgreSQL.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGDATABASE" = 'airlinerra_disposable'
test "$PGUSER" = 'postgres'
ticket_key="demand.s9g1:$(printf '%064d' 0 | tr 0 b)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# The previous acceptance intentionally leaves a partially issued pair.
# Restore unissued state inside disposable fixtures only.
psql -X -qAt -v ON_ERROR_STOP=1 -c "
DELETE FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE reservation_key='$ticket_key';
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1 SET booked_seats=0
 WHERE id IN ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
              'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid);
" >"$tmp/reset.log"

cat >"$tmp/first.sql" <<'SQL'
\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(583729,10029);
\echo WORKER-LOCK-HELD
SELECT pg_sleep(2);
SELECT airlinerra_game.section9_promote_completed_demand_holds_batch_v1(50)->>'itinerariesIssued';
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$tmp/first.sql" >"$tmp/first.log" 2>&1 &
first=$!
for i in $(seq 1 80);do
 if grep -qx 'WORKER-LOCK-HELD' "$tmp/first.log" 2>/dev/null;then break;fi
 sleep 0.1
done
grep -qx 'WORKER-LOCK-HELD' "$tmp/first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_promote_completed_demand_holds_batch_v1(50)->>'status';" \
 >"$tmp/second.log"
grep -qx demand_ticket_worker_in_progress "$tmp/second.log"
wait "$first"
grep -qx '1' "$tmp/first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
  WHERE reservation_key='$ticket_key' AND seats_requested=2)=2
 AND (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1
  WHERE id IN ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
               'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)
  AND booked_seats=2)=2
 THEN 'PASS-EXACTLY-ONCE' ELSE 'FAIL-DUPLICATE-WORKER' END;
" | grep -qx PASS-EXACTLY-ONCE
echo 'PASS: unchanged automatic demand worker mutex rejects overlap and issues exactly two passenger legs.'
