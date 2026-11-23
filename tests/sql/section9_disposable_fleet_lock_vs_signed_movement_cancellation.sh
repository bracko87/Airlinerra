#!/usr/bin/env bash
# Disposable PostgreSQL 17 only. Reproduce maintenance-style fleet row
# lock blocking signed movement while ORIGINAL cancellation commits independently.
# The maintenance side is a row-lock simulator. Movement and cancellation
# execute their actual private functions, with synthetic world/aircraft evidence.
set -euo pipefail
test "$PGHOST" = 127.0.0.1
test "$PGPORT" = 5432
test "$PGUSER" = postgres
test "$PGDATABASE" = airlinerra_disposable
t="$(mktemp -d)";trap 'rm -rf "$t"' EXIT
owner='11111111-1111-4111-8111-111111111111'
sid='dededede-1111-4111-8111-dededededede'
oid='dededede-2222-4222-8222-dededededede'
aircraft='dededede-3333-4333-8333-dededededede'
flight="$sid:2026-11-21:1"
eid='signed-maintenance-fleet-race-20261123'

psql -X -qAt -v ON_ERROR_STOP=1 <<SQL >"$t/setup.log"
INSERT INTO airlinerra_game.airline_aircraft_inventory(
 id,airline_id,fleet_status,ownership_type,configuration_id,registration)
 VALUES('$aircraft','$owner','in_service','owned',100,'TEST-FLEET-LOCK');
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
 id,world_id,airline_id,aircraft_inventory_id,configuration_id,version,
 status,operationally_verified,origin_airport_key,destination_airport_key,
 flight_number,weekly_schedule,reference_departure_utc,reference_arrival_utc)
 VALUES('$sid',1,'$owner','$aircraft',100,1,'active',true,
 'OURAIRPORTS:2212','OURAIRPORTS:2218','TEST504',
 '[{"day":5,"time":"16:00"}]'::jsonb,
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z');
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
 id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,
 weekly_entry,flight_local_date,verified_passenger_seats,booked_seats,
 booking_status,source_kind,departure_utc,arrival_utc,world_id,
 recognized_revenue_usd)
 VALUES('$oid','$owner','$sid','$aircraft',1,1,'2026-11-21',110,0,
 'open','game_verified_saleable_schedule_v1',
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z',1,0);
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,
 commercial_version,passenger_capacity,passengers_held,status,
 departure_utc,arrival_utc,cargo_held_tonnes)
 VALUES('$flight','$sid','$owner',1,1,110,0,'preflight_only',
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z',0);
SQL

cat >"$t/maintenance_hold.sql" <<SQL
\\set ON_ERROR_STOP on
BEGIN;
SELECT id FROM airlinerra_game.airline_aircraft_inventory
 WHERE id='$aircraft'::uuid FOR UPDATE;
\\echo MAINTENANCE-FLEET-EXCLUSIVE-LOCKED
SELECT pg_sleep(4);
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/maintenance_hold.sql" >"$t/maint.log" 2>&1 &
a=$!
for i in $(seq 1 100);do
 grep -qx MAINTENANCE-FLEET-EXCLUSIVE-LOCKED "$t/maint.log" 2>/dev/null && break
 sleep .05
done
grep -qx MAINTENANCE-FLEET-EXCLUSIVE-LOCKED "$t/maint.log"

cat >"$t/signed.sql" <<SQL
\\set ON_ERROR_STOP on
SELECT airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 '$owner'::uuid,'$sid'::uuid,1,'2026-11-21',1,'departed',
 '2026-11-21T16:00:00Z'::timestamptz,'$eid',
 encode(extensions.hmac(
  convert_to(concat_ws(E'\\n',
   'airlinerra-operated-game-event-v1','1',
   '$owner','$sid','1','2026-11-21','1','departed',
   '2026-11-21T16:00:00Z','$eid'),'UTF8'),
  convert_to(repeat('t',80),'UTF8'),'sha256'),'hex'))->>'status';
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/signed.sql" >"$t/movement.log" 2>&1 &
b=$!

# Observe an actual server-side blocking relationship, not just a sleep.
blocked=0
for i in $(seq 1 70);do
 if psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE
    query LIKE '%$eid%' AND state='active' AND
    cardinality(pg_blocking_pids(pid))>0);" |grep -qx t;then
  blocked=1;break
 fi
 sleep .05
done
if [ "$blocked" -ne 1 ];then
 echo 'FAIL: actual signed writer was not observed waiting on fleet lock'
 cat "$t/maint.log" "$t/movement.log"
 exit 1
fi

# Unflown cancellation should complete before the maintenance row is
# released and, on release, movement must see the committed cancellation.
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$oid'::uuid,'maximum_delay_exceeded')->>'status';" \
 >"$t/cancel.log" 2>&1
grep -qx flight_cancelled "$t/cancel.log" || { cat "$t/cancel.log"; exit 1; }
wait "$a"
if wait "$b";then
 echo 'FAIL: signed movement unexpectedly accepted cancelled flight'
 cat "$t/movement.log";exit 1
fi
grep -q SECTION9_CANCELLED_OCCURRENCE_MOVEMENT_FORBIDDEN "$t/movement.log"

psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='$oid'::uuid)='cancelled'
 AND (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1
   WHERE flight_occurrence_id='$flight')=0
 AND (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1
   WHERE occurrence_id='$oid'::uuid)=1
 THEN 'PASS-FLEET-LOCK-CANCEL-MOVEMENT-ORDER'
 ELSE 'FAIL-FLEET-LOCK-CANCEL-MOVEMENT-ORDER' END;
" |grep -qx PASS-FLEET-LOCK-CANCEL-MOVEMENT-ORDER

echo 'PASS maintenance-style fleet lock -> signed movement wait -> original cancellation -> signed writer fail-closed.'
