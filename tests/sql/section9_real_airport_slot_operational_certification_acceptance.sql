-- Section 5+6 actual verifier isolation: no real slot, certification or airline modified.
DO $slot_fixture$
DECLARE t text; fn record; a record; aircraft record; sc uuid; game_day date; orig text:='OURAIRPORTS:4610'; dest text:='OURAIRPORTS:4612'; dep timestamptz:='2026-11-23T10:00:00Z'; arr timestamptz:='2026-11-23T12:00:00Z'; weekly jsonb:='[{"day":0,"time":"11:00"}]'::jsonb; verdict jsonb; restriction jsonb; result jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA cert_slots_fixture_14z;
 CREATE TABLE cert_slots_fixture_14z.fixture_worlds(id smallint primary key,state text,opens_at timestamptz);
 INSERT INTO cert_slots_fixture_14z.fixture_worlds VALUES(1,'active',now()-interval '3 days');
 FOREACH t IN ARRAY ARRAY['airlines','airline_aircraft_inventory','airline_flight_schedule_drafts_v1',
 'holding_world_clock_v1','section9_verified_game_tick_receipts_v1',
 'section6_airport_slot_capacity_v1','section6_weekly_airport_slot_reservations_v1',
 'section9_verified_schedule_capacity_v1'] LOOP
  EXECUTE format('CREATE TABLE cert_slots_fixture_14z.%I (LIKE airlinerra_game.%I INCLUDING ALL)',t,t);
 END LOOP;
 SELECT * INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT * INTO STRICT aircraft FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=a.id LIMIT 1;
 game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF game_day IS DISTINCT FROM date '2026-11-22' THEN RAISE EXCEPTION 'fixture date must match verification day';END IF;
 FOREACH t IN ARRAY ARRAY['airport_unified_operations_v1','section5_airport_operating_policy_v1','section5_airport_simplified_game_rules_v1',
 'airport_runway_inventory','airport_runway_source_status_evidence','airport_sections1_8_combined_members_v1','section5_airport_batch50_screen_v1',
 'section5_airport_icao_chapter_policy_v2','section5_airport_official_noise_rules_v2','section5_airport_time_restrictions_v1',
 'section5_full_weight_airport_aircraft_screen_v2','section5_runway_specific_restrictions_v1'] LOOP
  EXECUTE format('CREATE TABLE cert_slots_fixture_14z.%I AS SELECT * FROM airlinerra_game.%I WHERE world_id=1 AND airport_key=ANY($1)',t,t) USING ARRAY[orig,dest];
 END LOOP;
 CREATE TABLE cert_slots_fixture_14z.section5_icao_aircraft_certification_v2 AS SELECT * FROM airlinerra_game.section5_icao_aircraft_certification_v2 WHERE configuration_id=aircraft.configuration_id;
 FOR fn IN SELECT pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='airlinerra_game'::regnamespace AND proname IN (
 'section5_local_restriction_window_match_v1','section5_universal_airport_leg_restriction_v1','section5_simplified_airport_leg_screen_v1',
 'section5_universal_route_restriction_gate_v1','section5_batch_route_restriction_screen_v1','section5_weekly_route_restriction_gate_v1',
 'section9_game_route_restrictions_valid_v1','section6_weekly_slot_proposals_v1','section6_weekly_slot_preflight_v1','section9_verify_slot_clearance_source_v1'
 ) LOOP
  EXECUTE replace(replace(fn.def,'airlinerra_game','cert_slots_fixture_14z'),'public.cert_slots_fixture_14z_worlds','cert_slots_fixture_14z.fixture_worlds');
 END LOOP;
 INSERT INTO cert_slots_fixture_14z.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO cert_slots_fixture_14z.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=aircraft.id;
 INSERT INTO cert_slots_fixture_14z.holding_world_clock_v1 SELECT * FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 INSERT INTO cert_slots_fixture_14z.section9_verified_game_tick_receipts_v1 SELECT * FROM airlinerra_game.section9_verified_game_tick_receipts_v1 WHERE world_id=1 AND game_date=game_day;
 INSERT INTO cert_slots_fixture_14z.section6_airport_slot_capacity_v1 SELECT * FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=1 AND airport_key IN(orig,dest);
 INSERT INTO cert_slots_fixture_14z.airline_flight_schedule_drafts_v1(world_id,airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified,departure_stand_type,arrival_stand_type)
 VALUES(1,a.id,aircraft.id,aircraft.configuration_id,a.iata_code||'973',orig,dest,dep,arr,weekly,'{}'::jsonb,a.owner_player_id,'draft',false,'terminal','terminal') RETURNING id INTO sc;
 INSERT INTO cert_slots_fixture_14z.section9_verified_schedule_capacity_v1(schedule_id,airline_id,schedule_version,passenger_seats,cargo_capacity_tonnes,verification_source)
 VALUES(sc,a.id,1,156,0,'verified_test_capacity_14z');
 restriction:=cert_slots_fixture_14z.section5_weekly_route_restriction_gate_v1(1,orig,dest,aircraft.configuration_id,dep,arr,weekly);
 IF NOT cert_slots_fixture_14z.section9_game_route_restrictions_valid_v1(orig,dest,restriction)
 THEN RAISE EXCEPTION 'eligible domestic game airport restrictions rejected %',restriction;END IF;
 INSERT INTO cert_slots_fixture_14z.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT sc,1,airport_key,stand_type,direction,weekday,minute_of_day FROM cert_slots_fixture_14z.section6_weekly_slot_proposals_v1(1,orig,dest,dep,arr,weekly,'terminal','terminal');
 verdict:=cert_slots_fixture_14z.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'verified_game_airport_slots' OR verdict->>'verified'<>'true' OR (verdict->>'reservedSlots')::int<>2
 THEN RAISE EXCEPTION 'actual reserved airport slots rejected %',verdict;END IF;
 UPDATE cert_slots_fixture_14z.section6_weekly_airport_slot_reservations_v1 SET minute_of_day=minute_of_day+10 WHERE schedule_id=sc AND airport_key=orig AND direction='departure';
 verdict:=cert_slots_fixture_14z.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'blocked_slot_clearance_evidence' OR NOT verdict->'blockers' ? 'RECURRING_SLOT_RESERVATIONS_MISMATCH'
 THEN RAISE EXCEPTION 'mismatched slot accepted %',verdict;END IF;
 DELETE FROM cert_slots_fixture_14z.section6_weekly_airport_slot_reservations_v1 WHERE schedule_id=sc;
 INSERT INTO cert_slots_fixture_14z.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT sc,1,airport_key,stand_type,direction,weekday,minute_of_day FROM cert_slots_fixture_14z.section6_weekly_slot_proposals_v1(1,orig,dest,dep,arr,weekly,'terminal','terminal');
 UPDATE cert_slots_fixture_14z.section6_airport_slot_capacity_v1 SET terminal_stands=0,terminal_per_direction_10m=0 WHERE airport_key=orig;
 verdict:=cert_slots_fixture_14z.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'blocked_slot_clearance_evidence' OR NOT verdict->'blockers' ? 'AIRPORT_CAPACITY_RECHECK_FAILED'
 THEN RAISE EXCEPTION 'airport without capacity approved %',verdict;END IF;
 IF cert_slots_fixture_14z.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day+1)->>'status'<>'blocked_unverified_world_or_game_day'
 THEN RAISE EXCEPTION 'unverified game day approved';END IF;
 result:=jsonb_build_object('status','passed','actualGameNightAndRunwayRestrictions',true,'actualWeeklySlotProposals',true,'actualHourAndTenMinuteCapacity',true,'matchedReservationsCertified',true,'mismatchedReservationBlocked',true,'zeroStandCapacityBlocked',true,'wrongGameDateBlocked',true,'noGameDataMutated',true);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.cert_slots_fixture_14z',SQLERRM,true);END;
END $slot_fixture$;
SELECT current_setting('airlinerra.cert_slots_fixture_14z',true)::jsonb result,to_regnamespace('cert_slots_fixture_14z') IS NULL fixture_removed,(SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1) live_reservations;