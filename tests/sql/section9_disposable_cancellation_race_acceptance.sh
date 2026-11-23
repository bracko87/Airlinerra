#!/usr/bin/env bash
# Disposable PostgreSQL concurrency acceptance. Never run against live data.
set -euo pipefail
test "${PGHOST:-}" = '127.0.0.1'
test "${PGDATABASE:-}" = 'airlinerra_disposable'
test "${PGUSER:-}" = 'postgres'
psql -X -v ON_ERROR_STOP=1 -q -f tests/sql/section9_disposable_cancellation_race_setup.sql

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

# A psql connection deliberately holds the schedule lock before executing its
# operation. Its marker only appears AFTER the FOR UPDATE lock is acquired.
hold_writer() {
 local schedule="$1" call="$2" label="$3"
 cat > "$temp_dir/$label.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM cancellation_lab.schedules WHERE id='$schedule' FOR UPDATE;
\echo LOCKED-$label
SELECT pg_sleep(2);
SELECT $call;
COMMIT;
SQL
 psql -X -qAt -v ON_ERROR_STOP=1 -f "$temp_dir/$label.sql" >"$temp_dir/$label.log" 2>&1 &
 echo $!
}
await_marker() {
 local label="$1"
 for i in $(seq 1 80); do
  if grep -q "^LOCKED-$label$" "$temp_dir/$label.log" 2>/dev/null; then return 0; fi
  sleep 0.1
 done
 echo "Lock acquisition timeout: $label" >&2
 cat "$temp_dir/$label.log" >&2
 exit 1
}
OWNER='11111111-1111-4111-8111-111111111111'
A='77777777-7777-4777-8777-777777777777'
AO='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
B='88888888-8888-4888-8888-888888888888'
BO='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'

# Scenario 1: cancellation gets the row lock first. The booker MUST reject
# after waiting for the cancellation to commit.
hold_writer "$A" "cancellation_lab.try_cancel('$OWNER','$A',1)" cancel_first >/dev/null
await_marker cancel_first
psql -X -qAt -v ON_ERROR_STOP=1 -c "SELECT cancellation_lab.try_book('$OWNER','$A','$AO','cccccccc-cccc-4ccc-8ccc-cccccccccccc');" >"$temp_dir/late_booking.log" 2>&1 &
late_booking_pid=$!
wait "$late_booking_pid"
grep -qx 'denied_inactive' "$temp_dir/late_booking.log"
grep -qx 'cancelled_slots_1' "$temp_dir/cancel_first.log"

# Scenario 2: booking gets the row lock first. Cancellation MUST reject
# without releasing a reserved seat or an airport slot.
hold_writer "$B" "cancellation_lab.try_book('$OWNER','$B','$BO','dddddddd-dddd-4ddd-8ddd-dddddddddddd')" booking_first >/dev/null
await_marker booking_first
psql -X -qAt -v ON_ERROR_STOP=1 -c "SELECT cancellation_lab.try_cancel('$OWNER','$B',1);" >"$temp_dir/late_cancellation.log" 2>&1 &
late_cancel_pid=$!
wait "$late_cancel_pid"
grep -qx 'booked' "$temp_dir/booking_first.log"
grep -qx 'denied_reservations_or_finance' "$temp_dir/late_cancellation.log"

psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT status='cancelled' AND version=2 FROM cancellation_lab.schedules WHERE id='$A')
 AND (SELECT count(*)=0 FROM cancellation_lab.slots WHERE schedule_id='$A')
 AND (SELECT count(*)=0 FROM cancellation_lab.occurrences WHERE schedule_id='$A')
 AND (SELECT count(*)=0 FROM cancellation_lab.reservations WHERE occurrence_id='$AO')
 AND (SELECT status='active' AND version=1 FROM cancellation_lab.schedules WHERE id='$B')
 AND (SELECT count(*)=1 FROM cancellation_lab.slots WHERE schedule_id='$B')
 AND (SELECT count(*)=1 FROM cancellation_lab.reservations WHERE occurrence_id='$BO')
 AND (SELECT booked_seats=1 FROM cancellation_lab.occurrences WHERE id='$BO')
 THEN 'PASS-both-concurrent-write-orders' ELSE 'FAIL-concurrent-write-state' END;
" | grep -qx 'PASS-both-concurrent-write-orders'
echo 'PASS: cancellation-first blocks booking, booking-first blocks cancellation; no partial slot or booking loss.'
