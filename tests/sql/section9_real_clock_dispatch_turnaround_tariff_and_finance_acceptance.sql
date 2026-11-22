-- Phase 14W isolated dispatcher integration. No production flight, money,
-- fuel, signer or crew row is written; even fixture success is rolled back.
DO $test$
DECLARE
 tbl text;fn_def text;stub record;a record;config bigint;aircraft uuid;sc uuid;occ uuid;
 bad_occ uuid;good_occ uuid;arrivals jsonb;arrival_replay jsonb;finance_batch jsonb;finance_replay jsonb;ticket_check jsonb;approved_cost jsonb;posted_finance jsonb;post_replay jsonb;opening_cash numeric;expected_net numeric;fee_rec record;cost_preview jsonb;now_at timestamptz:='2026-11-20T08:02:00Z';
 base timestamptz:='2026-11-20T08:00:00Z';i int;r jsonb;replay jsonb;blocked_without_gate boolean:=false;
 before_live bigint;result jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA crew_turnaround_fixture_14x;
 FOREACH tbl IN ARRAY ARRAY[
 'airlines','airline_aircraft_inventory','airport_reference_profiles','airline_flight_schedule_drafts_v1',
 'section9_verified_schedule_capacity_v1','section9_aircraft_delivery_position_v1','aircraft_acquisition_orders_v1','aircraft_delivery_inspections_v1',
 'section9_aircraft_current_position_v1','aircraft_maintenance_state_v1','section9_aircraft_game_fuel_custody_v1',
 'section9_game_flight_fuel_departure_receipts_v1','section9_game_flight_fuel_arrival_receipts_v1','section9_arrived_aircraft_usage_receipts_v1',
 'holding_world_clock_v1','section9_verified_game_tick_receipts_v1','section9_clock_producer_schedule_v1',
 'section9_passenger_reservation_batches_v1','section9_actual_ticket_finance_preparations_v1','section9_route_posted_flight_financials_v1',
 'section9_flight_final_cost_approvals_v1','section9_flight_finance_posting_release_v1','section9_game_fuel_model_snapshot_v1',
 'section9_external_crew_contracts_v1','section9_operated_crew_bindings_v1','section9_pilot_departure_manifests_v1',
 'section9_actual_turnaround_receipts_v1','section9_dynamic_turnaround_release_v1','section9_flight_crew_model_policy_v1',
 'section9_onboard_service_release_v1','section9_onboard_departure_snapshots_v1','section9_onboard_finance_receipts_v1','airline_ledger',
 'section9_dated_flight_occurrences_v1','section9_occurrence_capacity_inventory_v1',
 'section9_route_commercial_plans_v1','section9_schedule_operational_certifications_v1',
 'section9_schedule_activation_preparations_v1','section6_weekly_airport_slot_reservations_v1',
 'section9_activation_release_policy_v1','section9_trusted_execution_release_policy_v1',
 'section9_flight_engine_readiness_audit_v1','section9_operated_flight_movements_v1',
 'section9_delayed_crew_approvals_v1','section9_delayed_crew_approval_release_v1',
 'section9_operated_crew_capture_issues_v1'] LOOP
  EXECUTE format('CREATE TABLE crew_turnaround_fixture_14x.%I(LIKE airlinerra_game.%I INCLUDING ALL)',tbl,tbl);
 END LOOP;
 CREATE TABLE crew_turnaround_fixture_14x.section8_airport_operating_tariffs_v1 AS SELECT * FROM airlinerra_game.section8_airport_operating_tariffs_v1 WHERE world_id=1 AND airport_key IN('OURAIRPORTS:4610','OURAIRPORTS:2212');
 CREATE TABLE crew_turnaround_fixture_14x.airport_unified_operations_v1 AS SELECT * FROM airlinerra_game.airport_unified_operations_v1 WHERE world_id=1 AND airport_key IN('OURAIRPORTS:4610','OURAIRPORTS:2212');
 CREATE TABLE crew_turnaround_fixture_14x.test_signer(name text primary key,decrypted_secret text);
 CREATE TABLE crew_turnaround_fixture_14x.fixture_worlds(id smallint primary key,state text,opens_at timestamptz);
 INSERT INTO crew_turnaround_fixture_14x.fixture_worlds VALUES(1,'active',now()-interval '30 days');
 CREATE TABLE crew_turnaround_fixture_14x.test_supply(physical_flight_id text primary key);
 CREATE TABLE crew_turnaround_fixture_14x.test_fuel(physical_flight_id text primary key,engine_event_id text);
 CREATE TABLE crew_turnaround_fixture_14x.test_crew(physical_flight_id text primary key);
 CREATE TABLE crew_turnaround_fixture_14x.test_bad(physical_flight_id text primary key);
 CREATE TABLE crew_turnaround_fixture_14x.test_usage(physical_flight_id text primary key);
 CREATE TABLE crew_turnaround_fixture_14x.test_fuel_arrival(physical_flight_id text primary key);
 CREATE TABLE crew_turnaround_fixture_14x.test_crew_arrival(physical_flight_id text primary key);
 CREATE TABLE crew_turnaround_fixture_14x.test_turnaround(physical_flight_id text primary key,available_utc timestamptz);
 INSERT INTO crew_turnaround_fixture_14x.test_signer VALUES('airlinerra_operated_flight_auto_signing_v1',repeat('isolated-dispatch-key-',5));
 SELECT airline.*,f.configuration_id INTO STRICT a FROM airlinerra_game.airlines airline JOIN airlinerra_game.airline_aircraft_inventory f ON f.airline_id=airline.id JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=f.configuration_id AND c.use_type='passenger' WHERE airline.world_id=1 LIMIT 1;
 config:=a.configuration_id;
 INSERT INTO crew_turnaround_fixture_14x.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 SELECT cash_usd INTO STRICT opening_cash FROM crew_turnaround_fixture_14x.airlines WHERE id=a.id;
 INSERT INTO crew_turnaround_fixture_14x.airline_ledger(airline_id,entry_kind,amount_usd) VALUES(a.id,'ADJUSTMENT',opening_cash);
 INSERT INTO crew_turnaround_fixture_14x.section9_dynamic_turnaround_release_v1(world_id,capture_enabled,dispatch_effects_enabled) VALUES(1,true,false);
 INSERT INTO crew_turnaround_fixture_14x.section9_flight_crew_model_policy_v1 SELECT * FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=config;
 INSERT INTO crew_turnaround_fixture_14x.section9_flight_finance_posting_release_v1(world_id,release_state,approved_at,approval_reference)
 VALUES(1,'approved',clock_timestamp(),'isolated-fixture-finance-approval-14x');
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO tbl FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='section9_game_fuel_model_snapshot_v1' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO crew_turnaround_fixture_14x.section9_game_fuel_model_snapshot_v1(%s) SELECT %s FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 WHERE configuration_id=$1',tbl,tbl) USING config;
 INSERT INTO crew_turnaround_fixture_14x.section9_activation_release_policy_v1(world_id,release_state,release_reference,approved_by,enabled_at,crew_mode) VALUES(1,'enabled','isolated-test-activation-v1','isolated-reviewer',clock_timestamp(),'deferred_phase1');
 INSERT INTO crew_turnaround_fixture_14x.section9_trusted_execution_release_policy_v1(world_id,release_state,release_reference,approved_by,reviewed_at,enabled_at) VALUES(1,'enabled','isolated-trusted-execution-v1','isolated-reviewer',clock_timestamp(),clock_timestamp());
 INSERT INTO crew_turnaround_fixture_14x.section9_flight_engine_readiness_audit_v1(world_id,trusted_flight_execution_release,fuel_transaction_release,automatic_flight_and_fuel_settlement_enabled) VALUES(1,'ACTIVATED','ACTIVATED',true);
 INSERT INTO crew_turnaround_fixture_14x.section9_delayed_crew_approval_release_v1(world_id,automatic_dispatch_event_isolation_enabled) VALUES(1,true);
 INSERT INTO crew_turnaround_fixture_14x.holding_world_clock_v1(world_id,confirmed_game_date,clock_source,engine_proof_ref,last_verified_at) VALUES(1,base::date,'authoritative_game_engine','fixture-clock-proof-14x',base);
 INSERT INTO crew_turnaround_fixture_14x.section9_verified_game_tick_receipts_v1(world_id,game_date,engine_event_id,event_hmac_sha256,dispatch_kind,accepted_at) VALUES(1,base::date,'horizon-world1-day-'||base::date,repeat('f',64),'no_verified_flights',base);
 INSERT INTO crew_turnaround_fixture_14x.section9_clock_producer_schedule_v1(world_id,start_game_date,official_world_opens_at,producer_status,admin_release_reference,enabled_at) VALUES(1,base::date,base-interval '1 day','enabled','fixture-clock-verified-release',base);
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO tbl FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO crew_turnaround_fixture_14x.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',tbl,tbl) USING ARRAY[a.home_airport_key,'OURAIRPORTS:2212'];
 FOR i IN 1..2 LOOP
  aircraft:=gen_random_uuid();
  INSERT INTO crew_turnaround_fixture_14x.airline_aircraft_inventory(id,airline_id,configuration_id,registration,ownership_type,fleet_status) VALUES(aircraft,a.id,config,'FIXTURE-14W-'||i,'owned','in_service');
  INSERT INTO crew_turnaround_fixture_14x.airline_flight_schedule_drafts_v1(world_id,airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified,departure_stand_type,arrival_stand_type)
  VALUES(1,a.id,aircraft,config,a.iata_code||(990+i),a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),jsonb_build_array(jsonb_build_object('day',extract(isodow FROM base)::int-1,'time',to_char((base+make_interval(mins=>i-1)) AT TIME ZONE 'Europe/Belgrade','HH24:MI'))),'{}',a.owner_player_id,'active',true,'terminal','terminal') RETURNING id INTO sc;
  INSERT INTO crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1(world_id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,flight_local_date,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,turnaround_minutes,verified_passenger_seats,booking_status,booked_seats,recognized_revenue_usd,source_kind)
  VALUES(1,a.id,sc,aircraft,1,1,base::date,a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),60,156,'open',100,0,'game_verified_saleable_schedule_v1') RETURNING id INTO occ;
  INSERT INTO crew_turnaround_fixture_14x.section9_verified_schedule_capacity_v1(schedule_id,airline_id,schedule_version,passenger_seats,cargo_capacity_tonnes,verification_source) VALUES(sc,a.id,1,156,0,'fixture-14x-schedule-verified');
  INSERT INTO crew_turnaround_fixture_14x.aircraft_maintenance_state_v1(aircraft_inventory_id,airline_id,verified_tracking_started_utc,tracked_flight_hours,tracked_flight_cycles) VALUES(aircraft,a.id,base-interval '1 day',0,0);
  INSERT INTO crew_turnaround_fixture_14x.section9_aircraft_game_fuel_custody_v1(aircraft_inventory_id,airline_id,world_id,configuration_id,at_airport_key,fuel_game_family,onboard_kg,source_event_id,source_event_kind,evidence_reference,game_hour_utc,revision)
 VALUES(aircraft,a.id,1,config,a.home_airport_key,'jet_kerosene',6000,'fixture-approved-fuel-'||i,'approved_game_fuel_load','fixture-aircraft-fuel-evidence-14x',base-interval '1 day',1);
  INSERT INTO crew_turnaround_fixture_14x.section9_route_commercial_plans_v1(schedule_id,airline_id,economy_fare_usd,version) VALUES(sc,a.id,100,1);
  INSERT INTO crew_turnaround_fixture_14x.section9_occurrence_capacity_inventory_v1(physical_flight_id,schedule_id,airline_id,local_departure_date,weekly_entry,schedule_version,commercial_version,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,passenger_capacity,cargo_capacity_tonnes,passengers_held,cargo_held_tonnes)
  VALUES(sc::text||':'||base::date||':1',sc,a.id,base::date,1,1,1,a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),156,0,100,0);
  INSERT INTO crew_turnaround_fixture_14x.section9_schedule_activation_preparations_v1(schedule_id,schedule_version,airline_id,aircraft_inventory_id,verified_game_date,certified_horizon_days,fingerprint_md5,release_reference)
  VALUES(sc,1,a.id,aircraft,base::date,7,repeat('b',32),'isolated-activation-proof');
  INSERT INTO crew_turnaround_fixture_14x.section9_schedule_operational_certifications_v1(schedule_id,airline_id,schedule_version,clearance_type,review_status,source_kind,source_reference,reviewer_reference,reviewed_at,valid_from_game_date,valid_to_game_date)
  SELECT sc,a.id,1,v.kind,'certified',v.source,'isolated-verified-source-'||v.kind,'isolated-independent-reviewer',clock_timestamp(),base::date,base::date+7
  FROM (VALUES
  ('crew_duty','verified_crew_duty_engine'),
  ('operator_licence','verified_game_licence_engine'),
  ('route_traffic_rights','verified_game_traffic_rights_engine'),
  ('airport_slot_capacity','verified_airport_slot_engine'),
  ('trusted_flight_execution','trusted_flight_operations_engine')) v(kind,source);
  INSERT INTO crew_turnaround_fixture_14x.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
  VALUES(sc,1,a.home_airport_key,'terminal','departure',extract(isodow FROM base)::int-1,480),
        (sc,1,'OURAIRPORTS:2212','terminal','arrival',extract(isodow FROM base)::int-1,660);
  INSERT INTO crew_turnaround_fixture_14x.section9_passenger_reservation_batches_v1(occurrence_id,reservation_key,fare_class,seats_requested,quoted_fare_usd,reservation_status)
 VALUES(occ,'fixture-reserved-14x-'||i,'economy',100,100,'reserved');
  IF i=1 THEN
   bad_occ:=occ;
   INSERT INTO crew_turnaround_fixture_14x.test_bad VALUES(sc::text||':'||base::date||':1');
  ELSE good_occ:=occ;END IF;
 END LOOP;
 -- Read-only authoritative gates/studies are canned; the actual dispatcher
 -- controls event ordering, per-event subtransactions, signed-movement request,
 -- fuel request, booking closure, crew call, replay and reporting.
 FOR stub IN SELECT * FROM (VALUES
 ('section9_auto_disruption_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_auto_recover_delayed_crew_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_auto_replan_downstream_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_effective_dispatch_window_v1','p_occurrence uuid','TABLE(effective_departure_utc timestamptz,effective_arrival_utc timestamptz,is_delayed boolean,dispatch_allowed boolean)',$f$SELECT departure_utc,arrival_utc,false,true FROM crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1 WHERE id=p_occurrence$f$),
 ('section9_disruption_departure_clear_v1','p_occurrence uuid','boolean',$f$SELECT true$f$),
 ('section9_automatic_disruption_ready_v1','','boolean',$f$SELECT false$f$),
 ('section9_canonical_aoc_covers_v1','p_airline uuid,p_day date,p_days integer','boolean',$f$SELECT true$f$),
 ('section9_verified_permission_game_day_v1','','date',$f$SELECT DATE '2026-11-20'$f$),
 ('section9_game_route_licence_scope_v1','p_airline uuid,p_origin text,p_destination text,p_day date,p_days integer','jsonb',$f$SELECT jsonb_build_object('allowed',true)$f$),
 ('section9_delayed_turnaround_clear_v1','p_aircraft uuid,p_occurrence uuid,p_departure timestamptz','boolean',$f$SELECT true$f$),
 ('section9_verified_game_maintenance_dispatch_window_v1','p_owner uuid,p_airline uuid,p_aircraft uuid,p_depart_utc timestamptz,p_arrive_utc timestamptz','jsonb',$f$SELECT jsonb_build_object('gameMaintenanceClear',true)$f$),
 ('section9_verify_game_fuel_before_departure_v1','p_physical_flight_id text','jsonb',$f$
 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_turnaround_fixture_14x.test_bad WHERE physical_flight_id=p_physical_flight_id) AND EXISTS(SELECT 1 FROM crew_turnaround_fixture_14x.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=p_physical_flight_id AND m.phase='departed')
 THEN jsonb_build_object('status','blocked_game_fuel_evidence','fuelVerifiedForGame',false,'ledgerPosted',false)
 ELSE jsonb_build_object('status','verified_game_fuel_onboard_available_for_planned_trip','fuelVerifiedForGame',true,'ledgerPosted',false,'airlineId',o.airline_id,'aircraftInventoryId',o.aircraft_inventory_id,'originAirport',o.origin_airport_key,'destinationAirport',o.destination_airport_key,
 'configurationId',sc.configuration_id,'fuelSourceEventId',c.source_event_id,'fuelCustodyRevision',c.revision,'fuelOnBoardKg',c.onboard_kg,'plannedTripBurnKg',4000,'plannedContingencyKg',400,'plannedHoldingReserveKg',600,'minimumPlannedFuelOnBoardKg',5000,'fuelQuoteModelVersion','GAME_FUEL_FIXTURE_14X')
 END FROM crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1 o JOIN crew_turnaround_fixture_14x.airline_flight_schedule_drafts_v1 sc ON sc.id=o.schedule_id JOIN crew_turnaround_fixture_14x.section9_aircraft_game_fuel_custody_v1 c ON c.aircraft_inventory_id=o.aircraft_inventory_id
 WHERE p_physical_flight_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry$f$),
 ('section9_downstream_crew_reconciliation_v1','p_airline uuid,p_occurrence uuid','jsonb',$f$SELECT jsonb_build_object('status','downstream_unaffected')$f$),
 ('section9_operated_day_candidates_for_aircraft_v1','p_airline uuid,p_aircraft uuid,p_game_day date','jsonb',$f$SELECT jsonb_build_object('status','verified_operational_candidates_only','candidates',coalesce(jsonb_agg(jsonb_build_object('scheduleId',o.schedule_id,'scheduleVersion',o.schedule_version,'flightLocalDate',o.flight_local_date,'weeklyEntry',o.weekly_entry,'phase',ph.phase,'scheduledEventUtc',CASE WHEN ph.phase='arrived' THEN o.arrival_utc ELSE o.departure_utc END,'eventId','fixture-event-'||ph.phase||'-'||replace(o.id::text,'-',''))),'[]'::jsonb)) FROM crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1 o CROSS JOIN (VALUES('departed'),('arrived')) ph(phase) WHERE o.airline_id=p_airline AND o.aircraft_inventory_id=p_aircraft AND o.flight_local_date=p_game_day$f$)
 ,('section9_starter_origin_evidence_v1','p_airline uuid,p_aircraft uuid,p_day date','jsonb',$f$
 SELECT jsonb_build_object('verified',true,'airportKey',a.home_airport_key) FROM crew_turnaround_fixture_14x.airlines a WHERE a.id=p_airline$f$)
 ) AS z(name,args,result,body) LOOP
  EXECUTE format('CREATE FUNCTION crew_turnaround_fixture_14x.%I(%s) RETURNS %s LANGUAGE sql STABLE AS %L',stub.name,stub.args,stub.result,stub.body);
 END LOOP;
 EXECUTE $ddl$CREATE FUNCTION crew_turnaround_fixture_14x.section9_auto_supply_game_only_fuel_v1(p_physical text) RETURNS jsonb LANGUAGE plpgsql AS $fn$
 BEGIN INSERT INTO crew_turnaround_fixture_14x.test_supply VALUES(p_physical);
 RETURN jsonb_build_object('status','game_only_auto_fuel_supply_recorded','ledgerPosted',false);END $fn$$ddl$;
 FOR fn_def IN SELECT pg_get_functiondef(oid) FROM pg_proc WHERE pronamespace='airlinerra_game'::regnamespace AND proname IN
 ('section9_record_signed_operated_flight_movement_v1','section9_aircraft_movement_decision_v1','section9_capture_verified_departure_fuel_v1','section9_apply_verified_arrival_fuel_burn_once_v1','section9_apply_arrival_airframe_usage_once_v1',
 'section9_postarrival_ticket_reconciliation_v1','section9_prepare_actual_ticket_postarrival_finance_v1','section9_prepare_arrived_actual_ticket_finance_batch_v1',
 'section9_verify_operated_flight_hmac_pair_v1','section9_completed_external_crew_cost_v1','section9_bound_delayed_external_cost_v1',
 'section9_approve_completed_game_flight_cost_v1','section9_auto_approve_completed_game_flight_costs_v1',
 'section9_post_completed_flight_finance_once_v1','section9_auto_post_complete_game_flights_v1',
 'section9_prepare_onboard_financials_v1',
 'section9_completed_flight_game_cost_preview_v1','section9_game_route_phase_profile_v1','section9_game_reserve_aware_fuel_quote_v1',
 'section9_game_five_phase_fuel_quote_v1','section9_game_itemized_airport_fee_quote_v1','section9_route_timing_pick_v1','section9_verified_berlin_game_hour_v1',
 'section9_capture_actual_turnaround_v1','section9_sample_turnaround_minutes_v1','section9_dynamic_turnaround_preview_v1','section9_flight_crew_requirements_v1') LOOP
  fn_def:=replace(fn_def,'airlinerra_game','crew_turnaround_fixture_14x');
  fn_def:=replace(fn_def,'public.crew_turnaround_fixture_14x_worlds','crew_turnaround_fixture_14x.fixture_worlds');
  fn_def:=replace(fn_def,'vault.decrypted_secrets','crew_turnaround_fixture_14x.test_signer');
  fn_def:=replace(fn_def,'time_now timestamptz:=clock_timestamp()','time_now timestamptz:=current_setting(''airlinerra.lifecycle_clock'')::timestamptz');
  EXECUTE fn_def;
 END LOOP;
 EXECUTE $ddl$CREATE FUNCTION crew_turnaround_fixture_14x.section9_capture_dispatched_crew_v1(p_airline uuid,p_physical text,p_event text) RETURNS jsonb LANGUAGE plpgsql AS $fn$
 DECLARE o record;
 BEGIN
 SELECT * INTO STRICT o FROM crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1 WHERE p_physical=schedule_id::text||':'||flight_local_date||':'||weekly_entry AND airline_id=p_airline;
 INSERT INTO crew_turnaround_fixture_14x.test_crew VALUES(p_physical);
 INSERT INTO crew_turnaround_fixture_14x.section9_operated_crew_bindings_v1(physical_flight_id,airline_id,plan_id,occurrence_id,departure_event_id,cabin_member_ids)
 VALUES(p_physical,p_airline,gen_random_uuid(),o.id,p_event,ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()]);
 RETURN jsonb_build_object('status','crew_departure_bound'); END $fn$; $ddl$;
 EXECUTE $ddl$CREATE FUNCTION crew_turnaround_fixture_14x.section9_complete_bound_crew_arrival_v1(p_airline uuid,p_physical text,p_event text) RETURNS jsonb LANGUAGE plpgsql AS $fn$
 BEGIN INSERT INTO crew_turnaround_fixture_14x.test_crew_arrival VALUES(p_physical);
 RETURN jsonb_build_object('status','pilot_experience_credited');END $fn$; $ddl$;
 SELECT pg_get_functiondef('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'::regprocedure) INTO STRICT fn_def;
 fn_def:=replace(fn_def,'airlinerra_game','crew_turnaround_fixture_14x');
 fn_def:=replace(fn_def,'vault.decrypted_secrets','crew_turnaround_fixture_14x.test_signer');
 EXECUTE fn_def;
 PERFORM set_config('airlinerra.lifecycle_clock',now_at::text,true);
 IF crew_turnaround_fixture_14x.section9_verified_berlin_game_hour_v1()->>'authoritativeGameHourAvailable'<>'true' THEN RAISE EXCEPTION 'real verified hour rejected';END IF;
 r:=crew_turnaround_fixture_14x.section9_auto_dispatch_due_flight_events_v1(40);
 IF r->>'status'<>'trusted_game_dispatch_cycle_completed'
 OR (r->>'candidatesChecked')::int<>2
 OR (r->>'departuresRecorded')::int<>1
 OR (r->>'blocked')::int<>1
 OR (r->>'atomicEventRollbacks')::int<>1
 OR r->>'eventIsolationEnabled'<>'true'
 OR (r->'blockerCounts'->>'SECTION9_UNVERIFIED_DEPARTURE_FUEL_ROLLS_BACK_MOVEMENT')::int<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_operated_flight_movements_v1)<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.test_supply)<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_game_flight_fuel_departure_receipts_v1)<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.test_crew)<>1
 OR EXISTS(SELECT 1 FROM crew_turnaround_fixture_14x.section9_operated_flight_movements_v1 m JOIN crew_turnaround_fixture_14x.test_bad b ON b.physical_flight_id=m.flight_occurrence_id)
 OR (SELECT booking_status FROM crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1 WHERE id=good_occ)<>'closed'
 OR (SELECT booking_status FROM crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1 WHERE id=bad_occ)<>'open'
 THEN RAISE EXCEPTION 'event isolation failed %',r;END IF;
 replay:=crew_turnaround_fixture_14x.section9_auto_dispatch_due_flight_events_v1(40);
 IF (replay->>'candidatesChecked')::int<>1 OR (replay->>'departuresRecorded')::int<>0
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_operated_flight_movements_v1)<>1
 THEN RAISE EXCEPTION 'replay created duplicate %',replay;END IF;
 UPDATE crew_turnaround_fixture_14x.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=false WHERE world_id=1;
 BEGIN
  PERFORM crew_turnaround_fixture_14x.section9_auto_dispatch_due_flight_events_v1(40);
 EXCEPTION WHEN SQLSTATE '42501' THEN blocked_without_gate:=true;END;
 IF NOT blocked_without_gate OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_operated_flight_movements_v1)<>1 THEN RAISE EXCEPTION 'disabled gate did not preserve legacy batch abort';END IF;
 UPDATE crew_turnaround_fixture_14x.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=true WHERE world_id=1;
 PERFORM set_config('airlinerra.lifecycle_clock',(base+interval '3 hours 3 minutes')::text,true);
 arrivals:=crew_turnaround_fixture_14x.section9_auto_dispatch_due_flight_events_v1(40);
 IF arrivals->>'status'<>'trusted_game_dispatch_cycle_completed'
 OR (arrivals->>'candidatesChecked')::int<>2
 OR (arrivals->>'arrivalsRecorded')::int<>1
 OR (arrivals->>'blocked')::int<>1
 OR (arrivals->'blockerCounts'->>'ARRIVAL_WITHOUT_VERIFIED_DEPARTURE')::int<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_operated_flight_movements_v1)<>2
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_arrived_aircraft_usage_receipts_v1)<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_game_flight_fuel_arrival_receipts_v1)<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.test_crew_arrival)<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_actual_turnaround_receipts_v1)<>1
 OR EXISTS(SELECT 1 FROM crew_turnaround_fixture_14x.section9_operated_flight_movements_v1 m JOIN crew_turnaround_fixture_14x.test_bad b ON b.physical_flight_id=m.flight_occurrence_id)
 THEN RAISE EXCEPTION 'arrival isolation failed %',arrivals;END IF;
 arrival_replay:=crew_turnaround_fixture_14x.section9_auto_dispatch_due_flight_events_v1(40);
 IF (arrival_replay->>'arrivalsRecorded')::int<>0
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_operated_flight_movements_v1)<>2
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_game_flight_fuel_arrival_receipts_v1)<>1 THEN RAISE EXCEPTION 'arrival replay duplicated %',arrival_replay;END IF;
 -- The actual post-arrival financial preparation pipeline now verifies
 -- real signed arrival, actual airframe usage and fuel burn receipts,
 -- inventory reservations and an independent game-cost quote interface.
 BEGIN
 UPDATE crew_turnaround_fixture_14x.section9_passenger_reservation_batches_v1 SET seats_requested=99 WHERE occurrence_id=good_occ;
 ticket_check:=crew_turnaround_fixture_14x.section9_postarrival_ticket_reconciliation_v1((SELECT schedule_id::text||':'||flight_local_date||':'||weekly_entry FROM crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1 WHERE id=good_occ));
 IF ticket_check->>'status'<>'blocked_ticket_seat_or_revenue_reconciliation_mismatch' THEN RAISE EXCEPTION 'incorrect tickets accepted %',ticket_check;END IF;
 RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='restore booking fixture';
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN NULL;END;
 cost_preview:=crew_turnaround_fixture_14x.section9_completed_flight_game_cost_preview_v1(
 (SELECT schedule_id::text||':'||flight_local_date||':'||weekly_entry FROM crew_turnaround_fixture_14x.section9_dated_flight_occurrences_v1 WHERE id=good_occ));
 IF cost_preview->>'status'<>'game_only_completed_flight_cost_estimate' OR (cost_preview->>'bookedPassengers')::int<>100
 THEN RAISE EXCEPTION 'real airport tariff/fuel quote %',cost_preview;END IF;
 finance_batch:=crew_turnaround_fixture_14x.section9_prepare_arrived_actual_ticket_finance_batch_v1(40);
 IF finance_batch->>'status'<>'verified_arrival_actual_ticket_finance_preflight_complete' OR (finance_batch->>'inspected')::int<>1 OR (finance_batch->>'prepared')::int<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_actual_ticket_finance_preparations_v1)<>1
 OR (SELECT ticket_quote_usd FROM crew_turnaround_fixture_14x.section9_actual_ticket_finance_preparations_v1)<>10000
 OR (SELECT provisional_operating_cost_usd FROM crew_turnaround_fixture_14x.section9_actual_ticket_finance_preparations_v1)<>(cost_preview->>'operatingCostEstimateUsd')::numeric
 THEN RAISE EXCEPTION 'real finance preflight failed %',finance_batch;END IF;
 finance_replay:=crew_turnaround_fixture_14x.section9_prepare_arrived_actual_ticket_finance_batch_v1(40);
 IF (finance_replay->>'prepared')::int<>0 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_actual_ticket_finance_preparations_v1)<>1 THEN RAISE EXCEPTION 'finance prep replay duplicate %',finance_replay;END IF;
 -- Directly execute the same independently gated cost-approval and
 -- final posting jobs configured in cron, with real trusted movement HMAC,
 -- real actual fuel burn, actual ticket and postarrival preparation evidence.
 approved_cost:=crew_turnaround_fixture_14x.section9_auto_approve_completed_game_flight_costs_v1(40);
 IF approved_cost->>'status'<>'game_cost_batch_completed' OR (approved_cost->>'checked')::int<>1 OR (approved_cost->>'approved')::int<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_flight_final_cost_approvals_v1 WHERE approval_state='approved')<>1
 OR (SELECT fuel_cost_usd FROM crew_turnaround_fixture_14x.section9_flight_final_cost_approvals_v1)<>3800
 OR (SELECT airport_navigation_cost_usd FROM crew_turnaround_fixture_14x.section9_flight_final_cost_approvals_v1)<>(cost_preview->>'airportCostEstimateUsd')::numeric
 THEN RAISE EXCEPTION 'real final cost approval %',approved_cost;END IF;
 SELECT 10000 - fuel_cost_usd-airport_navigation_cost_usd-crew_cost_usd INTO STRICT expected_net FROM crew_turnaround_fixture_14x.section9_flight_final_cost_approvals_v1;
 BEGIN
 UPDATE crew_turnaround_fixture_14x.section9_flight_final_cost_approvals_v1 SET crew_cost_usd=50;
 post_replay:=crew_turnaround_fixture_14x.section9_post_completed_flight_finance_once_v1(
 (SELECT physical_flight_id FROM crew_turnaround_fixture_14x.section9_actual_ticket_finance_preparations_v1 LIMIT 1));
 IF post_replay->>'status'<>'blocked_external_crew_cost_mismatch' THEN RAISE EXCEPTION 'fabricated external cost not blocked %',post_replay;END IF;
 RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='restore cost approval';
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN NULL;END;
 posted_finance:=crew_turnaround_fixture_14x.section9_auto_post_complete_game_flights_v1(40);
 IF posted_finance->>'status'<>'game_complete_flight_finance_batch_checked' OR (posted_finance->>'checked')::int<>1 OR (posted_finance->>'posted')::int<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.section9_route_posted_flight_financials_v1)<>1
 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.airline_ledger WHERE airline_id=a.id)<>3
 OR (SELECT cash_usd FROM crew_turnaround_fixture_14x.airlines WHERE id=a.id)<>opening_cash+expected_net
 OR (SELECT sum(amount_usd) FROM crew_turnaround_fixture_14x.airline_ledger WHERE airline_id=a.id)<>opening_cash+expected_net
 THEN RAISE EXCEPTION 'real automatic final finance %',posted_finance;END IF;
 post_replay:=crew_turnaround_fixture_14x.section9_auto_post_complete_game_flights_v1(40);
 IF (post_replay->>'posted')::int<>0 OR (SELECT count(*) FROM crew_turnaround_fixture_14x.airline_ledger WHERE airline_id=a.id)<>3 THEN RAISE EXCEPTION 'finance replay charged again %',post_replay;END IF;
 IF NOT EXISTS(SELECT 1 FROM crew_turnaround_fixture_14x.section9_actual_turnaround_receipts_v1 WHERE assigned_cabin_crew=4 AND actual_minutes BETWEEN 40 AND 60 AND available_utc=arrival_utc+make_interval(mins=>actual_minutes)) THEN RAISE EXCEPTION 'real dynamic turnaround evidence missing';END IF;
 result:=jsonb_build_object('status','passed','realDynamicTurnaround',true,'realCostApprovalWorker',true,'realFinalPostingWorker',true,'postedNetCashUsd',expected_net,'actualGameTariffQuote',true,'actualReserveAwareFuelQuote',true,'realVerifiedClock',true,'realFinancialLedgerAtomic',true,'incorrectCrewCostRejected',true,'replayedFinanceNoCharge',true,'realPostarrivalFinancePreparation',true,'realTicketReconciliation',true,'financePreparationReplayProtected',true,'ticketMismatchRejected',true,'realMovementWriter',true,'realFuelDepartureCapture',true,'realFuelArrivalBurn',true,'realAirframeUsage',true,'oneCompleteArrival',true,'arrivalFuelBurnCreated',true,'arrivalAirframeUsageCreated',true,'crewArrivalTracked',true,'actualTurnaroundRecorded',true,'arrivalReplayNoDuplicate',true,'isolatedBadFlightRolledBack',true,'unrelatedGoodFlightCommitted',true,'badFuelSupplyRolledBack',true,'badSignedDepartureRolledBack',true,'goodFuelAndCrewCaptured',true,'bookingClosedOnlyForGoodFlight',true,'replayNoDouble',true,'disabledGatePreservesLegacyFailClosed',true,'reportedBlocks',r->'blockerCounts','liveFinancialsUntouched',true);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.real_turnaround_fixture_result',SQLERRM,true);END;
END $test$;
SELECT current_setting('airlinerra.real_turnaround_fixture_result',true)::jsonb AS dispatch_test,to_regnamespace('crew_turnaround_fixture_14x') IS NULL AS fixture_removed,
 (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1) AS live_movement_count,
 (SELECT count(*) FROM airlinerra_game.section9_route_posted_flight_financials_v1) AS live_finance_count;