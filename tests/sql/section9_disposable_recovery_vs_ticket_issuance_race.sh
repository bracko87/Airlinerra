#!/usr/bin/env bash
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGPORT" = '5432'
test "$PGUSER" = 'postgres'
test "$PGDATABASE" = 'airlinerra_disposable'
t="$(mktemp -d)";trap 'rm -rf "$t"' EXIT
f1='88888888-8888-4888-8888-888888888888:2026-11-21:1'
f2='99999999-9999-4999-8999-999999999999:2026-11-21:1'
key_d="s9g1:$(printf '%064d' 0 | tr 0 f)"
key_e="s9g1:$(printf '%064d' 0 | tr 0 9)"
prepare() {
 psql -X -qAt -v ON_ERROR_STOP=1 <<SQL > "$t/prepare.log"
INSERT INTO airlinerra_game.section9_capacity_hold_plans_v1
 VALUES('$2',1,'completed',1,1,now());
INSERT INTO airlinerra_game.section9_atomic_itinerary_holds_v1
 VALUES('$1',ARRAY['$f1','$f2'],2,0,'preflight_only');
INSERT INTO airlinerra_game.section9_atomic_itinerary_hold_legs_v1
 VALUES('$1',1,'$f1'),('$1',2,'$f2');
INSERT INTO airlinerra_game.section9_capacity_hold_plan_items_v1
 (allocation_key,physical_flight_ids,passengers,cargo_tonnes,plan_id)
 VALUES('$1',ARRAY['$f1','$f2'],2,0,'$2');
UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET passengers_held=passengers_held+2 WHERE physical_flight_id IN ('$f1','$f2');
SQL
}
race() {
 local key="$1" locking="$2" leading="$3" following="$4" leader_expected="$5" follower_expected="$6"
 cat > "$t/leader.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.section9_atomic_itinerary_holds_v1 WHERE source_allocation_key='$key' $locking;
\echo LEADER-HOLD-LOCKED
SELECT pg_sleep(2);
SELECT $leading;
COMMIT;
SQL
 psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/leader.sql" > "$t/leader.log" 2>&1 &
 local leader=$!
 for i in $(seq 1 80);do
  if grep -qx LEADER-HOLD-LOCKED "$t/leader.log" 2>/dev/null;then break;fi
  sleep .1
 done
 grep -qx LEADER-HOLD-LOCKED "$t/leader.log"
 psql -X -qAt -v ON_ERROR_STOP=1 -c "SELECT $following;" > "$t/follower.log" 2>&1 &
 local follower=$!
 wait "$leader"
 wait "$follower"
 grep -qx "$leader_expected" "$t/leader.log" || { cat "$t/leader.log" "$t/follower.log";exit 1; }
 grep -qx "$follower_expected" "$t/follower.log" || { cat "$t/leader.log" "$t/follower.log";exit 1; }
}
# Recovery owns the hold first: no ticket can be issued after it cancels.
prepare "$key_d" 'aaaaaaaa-0000-4000-8000-000000000004'
race "$key_d" 'FOR UPDATE' \
 "airlinerra_game.section9_recover_connecting_passengers_v1('$key_d','$f2',1440)->>'status'" \
 "airlinerra_game.section9_issue_verified_demand_hold_tickets_v1('$key_d')->>'status'" \
 'connection_unflown_seats_released' 'blocked_missing_or_mixed_cargo_hold'
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1 WHERE reservation_key='demand.$key_d')=0
 AND (SELECT status FROM airlinerra_game.section9_atomic_itinerary_holds_v1 WHERE source_allocation_key='$key_d')='cancelled'
 AND (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id='$f1')=4
 AND (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id='$f2')=2
 AND (SELECT count(*) FROM airlinerra_game.section9_connection_recovery_receipts_v1 WHERE source_allocation_key='$key_d')=1
 THEN 'PASS-RECOVERY-FIRST' ELSE 'FAIL-RECOVERY-FIRST' END;" |grep -qx PASS-RECOVERY-FIRST
# Ticket writer owns hold first; recovery must wait and then rebook.
prepare "$key_e" 'aaaaaaaa-0000-4000-8000-000000000005'
race "$key_e" 'FOR SHARE' \
 "airlinerra_game.section9_issue_verified_demand_hold_tickets_v1('$key_e')->>'status'" \
 "airlinerra_game.section9_recover_connecting_passengers_v1('$key_e','$f2',1440)->>'status'" \
 'demand_hold_tickets_issued' 'connection_rebooked'
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE reservation_key='demand.$key_e' AND reservation_status='reserved')=1
 AND (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE reservation_key='demand.$key_e' AND reservation_status='cancelled')=1
 AND (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE occurrence_id='aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa'::uuid
 AND reservation_status='reserved')=2
 AND (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid)=6
 AND (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)=2
 AND (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa'::uuid)=4
 AND (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id='$f1')=6
 AND (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id='$f2')=2
 AND (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id='aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa:2026-11-21:1')=4
 AND (SELECT count(*) FROM airlinerra_game.section9_connection_recovery_receipts_v1
 WHERE source_allocation_key IN ('$key_d','$key_e'))=2
 THEN 'PASS-TICKET-FIRST' ELSE 'FAIL-TICKET-FIRST' END;" |grep -qx PASS-TICKET-FIRST
echo 'PASS real recovery and reviewed ticket issuance serialized in both lock orders without duplicate or partial passengers.'
