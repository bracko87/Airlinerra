-- Phase 14Z game-licence source verifier acceptance. Isolated schema, rolled back.
DO $fixture$
DECLARE
 t text; cols text; fn record; a record; aircraft record; home_key text; international_key text:='OURAIRPORTS:2212'; foreign_key text:='OURAIRPORTS:2214';
 home_schedule uuid; foreign_schedule uuid; game_day date; result jsonb; aoc jsonb; op jsonb; rights jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA cert_aoc_fixture_14z;
 CREATE TABLE cert_aoc_fixture_14z.fixture_worlds(id smallint primary key,state text,opens_at timestamptz);
 INSERT INTO cert_aoc_fixture_14z.fixture_worlds VALUES(1,'active',now()-interval '2 days');
 FOREACH t IN ARRAY ARRAY[
 'airlines','airline_aircraft_inventory','airline_flight_schedule_drafts_v1',
 'airport_reference_profiles','holding_world_clock_v1','section9_verified_game_tick_receipts_v1',
 'section9_aoc_release_policy_v1','section9_aoc_certificates_v1','section9_aoc_operating_companies_v1',
 'section9_aoc_safety_incidents_v1','section9_aoc_corrective_tasks_v1','section9_aoc_independent_correction_release_v1',
 'section9_aoc_compliance_receipts_v1','section9_aoc_verified_correction_proofs_v1',
 'section9_game_maintenance_service_receipts_v1','section9_game_permission_applications_v1','section9_operator_licence_evidence_v1',
 'airline_ledger','aviation_countries_v1','airport_offices',
 'licence2_directed_route_allocations_v1','licence2_market_policy_v1','licence2_market_levels_v1','licence2_airline_market_permits_v1'
 ] LOOP
  EXECUTE format('CREATE TABLE cert_aoc_fixture_14z.%I(LIKE airlinerra_game.%I INCLUDING ALL)',t,t);
 END LOOP;
 CREATE TABLE cert_aoc_fixture_14z.airport_unified_operations_v1 AS SELECT * FROM airlinerra_game.airport_unified_operations_v1 WHERE world_id=1 AND airport_key IN ('OURAIRPORTS:4610','OURAIRPORTS:2212','OURAIRPORTS:2214');
 FOR fn IN SELECT pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='airlinerra_game'::regnamespace AND proname IN(
 'section9_verified_permission_game_day_v1','section9_aoc_safety_score_v1',
 'section9_aoc_flight_release_readiness_v1','section9_canonical_aoc_covers_v1',
 'section9_verify_game_operator_licence_v1','section9_verify_game_route_traffic_rights_v1',
 'section9_game_route_licence_scope_v1','licence2_foreign_route_preview_v1','licence2_country_market_v1'
 ) LOOP
  EXECUTE replace(replace(fn.def,'airlinerra_game','cert_aoc_fixture_14z'),'public.cert_aoc_fixture_14z_worlds','cert_aoc_fixture_14z.fixture_worlds');
 END LOOP;
 SELECT * INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT * INTO STRICT aircraft FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=a.id LIMIT 1;
 home_key:=a.home_airport_key;
 game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF game_day IS NULL THEN RAISE EXCEPTION 'production game-day not verified; cannot fixture';END IF;
 INSERT INTO cert_aoc_fixture_14z.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO cert_aoc_fixture_14z.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=aircraft.id;
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO cols FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO cert_aoc_fixture_14z.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',cols,cols)
 USING ARRAY[home_key,international_key,foreign_key];
 INSERT INTO cert_aoc_fixture_14z.holding_world_clock_v1 SELECT * FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 INSERT INTO cert_aoc_fixture_14z.section9_verified_game_tick_receipts_v1 SELECT * FROM airlinerra_game.section9_verified_game_tick_receipts_v1 WHERE world_id=1 AND game_date=game_day;
 INSERT INTO cert_aoc_fixture_14z.section9_aoc_release_policy_v1 SELECT * FROM airlinerra_game.section9_aoc_release_policy_v1 WHERE world_id=1;
 INSERT INTO cert_aoc_fixture_14z.section9_aoc_certificates_v1 SELECT * FROM airlinerra_game.section9_aoc_certificates_v1 WHERE airline_id=a.id;
 INSERT INTO cert_aoc_fixture_14z.section9_aoc_operating_companies_v1 SELECT * FROM airlinerra_game.section9_aoc_operating_companies_v1 WHERE airline_id=a.id;
 INSERT INTO cert_aoc_fixture_14z.aviation_countries_v1 SELECT * FROM airlinerra_game.aviation_countries_v1;
 INSERT INTO cert_aoc_fixture_14z.licence2_market_policy_v1 SELECT * FROM airlinerra_game.licence2_market_policy_v1;
 INSERT INTO cert_aoc_fixture_14z.licence2_market_levels_v1 SELECT * FROM airlinerra_game.licence2_market_levels_v1;
 INSERT INTO cert_aoc_fixture_14z.licence2_airline_market_permits_v1 SELECT * FROM airlinerra_game.licence2_airline_market_permits_v1 WHERE airline_id=a.id;
 INSERT INTO cert_aoc_fixture_14z.licence2_directed_route_allocations_v1 SELECT * FROM airlinerra_game.licence2_directed_route_allocations_v1 WHERE airline_id=a.id;
 INSERT INTO cert_aoc_fixture_14z.airport_offices SELECT * FROM airlinerra_game.airport_offices WHERE airline_id=a.id;
 INSERT INTO cert_aoc_fixture_14z.airline_flight_schedule_drafts_v1(world_id,airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified)
 VALUES(1,a.id,aircraft.id,aircraft.configuration_id,a.iata_code||'971',home_key,international_key,(game_day::timestamp + interval '11 hours') AT TIME ZONE 'Europe/Belgrade',(game_day::timestamp + interval '14 hours') AT TIME ZONE 'Europe/Belgrade','[{"day":0,"time":"11:00"}]', '{}'::jsonb,a.owner_player_id,'draft',false) RETURNING id INTO home_schedule;
 INSERT INTO cert_aoc_fixture_14z.airline_flight_schedule_drafts_v1(world_id,airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified)
 VALUES(1,a.id,aircraft.id,aircraft.configuration_id,a.iata_code||'972',international_key,foreign_key,(game_day::timestamp + interval '10 hours') AT TIME ZONE 'Europe/Berlin',(game_day::timestamp + interval '12 hours') AT TIME ZONE 'Europe/Berlin','[{"day":0,"time":"10:00"}]','{}'::jsonb,a.owner_player_id,'draft',false) RETURNING id INTO foreign_schedule;
 aoc:=cert_aoc_fixture_14z.section9_aoc_flight_release_readiness_v1(a.id,game_day);
 IF aoc->>'status'<>'AOC_FLIGHT_READY' OR aoc->>'authorized'<>'true' THEN RAISE EXCEPTION 'valid game AOC rejected %',aoc;END IF;
 op:=cert_aoc_fixture_14z.section9_verify_game_operator_licence_v1(a.id,home_schedule,1,game_day);
 IF op->>'status'<>'verified_game_operator_licence' OR op->>'verified'<>'true' THEN RAISE EXCEPTION 'valid operator proof rejected %',op;END IF;
 rights:=cert_aoc_fixture_14z.section9_verify_game_route_traffic_rights_v1(a.id,home_schedule,1,game_day);
 IF rights->>'status'<>'verified_game_route_traffic_rights' THEN RAISE EXCEPTION 'L1 home market route rejected %',rights;END IF;
 rights:=cert_aoc_fixture_14z.section9_verify_game_route_traffic_rights_v1(a.id,foreign_schedule,1,game_day);
 IF rights->>'status'<>'blocked_game_route_traffic_rights' OR rights->>'verified'<>'false' THEN RAISE EXCEPTION 'foreign-to-foreign route unlicensed %',rights;END IF;
 UPDATE cert_aoc_fixture_14z.section9_aoc_certificates_v1 SET status='expired' WHERE airline_id=a.id;
 IF cert_aoc_fixture_14z.section9_canonical_aoc_covers_v1(a.id,game_day,0)
 OR cert_aoc_fixture_14z.section9_verify_game_operator_licence_v1(a.id,home_schedule,1,game_day)->>'verified'<>'false'
 THEN RAISE EXCEPTION 'expired AOC granted flight rights';END IF;
 UPDATE cert_aoc_fixture_14z.section9_aoc_certificates_v1 SET status='active' WHERE airline_id=a.id;
 INSERT INTO cert_aoc_fixture_14z.section9_aoc_safety_incidents_v1(event_id,airline_id,world_id,severity,occurred_game_day,description_code,verified_event_reference,required_action_count)
 VALUES('fixture-major-safety-a-14z-'||a.id,a.id,1,'major',game_day,'GAME_SAFETY_AUDIT','fixture-aoc-independent-safety-review-14z-a',1),
 ('fixture-major-safety-b-14z-'||a.id,a.id,1,'major',game_day,'GAME_SAFETY_AUDIT','fixture-aoc-independent-safety-review-14z-b',1);
 aoc:=cert_aoc_fixture_14z.section9_aoc_flight_release_readiness_v1(a.id,game_day);
 IF aoc->>'authorized'<>'false' OR NOT aoc->'issues' ? 'AOC_SAFETY_RATING_BELOW_70' THEN RAISE EXCEPTION 'unsafe operator approved %',aoc;END IF;
 DELETE FROM cert_aoc_fixture_14z.section9_aoc_safety_incidents_v1 WHERE airline_id=a.id;
 IF cert_aoc_fixture_14z.section9_verify_game_operator_licence_v1(a.id,home_schedule,2,game_day)->>'status'<>'blocked_stale_or_non_draft_schedule' THEN RAISE EXCEPTION 'stale version approved';END IF;
 IF cert_aoc_fixture_14z.section9_verify_game_operator_licence_v1(a.id,home_schedule,1,game_day+1)->>'verified'<>'false' THEN RAISE EXCEPTION 'unverified clock date approved';END IF;
 result:=jsonb_build_object('status','passed','validAocAndOperator',true,'homeMarketRightsGranted',true,'foreignToForeignRequiresL2',true,'expiredAocRejected',true,'below70SafetyRejected',true,'staleVersionRejected',true,'clockDayMismatchRejected',true,'noGameWrites',true);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.cert_aoc_fixture_14z',SQLERRM,true);END;
END $fixture$;
SELECT current_setting('airlinerra.cert_aoc_fixture_14z',true)::jsonb result,to_regnamespace('cert_aoc_fixture_14z') IS NULL fixture_removed,(SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1) live_certifications;