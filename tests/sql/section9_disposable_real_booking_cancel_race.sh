#!/usr/bin/env bash
# Races the UNCHANGED Airlinerra direct-booking procedure against an
# UNDEPLOYED synthetic cancellation candidate on representative game tables.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGDATABASE" = 'airlinerra_disposable'
test "$PGUSER" = 'postgres'
psql -X -v ON_ERROR_STOP=1 -q -f tests/sql/section9_disposable_real_booking_cancel_race_setup.sql
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
owner='22222222-2222-4222-8222-222222222222'
airline='11111111-1111-4111-8111-111111111111'
a='66666666-6666-4666-8666-666666666666'
b='77777777-7777-4777-8777-777777777777'
ao='cccccccc-cccc-4ccc-8ccc-cccccccccccc'
bo='dddddddd-dddd-4ddd-8ddd-dddddddddddd'

start_inventory_lock() {
 local schedule="$1" sql="$2" label="$3"
 cat > "$temp/$label.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE schedule_id='$schedule' FOR UPDATE;
\echo LOCKED-$label
SELECT pg_sleep(2);
SELECT $sql;
COMMIT;
SQL
 psql -X -qAt -v ON_ERROR_STOP=1 -f "$temp/$label.sql" > "$temp/$label.log" 2>&1 &
}
wait_locked() {
 local label="$1"
 for i in $(seq 1 90);do
  if grep -qx "LOCKED-$label" "$temp/$label.log" 2>/dev/null;then return;fi
  sleep 0.1
 done
 echo "Timed out waiting for $label lock" >&2
 cat "$temp/$label.log" >&2
 exit 1
}

# Actual booking after candidate cancellation: the missing flight/capacity
# causes the unchanged reservation function to refuse the new ticket.
start_inventory_lock "$a" "real_booking_cancel_lab.proposed_cancel('$owner','$airline','$a',1)" cancellation_first
wait_locked cancellation_first
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_reserve_verified_game_passenger_seats_v1('$ao','race.late.booking','economy',2)->>'status';" \
 > "$temp/late_booking.log" 2>&1 &
late_booking=$!
wait "$late_booking"
grep -qx candidate_cancelled "$temp/cancellation_first.log"
grep -qx blocked_unknown_flight "$temp/late_booking.log"

# Actual booking first: the protected cancellation candidate waits for the
# capacity lock, sees booked seats and refuses without removing any slots.
start_inventory_lock "$b" \
 "airlinerra_game.section9_reserve_verified_game_passenger_seats_v1('$bo','race.early.booking','economy',2)->>'status'" booking_first
wait_locked booking_first
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT real_booking_cancel_lab.proposed_cancel('$owner','$airline','$b',1);" \
 > "$temp/late_cancellation.log" 2>&1 &
late_cancel=$!
wait "$late_cancel"
grep -qx game_passenger_seats_reserved "$temp/booking_first.log"
grep -qx blocked_reserved_seats "$temp/late_cancellation.log"

psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT status='cancelled' AND version=2
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE id='$a')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE schedule_id='$a')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE schedule_id='$a')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 WHERE schedule_id='$a')
 AND (SELECT status='active' AND version=1
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE id='$b')
 AND (SELECT passengers_held=2
  FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE schedule_id='$b')
 AND (SELECT booked_seats=2
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id='$bo')
 AND (SELECT count(*)=1 FROM airlinerra_game.section9_passenger_reservation_batches_v1 WHERE occurrence_id='$bo')
 AND (SELECT count(*)=2 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 WHERE schedule_id='$b')
 AND (SELECT count(*)=1 FROM real_booking_cancel_lab.audit WHERE schedule_id='$a')
 AND (SELECT count(*)=0 FROM real_booking_cancel_lab.audit WHERE schedule_id='$b')
 THEN 'PASS-real-booking-both-orders'
 ELSE 'FAIL-real-booking-both-orders' END;
" | grep -qx PASS-real-booking-both-orders

echo 'PASS: unchanged real booking SQL vs isolated candidate in both lock orders; no ticket or slot loss.'
