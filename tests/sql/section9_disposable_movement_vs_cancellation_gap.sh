#!/usr/bin/env bash
# Disposable-only reproduction of movement read-without-row-lock race,
# plus corrected FOR SHARE protocol in both orders.
# Movement publication is a narrow simulator of the original writer's
# SELECT dated status + INSERT sequence, not a signed-HMAC invocation.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGPORT" = '5432'
test "$PGUSER" = 'postgres'
test "$PGDATABASE" = 'airlinerra_disposable'
t="$(mktemp -d)";trap 'rm -rf "$t"' EXIT
owner='11111111-1111-4111-8111-111111111111'
sc1='fafafafa-1111-4111-8111-fafafafafafa'
sc2='fafafafa-2222-4222-8222-fafafafafafa'
sc3='fafafafa-3333-4333-8333-fafafafafafa'
oc1='fafafafa-4444-4444-8444-fafafafafafa'
oc2='fafafafa-5555-4555-8555-fafafafafafa'
oc3='fafafafa-6666-4666-8666-fafafafafafa'
f1="$sc1:2026-11-21:1";f2="$sc2:2026-11-21:1";f3="$sc3:2026-11-21:1"

psql -X -qAt -v ON_ERROR_STOP=1 <<SQL > "$t/setup.log"
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
 id,world_id,airline_id,aircraft_inventory_id,configuration_id,version,
 status,operationally_verified,origin_airport_key,destination_airport_key,
 flight_number,weekly_schedule)
SELECT v.sid,s.world_id,s.airline_id,s.aircraft_inventory_id,
 s.configuration_id,s.version,s.status,s.operationally_verified,
 s.origin_airport_key,s.destination_airport_key,v.number,s.weekly_schedule
FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
CROSS JOIN (VALUES('$sc1'::uuid,'LAB401'),('$sc2'::uuid,'LAB402'),
 ('$sc3'::uuid,'LAB403')) v(sid,number)
WHERE s.id='eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid;
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
 id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,
 flight_local_date,verified_passenger_seats,booked_seats,booking_status,source_kind,
 departure_utc,world_id,recognized_revenue_usd)
SELECT v.occ,'$owner'::uuid,v.sid,'33333333-3333-4333-8333-333333333333',
 1,1,'2026-11-21'::date,110,0,'open',
 'game_verified_saleable_schedule_v1','2026-11-21T16:00:00Z'::timestamptz,1,0
FROM (VALUES('$oc1'::uuid,'$sc1'::uuid),('$oc2'::uuid,'$sc2'::uuid),
 ('$oc3'::uuid,'$sc3'::uuid)) v(occ,sid);
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,commercial_version,
 passenger_capacity,passengers_held,status,departure_utc,arrival_utc,cargo_held_tonnes)
SELECT v.flight,v.sid,'$owner'::uuid,1,1,110,0,'preflight_only',
 '2026-11-21T16:00:00Z'::timestamptz,'2026-11-21T17:00:00Z'::timestamptz,0
FROM (VALUES('$f1'::text,'$sc1'::uuid),('$f2'::text,'$sc2'::uuid),
 ('$f3'::text,'$sc3'::uuid)) v(flight,sid);
SQL

# Case 1: faithful original status read has NO row lock.
# Real cancellation commits, then movement insert completes on stale status.
cat >"$t/stale_reader.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT CASE WHEN booking_status='open' THEN 'MOVEMENT-SEES-OPEN'
 ELSE 'MOVEMENT-BLOCKED' END FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$oc1'::uuid;
\echo MOVEMENT-STATUS-READ
SELECT pg_sleep(2);
INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(
 schedule_id,flight_local_date,weekly_entry,flight_occurrence_id,phase,actual_event_utc)
 VALUES('$sc1'::uuid,'2026-11-21',1,'$f1','departed','2026-11-21T16:00:00Z');
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/stale_reader.sql" >"$t/stale_reader.log" 2>&1 &
a=$!
for i in $(seq 1 80);do grep -qx MOVEMENT-STATUS-READ "$t/stale_reader.log" 2>/dev/null && break;sleep .1;done
grep -qx MOVEMENT-SEES-OPEN "$t/stale_reader.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$oc1'::uuid,'maximum_delay_exceeded')->>'status';" \
 > "$t/stale_cancel.log"
