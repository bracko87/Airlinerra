#!/usr/bin/env bash
# Disposable-only fuel custody lock protocol vs ACTUAL signed movement
# and cancellation. Fuel verification itself is synthetic, not certified.
set -euo pipefail
test "$PGHOST" = 127.0.0.1
test "$PGPORT" = 5432
test "$PGUSER" = postgres
test "$PGDATABASE" = airlinerra_disposable
t="$(mktemp -d)";trap 'rm -rf "$t"' EXIT
owner='11111111-1111-4111-8111-111111111111'
s1='efefefef-1111-4111-8111-efefefefefef'
s2='efefefef-2222-4222-8222-efefefefefef'
o1='efefefef-3333-4333-8333-efefefefefef'
o2='efefefef-4444-4444-8444-efefefefefef'
a1='efefefef-5555-4555-8555-efefefefefef'
a2='efefefef-6666-4666-8666-efefefefefef'
f1="$s1:2026-11-21:1";f2="$s2:2026-11-21:1"
psql -X -qAt -v ON_ERROR_STOP=1 <<SQL >"$t/setup.log"
CREATE TABLE airlinerra_game.fixture_fuel_custody_lock_v1(
 aircraft_inventory_id uuid PRIMARY KEY,airline_id uuid,onboard_kg numeric);
INSERT INTO airlinerra_game.airline_aircraft_inventory(
 id,airline_id,fleet_status,ownership_type,configuration_id,registration)
 VALUES('$a1','$owner','in_service','owned',100,'FUEL-LOCK1'),
 ('$a2','$owner','in_service','owned',100,'FUEL-LOCK2');
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
 id,world_id,airline_id,aircraft_inventory_id,configuration_id,version,
 status,operationally_verified,origin_airport_key,destination_airport_key,
 flight_number,weekly_schedule,reference_departure_utc,reference_arrival_utc)
 VALUES
 ('$s1',1,'$owner','$a1',100,1,'active',true,'OURAIRPORTS:2212',
 'OURAIRPORTS:2218','TEST601','[{"day":5,"time":"16:00"}]'::jsonb,
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z'),
 ('$s2',1,'$owner','$a2',100,1,'active',true,'OURAIRPORTS:2212',
 'OURAIRPORTS:2218','TEST602','[{"day":5,"time":"16:00"}]'::jsonb,
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z');
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
 id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,
 weekly_entry,flight_local_date,verified_passenger_seats,booked_seats,
 booking_status,source_kind,departure_utc,arrival_utc,world_id,
 recognized_revenue_usd)
 VALUES
 ('$o1','$owner','$s1','$a1',1,1,'2026-11-21',110,0,'open',
 'game_verified_saleable_schedule_v1','2026-11-21T16:00:00Z',
 '2026-11-21T17:00:00Z',1,0),
 ('$o2','$owner','$s2','$a2',1,1,'2026-11-21',110,0,'open',
 'game_verified_saleable_schedule_v1','2026-11-21T16:00:00Z',
 '2026-11-21T17:00:00Z',1,0);
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,
 commercial_version,passenger_capacity,passengers_held,status,
 departure_utc,arrival_utc,cargo_held_tonnes)
 VALUES
 ('$f1','$s1','$owner',1,1,110,0,'preflight_only',
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z',0),
 ('$f2','$s2','$owner',1,1,110,0,'preflight_only',
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z',0);
INSERT INTO airlinerra_game.fixture_fuel_custody_lock_v1 VALUES
 ('$a1','$owner',2000),('$a2','$owner',2000);
SQL
signed_call() {
 local sid="$1" eid="$2"
 cat <<SQL
SELECT airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 '$owner'::uuid,'$sid'::uuid,1,'2026-11-21',1,'departed',
 '2026-11-21T16:00:00Z'::timestamptz,'$eid',
 encode(extensions.hmac(convert_to(concat_ws(E'\\n',
  'airlinerra-operated-game-event-v1','1','$owner','$sid','1',
  '2026-11-21','1','departed','2026-11-21T16:00:00Z','$eid'),
  'UTF8'),convert_to(repeat('t',80),'UTF8'),'sha256'),'hex'))->>'status';
SQL
}
# Flight 1: fuel custody and occurrence lock held by dispatcher.
cat >"$t/first.sql" <<SQL
\\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.fixture_fuel_custody_lock_v1
 WHERE aircraft_inventory_id='$a1'::uuid FOR UPDATE;
SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$o1'::uuid FOR SHARE;
\\echo FUEL-AND-OCCURRENCE-HELD
SELECT pg_sleep(2);
$(signed_call "$s1" "signed-fuel-first-20261123")
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/first.sql" >"$t/first.log" 2>&1 &
p=$!
for i in $(seq 1 80);do grep -qx FUEL-AND-OCCURRENCE-HELD "$t/first.log" 2>/dev/null && break;sleep .05;done
grep -qx FUEL-AND-OCCURRENCE-HELD "$t/first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$o1'::uuid,'maximum_delay_exceeded')->>'status';" \
 >"$t/late_cancel.log" 2>&1 &
q=$!
wait "$p";wait "$q"
grep -qx operated_flight_departure_recorded "$t/first.log"
grep -qx flight_already_operated_or_settled "$t/late_cancel.log"

# Flight 2: fuel custody locked but occurrence not yet. Cancellation wins.
cat >"$t/second.sql" <<SQL
\\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.fixture_fuel_custody_lock_v1
 WHERE aircraft_inventory_id='$a2'::uuid FOR UPDATE;
\\echo FUEL-ONLY-HELD
SELECT pg_sleep(2);
$(signed_call "$s2" "signed-fuel-second-20261123")
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/second.sql" >"$t/second.log" 2>&1 &
p=$!
for i in $(seq 1 80);do grep -qx FUEL-ONLY-HELD "$t/second.log" 2>/dev/null && break;sleep .05;done
grep -qx FUEL-ONLY-HELD "$t/second.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$o2'::uuid,'maximum_delay_exceeded')->>'status';" \
 >"$t/early_cancel.log" 2>&1
grep -qx flight_cancelled "$t/early_cancel.log"
if wait "$p";then echo 'FAIL cancelled flight departed';cat "$t/second.log";exit 1;fi
grep -q SECTION9_CANCELLED_OCCURRENCE_MOVEMENT_FORBIDDEN "$t/second.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id='$o1'::uuid)='open'
 AND (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id='$o2'::uuid)='cancelled'
 AND (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id='$f1' AND phase='departed')=1
 AND (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id='$f2')=0
 AND (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1 WHERE occurrence_id='$o1'::uuid)=0
 AND (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1 WHERE occurrence_id='$o2'::uuid)=1
 AND (SELECT count(*) FROM airlinerra_game.fixture_fuel_custody_lock_v1 WHERE onboard_kg=2000)=2
 THEN 'PASS-FUEL-CUSTODY-MOVEMENT-CANCELLATION'
 ELSE 'FAIL-FUEL-CUSTODY-MOVEMENT-CANCELLATION' END;
" |grep -qx PASS-FUEL-CUSTODY-MOVEMENT-CANCELLATION
echo 'PASS synthetic fuel custody locks and actual signed movement / cancellation in both orders.'
