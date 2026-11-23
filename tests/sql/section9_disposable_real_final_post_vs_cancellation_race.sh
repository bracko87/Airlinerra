#!/usr/bin/env bash
# Disposable-only race: unchanged final money writer versus unchanged
# unflown cancellation worker on two independently completed synthetic flights.
# Synthetic HMAC, ticket and fuel proofs were installed by prior acceptance;
# this does NOT test actual signed operational evidence.
set -euo pipefail
test "$PGHOST" = 127.0.0.1
test "$PGPORT" = 5432
test "$PGUSER" = postgres
test "$PGDATABASE" = airlinerra_disposable
t="$(mktemp -d)";trap 'rm -rf "$t"' EXIT
owner='11111111-1111-4111-8111-111111111111'
s1='eeeeeeee-3333-4333-8333-eeeeeeeeeeee'
s2='eeeeeeee-5555-4555-8555-eeeeeeeeeeee'
o1='eeeeeeee-4444-4444-8444-eeeeeeeeeeee'
o2='eeeeeeee-6666-4666-8666-eeeeeeeeeeee'
f1="$s1:2026-11-21:1"
f2="$s2:2026-11-21:1"
seed='eeeeeeee-1111-4111-8111-eeeeeeeeeeee:2026-11-21:1'

psql -X -qAt -v ON_ERROR_STOP=1 <<SQL > "$t/setup.log"
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
 id,world_id,airline_id,aircraft_inventory_id,configuration_id,version,
 status,operationally_verified,origin_airport_key,destination_airport_key,
 flight_number,weekly_schedule)
SELECT v.schedule_id, s.world_id,s.airline_id,s.aircraft_inventory_id,
 s.configuration_id,s.version,s.status,s.operationally_verified,
 s.origin_airport_key,s.destination_airport_key,v.flight_number,s.weekly_schedule
FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
CROSS JOIN (VALUES('$s1'::uuid,'LAB311'),('$s2'::uuid,'LAB312')) v(schedule_id,flight_number)
WHERE s.id='eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid;

INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
 id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,
 flight_local_date,verified_passenger_seats,booked_seats,booking_status,source_kind,
 departure_utc,world_id,recognized_revenue_usd)
VALUES
 ('$o1','$owner','$s1','33333333-3333-4333-8333-333333333333',1,1,
 '2026-11-21',110,2,'closed','game_verified_saleable_schedule_v1',
 '2026-11-21T16:00:00Z',1,0),
 ('$o2','$owner','$s2','33333333-3333-4333-8333-333333333333',1,1,
 '2026-11-21',110,2,'closed','game_verified_saleable_schedule_v1',
 '2026-11-21T17:00:00Z',1,0);

INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,commercial_version,
 passenger_capacity,passengers_held,status,departure_utc,arrival_utc,cargo_held_tonnes)
