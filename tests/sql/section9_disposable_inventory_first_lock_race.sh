#!/usr/bin/env bash
# Inventory-first concurrency test, disposable database ONLY.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGDATABASE" = 'airlinerra_disposable'
test "$PGUSER" = 'postgres'
psql -X -v ON_ERROR_STOP=1 -q -f tests/sql/section9_disposable_inventory_first_lock_setup.sql
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
owner='99999999-9999-4999-8999-999999999999'
a='11111111-1111-4111-8111-111111111111'
b='22222222-2222-4222-8222-222222222222'
a_occ='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
b_occ='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'

hold_inventory() {
 local schedule="$1" action="$2" marker="$3"
 cat >"$temp/$marker.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM inventory_lock_lab.capacity WHERE schedule_id='$schedule' FOR UPDATE;
\echo LOCKED-$marker
SELECT pg_sleep(2);
SELECT $action;
COMMIT;
SQL
 psql -X -qAt -v ON_ERROR_STOP=1 -f "$temp/$marker.sql" >"$temp/$marker.log" 2>&1 &
}
await_lock() {
 local marker="$1"
 for i in $(seq 1 80); do
  if grep -qx "LOCKED-$marker" "$temp/$marker.log" 2>/dev/null;then return;fi
  sleep 0.1
 done
 echo "Timed out waiting for $marker inventory lock" >&2
 cat "$temp/$marker.log" >&2
 exit 1
}

# Cancellation-first: booking waits on inventory lock, then sees no inventory.
hold_inventory "$a" "inventory_lock_lab.cancel('$owner','$a',1)" cancel_first
await_lock cancel_first
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT inventory_lock_lab.book('$owner','$a','$a_occ','cccccccc-cccc-4ccc-8ccc-cccccccccccc');" \
 >"$temp/late_book.log" 2>&1 &
late_book=$!
wait "$late_book"
grep -qx cancelled "$temp/cancel_first.log"
grep -qx blocked_missing_capacity "$temp/late_book.log"

# Booking-first: cancellation waits, then rechecks held seats under row locks.
hold_inventory "$b" "inventory_lock_lab.book('$owner','$b','$b_occ','dddddddd-dddd-4ddd-8ddd-dddddddddddd')" booking_first
await_lock booking_first
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT inventory_lock_lab.cancel('$owner','$b',1);" \
 >"$temp/late_cancel.log" 2>&1 &
late_cancel=$!
wait "$late_cancel"
grep -qx booked "$temp/booking_first.log"
grep -qx blocked_reservations "$temp/late_cancel.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT status='cancelled' AND version=2 FROM inventory_lock_lab.schedules WHERE id='$a')
 AND NOT EXISTS(SELECT 1 FROM inventory_lock_lab.capacity WHERE schedule_id='$a')
 AND NOT EXISTS(SELECT 1 FROM inventory_lock_lab.occurrences WHERE schedule_id='$a')
 AND NOT EXISTS(SELECT 1 FROM inventory_lock_lab.slots WHERE schedule_id='$a')
 AND (SELECT status='active' AND version=1 FROM inventory_lock_lab.schedules WHERE id='$b')
 AND (SELECT held=1 FROM inventory_lock_lab.capacity WHERE schedule_id='$b')
 AND (SELECT booked=1 FROM inventory_lock_lab.occurrences WHERE id='$b_occ')
 AND (SELECT count(*)=1 FROM inventory_lock_lab.reservations WHERE occurrence_id='$b_occ')
 AND (SELECT count(*)=1 FROM inventory_lock_lab.slots WHERE schedule_id='$b')
 AND (SELECT count(*)=1 FROM inventory_lock_lab.journal WHERE schedule_id='$a')
 AND (SELECT count(*)=0 FROM inventory_lock_lab.journal WHERE schedule_id='$b')
 THEN 'PASS-inventory-first-two-orders'
 ELSE 'FAIL-inventory-first-two-orders' END;
" | grep -qx 'PASS-inventory-first-two-orders'
echo 'PASS: synthetic inventory-first cancellation/book race in both orders; no lost reservations or slots.'
