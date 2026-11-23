#!/usr/bin/env bash
# Disposable-only check that recovery uses actual disruption mutex.
# No real recovery or flight mutations; saved receipt only.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGDATABASE" = 'airlinerra_disposable'
test "$PGUSER" = 'postgres'
test "$PGPORT" = '5432'
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
key="s9g1:$(printf '%064d' 0 | tr 0 e)"
cat > "$temp/locker.sql" <<'SQL'
\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(583729,10041);
\echo DISRUPTION-LOCK-HELD
SELECT pg_sleep(2);
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$temp/locker.sql" > "$temp/locker.log" 2>&1 &
locker=$!
for i in $(seq 1 80); do
 if grep -qx 'DISRUPTION-LOCK-HELD' "$temp/locker.log" 2>/dev/null; then break; fi
 sleep .1
done
grep -qx 'DISRUPTION-LOCK-HELD' "$temp/locker.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_recover_connecting_passengers_v1('$key',NULL,1440)->>'status';" \
 > "$temp/overlap.log"
grep -qx connection_dispatch_busy "$temp/overlap.log"
wait "$locker"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT CASE WHEN r->>'replayed'='true'
 AND r->>'recovered'='true' AND r->>'ledgerPosted'='false'
 AND r->>'refundUsd'='0'
 THEN 'PASS-REPLAY' ELSE 'FAIL-REPLAY' END FROM
 (SELECT airlinerra_game.section9_recover_connecting_passengers_v1('$key',NULL,1440) AS r) q;" \
 | grep -qx PASS-REPLAY
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT CASE WHEN count(*)=1 THEN 'PASS-ONE-RECEIPT' ELSE 'FAIL-RECEIPT' END
 FROM airlinerra_game.section9_connection_recovery_receipts_v1
 WHERE source_allocation_key='$key';" | grep -qx PASS-ONE-RECEIPT
echo 'PASS: existing recovery writer refuses overlapping disruption mutex, then safely replays receipt without posting funds.'
