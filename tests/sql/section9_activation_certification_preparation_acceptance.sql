-- Section 9 activation preparation: ROLLBACK-ONLY negative security tests.
BEGIN;
DO $t$
DECLARE a uuid; owner_id uuid; code text; home text;
 plane uuid; sid uuid; result jsonb;
 old_schedules bigint;old_prepared bigint;old_moves bigint;
 old_pos bigint;old_money bigint; old_control bigint; old_cert bigint;
BEGIN
 SELECT count(*) INTO old_schedules
  FROM airlinerra_game.airline_flight_schedule_drafts_v1;
 SELECT count(*) INTO old_prepared
  FROM airlinerra_game.section9_schedule_activation_preparations_v1;
 SELECT count(*) INTO old_moves
  FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO old_pos
  FROM airlinerra_game.section9_aircraft_current_position_v1;
 SELECT count(*) INTO old_money FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO old_control
  FROM airlinerra_game.section9_activation_release_policy_v1;
 SELECT count(*) INTO old_cert
  FROM airlinerra_game.section9_schedule_operational_certifications_v1;

 IF has_function_privilege('authenticated',
  'airlinerra_game.section9_prepare_certified_schedule_activation_v1(uuid,uuid,uuid,integer,date,integer)',
  'EXECUTE')
 OR has_function_privilege('anon',
  'airlinerra_game.section9_prepare_certified_schedule_activation_v1(uuid,uuid,uuid,integer,date,integer)',
  'EXECUTE')
 OR has_table_privilege('authenticated',
  'airlinerra_game.section9_schedule_operational_certifications_v1','INSERT')
 OR has_table_privilege('anon',
  'airlinerra_game.section9_activation_release_policy_v1','SELECT')
 THEN RAISE EXCEPTION 'Private activation preparation exposed to browser';END IF;
 SELECT id,owner_player_id,iata_code,home_airport_key
 INTO a,owner_id,code,home FROM airlinerra_game.airlines
 WHERE world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'Need existing world1 test airline';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'S9-PREP-ROLLBACK','owned','in_service') RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,
  created_by_player_id)
 VALUES(a,plane,3,code||'977',home,
  CASE WHEN home='OURAIRPORTS:2212' THEN 'OURAIRPORTS:4610'
  ELSE 'OURAIRPORTS:2212' END,
  '2000-01-03T09:00:00Z','2000-01-03T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,owner_id)
 RETURNING id INTO sid;

 BEGIN
  PERFORM airlinerra_game.section9_prepare_certified_schedule_activation_v1(
   '11111111-1111-4111-8111-111111111111',a,sid,1,DATE '2000-01-03',28);
  RAISE EXCEPTION 'Unowned schedule accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 result:=airlinerra_game.section9_prepare_certified_schedule_activation_v1(
  owner_id,a,sid,2,DATE '2000-01-03',28);
 IF result->>'status'<>'blocked_stale_schedule_version'
  OR result->>'prepared'<>'false'
  OR result->>'flightActivated'<>'false'
 THEN RAISE EXCEPTION 'Stale version changed state: %',result;END IF;
 result:=airlinerra_game.section9_prepare_certified_schedule_activation_v1(
  owner_id,a,sid,1,DATE '2000-01-03',28);
 IF result->>'status'<>'blocked_activation_preparation'
  OR result->>'prepared'<>'false'
  OR result->>'flightActivated'<>'false'
  OR result->>'movementRecorded'<>'false'
  OR result->>'bookingsCreated'<>'false'
  OR result->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Unreleased flight was prepared: %',result;END IF;
 IF NOT result->'blockers' ? 'WORLD_NOT_OPEN' OR
  NOT result->'blockers' ? 'SIX_INDEPENDENT_OPERATIONAL_CERTIFICATIONS_MISSING'
 THEN RAISE EXCEPTION 'Core blockers absent: %',result;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_schedule_activation_preparations_v1)<>old_prepared
 OR (SELECT count(*) FROM airlinerra_game.section9_activation_release_policy_v1)<>old_control
 OR (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1)<>old_cert
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>old_moves
 OR (SELECT count(*) FROM airlinerra_game.section9_aircraft_current_position_v1)<>old_pos
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>old_money
 OR (SELECT status FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE id=sid)<>'draft'
 THEN RAISE EXCEPTION 'Certification attempt wrote activation or movements';END IF;
 RAISE NOTICE 'PASS: owner protected, version-fenced, world and six approvals absent, no activation';
END $t$;
ROLLBACK;