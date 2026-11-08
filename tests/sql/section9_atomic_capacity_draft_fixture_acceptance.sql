-- Rollback-only Section 9 physical inventory boundary checks.
-- A test DRAFT schedule may be used to exercise the inventory constraints,
-- but must still be forbidden from acquiring a commercial capacity hold.
BEGIN;
DO $test$
DECLARE a uuid;u uuid;code text;plane uuid;s uuid;pid text;
 passenger_rejected bool:=false;cargo_rejected bool:=false;hold_denied bool:=false;
 baseline_ledger bigint;baseline_cash numeric;
BEGIN
 SELECT id,owner_player_id,iata_code,cash_usd
 INTO a,u,code,baseline_cash
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'Need existing test airline';END IF;
 SELECT count(*) INTO baseline_ledger FROM airlinerra_game.airline_ledger;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'SECTION9-ATOMIC-ROLLBACK','owned','in_service')
 RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,plane,3,code||'973','OURAIRPORTS:2214','OURAIRPORTS:2212',
  '2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,u)
 RETURNING id INTO s;
 pid:=s::text||':2026-11-09:1';
 INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
  physical_flight_id,schedule_id,airline_id,local_departure_date,
  weekly_entry,schedule_version,commercial_version,
  origin_airport_key,destination_airport_key,departure_utc,arrival_utc,
  passenger_capacity,cargo_capacity_tonnes)
 VALUES(pid,s,a,'2026-11-09',1,1,1,
  'OURAIRPORTS:2214','OURAIRPORTS:2212',
  '2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',10,1.5);

 UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET passengers_held=10,cargo_held_tonnes=1.5 WHERE physical_flight_id=pid;
 BEGIN
  UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
  SET passengers_held=11 WHERE physical_flight_id=pid;
 EXCEPTION WHEN check_violation THEN passenger_rejected:=true;END;
 BEGIN
  UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
  SET cargo_held_tonnes=1.501 WHERE physical_flight_id=pid;
 EXCEPTION WHEN check_violation THEN cargo_rejected:=true;END;
 IF NOT passenger_rejected OR NOT cargo_rejected
 THEN RAISE EXCEPTION 'Physical overcapacity constraint failed';END IF;
 BEGIN
  PERFORM airlinerra_game.section9_hold_verified_itinerary_v1(
   's9-test-draft-block',ARRAY[pid],1,0::numeric);
 EXCEPTION WHEN SQLSTATE '42501' THEN hold_denied:=true;END;
 IF NOT hold_denied THEN RAISE EXCEPTION 'Draft inventory gained unauthorized itinerary hold';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_atomic_itinerary_holds_v1
  WHERE source_allocation_key='s9-test-draft-block')
 THEN RAISE EXCEPTION 'Failed draft hold persisted';END IF;
 IF (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=a)<>baseline_cash
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>baseline_ledger
 THEN RAISE EXCEPTION 'Airline finance mutated';END IF;
 RAISE NOTICE 'PASS capacity CHECK constraints, denied draft bypass, no financial mutation';
END $test$;
ROLLBACK;