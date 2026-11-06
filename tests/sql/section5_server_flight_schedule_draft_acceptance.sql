-- Disposable World 1 owned-fleet schedule draft and activation guard test.
-- TEST FIXTURE IS FULLY ROLLED BACK. Never creates a live aircraft or flight.
BEGIN;
DO $tests$
DECLARE airline uuid; owner uuid; iata text; plane uuid; v jsonb; ready jsonb;
 unauthorized boolean:=false; curfew_denied boolean:=false; direct_activation_denied boolean:=false;
 missing_fleet_denied boolean:=false;
BEGIN
 SELECT a.id,a.owner_player_id,a.iata_code INTO airline,owner,iata
 FROM airlinerra_game.airlines a WHERE a.world_id=1 LIMIT 1;
 IF airline IS NULL OR iata IS NULL THEN RAISE EXCEPTION 'No configured airline for isolated test'; END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
 airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(airline,3,'TEST-SCHED-ROLLBACK-96','owned','in_service')
 RETURNING id INTO plane;
 BEGIN
  PERFORM airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
   gen_random_uuid(),airline,plane,iata||'941',
   'OURAIRPORTS:2220','OURAIRPORTS:4001',
   '2026-11-06T10:00:00Z'::timestamptz,'2026-11-06T12:00:00Z'::timestamptz,
   '[{"day":0,"time":"13:00"}]'::jsonb);
 EXCEPTION WHEN SQLSTATE '42501' THEN unauthorized:=true; END;
 IF NOT unauthorized THEN RAISE EXCEPTION 'Foreign user wrote a draft'; END IF;

 BEGIN
  PERFORM airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
   owner,airline,gen_random_uuid(),iata||'941',
   'OURAIRPORTS:2220','OURAIRPORTS:4001',
   '2026-11-06T10:00:00Z'::timestamptz,'2026-11-06T12:00:00Z'::timestamptz,
   '[{"day":0,"time":"13:00"}]'::jsonb);
 EXCEPTION WHEN SQLSTATE 'P0001' THEN missing_fleet_denied:=true; END;
 IF NOT missing_fleet_denied THEN RAISE EXCEPTION 'Non-owned aircraft accepted'; END IF;

 v:=airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
  owner,airline,plane,iata||'941',
  'OURAIRPORTS:2220','OURAIRPORTS:4001',
  '2026-11-06T10:00:00Z'::timestamptz,'2026-11-06T12:00:00Z'::timestamptz,
  '[{"day":0,"time":"13:00"},{"day":2,"time":"14:00"}]'::jsonb);
 IF v->>'status'<>'draft' OR (v->>'weeklyOccurrencesScreened')::int<>8
 OR (v->>'canActivateNormalFlight')::boolean IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Server draft restriction screen failed: %',v; END IF;

 ready:=airlinerra_game.section5_schedule_activation_readiness_v1(owner,(v->>'scheduleId')::uuid);
 IF ready->>'status'<>'BLOCKED_OPERATIONAL_SYSTEMS_NOT_CONNECTED' OR
 (ready->>'canActivateNormalFlight')::boolean IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Unfinished flight systems allowed activation: %',ready; END IF;

 v:=airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
  owner,airline,plane,iata||'942',
  'OURAIRPORTS:2220','OURAIRPORTS:4001',
  '2026-11-06T10:00:00Z'::timestamptz,'2026-11-06T12:00:00Z'::timestamptz,
  '[{"day":0,"time":"13:00"}]'::jsonb,(v->>'scheduleId')::uuid);
 IF (v->>'version')::int<>2 OR v->>'status'<>'draft'
 THEN RAISE EXCEPTION 'Owned edit failed: %',v; END IF;

 BEGIN
  UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
  SET status='active' WHERE id=(v->>'scheduleId')::uuid;
 EXCEPTION WHEN check_violation THEN direct_activation_denied:=true; END;
 IF NOT direct_activation_denied THEN RAISE EXCEPTION 'Direct active-state modification succeeded'; END IF;

 BEGIN
  PERFORM airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
   owner,airline,plane,iata||'943',
   'OURAIRPORTS:5564','OURAIRPORTS:4001',
   '2026-11-06T10:00:00Z'::timestamptz,'2026-11-06T12:00:00Z'::timestamptz,
   '[{"day":4,"time":"23:30"}]'::jsonb);
 EXCEPTION WHEN SQLSTATE 'P0001' THEN curfew_denied:=true; END;
 IF NOT curfew_denied THEN RAISE EXCEPTION 'Fukuoka curfew not enforced'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1 d WHERE d.airline_id=airline)<>1
 THEN RAISE EXCEPTION 'Unexpected number of writes'; END IF;
 RAISE NOTICE 'PASS: ownership, aircraft registration, recurrent curfew, edit version, check-only activation and database active-state denial';
END $tests$;
ROLLBACK;