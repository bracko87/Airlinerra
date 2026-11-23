#!/usr/bin/env bash
# Disposable PG17-only actual cancellation versus finance-preparation
# row-lock/status protocol. The finance side is a precisely scoped protocol
# simulator; it is NOT the full, signed-arrival finance preparation writer.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGPORT" = '5432'
test "$PGUSER" = 'postgres'
test "$PGDATABASE" = 'airlinerra_disposable'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

owner='11111111-1111-4111-8111-111111111111'
aircraft='33333333-3333-4333-8333-333333333333'
schedule_a='cccccccc-1111-4111-8111-cccccccccccc'
schedule_b='dddddddd-1111-4111-8111-dddddddddddd'
occ_a='cccccccc-2222-4222-8222-cccccccccccc'
occ_b='dddddddd-2222-4222-8222-dddddddddddd'
flight_a="$schedule_a:2026-11-21:1"
flight_b="$schedule_b:2026-11-21:1"

# Test-only independent single-leg flights. Avoid existing connecting holds.
psql -X -qAt -v ON_ERROR_STOP=1 <<SQL >"$tmp/setup.log"
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1 VALUES
 ('$schedule_a',1,'$owner','$aircraft',100,1,'active',true,
 'OURAIRPORTS:2212','OURAIRPORTS:2218','LAB201','[]'::jsonb),
 ('$schedule_b',1,'$owner','$aircraft',100,1,'active',true,
 'OURAIRPORTS:2212','OURAIRPORTS:2218','LAB202','[]'::jsonb);
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
 id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,
 weekly_entry,flight_local_date,verified_passenger_seats,booked_seats,
 booking_status,source_kind,departure_utc,world_id,recognized_revenue_usd)
 VALUES
 ('$occ_a','$owner','$schedule_a','$aircraft',1,1,
 '2026-11-21',110,2,'open','game_verified_saleable_schedule_v1',
 '2026-11-21T16:00:00Z',1,0),
 ('$occ_b','$owner','$schedule_b','$aircraft',1,1,
 '2026-11-21',110,2,'open','game_verified_saleable_schedule_v1',
 '2026-11-21T17:00:00Z',1,0);
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,
 commercial_version,passenger_capacity,passengers_held,status,
 departure_utc,arrival_utc,cargo_held_tonnes)
 VALUES
 ('$flight_a','$schedule_a','$owner',1,1,110,2,'preflight_only',
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z',0),
 ('$flight_b','$schedule_b','$owner',1,1,110,2,'preflight_only',
 '2026-11-21T17:00:00Z','2026-11-21T18:00:00Z',0);
INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1(
 occurrence_id,reservation_key,fare_class,seats_requested,quoted_fare_usd,
 reservation_status,paid_upfront,recognized_revenue_usd)
 VALUES
 ('$occ_a','fixture.finance.race.a','economy',2,90,'reserved',false,0),
 ('$occ_b','fixture.finance.race.b','economy',2,90,'reserved',false,0);
SQL

# ORDER ONE: finance-preparation protocol acquires FOR SHARE capacity and
# occurrence rows, representing writer's verified closed/arrived transition.
# Cancellation waits and then sees closed flight, refusing mutation.
cat > "$tmp/preparation_leads.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id='$flight_a' FOR SHARE;
SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$occ_a'::uuid FOR SHARE;
\echo FINANCE-SHARE-LOCKED
SELECT pg_sleep(2);
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET booking_status='closed' WHERE id='$occ_a'::uuid;
INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1
 VALUES('$flight_a','UNPOSTED_GAME_ESTIMATE');
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$tmp/preparation_leads.sql" >"$tmp/finance_first.log" 2>&1 &
pid=$!
for i in $(seq 1 80);do
 if grep -qx 'FINANCE-SHARE-LOCKED' "$tmp/finance_first.log" 2>/dev/null;then break;fi
 sleep 0.1
done
grep -qx 'FINANCE-SHARE-LOCKED' "$tmp/finance_first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$occ_a'::uuid,'maximum_delay_exceeded')->>'status';" \
 >"$tmp/cancel_waits.log" 2>&1 &
follower=$!
wait "$pid"
wait "$follower"
grep -qx flight_not_cancellable "$tmp/cancel_waits.log" || {
 cat "$tmp/finance_first.log" "$tmp/cancel_waits.log"; exit 1;
}

# ORDER TWO: original cancellation takes capacity FOR UPDATE first.
# A finance-protocol reader waits for commit, then rechecks occurrence status.
cat > "$tmp/cancellation_leads.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id='$flight_b' FOR UPDATE;
\echo CANCELLATION-EXCLUSIVE-LOCKED
SELECT pg_sleep(2);
SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1(
 '$occ_b'::uuid,'maximum_delay_exceeded')->>'status';
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$tmp/cancellation_leads.sql" >"$tmp/cancel_first.log" 2>&1 &
pid=$!
for i in $(seq 1 80);do
 if grep -qx 'CANCELLATION-EXCLUSIVE-LOCKED' "$tmp/cancel_first.log" 2>/dev/null;then break;fi
 sleep 0.1
done
grep -qx 'CANCELLATION-EXCLUSIVE-LOCKED' "$tmp/cancel_first.log"
psql -X -qAt -v ON_ERROR_STOP=1 <<SQL >"$tmp/finance_waits.log" 2>&1 &
BEGIN;
SELECT 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id='$flight_b' FOR SHARE;
SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$occ_b'::uuid FOR SHARE;
SELECT CASE WHEN (SELECT booking_status
 FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$occ_b'::uuid)='closed'
 THEN 'PROTOCOL-READY' ELSE 'PROTOCOL-BLOCKED' END;
ROLLBACK;
SQL
follower=$!
wait "$pid"
wait "$follower"
grep -qx flight_cancelled "$tmp/cancel_first.log" || {
 cat "$tmp/cancel_first.log"; exit 1;
}
grep -qx PROTOCOL-BLOCKED "$tmp/finance_waits.log" || {
 cat "$tmp/finance_waits.log"; exit 1;
}

# Require strict settlement/cancellation outcomes, no refunded cash and no
# loss of paid or unrelated records. Race A is closed and retained; race B
# cancelled and zero-held, with a single immutable receipt.
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='$occ_a'::uuid)='closed'
 AND (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='$occ_a'::uuid)=2
 AND (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
   WHERE physical_flight_id='$flight_a')=2
 AND (SELECT count(*) FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
   WHERE physical_flight_id='$flight_a')=1
 AND (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='$occ_b'::uuid)='cancelled'
 AND (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='$occ_b'::uuid)=0
 AND (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
   WHERE physical_flight_id='$flight_b')=0
 AND (SELECT count(*) FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
   WHERE physical_flight_id='$flight_b')=0
 AND (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1
   WHERE occurrence_id='$occ_a'::uuid)=0
 AND (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1
   WHERE occurrence_id='$occ_b'::uuid)=1
 AND (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE occurrence_id='$occ_a'::uuid AND reservation_status='reserved')=1
 AND (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE occurrence_id='$occ_b'::uuid AND reservation_status='cancelled')=1
 THEN 'PASS-SETTLEMENT-CANCELLATION-LOCK-ORDERS'
 ELSE 'FAIL-SETTLEMENT-CANCELLATION-LOCK-ORDERS' END;
" |grep -qx PASS-SETTLEMENT-CANCELLATION-LOCK-ORDERS
echo 'PASS: original cancellation and simulated finance-preparation row-lock protocol serialize in both directions.'
