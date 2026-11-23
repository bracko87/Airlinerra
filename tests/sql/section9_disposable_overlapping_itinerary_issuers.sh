#!/usr/bin/env bash
# Competing DIFFERENT itinerary keys with both physical flight legs shared.
# All writes target disposable PostgreSQL and pre-existing synthetic fixtures.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGPORT" = '5432'
test "$PGUSER" = 'postgres'
test "$PGDATABASE" = 'airlinerra_disposable'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
key_a="s9g1:$(printf '%064d' 0 | tr '0' 'b')"
key_b="s9g1:$(printf '%064d' 0 | tr '0' 'c')"
key_c="s9g1:$(printf '%064d' 0 | tr '0' 'd')"
one='88888888-8888-4888-8888-888888888888:2026-11-21:1'
two='99999999-9999-4999-8999-999999999999:2026-11-21:1'
occ_a='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
occ_b='ffffffff-ffff-4fff-8fff-ffffffffffff'

# Reset issued rows from prior acceptance and represent TWO committed
# allocations, each of two passengers, already held in the same inventories.
psql -X -qAt -v ON_ERROR_STOP=1 <<SQL > "$tmp/setup.log"
DELETE FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE occurrence_id IN ('$occ_a'::uuid,'$occ_b'::uuid);
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET booked_seats=0 WHERE id IN ('$occ_a'::uuid,'$occ_b'::uuid);
UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET passengers_held=4 WHERE physical_flight_id IN ('$one','$two');
INSERT INTO airlinerra_game.section9_capacity_hold_plans_v1
 VALUES('aaaaaaaa-0000-4000-8000-000000000002',1,'completed',1,1,now());
INSERT INTO airlinerra_game.section9_atomic_itinerary_holds_v1
 VALUES('$key_b',ARRAY['$one','$two'],2,0,'preflight_only');
INSERT INTO airlinerra_game.section9_atomic_itinerary_hold_legs_v1 VALUES
 ('$key_b',1,'$one'),('$key_b',2,'$two');
INSERT INTO airlinerra_game.section9_capacity_hold_plan_items_v1
 (allocation_key,physical_flight_ids,passengers,cargo_tonnes,plan_id)
 VALUES('$key_b',ARRAY['$one','$two'],2,0,
 'aaaaaaaa-0000-4000-8000-000000000002');
SQL

# Explicitly hold first physical inventory lock until the second session has
# begun waiting, then let the first writer issue both legs.
cat > "$tmp/first.sql" <<SQL
\\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id='$one' FOR UPDATE;
\\echo DIFFERENT-ITINERARY-FIRST-LOCKED
SELECT pg_sleep(2);
SELECT airlinerra_game.section9_issue_verified_demand_hold_tickets_v1('$key_a')->>'status';
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$tmp/first.sql" >"$tmp/first.log" 2>&1 &
first_pid=$!
for i in $(seq 1 80); do
 if grep -qx DIFFERENT-ITINERARY-FIRST-LOCKED "$tmp/first.log" 2>/dev/null; then break; fi
 sleep 0.1
done
grep -qx DIFFERENT-ITINERARY-FIRST-LOCKED "$tmp/first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_issue_verified_demand_hold_tickets_v1('$key_b')->>'status';" \
 > "$tmp/second.log" 2>&1 &
second_pid=$!
wait "$first_pid"
wait "$second_pid"
grep -qx demand_hold_tickets_issued "$tmp/first.log"
grep -qx demand_hold_tickets_issued "$tmp/second.log"

psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
  WHERE reservation_key IN ('demand.$key_a','demand.$key_b')
   AND reservation_status='reserved' AND seats_requested=2
   AND recognized_revenue_usd=0 AND paid_upfront=false)=4
 AND (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1
  WHERE id IN ('$occ_a'::uuid,'$occ_b'::uuid) AND booked_seats=4)=2
 AND (SELECT count(*) FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
  WHERE physical_flight_id IN ('$one','$two')
    AND passengers_held=4 AND passenger_capacity>=4)=2
 THEN 'PASS-TWO-DIFFERENT-ITINERARIES' ELSE 'FAIL-CAPACITY-RACE' END;
" | grep -qx PASS-TWO-DIFFERENT-ITINERARIES

# A third *unreserved* allocation has no additional held capacity. It must
# fail closed rather than issue an oversold/partially-issued connecting pair.
psql -X -qAt -v ON_ERROR_STOP=1 <<SQL > "$tmp/third_setup.log"
INSERT INTO airlinerra_game.section9_capacity_hold_plans_v1
 VALUES('aaaaaaaa-0000-4000-8000-000000000003',1,'completed',1,1,now());
INSERT INTO airlinerra_game.section9_atomic_itinerary_holds_v1
 VALUES('$key_c',ARRAY['$one','$two'],2,0,'preflight_only');
INSERT INTO airlinerra_game.section9_atomic_itinerary_hold_legs_v1 VALUES
 ('$key_c',1,'$one'),('$key_c',2,'$two');
INSERT INTO airlinerra_game.section9_capacity_hold_plan_items_v1
 (allocation_key,physical_flight_ids,passengers,cargo_tonnes,plan_id)
 VALUES('$key_c',ARRAY['$one','$two'],2,0,
 'aaaaaaaa-0000-4000-8000-000000000003');
SQL
psql -X -v ON_ERROR_STOP=1 -qAt -c "
DO \$test\$
DECLARE caught boolean:=false;
BEGIN
 BEGIN
  PERFORM airlinerra_game.section9_issue_verified_demand_hold_tickets_v1('$key_c');
 EXCEPTION WHEN SQLSTATE '23505' THEN caught:=true;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'Unreserved third itinerary was accepted';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
     WHERE reservation_key IN ('demand.$key_a','demand.$key_b'))<>4
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_reservation_batches_v1
     WHERE reservation_key='demand.$key_c')
 OR (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id IN ('$occ_a'::uuid,'$occ_b'::uuid) AND booked_seats=4)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
     WHERE physical_flight_id IN ('$one','$two') AND passengers_held=4)<>2
 THEN RAISE EXCEPTION 'Rejected third itinerary changed committed seats';END IF;
END \$test\$;
" > "$tmp/third_rejected.log"
echo 'PASS: distinct connecting journeys share physical legs safely, and an unheld third journey cannot add passengers.'