grep -qx flight_cancelled "$t/stale_cancel.log"
wait "$a"
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id='$oc1'::uuid)='cancelled'
 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1
  WHERE flight_occurrence_id='$f1' AND phase='departed')
 THEN 'PASS-DEMONSTRATED-UNSAFE-STALENESS' ELSE 'FAIL-DID-NOT-REPRODUCE' END;" \
 |grep -qx PASS-DEMONSTRATED-UNSAFE-STALENESS

# Case 2: suggested movement FOR SHARE lock held first. Real cancellation
# cannot pass the occurrence FOR UPDATE until signed-movement insert commits.
cat >"$t/lock_first.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT CASE WHEN booking_status='open' THEN 'LOCKED-MOVEMENT-OPEN' ELSE 'ERROR' END
 FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$oc2'::uuid FOR SHARE;
\echo MOVEMENT-OCCURRENCE-SHARE-LOCKED
SELECT pg_sleep(2);
INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(
 schedule_id,flight_local_date,weekly_entry,flight_occurrence_id,phase,actual_event_utc)
 VALUES('$sc2'::uuid,'2026-11-21',1,'$f2','departed','2026-11-21T16:00:00Z');
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/lock_first.sql" >"$t/lock_first.log" 2>&1 &
a=$!
for i in $(seq 1 80);do grep -qx MOVEMENT-OCCURRENCE-SHARE-LOCKED "$t/lock_first.log" 2>/dev/null && break;sleep .1;done
grep -qx MOVEMENT-OCCURRENCE-SHARE-LOCKED "$t/lock_first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$oc2'::uuid,'maximum_delay_exceeded')->>'status';" \
 > "$t/lock_cancel.log" 2>&1 &
b=$!
wait "$a";wait "$b"
grep -qx flight_already_operated_or_settled "$t/lock_cancel.log"

# Case 3: original cancellation takes exclusive lock first; proposed
# movement lock waits, rechecks status, and must reject cancelled flights.
cat >"$t/cancel_first.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT id FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$oc3'::uuid FOR UPDATE;
\echo CANCEL-EXCLUSIVE-LOCKED
SELECT pg_sleep(2);
SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1(
 '$oc3'::uuid,'maximum_delay_exceeded')->>'status';
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/cancel_first.sql" >"$t/cancel_first.log" 2>&1 &
a=$!
for i in $(seq 1 80);do grep -qx CANCEL-EXCLUSIVE-LOCKED "$t/cancel_first.log" 2>/dev/null && break;sleep .1;done
grep -qx CANCEL-EXCLUSIVE-LOCKED "$t/cancel_first.log"
psql -X -qAt -v ON_ERROR_STOP=1 <<SQL >"$t/move_waits.log" 2>&1 &
BEGIN;
SELECT CASE WHEN booking_status='cancelled' THEN 'PROPOSED-MOVEMENT-BLOCKS'
 ELSE 'UNSAFE-MOVEMENT' END
 FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$oc3'::uuid FOR SHARE;
ROLLBACK;
SQL
b=$!
wait "$a";wait "$b"
grep -qx flight_cancelled "$t/cancel_first.log"
grep -qx PROPOSED-MOVEMENT-BLOCKS "$t/move_waits.log"

psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id='$oc2'::uuid)='open'
 AND (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id='$oc3'::uuid)='cancelled'
 AND (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id='$f2')=1
 AND (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id='$f3')=0
 THEN 'PASS-PROPOSED-LOCK-ORDERS'
 ELSE 'FAIL-PROPOSED-LOCK-ORDERS' END;" |grep -qx PASS-PROPOSED-LOCK-ORDERS
echo 'PASS: reproduced stale-read race in original movement publication protocol; synthetic FOR SHARE correction prevented both orders.'
