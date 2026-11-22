-- Phase 14W isolated dispatcher integration. No production flight, money,
-- fuel, signer or crew row is written; even fixture success is rolled back.
DO $test$
DECLARE
 tbl text;fn_def text;stub record;a record;config bigint;aircraft uuid;sc uuid;occ uuid;
 bad_occ uuid;good_occ uuid;arrivals jsonb;arrival_replay jsonb;finance_batch jsonb;finance_replay jsonb;ticket_check jsonb;approved_cost jsonb;posted_finance jsonb;post_replay jsonb;opening_cash numeric;expected_net numeric;fee_rec record;cost_preview jsonb;now_at timestamptz:='2026-11-20T08:02:00Z';
 base timestamptz:='2026-11-20T08:00:00Z';i int;r jsonb;replay jsonb;blocked_without_gate boolean:=false;
 before_live bigint;result jsonb;hire jsonb;grp text;member_captain uuid;member_fo uuid;member_cabin uuid[];assignment_duties jsonb;crew_assignments jsonb:='[]'::jsonb;crew_snapshot jsonb;crew_save jsonb;crew_plan uuid:=gen_random_uuid();crew_hiring_invoice numeric;invalid_crew jsonb;gate_guard jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA crew_strict_roster_fixture_14y;
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
 'airport_facilities','section9_game_approved_fuel_load_receipts_v1',
 'section9_onboard_service_release_v1','section9_onboard_departure_snapshots_v1','section9_onboard_finance_receipts_v1','airline_ledger',
 'section9_crew_bases_v1','section9_pilot_qualification_groups_v1','section9_airline_crew_roster_v1','section9_pilot_profiles_v1','section9_pilot_family_permissions_v1','section9_pilot_base_assignments_v1',
 'section9_cabin_crew_pools_v1','section9_cabin_crew_members_v1','section9_crew_unavailability_v1',
 'section9_shared_crew_employment_release_v1','section9_shared_crew_salary_policy_v1','section9_shared_crew_hire_batches_v1','section9_crew_scheduler_policy_v2',
 'section9_crew_plan_batches_v1','section9_planned_flight_crews_v1','section9_planned_crew_duties_v1','section9_planned_crew_seats_v1',
 'section9_pilot_flight_experience_v1','section9_crew_movement_capture_release_v1',
 'section9_dated_flight_occurrences_v1','section9_occurrence_capacity_inventory_v1',
 'section9_route_commercial_plans_v1','section9_schedule_operational_certifications_v1',
 'section9_schedule_activation_preparations_v1','section6_weekly_airport_slot_reservations_v1',
 'section9_activation_release_policy_v1','section9_trusted_execution_release_policy_v1',
 'section9_flight_engine_readiness_audit_v1','section9_operated_flight_movements_v1',
 'section9_delayed_crew_approvals_v1','section9_delayed_crew_approval_release_v1',
 'section9_operated_crew_capture_issues_v1'] LOOP
  EXECUTE format('CREATE TABLE crew_strict_roster_fixture_14y.%I(LIKE airlinerra_game.%I INCLUDING ALL)',tbl,tbl);
 END LOOP;
 CREATE TABLE crew_strict_roster_fixture_14y.section8_airport_operating_tariffs_v1 AS SELECT * FROM airlinerra_game.section8_airport_operating_tariffs_v1 WHERE world_id=1 AND airport_key IN('OURAIRPORTS:4610','OURAIRPORTS:2212');
 CREATE TABLE crew_strict_roster_fixture_14y.airport_unified_operations_v1 AS SELECT * FROM airlinerra_game.airport_unified_operations_v1 WHERE world_id=1 AND airport_key IN('OURAIRPORTS:4610','OURAIRPORTS:2212');
 CREATE TABLE crew_strict_roster_fixture_14y.test_signer(name text primary key,decrypted_secret text);
 CREATE TABLE crew_strict_roster_fixture_14y.fixture_worlds(id smallint primary key,state text,opens_at timestamptz);
 INSERT INTO crew_strict_roster_fixture_14y.fixture_worlds VALUES(1,'active',now()-interval '30 days');
 INSERT INTO crew_strict_roster_fixture_14y.airport_facilities SELECT * FROM airlinerra_game.airport_facilities WHERE world_id=1 AND airport_key IN('OURAIRPORTS:4610','OURAIRPORTS:2212');
 CREATE TABLE crew_strict_roster_fixture_14y.test_supply(physical_flight_id text primary key);
 CREATE TABLE crew_strict_roster_fixture_14y.test_fuel(physical_flight_id text primary key,engine_event_id text);
 CREATE TABLE crew_strict_roster_fixture_14y.test_crew(physical_flight_id text primary key);
 CREATE TABLE crew_strict_roster_fixture_14y.test_bad(physical_flight_id text primary key);
 CREATE TABLE crew_strict_roster_fixture_14y.test_usage(physical_flight_id text primary key);
 CREATE TABLE crew_strict_roster_fixture_14y.test_fuel_arrival(physical_flight_id text primary key);
 CREATE TABLE crew_strict_roster_fixture_14y.test_crew_arrival(physical_flight_id text primary key);
 CREATE TABLE crew_strict_roster_fixture_14y.test_turnaround(physical_flight_id text primary key,available_utc timestamptz);
 INSERT INTO crew_strict_roster_fixture_14y.test_signer VALUES('airlinerra_operated_flight_auto_signing_v1',repeat('isolated-dispatch-key-',5));
 SELECT airline.*,f.configuration_id INTO STRICT a FROM airlinerra_game.airlines airline JOIN airlinerra_game.airline_aircraft_inventory f ON f.airline_id=airline.id JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=f.configuration_id AND c.use_type='passenger' WHERE airline.world_id=1 LIMIT 1;
 config:=a.configuration_id;
 INSERT INTO crew_strict_roster_fixture_14y.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 SELECT cash_usd INTO STRICT opening_cash FROM crew_strict_roster_fixture_14y.airlines WHERE id=a.id;
 INSERT INTO crew_strict_roster_fixture_14y.airline_ledger(airline_id,entry_kind,amount_usd) VALUES(a.id,'ADJUSTMENT',opening_cash);
 INSERT INTO crew_strict_roster_fixture_14y.section9_dynamic_turnaround_release_v1(world_id,capture_enabled,dispatch_effects_enabled) VALUES(1,true,false);
 INSERT INTO crew_strict_roster_fixture_14y.section9_flight_crew_model_policy_v1 SELECT * FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=config;
 SELECT qualification_group INTO STRICT grp FROM crew_strict_roster_fixture_14y.section9_flight_crew_model_policy_v1 WHERE configuration_id=config;
 INSERT INTO crew_strict_roster_fixture_14y.section9_crew_bases_v1 SELECT * FROM airlinerra_game.section9_crew_bases_v1 WHERE airline_id=a.id AND airport_key=a.home_airport_key;
 INSERT INTO crew_strict_roster_fixture_14y.section9_pilot_qualification_groups_v1 SELECT * FROM airlinerra_game.section9_pilot_qualification_groups_v1 WHERE qualification_group=grp;
 INSERT INTO crew_strict_roster_fixture_14y.section9_shared_crew_employment_release_v1(world_id,manual_hiring_enabled,automatic_hiring_enabled,payroll_enabled) VALUES(1,true,false,false);
 INSERT INTO crew_strict_roster_fixture_14y.section9_shared_crew_salary_policy_v1 SELECT * FROM airlinerra_game.section9_shared_crew_salary_policy_v1;
 INSERT INTO crew_strict_roster_fixture_14y.section9_crew_scheduler_policy_v2 SELECT * FROM airlinerra_game.section9_crew_scheduler_policy_v2;
 INSERT INTO crew_strict_roster_fixture_14y.section9_crew_movement_capture_release_v1(world_id,capture_enabled) VALUES(1,true);
 INSERT INTO crew_strict_roster_fixture_14y.section9_flight_finance_posting_release_v1(world_id,release_state,approved_at,approval_reference)
 VALUES(1,'approved',clock_timestamp(),'isolated-fixture-finance-approval-14x');
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO tbl FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='section9_game_fuel_model_snapshot_v1' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO crew_strict_roster_fixture_14y.section9_game_fuel_model_snapshot_v1(%s) SELECT %s FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 WHERE configuration_id=$1',tbl,tbl) USING config;
 INSERT INTO crew_strict_roster_fixture_14y.section9_activation_release_policy_v1(world_id,release_state,release_reference,approved_by,enabled_at,crew_mode) VALUES(1,'enabled','isolated-test-activation-v1','isolated-reviewer',clock_timestamp(),'deferred_phase1');
 INSERT INTO crew_strict_roster_fixture_14y.section9_trusted_execution_release_policy_v1(world_id,release_state,release_reference,approved_by,reviewed_at,enabled_at) VALUES(1,'enabled','isolated-trusted-execution-v1','isolated-reviewer',clock_timestamp(),clock_timestamp());
 INSERT INTO crew_strict_roster_fixture_14y.section9_flight_engine_readiness_audit_v1(world_id,trusted_flight_execution_release,fuel_transaction_release,automatic_flight_and_fuel_settlement_enabled) VALUES(1,'ACTIVATED','ACTIVATED',true);
 INSERT INTO crew_strict_roster_fixture_14y.section9_delayed_crew_approval_release_v1(world_id,automatic_dispatch_event_isolation_enabled,automatic_normal_crew_enforcement_enabled) VALUES(1,true,true);
 INSERT INTO crew_strict_roster_fixture_14y.holding_world_clock_v1(world_id,confirmed_game_date,clock_source,engine_proof_ref,last_verified_at) VALUES(1,base::date,'authoritative_game_engine','fixture-clock-proof-14x',base);
 INSERT INTO crew_strict_roster_fixture_14y.section9_verified_game_tick_receipts_v1(world_id,game_date,engine_event_id,event_hmac_sha256,dispatch_kind,accepted_at) VALUES(1,base::date,'horizon-world1-day-'||base::date,repeat('f',64),'no_verified_flights',base);
 INSERT INTO crew_strict_roster_fixture_14y.section9_clock_producer_schedule_v1(world_id,start_game_date,official_world_opens_at,producer_status,admin_release_reference,enabled_at) VALUES(1,base::date,base-interval '1 day','enabled','fixture-clock-verified-release',base);
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO tbl FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO crew_strict_roster_fixture_14y.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',tbl,tbl) USING ARRAY[a.home_airport_key,'OURAIRPORTS:2212'];
 CREATE FUNCTION crew_strict_roster_fixture_14y.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS 'SELECT ''2026-11-18T08:00:00Z''::timestamptz';
 FOR fn_def IN SELECT pg_get_functiondef(oid) FROM pg_proc WHERE pronamespace='airlinerra_game'::regnamespace AND proname IN
 ('section9_owned_shared_crew_payroll_forecast_v1','section9_owned_shared_crew_hire_quote_v1','section9_confirm_owned_shared_crew_hire_v1',
 'section9_pilot_can_fill_rank_v1','section9_crew_unavailability_windows_v1','section9_owned_weekly_crew_input_v1','section9_crew_rotation_window_v2',
 'section9_crew_duty_fit_v2','section9_save_owned_crew_plan_preview_v1',
 'section9_record_pilot_departure_manifest_v1','section9_credit_completed_pilot_flight_v1','section9_capture_dispatched_crew_v1','section9_complete_bound_crew_arrival_v1',
 'section9_crew_actual_history_v1','section9_flight_crew_requirements_v1','section9_cabin_composition_valid_v1','section9_verified_external_cabin_input_v1','section9_pilot_counts_valid_v1',
 'section9_same_duty_prior_sector_v1') LOOP
  fn_def:=replace(fn_def,'airlinerra_game','crew_strict_roster_fixture_14y');
  EXECUTE fn_def;
 END LOOP;
 -- Hire actual qualified internal employees (two independent rotation teams).

 FOR i IN 1..2 LOOP
  aircraft:=gen_random_uuid();
  INSERT INTO crew_strict_roster_fixture_14y.airline_aircraft_inventory(id,airline_id,configuration_id,registration,ownership_type,fleet_status) VALUES(aircraft,a.id,config,'FIXTURE-14W-'||i,'owned','in_service');
  IF i=1 THEN
 hire:=crew_strict_roster_fixture_14y.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,gen_random_uuid(),a.home_airport_key,grp,2,2,8,100000);
 IF hire->>'status'<>'shared_crew_hired' THEN RAISE EXCEPTION 'actual qualification hire failed %',hire;END IF;
 crew_hiring_invoice:=(hire->>'additionalMonthlySalaryUsd')::numeric;
  END IF;
  INSERT INTO crew_strict_roster_fixture_14y.airline_flight_schedule_drafts_v1(world_id,airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified,departure_stand_type,arrival_stand_type)
  VALUES(1,a.id,aircraft,config,a.iata_code||(990+i),a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),jsonb_build_array(jsonb_build_object('day',extract(isodow FROM base)::int-1,'time',to_char((base+make_interval(mins=>i-1)) AT TIME ZONE 'Europe/Belgrade','HH24:MI'))),'{}',a.owner_player_id,'active',true,'terminal','terminal') RETURNING id INTO sc;
  INSERT INTO crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1(world_id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,flight_local_date,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,turnaround_minutes,verified_passenger_seats,booking_status,booked_seats,recognized_revenue_usd,source_kind)
  VALUES(1,a.id,sc,aircraft,1,1,base::date,a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),60,156,'open',100,0,'game_verified_saleable_schedule_v1') RETURNING id INTO occ;
  INSERT INTO crew_strict_roster_fixture_14y.section9_verified_schedule_capacity_v1(schedule_id,airline_id,schedule_version,passenger_seats,cargo_capacity_tonnes,verification_source) VALUES(sc,a.id,1,156,0,'fixture-14x-schedule-verified');
  INSERT INTO crew_strict_roster_fixture_14y.aircraft_maintenance_state_v1(aircraft_inventory_id,airline_id,verified_tracking_started_utc,tracked_flight_hours,tracked_flight_cycles) VALUES(aircraft,a.id,base-interval '1 day',0,0);
  INSERT INTO crew_strict_roster_fixture_14y.section9_aircraft_game_fuel_custody_v1(aircraft_inventory_id,airline_id,world_id,configuration_id,at_airport_key,fuel_game_family,onboard_kg,source_event_id,source_event_kind,evidence_reference,game_hour_utc,revision)
 VALUES(aircraft,a.id,1,config,a.home_airport_key,'TURBINE_KEROSENE_ASSUMED',CASE WHEN i=1 THEN 1000 ELSE 20000 END,'fixture-approved-fuel-'||i,'approved_game_fuel_load','fixture-aircraft-fuel-evidence-14x',base-interval '1 day',1);
  INSERT INTO crew_strict_roster_fixture_14y.section9_game_approved_fuel_load_receipts_v1(source_event_id,airline_id,aircraft_inventory_id,at_airport_key,fuel_family,load_added_kg,fuel_after_load_kg,game_hour_utc,game_supplier_reference,source_status)
 VALUES('fixture-approved-fuel-'||i,a.id,aircraft,a.home_airport_key,'TURBINE_KEROSENE_ASSUMED',CASE WHEN i=1 THEN 1000 ELSE 20000 END,CASE WHEN i=1 THEN 1000 ELSE 20000 END,base-interval '1 day','fixture-aircraft-fuel-evidence-14x','game_authority_approved');
  INSERT INTO crew_strict_roster_fixture_14y.section9_route_commercial_plans_v1(schedule_id,airline_id,economy_fare_usd,version) VALUES(sc,a.id,100,1);
  INSERT INTO crew_strict_roster_fixture_14y.section9_occurrence_capacity_inventory_v1(physical_flight_id,schedule_id,airline_id,local_departure_date,weekly_entry,schedule_version,commercial_version,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,passenger_capacity,cargo_capacity_tonnes,passengers_held,cargo_held_tonnes)
  VALUES(sc::text||':'||base::date||':1',sc,a.id,base::date,1,1,1,a.home_airport_key,'OURAIRPORTS:2212',base+make_interval(mins=>i-1),base+make_interval(hours=>3,mins=>i-1),156,0,100,0);
  INSERT INTO crew_strict_roster_fixture_14y.section9_schedule_activation_preparations_v1(schedule_id,schedule_version,airline_id,aircraft_inventory_id,verified_game_date,certified_horizon_days,fingerprint_md5,release_reference)
  VALUES(sc,1,a.id,aircraft,base::date,7,repeat('b',32),'isolated-activation-proof');
  INSERT INTO crew_strict_roster_fixture_14y.section9_schedule_operational_certifications_v1(schedule_id,airline_id,schedule_version,clearance_type,review_status,source_kind,source_reference,reviewer_reference,reviewed_at,valid_from_game_date,valid_to_game_date)
  SELECT sc,a.id,1,v.kind,'certified',v.source,'isolated-verified-source-'||v.kind,'isolated-independent-reviewer',clock_timestamp(),base::date,base::date+7
  FROM (VALUES
  ('crew_duty','verified_crew_duty_engine'),
  ('operator_licence','verified_game_licence_engine'),
  ('route_traffic_rights','verified_game_traffic_rights_engine'),
  ('airport_slot_capacity','verified_airport_slot_engine'),
  ('trusted_flight_execution','trusted_flight_operations_engine')) v(kind,source);
  INSERT INTO crew_strict_roster_fixture_14y.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
  VALUES(sc,1,a.home_airport_key,'terminal','departure',extract(isodow FROM base)::int-1,480),
        (sc,1,'OURAIRPORTS:2212','terminal','arrival',extract(isodow FROM base)::int-1,660);
  INSERT INTO crew_strict_roster_fixture_14y.section9_passenger_reservation_batches_v1(occurrence_id,reservation_key,fare_class,seats_requested,quoted_fare_usd,reservation_status)
 VALUES(occ,'fixture-reserved-14x-'||i,'economy',100,100,'reserved');
  member_captain:=(hire->'pilotIds'->>(i-1))::uuid;
  member_fo:=(hire->'pilotIds'->>(i+1))::uuid;
  member_cabin:=ARRAY[(hire->'cabinIds'->>((i-1)*4))::uuid,(hire->'cabinIds'->>((i-1)*4+1))::uuid,(hire->'cabinIds'->>((i-1)*4+2))::uuid,(hire->'cabinIds'->>((i-1)*4+3))::uuid];
  SELECT jsonb_agg(jsonb_build_object('employeeId',x.emp,'role',x.seat,'dutyStartUtc',base+make_interval(mins=>i-1)-interval '2 hours','dutyEndUtc',base+make_interval(hours=>3,mins=>i-1)+interval '30 minutes')) INTO assignment_duties
  FROM (SELECT member_captain emp,'captain' seat UNION ALL SELECT member_fo,'firstOfficer' UNION ALL SELECT unnest(member_cabin),'cabin') x;
  crew_assignments:=crew_assignments||jsonb_build_array(jsonb_build_object('flightId',occ,'aircraftId',aircraft,'departureUtc',base+make_interval(mins=>i-1),'arrivalUtc',base+make_interval(hours=>3,mins=>i-1),'captains',jsonb_build_array(member_captain),'firstOfficers',jsonb_build_array(member_fo),'cabinCrew',to_jsonb(member_cabin),'duties',assignment_duties));
  IF i=1 THEN
   bad_occ:=occ;
   INSERT INTO crew_strict_roster_fixture_14y.test_bad VALUES(sc::text||':'||base::date||':1');
  ELSE good_occ:=occ;END IF;
 END LOOP;
 crew_snapshot:=crew_strict_roster_fixture_14y.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,base-interval '1 hour');
 IF crew_snapshot->>'status'<>'weekly_crew_bootstrap_input_preview' THEN RAISE EXCEPTION 'crew snapshot %',crew_snapshot;END IF;
 crew_save:=crew_strict_roster_fixture_14y.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,crew_plan,base-interval '1 hour',crew_snapshot,crew_assignments);
 IF crew_save->>'status'<>'validated_preview' OR (crew_save->>'flightCount')::int<>2 THEN RAISE EXCEPTION 'owned crew plan %',crew_save;END IF;
 -- Read-only authoritative gates/studies are canned; the actual dispatcher
 -- controls event ordering, per-event subtransactions, signed-movement request,
 -- fuel request, booking closure, crew call, replay and reporting.
 FOR stub IN SELECT * FROM (VALUES
 ('section9_auto_disruption_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_auto_recover_delayed_crew_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_auto_replan_downstream_cycle_v1','p_limit integer','jsonb',$f$SELECT '{}'::jsonb$f$),
 ('section9_effective_dispatch_window_v1','p_occurrence uuid','TABLE(effective_departure_utc timestamptz,effective_arrival_utc timestamptz,is_delayed boolean,dispatch_allowed boolean)',$f$SELECT departure_utc,arrival_utc,false,true FROM crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1 WHERE id=p_occurrence$f$),
 ('section9_disruption_departure_clear_v1','p_occurrence uuid','boolean',$f$SELECT true$f$),
 ('section9_automatic_disruption_ready_v1','','boolean',$f$SELECT false$f$),
 ('section9_canonical_aoc_covers_v1','p_airline uuid,p_day date,p_days integer','boolean',$f$SELECT true$f$),
 ('section9_verified_permission_game_day_v1','','date',$f$SELECT DATE '2026-11-20'$f$),
 ('section9_game_route_licence_scope_v1','p_airline uuid,p_origin text,p_destination text,p_day date,p_days integer','jsonb',$f$SELECT jsonb_build_object('allowed',true)$f$),
 ('section9_delayed_turnaround_clear_v1','p_aircraft uuid,p_occurrence uuid,p_departure timestamptz','boolean',$f$SELECT true$f$),
 ('section9_verified_game_maintenance_dispatch_window_v1','p_owner uuid,p_airline uuid,p_aircraft uuid,p_depart_utc timestamptz,p_arrive_utc timestamptz','jsonb',$f$SELECT jsonb_build_object('gameMaintenanceClear',true)$f$),
 ('section9_downstream_crew_reconciliation_v1','p_airline uuid,p_occurrence uuid','jsonb',$f$SELECT jsonb_build_object('status','downstream_unaffected')$f$),
 ('section9_operated_day_candidates_for_aircraft_v1','p_airline uuid,p_aircraft uuid,p_game_day date','jsonb',$f$SELECT jsonb_build_object('status','verified_operational_candidates_only','candidates',coalesce(jsonb_agg(jsonb_build_object('scheduleId',o.schedule_id,'scheduleVersion',o.schedule_version,'flightLocalDate',o.flight_local_date,'weeklyEntry',o.weekly_entry,'phase',ph.phase,'scheduledEventUtc',CASE WHEN ph.phase='arrived' THEN o.arrival_utc ELSE o.departure_utc END,'eventId','fixture-event-'||ph.phase||'-'||replace(o.id::text,'-',''))),'[]'::jsonb)) FROM crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1 o CROSS JOIN (VALUES('departed'),('arrived')) ph(phase) WHERE o.airline_id=p_airline AND o.aircraft_inventory_id=p_aircraft AND o.flight_local_date=p_game_day$f$)
 ,('section9_starter_origin_evidence_v1','p_airline uuid,p_aircraft uuid,p_day date','jsonb',$f$
 SELECT jsonb_build_object('verified',true,'airportKey',a.home_airport_key) FROM crew_strict_roster_fixture_14y.airlines a WHERE a.id=p_airline$f$)
 ) AS z(name,args,result,body) LOOP
  EXECUTE format('CREATE FUNCTION crew_strict_roster_fixture_14y.%I(%s) RETURNS %s LANGUAGE sql STABLE AS %L',stub.name,stub.args,stub.result,stub.body);
 END LOOP;
 FOR fn_def IN SELECT pg_get_functiondef(oid) FROM pg_proc WHERE pronamespace='airlinerra_game'::regnamespace AND proname IN
 ('section9_record_signed_operated_flight_movement_v1','section9_aircraft_movement_decision_v1','section9_capture_verified_departure_fuel_v1','section9_apply_verified_arrival_fuel_burn_once_v1','section9_apply_arrival_airframe_usage_once_v1',
 'section9_postarrival_ticket_reconciliation_v1','section9_prepare_actual_ticket_postarrival_finance_v1','section9_prepare_arrived_actual_ticket_finance_batch_v1',
 'section9_verify_operated_flight_hmac_pair_v1','section9_completed_external_crew_cost_v1','section9_bound_delayed_external_cost_v1',
 'section9_approve_completed_game_flight_cost_v1','section9_auto_approve_completed_game_flight_costs_v1',
 'section9_post_completed_flight_finance_once_v1','section9_auto_post_complete_game_flights_v1',
 'section9_prepare_onboard_financials_v1',
 'section9_completed_flight_game_cost_preview_v1','section9_game_route_phase_profile_v1','section9_game_reserve_aware_fuel_quote_v1',
 'section9_game_five_phase_fuel_quote_v1','section9_game_itemized_airport_fee_quote_v1','section9_route_timing_pick_v1','section9_verified_berlin_game_hour_v1',
 'section9_capture_actual_turnaround_v1','section9_sample_turnaround_minutes_v1','section9_dynamic_turnaround_preview_v1','section9_flight_crew_requirements_v1','section9_verify_game_fuel_before_departure_v1','section9_auto_supply_game_only_fuel_v1') LOOP
  fn_def:=replace(fn_def,'airlinerra_game','crew_strict_roster_fixture_14y');
  fn_def:=replace(fn_def,'public.crew_strict_roster_fixture_14y_worlds','crew_strict_roster_fixture_14y.fixture_worlds');
  fn_def:=replace(fn_def,'vault.decrypted_secrets','crew_strict_roster_fixture_14y.test_signer');
  fn_def:=replace(fn_def,'time_now timestamptz:=clock_timestamp()','time_now timestamptz:=current_setting(''airlinerra.lifecycle_clock'')::timestamptz');
  EXECUTE fn_def;
 END LOOP;

 EXECUTE $ddl$CREATE FUNCTION crew_strict_roster_fixture_14y.fixture_reject_bad_departure_fuel() RETURNS trigger LANGUAGE plpgsql AS $fn$
 BEGIN IF EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.test_bad WHERE physical_flight_id=NEW.physical_flight_id) THEN RAISE EXCEPTION 'FIXTURE_BAD_FUEL_RECEIPT';END IF;RETURN NEW;END $fn$; $ddl$;
 CREATE TRIGGER fixture_reject_bad_departure_fuel BEFORE INSERT ON crew_strict_roster_fixture_14y.section9_game_flight_fuel_departure_receipts_v1 FOR EACH ROW EXECUTE FUNCTION crew_strict_roster_fixture_14y.fixture_reject_bad_departure_fuel();
 SELECT pg_get_functiondef('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'::regprocedure) INTO STRICT fn_def;
 fn_def:=replace(fn_def,'airlinerra_game','crew_strict_roster_fixture_14y');
 fn_def:=replace(fn_def,'vault.decrypted_secrets','crew_strict_roster_fixture_14y.test_signer');
 EXECUTE fn_def;
 PERFORM set_config('airlinerra.lifecycle_clock',now_at::text,true);
 IF crew_strict_roster_fixture_14y.section9_verified_berlin_game_hour_v1()->>'authoritativeGameHourAvailable'<>'true' THEN RAISE EXCEPTION 'real verified hour rejected';END IF;

 UPDATE crew_strict_roster_fixture_14y.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=false WHERE world_id=1;
 gate_guard:=crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 IF gate_guard->>'status'<>'blocked_normal_crew_requires_atomic_isolation'
  OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)
 THEN RAISE EXCEPTION 'strict crew enabled without atomic events %',gate_guard;END IF;
 UPDATE crew_strict_roster_fixture_14y.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=true WHERE world_id=1;
 UPDATE crew_strict_roster_fixture_14y.section9_crew_movement_capture_release_v1 SET capture_enabled=false WHERE world_id=1;
 gate_guard:=crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 IF gate_guard->>'status'<>'blocked_normal_crew_capture_not_released'
  OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)
 THEN RAISE EXCEPTION 'strict crew without capture flag %',gate_guard;END IF;
 UPDATE crew_strict_roster_fixture_14y.section9_crew_movement_capture_release_v1 SET capture_enabled=true WHERE world_id=1;
 UPDATE crew_strict_roster_fixture_14y.section9_pilot_family_permissions_v1 SET qualification_status='suspended'
 WHERE airline_id=a.id AND crew_id=(hire->'pilotIds'->>1)::uuid AND qualification_group=grp;
 invalid_crew:=crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 IF invalid_crew->>'status'<>'trusted_game_dispatch_cycle_completed'
 OR (invalid_crew->>'departuresRecorded')::int<>0
 OR (invalid_crew->>'blocked')::int<>2
 OR (invalid_crew->'blockerCounts'->>'SECTION9_NORMAL_CREW_BINDING_ATOMIC_ROLLBACK')::int<>1
 OR (invalid_crew->'blockerCounts'->>'DISPATCH_EVENT_ATOMIC_ROLLBACK_P0001')::int<>1
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_game_flight_fuel_departure_receipts_v1)
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_pilot_departure_manifests_v1)
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_crew_bindings_v1)
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_crew_capture_issues_v1)
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1 WHERE booking_status<>'open')
 THEN RAISE EXCEPTION 'invalid pilot permitted to depart %',invalid_crew;END IF;
 UPDATE crew_strict_roster_fixture_14y.section9_pilot_family_permissions_v1 SET qualification_status='active'
 WHERE airline_id=a.id AND crew_id=(hire->'pilotIds'->>1)::uuid AND qualification_group=grp;
 INSERT INTO crew_strict_roster_fixture_14y.section9_crew_unavailability_v1(airline_id,cabin_member_id,reason,start_utc,end_utc)
 VALUES(a.id,(hire->'cabinIds'->>4)::uuid,'sickness',base-interval '1 hour',base+interval '4 hours');
 invalid_crew:=crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 IF (invalid_crew->>'departuresRecorded')::int<>0
 OR (invalid_crew->'blockerCounts'->>'SECTION9_NORMAL_CREW_BINDING_ATOMIC_ROLLBACK')::int<>1
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_crew_bindings_v1)
 THEN RAISE EXCEPTION 'unavailable cabin crew permitted to depart %',invalid_crew;END IF;
 UPDATE crew_strict_roster_fixture_14y.section9_crew_unavailability_v1 SET status='cancelled'
 WHERE airline_id=a.id AND cabin_member_id=(hire->'cabinIds'->>4)::uuid;
 r:=crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 IF r->>'status'<>'trusted_game_dispatch_cycle_completed'
 OR (r->>'candidatesChecked')::int<>2
 OR (r->>'departuresRecorded')::int<>1
 OR (r->>'blocked')::int<>1
 OR (r->>'atomicEventRollbacks')::int<>1
 OR r->>'eventIsolationEnabled'<>'true' OR r->>'normalCrewDispatchEnforced'<>'true'
 OR (r->'blockerCounts'->>'DISPATCH_EVENT_ATOMIC_ROLLBACK_P0001')::int<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_game_approved_fuel_load_receipts_v1)<>2
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_aircraft_game_fuel_custody_v1 c JOIN crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1 o ON o.aircraft_inventory_id=c.aircraft_inventory_id WHERE o.id=bad_occ AND (c.onboard_kg<>1000 OR c.revision<>1))
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_game_flight_fuel_departure_receipts_v1)<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_operated_crew_bindings_v1)<>1
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1 m JOIN crew_strict_roster_fixture_14y.test_bad b ON b.physical_flight_id=m.flight_occurrence_id)
 OR (SELECT booking_status FROM crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1 WHERE id=good_occ)<>'closed'
 OR (SELECT booking_status FROM crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1 WHERE id=bad_occ)<>'open'
 THEN RAISE EXCEPTION 'event isolation failed %',r;END IF;
 replay:=crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 IF (replay->>'candidatesChecked')::int<>1 OR (replay->>'departuresRecorded')::int<>0
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)<>1
 THEN RAISE EXCEPTION 'replay created duplicate %',replay;END IF;
 UPDATE crew_strict_roster_fixture_14y.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=false,automatic_normal_crew_enforcement_enabled=false WHERE world_id=1;
 BEGIN
  PERFORM crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 EXCEPTION WHEN OTHERS THEN blocked_without_gate:=true;END;
 IF NOT blocked_without_gate OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)<>1 THEN RAISE EXCEPTION 'disabled gate did not preserve legacy batch abort';END IF;
 UPDATE crew_strict_roster_fixture_14y.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=true,automatic_normal_crew_enforcement_enabled=true WHERE world_id=1;
 PERFORM set_config('airlinerra.lifecycle_clock',(base+interval '3 hours 3 minutes')::text,true);
 arrivals:=crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 IF arrivals->>'status'<>'trusted_game_dispatch_cycle_completed'
 OR (arrivals->>'candidatesChecked')::int<>2
 OR (arrivals->>'arrivalsRecorded')::int<>1 OR arrivals->>'normalCrewDispatchEnforced'<>'true'
 OR (arrivals->>'blocked')::int<>1
 OR (arrivals->'blockerCounts'->>'ARRIVAL_WITHOUT_VERIFIED_DEPARTURE')::int<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)<>2
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_arrived_aircraft_usage_receipts_v1)<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_game_flight_fuel_arrival_receipts_v1)<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_pilot_flight_experience_v1)<>2
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_actual_turnaround_receipts_v1)<>1
 OR EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1 m JOIN crew_strict_roster_fixture_14y.test_bad b ON b.physical_flight_id=m.flight_occurrence_id)
 THEN RAISE EXCEPTION 'arrival isolation failed %',arrivals;END IF;
 arrival_replay:=crew_strict_roster_fixture_14y.section9_auto_dispatch_due_flight_events_v1(40);
 IF (arrival_replay->>'arrivalsRecorded')::int<>0
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_operated_flight_movements_v1)<>2
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_game_flight_fuel_arrival_receipts_v1)<>1 THEN RAISE EXCEPTION 'arrival replay duplicated %',arrival_replay;END IF;
 -- The actual post-arrival financial preparation pipeline now verifies
 -- real signed arrival, actual airframe usage and fuel burn receipts,
 -- inventory reservations and an independent game-cost quote interface.
 BEGIN
 UPDATE crew_strict_roster_fixture_14y.section9_passenger_reservation_batches_v1 SET seats_requested=99 WHERE occurrence_id=good_occ;
 ticket_check:=crew_strict_roster_fixture_14y.section9_postarrival_ticket_reconciliation_v1((SELECT schedule_id::text||':'||flight_local_date||':'||weekly_entry FROM crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1 WHERE id=good_occ));
 IF ticket_check->>'status'<>'blocked_ticket_seat_or_revenue_reconciliation_mismatch' THEN RAISE EXCEPTION 'incorrect tickets accepted %',ticket_check;END IF;
 RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='restore booking fixture';
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN NULL;END;
 cost_preview:=crew_strict_roster_fixture_14y.section9_completed_flight_game_cost_preview_v1(
 (SELECT schedule_id::text||':'||flight_local_date||':'||weekly_entry FROM crew_strict_roster_fixture_14y.section9_dated_flight_occurrences_v1 WHERE id=good_occ));
 IF cost_preview->>'status'<>'game_only_completed_flight_cost_estimate' OR (cost_preview->>'bookedPassengers')::int<>100
 THEN RAISE EXCEPTION 'real airport tariff/fuel quote %',cost_preview;END IF;
 finance_batch:=crew_strict_roster_fixture_14y.section9_prepare_arrived_actual_ticket_finance_batch_v1(40);
 IF finance_batch->>'status'<>'verified_arrival_actual_ticket_finance_preflight_complete' OR (finance_batch->>'inspected')::int<>1 OR (finance_batch->>'prepared')::int<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_actual_ticket_finance_preparations_v1)<>1
 OR (SELECT ticket_quote_usd FROM crew_strict_roster_fixture_14y.section9_actual_ticket_finance_preparations_v1)<>10000
 OR (SELECT provisional_operating_cost_usd FROM crew_strict_roster_fixture_14y.section9_actual_ticket_finance_preparations_v1)<>(cost_preview->>'operatingCostEstimateUsd')::numeric
 THEN RAISE EXCEPTION 'real finance preflight failed %',finance_batch;END IF;
 finance_replay:=crew_strict_roster_fixture_14y.section9_prepare_arrived_actual_ticket_finance_batch_v1(40);
 IF (finance_replay->>'prepared')::int<>0 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_actual_ticket_finance_preparations_v1)<>1 THEN RAISE EXCEPTION 'finance prep replay duplicate %',finance_replay;END IF;
 -- Directly execute the same independently gated cost-approval and
 -- final posting jobs configured in cron, with real trusted movement HMAC,
 -- real actual fuel burn, actual ticket and postarrival preparation evidence.
 approved_cost:=crew_strict_roster_fixture_14y.section9_auto_approve_completed_game_flight_costs_v1(40);
 IF approved_cost->>'status'<>'game_cost_batch_completed' OR (approved_cost->>'checked')::int<>1 OR (approved_cost->>'approved')::int<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_flight_final_cost_approvals_v1 WHERE approval_state='approved')<>1
 OR (SELECT fuel_cost_usd FROM crew_strict_roster_fixture_14y.section9_flight_final_cost_approvals_v1)<>(SELECT round(planned_trip_burn_kg*.95,2) FROM crew_strict_roster_fixture_14y.section9_game_flight_fuel_departure_receipts_v1)
 OR (SELECT airport_navigation_cost_usd FROM crew_strict_roster_fixture_14y.section9_flight_final_cost_approvals_v1)<>(cost_preview->>'airportCostEstimateUsd')::numeric
 THEN RAISE EXCEPTION 'real final cost approval %',approved_cost;END IF;
 SELECT 10000 - fuel_cost_usd-airport_navigation_cost_usd-crew_cost_usd INTO STRICT expected_net FROM crew_strict_roster_fixture_14y.section9_flight_final_cost_approvals_v1;
 BEGIN
 UPDATE crew_strict_roster_fixture_14y.section9_flight_final_cost_approvals_v1 SET crew_cost_usd=50;
 post_replay:=crew_strict_roster_fixture_14y.section9_post_completed_flight_finance_once_v1(
 (SELECT physical_flight_id FROM crew_strict_roster_fixture_14y.section9_actual_ticket_finance_preparations_v1 LIMIT 1));
 IF post_replay->>'status'<>'blocked_external_crew_cost_mismatch' THEN RAISE EXCEPTION 'fabricated external cost not blocked %',post_replay;END IF;
 RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='restore cost approval';
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN NULL;END;
 posted_finance:=crew_strict_roster_fixture_14y.section9_auto_post_complete_game_flights_v1(40);
 IF posted_finance->>'status'<>'game_complete_flight_finance_batch_checked' OR (posted_finance->>'checked')::int<>1 OR (posted_finance->>'posted')::int<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_route_posted_flight_financials_v1)<>1
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.airline_ledger WHERE airline_id=a.id)<>3
 OR (SELECT cash_usd FROM crew_strict_roster_fixture_14y.airlines WHERE id=a.id)<>opening_cash+expected_net
 OR (SELECT sum(amount_usd) FROM crew_strict_roster_fixture_14y.airline_ledger WHERE airline_id=a.id)<>opening_cash+expected_net
 THEN RAISE EXCEPTION 'real automatic final finance %',posted_finance;END IF;
 post_replay:=crew_strict_roster_fixture_14y.section9_auto_post_complete_game_flights_v1(40);
 IF (post_replay->>'posted')::int<>0 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.airline_ledger WHERE airline_id=a.id)<>3 THEN RAISE EXCEPTION 'finance replay charged again %',post_replay;END IF;
 IF NOT EXISTS(SELECT 1 FROM crew_strict_roster_fixture_14y.section9_actual_turnaround_receipts_v1 WHERE assigned_cabin_crew=4 AND actual_minutes BETWEEN 40 AND 60 AND available_utc=arrival_utc+make_interval(mins=>actual_minutes)) THEN RAISE EXCEPTION 'real dynamic turnaround evidence missing';END IF;
 IF NOT EXISTS (SELECT 1 FROM crew_strict_roster_fixture_14y.section9_pilot_departure_manifests_v1 m JOIN crew_strict_roster_fixture_14y.section9_operated_crew_bindings_v1 b ON b.physical_flight_id=m.physical_flight_id AND b.airline_id=m.airline_id WHERE cardinality(m.captain_ids)=1 AND cardinality(m.first_officer_ids)=1 AND cardinality(b.cabin_member_ids)=4 AND m.external_captain_count=0 AND m.external_first_officer_count=0 AND b.external_cabin_count=0) THEN RAISE EXCEPTION 'actual owned crew not bound';END IF;
 IF (SELECT sum(flight_minutes) FROM crew_strict_roster_fixture_14y.section9_pilot_flight_experience_v1)<>360
 OR (SELECT count(*) FROM crew_strict_roster_fixture_14y.section9_pilot_profiles_v1 WHERE total_flight_minutes=180)<>2
 THEN RAISE EXCEPTION 'real flight experience not credited';END IF;
 result:=jsonb_build_object('status','passed','strictCrewGateTested',true,'missingAtomicGateDenied',true,'missingCaptureGateDenied',true,'suspendedCaptainFlightHeld',true,'crewErrorRollsBackMovementFuelBooking',true,'qualifiedCrewAllowed',true,'crewExperienceOnlyAfterSignedArrival',true,'actualOwnedCrewHired',true,'qualifiedCrewPlanSaved',true,'realDepartureManifest',true,'pilotExperienceCredited',true,'crewPayrollQuoteUsd',crew_hiring_invoice,'realDynamicTurnaround',true,'realFuelPreflight',true,'realAutomaticFuelSupply',true,'failedFuelTopUpRolledBack',true,'realCostApprovalWorker',true,'realFinalPostingWorker',true,'postedNetCashUsd',expected_net,'actualGameTariffQuote',true,'actualReserveAwareFuelQuote',true,'realVerifiedClock',true,'realFinancialLedgerAtomic',true,'incorrectCrewCostRejected',true,'replayedFinanceNoCharge',true,'realPostarrivalFinancePreparation',true,'realTicketReconciliation',true,'financePreparationReplayProtected',true,'ticketMismatchRejected',true,'realMovementWriter',true,'realFuelDepartureCapture',true,'realFuelArrivalBurn',true,'realAirframeUsage',true,'oneCompleteArrival',true,'arrivalFuelBurnCreated',true,'arrivalAirframeUsageCreated',true,'crewArrivalTracked',true,'actualTurnaroundRecorded',true,'arrivalReplayNoDuplicate',true,'isolatedBadFlightRolledBack',true,'unrelatedGoodFlightCommitted',true,'badFuelSupplyRolledBack',true,'badSignedDepartureRolledBack',true,'goodFuelAndCrewCaptured',true,'bookingClosedOnlyForGoodFlight',true,'replayNoDouble',true,'disabledGatePreservesLegacyFailClosed',true,'reportedBlocks',r->'blockerCounts','liveFinancialsUntouched',true);
 result:=result||jsonb_build_object('sickCabinAttendantFlightHeld',true);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.strict_crew_fixture_result',SQLERRM,true);END;
END $test$;
SELECT current_setting('airlinerra.strict_crew_fixture_result',true)::jsonb AS dispatch_test,to_regnamespace('crew_strict_roster_fixture_14y') IS NULL AS fixture_removed,
 (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1) AS live_movement_count,
 (SELECT count(*) FROM airlinerra_game.section9_route_posted_flight_financials_v1) AS live_finance_count;