VALUES
 ('$f1','$s1','$owner',1,1,110,2,'preflight_only',
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z',0),
 ('$f2','$s2','$owner',1,1,110,2,'preflight_only',
 '2026-11-21T17:00:00Z','2026-11-21T18:00:00Z',0);

INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1(
 occurrence_id,reservation_key,fare_class,seats_requested,quoted_fare_usd,
 reservation_status,paid_upfront,recognized_revenue_usd)
VALUES
 ('$o1','fixture.closed.settlement.race1','economy',2,150,'reserved',false,0),
 ('$o2','fixture.closed.settlement.race2','economy',2,150,'reserved',false,0);

INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1(
 physical_flight_id,preparation_status,source_version,airline_id,schedule_id,
 arrival_event_id,passenger_count,ticket_quote_usd,flight_local_date)
SELECT v.flight, p.preparation_status,p.source_version,p.airline_id,
 v.schedule_id,p.arrival_event_id,p.passenger_count,p.ticket_quote_usd,p.flight_local_date
FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1 p
CROSS JOIN (VALUES('$f1'::text,'$s1'::uuid),('$f2'::text,'$s2'::uuid)) v(flight,schedule_id)
WHERE p.physical_flight_id='$seed';

INSERT INTO airlinerra_game.section9_flight_final_cost_approvals_v1
SELECT v.flight,a.approval_state,a.approved_at,a.approval_reference,
 a.fuel_reserve_verified,a.fuel_reserve_kg,a.fuel_source_reference,
 a.tariff_source_reference,a.airline_id,a.arrived_event_id,
 a.fuel_cost_usd,a.airport_navigation_cost_usd,a.crew_cost_usd,
 a.maintenance_cost_usd,a.ownership_cost_usd,a.other_cost_usd,
 a.airport_fee_lines,a.tariff_model_version
FROM airlinerra_game.section9_flight_final_cost_approvals_v1 a
CROSS JOIN (VALUES('$f1'::text),('$f2'::text)) v(flight)
WHERE a.physical_flight_id='$seed';
SQL

# Settlement starts: hold its exact finance-preparation row, then execute
# original posting while independent cancellation attempts the same flight.
cat > "$t/post_first.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id='$f1' FOR UPDATE;
\echo FINAL-POSTING-STARTED
SELECT pg_sleep(2);
SELECT airlinerra_game.section9_post_completed_flight_finance_once_v1('$f1')->>'status';
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/post_first.sql" > "$t/post_first.log" 2>&1 &
a=$!
for i in $(seq 1 80);do
 grep -qx FINAL-POSTING-STARTED "$t/post_first.log" 2>/dev/null && break
 sleep .1
done
grep -qx FINAL-POSTING-STARTED "$t/post_first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$o1'::uuid,'maximum_delay_exceeded')->>'status';" \
 > "$t/cancel_second.log" 2>&1 &
b=$!
wait "$a";wait "$b"
grep -qx verified_complete_flight_finance_posted_once "$t/post_first.log" || {
 cat "$t/post_first.log"; exit 1;
}
grep -qx flight_not_cancellable "$t/cancel_second.log" || {
 cat "$t/cancel_second.log"; exit 1;
}

# Cancellation attempts first on another already-closed, prepared flight.
# It must fail closed; independent finance writer may post once.
cat > "$t/cancel_first.sql" <<SQL
\set ON_ERROR_STOP on
BEGIN;
SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$o2'::uuid FOR UPDATE;
\echo CANCELLATION-STARTED
SELECT pg_sleep(2);
SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$o2'::uuid,'maximum_delay_exceeded')->>'status';
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/cancel_first.sql" > "$t/cancel_first.log" 2>&1 &
a=$!
for i in $(seq 1 80);do
 grep -qx CANCELLATION-STARTED "$t/cancel_first.log" 2>/dev/null && break
 sleep .1
done
grep -qx CANCELLATION-STARTED "$t/cancel_first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_post_completed_flight_finance_once_v1('$f2')->>'status';" \
 > "$t/post_second.log" 2>&1 &
b=$!
wait "$a";wait "$b"
grep -qx flight_not_cancellable "$t/cancel_first.log" || {
 cat "$t/cancel_first.log"; exit 1;
}
grep -qx verified_complete_flight_finance_posted_once "$t/post_second.log" || {
 cat "$t/post_second.log"; exit 1;
}

# Each flight posts exactly once (+300 and -100), no cancellation receipts,
# and total airline cash reconciles against all ledger entries.
psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT count(*) FROM airlinerra_game.section9_route_posted_flight_financials_v1
   WHERE physical_flight_id IN ('$f1','$f2')
     AND record_status='posted_complete'
     AND ticket_income_usd=300
     AND fuel_cost_usd=80 AND airport_navigation_cost_usd=20)=2
 AND (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1
   WHERE occurrence_id IN ('$o1'::uuid,'$o2'::uuid))=0
 AND (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id IN ('$o1'::uuid,'$o2'::uuid)
     AND booking_status='closed' AND booked_seats=2)=2
 AND (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE occurrence_id IN ('$o1'::uuid,'$o2'::uuid)
     AND reservation_status='reserved')=2
 AND (SELECT cash_usd FROM airlinerra_game.airlines WHERE id='$owner'::uuid)
   =(SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger
     WHERE airline_id='$owner'::uuid)
 AND (SELECT count(*) FROM airlinerra_game.airline_ledger l
   JOIN airlinerra_game.section9_route_posted_flight_financials_v1 p
    ON l.id=p.revenue_ledger_id
   WHERE p.physical_flight_id IN ('$f1','$f2')
     AND l.entry_kind='REVENUE' AND l.amount_usd=300)=2
 AND (SELECT count(*) FROM airlinerra_game.airline_ledger l
   JOIN airlinerra_game.section9_route_posted_flight_financials_v1 p
    ON l.id=p.expense_ledger_id
   WHERE p.physical_flight_id IN ('$f1','$f2')
     AND l.entry_kind='EXPENSE' AND l.amount_usd=-100)=2
 THEN 'PASS-FINANCE-VS-CANCELLATION-POSTED'
 ELSE 'FAIL-FINANCE-VS-CANCELLATION-POSTED' END;
" |grep -qx PASS-FINANCE-VS-CANCELLATION-POSTED
echo 'PASS original final posting vs original cancellation on closed prepared flights in both orderings, no double money.'
