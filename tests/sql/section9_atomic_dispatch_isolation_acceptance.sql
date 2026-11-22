-- Phase 14W isolated dispatcher integration. No production flight, money,
-- fuel, signer or crew row is written; even fixture success is rolled back.
DO $test$
DECLARE
 tbl text;fn_def text;stub record;a record;config bigint;aircraft uuid;sc uuid;occ uuid;
 bad_occ uuid;good_occ uuid;now_at timestamptz:='2026-11-24T08:02:00Z';
 base timestamptz:='2026-11-24T08:00:00Z';i int;r jsonb;replay jsonb;blocked_without_gate boolean:=false;
 before_live bigint;result jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA crew_dispatch_fixture_14w;
 FOREACH tbl IN ARRAY ARRAY[
 'airlines','airline_aircraft_inventory','airport_reference_profiles','airline_flight_schedule_drafts_v1',
 'section9_dated_flight_occurrences_v1','section9_occurrence_capacity_inventory_v1',
 'section9_route_commercial_plans_v1','section9_schedule_operational_certifications_v1',
 'section9_schedule_activation_preparations_v1','section6_weekly_airport_slot_reservations_v1',
 'section9_activation_release_policy_v1','section9_trusted_execution_release_policy_v1',
 'section9_flight_engine_readiness_audit_v1','section9_operated_flight_movements_v1',
 'section9_delayed_crew_approvals_v1','section9_delayed_crew_approval_release_v1',
 'section9_operated_crew_capture_issues_v1'] LOOP
  EXECUTE format('CREATE TABLE crew_dispatch_fixture_14w.%I(LIKE airlinerra_game.%I INCLUDING ALL)',tbl,tbl);
 END LOOP;
 CREATE TABLE crew_dispatch_fixture_14w.test_signer(name text primary key,decrypted_secret text);
 CREATE TABLE crew_dispatch_fixture_14w.test_supply(physical_flight_id text primary key);
 CREATE TABLE crew_dispatch_fixture_14w.test_fuel(physical_flight_id text primary key,engine_event_id text);
 CREATE TABLE crew_dispatch_fixture_14w.test_crew(physical_flight_id text primary key);
 CREATE TABLE crew_dispatch_fixture_14w.test_bad(physical_flight_id text primary key);
 INSERT INTO crew_dispatch_fixture_14w.test_signer VALUES('airlinerra_operated_flight_auto_signing_v1',repeat('isolated-dispatch-key-',5));
 SELECT airline.*,f.configuration_id INTO STRICT a FROM airlinerra_game.airlines airline JOIN airlinerra_game.airline_aircraft_inventory f ON f.airline_id=airline.id JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=f.configuration_id AND c.use_type='passenger' WHERE airline.world_id=1 LIMIT 1;
 config:=a.configuration_id;
 INSERT INTO crew_dispatch_fixture_14w.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO crew_dispatch_fixture_14w.section9_activation_release_policy_v1(world_id,release_state,release_reference,approved_by,enabled_at,crew_mode) VALUES(1,'enabled','isolated-test-activation-v1','isolated-reviewer',clock_timestamp(),'deferred_phase1');
 INSERT INTO crew_dispatch_fixture_14w.section9_trusted_execution_release_policy_v1(world_id,release_state,release_reference,approved_by,reviewed_at,enabled_at) VALUES(1,'enabled','isolated-trusted-execution-v1','isolated-reviewer',clock_timestamp(),clock_timestamp());
 INSERT INTO crew_dispatch_fixture_14w.section9_flight_engine_readiness_audit_v1(world_id,trusted_flight_execution_release,fuel_transaction_release,automatic_flight_and_fuel_settlement_enabled) VALUES(1,'ACTIVATED','ACTIVATED',true);
 INSERT INTO crew_dispatch_fixture_14w.section9_delayed_crew_approval_release_v1(world_id,automatic_dispatch_event_isolation_enabled) VALUES(1,true);
 FOR i IN 1..2 LOOP
  aircraft:=gen_random_uuid();
  INSERT INTO crew_dispatch_fixture_14w.airline_aircraft_inventory(id,airline_id,configuration_id,registration,ownership_type,fleet_status) VALUES(aircraft,a.id,config,'FIXTURE-14W-'||i,'owned','in_service');
  INSERT INTO crew_dispatch_fixture_14w.airline_flight_schedule_drafts_v1(world_id,airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified)
  VALUES(1,a.id,aircraft,config,a.iata_code||(990+i),a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),jsonb_build_array(jsonb_build_object('day',extract(isodow FROM base)::int-1,'time','08:00')),'{}',a.owner_player_id,'active',true) RETURNING id INTO sc;
  INSERT INTO crew_dispatch_fixture_14w.section9_dated_flight_occurrences_v1(world_id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,flight_local_date,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,turnaround_minutes,verified_passenger_seats,booking_status,booked_seats,recognized_revenue_usd,source_kind)
  VALUES(1,a.id,sc,aircraft,1,1,base::date,a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),60,156,'open',0,0,'game_verified_saleable_schedule_v1') RETURNING id INTO occ;
  INSERT INTO crew_dispatch_fixture_14w.section9_route_commercial_plans_v1(schedule_id,airline_id,economy_fare_usd,version) VALUES(sc,a.id,100,1);
  INSERT INTO crew_dispatch_fixture_14w.section9_occurrence_capacity_inventory_v1(physical_flight_id,schedule_id,airline_id,local_departure_date,weekly_entry,schedule_version,commercial_version,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,passenger_capacity,cargo_capacity_tonnes,passengers_held)
  VALUES(sc::text||':'||base::date||':1',sc,a.id,base::date,1,1,1,a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),156,0,0);
  INSERT INTO crew_dispatch_fixture_14w.section9_schedule_activation_preparations_v1(schedule_id,schedule_version,airline_id,aircraft_inventory_id,verified_game_date,certified_horizon_days,fingerprint_md5,release_reference)
  VALUES(sc,1,a.id,aircraft,base::date,7,repeat('b',32),'isolated-activation-proof');
  INSERT INTO crew_dispatch_fixture_14w.section9_schedule_operational_certifications_v1(schedule_id,airline_id,schedule_version,clearance_type,review_status,source_kind,source_reference,reviewer_reference,reviewed_at,valid_from_game_date,valid_to_game_date)
  SELECT sc,a.id,1,v.kind,'certified',v.source,'isolated-verified-source-'||v.kind,'isolated-independent-reviewer',clock_timestamp(),base::date,base::date+7
  FROM (VALUES
  ('crew_duty','verified_crew_duty_engine'),
  ('operator_licence','verified_game_licence_engine'),
  ('route_traffic_rights','verified_game_traffic_rights_engine'),
  ('airport_slot_capacity','verified_airport_slot_engine'),
  ('trusted_flight_execution','trusted_flight_operations_engine')) v(kind,source);
  INSERT INTO crew_dispatch_fixture_14w.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
  VALUES(sc,1,a.home_airport_key,'terminal','departure',extract(isodow FROM base)::int-1,480),
        (sc,1,'OURAIRPORTS:2212','terminal','arrival',extract(isodow FROM base)::int-1,660);
  IF i=1 THEN
   bad_occ:=occ;
   INSERT INTO crew_dispatch_fixture_14w.test_bad VALUES(sc::text||':'||base::date||':1');
  ELSE good_occ:=occ;END IF;
 END LOOP;
 -- Read-only authoritative gates/studies are canned; the actual dispatcher
 -- controls event ordering, per-event subtransactions, signed-movement request,
 -- fuel request, booking closure, crew call, replay and reporting.
 FOR stub IN SELECT * FROM (VALUES
 ('section9_verified_berlin_game_hour_v1','','jsonb',$f$SELECT jsonb_build_object('authoritativeGameHourAvailable',true,'gameHourUtc','2026-11-24T08:02:00Z')$f$),
 ('section9_auto_disruption_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_auto_recover_delayed_crew_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_auto_replan_downstream_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_effective_dispatch_window_v1','p_occurrence uuid','TABLE(effective_departure_utc timestamptz,effective_arrival_utc timestamptz,is_delayed boolean,dispatch_allowed boolean)',$f$SELECT departure_utc,arrival_utc,false,true FROM crew_dispatch_fixture_14w.section9_dated_flight_occurrences_v1 WHERE id=p_occurrence$f$),
 ('section9_disruption_departure_clear_v1','p_occurrence uuid','boolean',$f$SELECT true$f$),
 ('section9_automatic_disruption_ready_v1','','boolean',$f$SELECT false$f$),
 ('section9_canonical_aoc_covers_v1','p_airline uuid,p_day date,p_days integer','boolean',$f$SELECT true$f$),
 ('section9_verified_permission_game_day_v1','','date',$f$SELECT DATE '2026-11-24'$f$),
 ('section9_game_route_licence_scope_v1','p_airline uuid,p_origin text,p_destination text,p_day date,p_days integer','jsonb',$f$SELECT jsonb_build_object('allowed',true)$f$),
 ('section9_delayed_turnaround_clear_v1','p_aircraft uuid,p_occurrence uuid,p_departure timestamptz','boolean',$f$SELECT true$f$),
 ('section9_verified_game_maintenance_dispatch_window_v1','p_owner uuid,p_airline uuid,p_aircraft uuid,p_depart_utc timestamptz,p_arrive_utc timestamptz','jsonb',$f$SELECT jsonb_build_object('gameMaintenanceClear',true)$f$),
 ('section9_verify_game_fuel_before_departure_v1','p_physical_flight_id text','jsonb',$f$SELECT jsonb_build_object('status','verified_game_fuel_onboard_available_for_planned_trip','fuelVerifiedForGame',true,'ledgerPosted',false)$f$),
 ('section9_downstream_crew_reconciliation_v1','p_airline uuid,p_occurrence uuid','jsonb',$f$SELECT jsonb_build_object('status','downstream_unaffected')$f$),
 ('section9_operated_day_candidates_for_aircraft_v1','p_airline uuid,p_aircraft uuid,p_game_day date','jsonb',$f$SELECT jsonb_build_object('status','verified_operational_candidates_only','candidates',coalesce(jsonb_agg(jsonb_build_object('scheduleId',o.schedule_id,'scheduleVersion',o.schedule_version,'flightLocalDate',o.flight_local_date,'weeklyEntry',o.weekly_entry,'phase','departed','scheduledEventUtc',o.departure_utc,'eventId','fixture-event-'||replace(o.id::text,'-',''))),'[]'::jsonb)) FROM crew_dispatch_fixture_14w.section9_dated_flight_occurrences_v1 o WHERE o.airline_id=p_airline AND o.aircraft_inventory_id=p_aircraft AND o.flight_local_date=p_game_day$f$)
 ) AS z(name,args,result,body) LOOP
  EXECUTE format('CREATE FUNCTION crew_dispatch_fixture_14w.%I(%s) RETURNS %s LANGUAGE sql STABLE AS %L',stub.name,stub.args,stub.result,stub.body);
 END LOOP;
 EXECUTE $ddl$CREATE FUNCTION crew_dispatch_fixture_14w.section9_auto_supply_game_only_fuel_v1(p_physical text) RETURNS jsonb LANGUAGE plpgsql AS $fn$
 BEGIN INSERT INTO crew_dispatch_fixture_14w.test_supply VALUES(p_physical);
 RETURN jsonb_build_object('status','game_only_auto_fuel_supply_recorded','ledgerPosted',false);END $fn$$ddl$;
 EXECUTE $ddl$CREATE FUNCTION crew_dispatch_fixture_14w.section9_record_signed_operated_flight_movement_v1(p_airline uuid,p_schedule uuid,p_version int,p_day date,p_entry int,p_phase text,p_utc timestamptz,p_event text,p_hmac text) RETURNS jsonb LANGUAGE plpgsql AS $fn$
 BEGIN
 INSERT INTO crew_dispatch_fixture_14w.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 SELECT 1,p_event,p_hmac,o.airline_id,o.aircraft_inventory_id,o.schedule_id,o.schedule_version,o.weekly_entry,o.flight_local_date,o.schedule_id::text||':'||o.flight_local_date||':'||o.weekly_entry,p_phase,o.origin_airport_key,o.destination_airport_key,o.departure_utc,o.arrival_utc,p_utc,'signed_operated_game_flight_v1' FROM crew_dispatch_fixture_14w.section9_dated_flight_occurrences_v1 o WHERE o.airline_id=p_airline AND o.schedule_id=p_schedule AND o.schedule_version=p_version AND o.flight_local_date=p_day AND o.weekly_entry=p_entry;
 IF NOT FOUND THEN RAISE EXCEPTION 'SIGNED_MOVEMENT_FIXTURE_MISSING';END IF;
 RETURN jsonb_build_object('movementRecorded',true,'replayed',false,'ledgerPosted',false);
 END $fn$$ddl$;
 EXECUTE $ddl$CREATE FUNCTION crew_dispatch_fixture_14w.section9_capture_verified_departure_fuel_v1(p_physical text,p_event text) RETURNS jsonb LANGUAGE plpgsql AS $fn$
 BEGIN
 IF EXISTS(SELECT 1 FROM crew_dispatch_fixture_14w.test_bad WHERE physical_flight_id=p_physical) THEN RETURN jsonb_build_object('status','unverified_fuel','fuelReceiptCreated',false);END IF;
 INSERT INTO crew_dispatch_fixture_14w.test_fuel VALUES(p_physical,p_event);
 RETURN jsonb_build_object('status','signed_game_fuel_departure_receipt_created','fuelReceiptCreated',true,'ledgerPosted',false);
 END $fn$$ddl$;
 EXECUTE $ddl$CREATE FUNCTION crew_dispatch_fixture_14w.section9_capture_dispatched_crew_v1(p_airline uuid,p_physical text,p_event text) RETURNS jsonb LANGUAGE plpgsql AS $fn$
 BEGIN INSERT INTO crew_dispatch_fixture_14w.test_crew VALUES(p_physical);
 RETURN jsonb_build_object('status','crew_departure_bound'); END $fn$$ddl$;
 SELECT pg_get_functiondef('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'::regprocedure) INTO STRICT fn_def;
 fn_def:=replace(fn_def,'airlinerra_game','crew_dispatch_fixture_14w');
 fn_def:=replace(fn_def,'vault.decrypted_secrets','crew_dispatch_fixture_14w.test_signer');
 EXECUTE fn_def;
 r:=crew_dispatch_fixture_14w.section9_auto_dispatch_due_flight_events_v1(40);
 IF r->>'status'<>'trusted_game_dispatch_cycle_completed'
 OR (r->>'candidatesChecked')::int<>2
 OR (r->>'departuresRecorded')::int<>1
 OR (r->>'blocked')::int<>1
 OR (r->>'atomicEventRollbacks')::int<>1
 OR r->>'eventIsolationEnabled'<>'true'
 OR (r->'blockerCounts'->>'SECTION9_UNVERIFIED_DEPARTURE_FUEL_ROLLS_BACK_MOVEMENT')::int<>1
 OR (SELECT count(*) FROM crew_dispatch_fixture_14w.section9_operated_flight_movements_v1)<>1
 OR (SELECT count(*) FROM crew_dispatch_fixture_14w.test_supply)<>1
 OR (SELECT count(*) FROM crew_dispatch_fixture_14w.test_fuel)<>1
 OR (SELECT count(*) FROM crew_dispatch_fixture_14w.test_crew)<>1
 OR EXISTS(SELECT 1 FROM crew_dispatch_fixture_14w.section9_operated_flight_movements_v1 m JOIN crew_dispatch_fixture_14w.test_bad b ON b.physical_flight_id=m.flight_occurrence_id)
 OR (SELECT booking_status FROM crew_dispatch_fixture_14w.section9_dated_flight_occurrences_v1 WHERE id=good_occ)<>'closed'
 OR (SELECT booking_status FROM crew_dispatch_fixture_14w.section9_dated_flight_occurrences_v1 WHERE id=bad_occ)<>'open'
 THEN RAISE EXCEPTION 'event isolation failed %',r;END IF;
 replay:=crew_dispatch_fixture_14w.section9_auto_dispatch_due_flight_events_v1(40);
 IF (replay->>'candidatesChecked')::int<>1 OR (replay->>'departuresRecorded')::int<>0
 OR (SELECT count(*) FROM crew_dispatch_fixture_14w.section9_operated_flight_movements_v1)<>1
 THEN RAISE EXCEPTION 'replay created duplicate %',replay;END IF;
 UPDATE crew_dispatch_fixture_14w.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=false WHERE world_id=1;
 BEGIN
  PERFORM crew_dispatch_fixture_14w.section9_auto_dispatch_due_flight_events_v1(40);
 EXCEPTION WHEN SQLSTATE '42501' THEN blocked_without_gate:=true;END;
 IF NOT blocked_without_gate OR (SELECT count(*) FROM crew_dispatch_fixture_14w.section9_operated_flight_movements_v1)<>1 THEN RAISE EXCEPTION 'disabled gate did not preserve legacy batch abort';END IF;
 result:=jsonb_build_object('status','passed','isolatedBadFlightRolledBack',true,'unrelatedGoodFlightCommitted',true,'badFuelSupplyRolledBack',true,'badSignedDepartureRolledBack',true,'goodFuelAndCrewCaptured',true,'bookingClosedOnlyForGoodFlight',true,'replayNoDouble',true,'disabledGatePreservesLegacyFailClosed',true,'reportedBlocks',r->'blockerCounts','liveFinancialsUntouched',true);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.atomic_dispatch_fixture_result',SQLERRM,true);END;
END $test$;
SELECT current_setting('airlinerra.atomic_dispatch_fixture_result',true)::jsonb AS dispatch_test,to_regnamespace('crew_dispatch_fixture_14w') IS NULL AS fixture_removed,
 (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1) AS live_movement_count,
 (SELECT count(*) FROM airlinerra_game.section9_route_posted_flight_financials_v1) AS live_finance_count;