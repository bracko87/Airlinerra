#!/usr/bin/env bash
# Race two direct executions of the reviewed, UNDEPLOYED two-leg ticket writer.
# The real stored procedure runs unchanged except for reviewed candidate fixes.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGDATABASE" = 'airlinerra_disposable'
test "$PGUSER" = 'postgres'
test "$PGPORT" = '5432'
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
allocation_key="s9g1:$(printf '%064d' 0 | tr '0' 'b')"
reservation_key="demand.$allocation_key"
first_occ='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
second_occ='ffffffff-ffff-4fff-8fff-ffffffffffff'
first_flight='88888888-8888-4888-8888-888888888888:2026-11-21:1'

# Previous acceptance leaves an issued pair; reset ONLY the disposable fixture.
# Seats were reserved by the demand planner and must remain held exactly once.
psql -X -qAt -v ON_ERROR_STOP=1 -c "
DELETE FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE reservation_key='$reservation_key';
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET booked_seats=0
 WHERE id IN ('$first_occ'::uuid,'$second_occ'::uuid);
" > "$temp_dir/reset.log"

# First session holds the same inventory row lock as the actual issuer,
# then runs the reviewed candidate inside its transaction.
cat > "$temp_dir/first.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id='$first_flight' FOR UPDATE;
\echo FIRST-ISSUER-LOCKED
SELECT pg_sleep(2);
SELECT airlinerra_game.section9_issue_verified_demand_hold_tickets_v1('$allocation_key')->>'status';
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$temp_dir/first.sql" > "$temp_dir/first.log" 2>&1 &
first_pid=$!
for i in $(seq 1 80); do
 if grep -qx 'FIRST-ISSUER-LOCKED' "$temp_dir/first.log" 2>/dev/null; then break; fi
 sleep 0.1
done
grep -qx 'FIRST-ISSUER-LOCKED' "$temp_dir/first.log"

# Second direct issuer waits on the capacity row and revalidates after commit.
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_issue_verified_demand_hold_tickets_v1('$allocation_key')->>'status';" \
 >"$temp_dir/second.log" 2>&1 &
second_pid=$!
wait "$second_pid"
wait "$first_pid"
grep -qx demand_hold_tickets_issued "$temp_dir/first.log"
grep -qx demand_tickets_already_issued "$temp_dir/second.log"

# Check both reserved ticket rows, booked-seat counts, unchanged held
# capacity and no charge/recognized revenue.
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
  WHERE reservation_key='$reservation_key' AND reservation_status='reserved'
    AND seats_requested=2 AND paid_upfront=false
    AND recognized_revenue_usd=0)=2
 AND (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1
  WHERE id IN ('$first_occ'::uuid,'$second_occ'::uuid) AND booked_seats=2)=2
 AND (SELECT count(*) FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
  WHERE schedule_id IN ('88888888-8888-4888-8888-888888888888'::uuid,
                       '99999999-9999-4999-8999-999999999999'::uuid)
    AND passengers_held=2)=2
 THEN 'PASS-DIRECT-TWO-LEG-ISSUER-RACE'
 ELSE 'FAIL-DIRECT-TWO-LEG-ISSUER-RACE' END;
" | grep -qx PASS-DIRECT-TWO-LEG-ISSUER-RACE
echo 'PASS: simultaneous direct issuers serialize on inventory rows; one writes both legs, other replays without extra tickets or money.'
