-- Signed crew duty integration: synthetic fuel, maintenance, and accelerated reporting policy.
SAVEPOINT automatic_outbound;
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1 ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT clock_timestamp();
CREATE TABLE airlinerra_game.section9_crew_scheduler_policy_v2(world_id smallint PRIMARY KEY,preflight_minutes int,postflight_minutes int,minimum_rest_minutes int);
INSERT INTO airlinerra_game.section9_crew_scheduler_policy_v2 VALUES(1,1,30,720);
CREATE TABLE airlinerra_game.section9_flight_crew_model_policy_v1(configuration_id bigint PRIMARY KEY,qualification_group text,minimum_cabin_crew int);
INSERT INTO airlinerra_game.section9_flight_crew_model_policy_v1 VALUES(1,'fixture',0);
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1(world_id smallint PRIMARY KEY,release_state text);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1(world_id smallint PRIMARY KEY,release_state text);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1(world_id smallint PRIMARY KEY,trusted_flight_execution_release text,fuel_transaction_release text,automatic_flight_and_fuel_settlement_enabled boolean);
INSERT INTO airlinerra_game.section9_activation_release_policy_v1 VALUES(1,'enabled');
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1 VALUES(1,'enabled');
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1 VALUES(1,'ACTIVATED','ACTIVATED',true);
CREATE FUNCTION airlinerra_game.section9_canonical_aoc_covers_v1(uuid,date,integer) RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
CREATE FUNCTION airlinerra_game.section9_verified_permission_game_day_v1() RETURNS date LANGUAGE sql AS $$SELECT (airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date$$;
CREATE OR REPLACE FUNCTION airlinerra_game.storage_reactivation_maintenance_window_v1(p_owner uuid,p_airline uuid,p_aircraft uuid,p_depart_utc timestamptz,p_arrive_utc timestamptz) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('gameMaintenanceClear',current_setting('test.storage_maintenance',true)='clear')$$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(p_physical_flight_id text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('status','game_fuel_already_sufficient')$$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('fuelVerifiedForGame',true,'plannedTripBurnKg',1000)$$;
CREATE TABLE airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,departure_engine_event_id text,planned_trip_burn_kg numeric);
CREATE FUNCTION airlinerra_game.section9_capture_verified_departure_fuel_v1(text,text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 SELECT $1,airline_id,aircraft_inventory_id,$2,1000 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=$2 AND phase='departed' AND flight_occurrence_id=$1;
 RETURN jsonb_build_object('fuelReceiptCreated',FOUND);
END $$;
CREATE FUNCTION airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 SELECT a.flight_occurrence_id,a.airline_id,a.aircraft_inventory_id,a.engine_event_id,d.engine_event_id,1,1 FROM airlinerra_game.section9_operated_flight_movements_v1 a JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.flight_occurrence_id=a.flight_occurrence_id AND d.phase='departed' WHERE a.flight_occurrence_id=$1 AND a.phase='arrived';
 RETURN jsonb_build_object('usageApplied',FOUND);
END $$;
CREATE FUNCTION airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(text,text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 IF current_setting('test.storage_fail_burn',true)='yes' THEN RETURN jsonb_build_object('fuelBurnRecorded',false);END IF;
 INSERT INTO airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 SELECT $1,airline_id,aircraft_inventory_id,$2,1000,destination_airport_key FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=$2 AND phase='arrived' AND flight_occurrence_id=$1;
 RETURN jsonb_build_object('fuelBurnRecorded',FOUND);
END $$;
-- Controlled commercial history input; signed storage receipts are real review records.
CREATE FUNCTION airlinerra_game.section9_crew_actual_history_v1(p_airline uuid,p_employee uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT coalesce(nullif(current_setting('test.storage_commercial_history',true),'')::jsonb,jsonb_build_object('availableForNewDuty',true,'history','[]'::jsonb))
$$;
CREATE FUNCTION airlinerra_game.section9_owned_weekly_crew_input_v1(p_player uuid,p_airline uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT current_setting('test.storage_weekly_input')::jsonb||jsonb_build_object('windowStartUtc',p_start)
$$;
ALTER TABLE airlinerra_game.section9_crew_scheduler_policy_v2 ADD COLUMN maximum_duty_minutes integer DEFAULT 720,ADD COLUMN maximum_working_days integer DEFAULT 5,ADD COLUMN working_day_window integer DEFAULT 7;
CREATE FUNCTION airlinerra_game.section9_crew_rotation_window_v2(p_legs jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pol record; leg jsonb; dep timestamptz; arr timestamptz; first_dep timestamptz;
 last_arr timestamptz; first_origin text; last_destination text; orig text; dest text;
 duty_start timestamptz; duty_end timestamptz; flight_minutes numeric:=0;
BEGIN
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF p_legs IS NULL OR jsonb_typeof(p_legs)<>'array' THEN RETURN jsonb_build_object('status','invalid_legs');END IF;
 IF jsonb_array_length(p_legs) NOT BETWEEN 1 AND 32 THEN RETURN jsonb_build_object('status','invalid_legs');END IF;
 FOR leg IN SELECT value FROM jsonb_array_elements(p_legs) LOOP
  IF NOT coalesce(leg->>'departureUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' OR NOT coalesce(leg->>'arrivalUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' THEN
   RETURN jsonb_build_object('status','invalid_leg_time');END IF;
  dep:=(leg->>'departureUtc')::timestamptz;arr:=(leg->>'arrivalUtc')::timestamptz;
  orig:=nullif(btrim(leg->>'originAirportKey'),'');dest:=nullif(btrim(leg->>'destinationAirportKey'),'');
  IF dep IS NULL OR arr IS NULL OR NOT isfinite(dep) OR NOT isfinite(arr) OR arr<=dep OR orig IS NULL OR dest IS NULL OR orig=dest THEN RETURN jsonb_build_object('status','invalid_leg');END IF;
  IF last_arr IS NOT NULL AND dep<last_arr THEN RETURN jsonb_build_object('status','overlapping_flights');END IF;
  IF last_destination IS NOT NULL AND last_destination<>orig THEN RETURN jsonb_build_object('status','crew_wrong_airport');END IF;
  IF first_dep IS NULL THEN first_dep:=dep;first_origin:=orig;END IF;
  last_arr:=arr;last_destination:=dest;flight_minutes:=flight_minutes+extract(epoch FROM arr-dep)/60;
 END LOOP;
 duty_start:=first_dep-make_interval(mins=>pol.preflight_minutes);
 duty_end:=last_arr+make_interval(mins=>pol.postflight_minutes);
 RETURN jsonb_build_object('status',CASE WHEN duty_end-duty_start>make_interval(mins=>pol.maximum_duty_minutes) THEN 'duty_too_long' ELSE 'rotation_preview' END,
 'dutyStartUtc',duty_start,'dutyEndUtc',duty_end,'startingAirport',first_origin,'endingAirport',last_destination,
 'dutyMinutes',extract(epoch FROM duty_end-duty_start)/60,'flightMinutes',flight_minutes,
 'legCount',jsonb_array_length(p_legs),'nextReadyUtc',duty_end+make_interval(mins=>pol.minimum_rest_minutes),
 'dispatchEnforced',false);
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN RETURN jsonb_build_object('status','invalid_leg_time');
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_crew_rotation_window_v2(jsonb) FROM PUBLIC,anon,authenticated,service_role;

-- Compare the proposed duty with a complete, authoritative employee duty history
-- (including future commitments). First known location is at the start of history.
-- A working day is the reporting date in the employee's home-base timezone.
-- Check all rolling seven-day windows containing the proposed reporting date.
CREATE FUNCTION airlinerra_game.section9_crew_duty_fit_v2(p_rotation jsonb,p_existing jsonb,p_home_timezone text,p_initial_airport text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pol record; s timestamptz;e timestamptz; d record; prev_end timestamptz; prev_dest text;
 report_date date;work_dates date[]:='{}'; day_start date; working_count integer; peak int:=0;
BEGIN
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF p_rotation->>'status' IS DISTINCT FROM 'rotation_preview' THEN RETURN jsonb_build_object('status','invalid_rotation','eligible',false);END IF;
 IF p_existing IS NULL OR jsonb_typeof(p_existing)<>'array' OR p_initial_airport IS NULL OR btrim(p_initial_airport)='' OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_home_timezone) THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);END IF;
 IF jsonb_array_length(p_existing)>366 THEN RETURN jsonb_build_object('status','history_requires_sharding','eligible',false);END IF;
 s:=(p_rotation->>'dutyStartUtc')::timestamptz;e:=(p_rotation->>'dutyEndUtc')::timestamptz;
 IF s IS NULL OR e IS NULL OR NOT isfinite(s) OR NOT isfinite(e) OR e<=s OR e-s>make_interval(mins=>pol.maximum_duty_minutes) THEN RETURN jsonb_build_object('status','invalid_rotation','eligible',false);END IF;
 report_date:=(s AT TIME ZONE p_home_timezone)::date;
 prev_dest:=p_initial_airport;
 FOR d IN SELECT (v->>'dutyStartUtc')::timestamptz ds,(v->>'dutyEndUtc')::timestamptz de,
 v->>'startingAirport' AS origin,v->>'endingAirport' AS destination
 FROM jsonb_array_elements(p_existing||jsonb_build_array(p_rotation)) x(v)
 ORDER BY ds,de LOOP
  IF d.ds IS NULL OR d.de IS NULL OR NOT isfinite(d.ds) OR NOT isfinite(d.de) OR d.de<=d.ds OR d.de-d.ds>make_interval(mins=>pol.maximum_duty_minutes) OR nullif(btrim(d.origin),'') IS NULL OR nullif(btrim(d.destination),'') IS NULL THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);END IF;
  IF prev_end IS NOT NULL AND d.ds<prev_end THEN RETURN jsonb_build_object('status','duty_overlap','eligible',false);END IF;
  IF prev_end IS NOT NULL AND d.ds<prev_end+make_interval(mins=>pol.minimum_rest_minutes) THEN RETURN jsonb_build_object('status','insufficient_rest','eligible',false);END IF;
  IF prev_dest IS DISTINCT FROM d.origin THEN RETURN jsonb_build_object('status','crew_wrong_airport','eligible',false);END IF;
  work_dates:=array_append(work_dates,(d.ds AT TIME ZONE p_home_timezone)::date);
  prev_end:=d.de;prev_dest:=d.destination;
 END LOOP;
 FOR day_start IN SELECT report_date-i FROM generate_series(0,pol.working_day_window-1) i LOOP
  SELECT count(DISTINCT dt) INTO working_count FROM unnest(work_dates) dt WHERE dt BETWEEN day_start AND day_start+pol.working_day_window-1;
  peak:=greatest(peak,working_count);
 END LOOP;
 RETURN jsonb_build_object('status',CASE WHEN peak>pol.maximum_working_days THEN 'working_days_exceeded' ELSE 'duty_fit_preview' END,
 'eligible',peak<=pol.maximum_working_days,'maxWorkingDaysInWindow',peak,'workingDayBasis','home_base_reporting_date','reportDate',report_date,'dispatchEnforced',false);
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_crew_duty_fit_v2(jsonb,jsonb,text,text) FROM PUBLIC,anon,authenticated,service_role;

-- Synthetic commercial occurrence and normalized plan schema, matching writer columns.
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1 ADD COLUMN id uuid,ADD COLUMN version int,ADD COLUMN configuration_id bigint;
ALTER TABLE airlinerra_game.section9_flight_crew_model_policy_v1 ADD COLUMN seat_basis text DEFAULT 'cargo_zero';
ALTER TABLE airlinerra_game.section9_crew_plan_batches_v1 ADD COLUMN window_start_utc timestamptz,ADD COLUMN window_end_utc timestamptz,ADD COLUMN source_snapshot jsonb,ADD COLUMN proposed_assignments jsonb;
ALTER TABLE airlinerra_game.section9_planned_crew_duties_v1 ADD COLUMN duty_id uuid DEFAULT gen_random_uuid(),ADD COLUMN cabin_member_id uuid,ADD COLUMN duty_start_utc timestamptz,ADD COLUMN report_date date,ADD COLUMN starting_airport text,ADD COLUMN ending_airport text;
CREATE TABLE airlinerra_game.section9_dated_flight_occurrences_v1(id uuid PRIMARY KEY,airline_id uuid,world_id smallint,schedule_id uuid,schedule_version int,aircraft_inventory_id uuid,booking_status text,departure_utc timestamptz,arrival_utc timestamptz,origin_airport_key text,destination_airport_key text,flight_local_date date,weekly_entry int,verified_passenger_seats int);
CREATE TABLE airlinerra_game.section9_planned_flight_crews_v1(plan_id uuid,airline_id uuid,occurrence_id uuid,schedule_version int,aircraft_inventory_id uuid,physical_flight_id text,qualification_group text,departure_utc timestamptz,arrival_utc timestamptz,origin_airport_key text,destination_airport_key text,captain_count int,first_officer_count int,cabin_count int,PRIMARY KEY(plan_id,occurrence_id));
CREATE TABLE airlinerra_game.section9_planned_crew_seats_v1(plan_id uuid,airline_id uuid,occurrence_id uuid,duty_id uuid,employee_id uuid,seat_role text,PRIMARY KEY(plan_id,occurrence_id,employee_id));
-- Minimal binding/issue tables for exercising exact rolling coverage.
CREATE TABLE airlinerra_game.section9_operated_crew_bindings_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,departure_event_id text);
CREATE TABLE airlinerra_game.section9_operated_crew_capture_issues_v1(engine_event_id text PRIMARY KEY,airline_id uuid,physical_flight_id text);
CREATE FUNCTION airlinerra_game.section9_owned_rolling_crew_input_v1(p_player uuid,p_airline uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT current_setting('test.storage_departure_roster')::jsonb$$;
CREATE OR REPLACE FUNCTION airlinerra_game.aircraft_storage_leg_airport_screen_v1(p_airport text,p_configuration bigint,p_operation text,p_at timestamptz,p_storage_endpoint boolean) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT jsonb_build_object('passed',current_setting('test.final_airport',true)='clear')$$;
CREATE OR REPLACE FUNCTION airlinerra_game.aircraft_storage_ferry_licence_screen_v1(p_airline uuid,p_purpose text,p_origin text,p_destination text,p_dep timestamptz,p_arr timestamptz) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT jsonb_build_object('allowed',current_setting('test.final_licence',true)='clear')$$;
DO $test$
DECLARE s record; r record; owner_id uuid; rid uuid; dep timestamptz; j jsonb; cash_held numeric; cap uuid:=gen_random_uuid();fo uuid:=gen_random_uuid();h jsonb; review_snapshot jsonb; departure_roster jsonb; assignments jsonb; pilot jsonb; new_dep timestamptz; new_arr timestamptz; plan_key uuid:=gen_random_uuid(); flight_key uuid:=gen_random_uuid();
BEGIN
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 j:=airlinerra_game.post_aircraft_storage_month_v1(s.airline_id,s.request_id,1);
 IF j->>'status' IS DISTINCT FROM 'paid' THEN RAISE EXCEPTION 'fixture billing: %',j;END IF;
 dep:=date_trunc('second',s.storage_started_utc+interval '2 minutes');
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',dep,2688.13,gen_random_uuid());
 IF j->>'created' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'fixture request: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=rid;
 j:=airlinerra_game.reserve_aircraft_reactivation_slots_v1(owner_id,s.airline_id,rid);
 IF j->>'slotsReserved' IS DISTINCT FROM '2' THEN RAISE EXCEPTION 'fixture slots: %',j;END IF;
 j:=airlinerra_game.hold_aircraft_reactivation_funds_v1(owner_id,s.airline_id,rid);
 IF j->>'fundsHeld' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'fixture hold: %',j;END IF;
 INSERT INTO airlinerra_game.aircraft_storage_crew_reservations_v1(request_id,airline_id,employee_id,seat_role,qualification_group,duty_start_utc,duty_end_utc,origin_airport_key,destination_airport_key,reserved_at)
 VALUES(rid,s.airline_id,cap,'captain','fixture',dep-interval '1 minute',r.arrival_utc+interval '30 minutes',r.origin_airport_key,r.destination_airport_key,s.storage_started_utc),
 (rid,s.airline_id,fo,'first_officer','fixture',dep-interval '1 minute',r.arrival_utc+interval '30 minutes',r.origin_airport_key,r.destination_airport_key,s.storage_started_utc);
 SELECT cash_usd INTO cash_held FROM airlinerra_game.airlines WHERE id=s.airline_id;
 UPDATE airlinerra_game.aircraft_storage_execution_release_v1 SET fuel_adapter_enabled=true,execution_enabled=true WHERE world_id=1;
 UPDATE airlinerra_game.aircraft_storage_signed_movement_release_v1 SET enabled=true WHERE world_id=1;
 PERFORM set_config('test.storage_hour',dep::text,true);
 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'departed');
 IF j->>'status' IS DISTINCT FROM 'reactivation_not_released' THEN RAISE EXCEPTION 'outbound release bypass: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_reactivation_release_v1 SET enabled=true WHERE world_id=1;
 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'departed');
 IF j->>'status' IS DISTINCT FROM 'storage_dispatch_clearance_missing' THEN RAISE EXCEPTION 'clearance bypass: %',j;END IF;
 INSERT INTO airlinerra_game.aircraft_storage_dispatch_clearance_v1(request_id,configuration_id,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,runway_review_reference,airport_restriction_review_reference,ferry_licence_review_reference,crew_review_reference,approved_at)
 VALUES(rid,1,r.origin_airport_key,r.destination_airport_key,dep,r.arrival_utc,'fixture','fixture','fixture','fixture',dep-interval '1 minute');
 PERFORM set_config('test.storage_maintenance','blocked',true);
 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'departed');
 IF j->>'status' IS DISTINCT FROM 'storage_maintenance_blocked' THEN RAISE EXCEPTION 'maintenance bypass: %',j;END IF;
 PERFORM set_config('test.storage_maintenance','clear',true);
 UPDATE airlinerra_game.storage_crew_departure_validation_release_v1 SET enabled=true;
 pilot:=jsonb_build_object('id',cap,'initialAirport',r.origin_airport_key,'locationEffectiveUtc',dep-interval '10 days','baseTimezone','UTC','employmentFrom',(dep-interval '10 days')::date,'history','[]'::jsonb,'absences','[]'::jsonb,'permissions',jsonb_build_array(jsonb_build_object('group','fixture','issued',(dep-interval '10 days')::date,'expires',(dep+interval '30 days')::date,'active',true,'captain',true,'firstOfficer',true)));
 departure_roster:=jsonb_build_object('status','rolling_crew_input_preview','unboundDeparturesLast7Days',0,'unresolvedCaptureIssues',0,'invalidOccurrenceCount',0,'alreadyReportedFutureFlights',0,'cabinHeadcountReconciled',true,'pilots',jsonb_build_array(pilot,pilot||jsonb_build_object('id',fo)),'cabinMembers','[]'::jsonb);
 PERFORM set_config('test.storage_departure_roster',jsonb_set(departure_roster,'{pilots,0,permissions,0,active}','false'::jsonb)::text,true);
 h:=airlinerra_game.storage_crew_departure_check_v1(rid);
 IF h->>'passed' IS DISTINCT FROM 'false' OR h->>'status' IS DISTINCT FROM 'storage_crew_duty_or_qualification_changed' THEN RAISE EXCEPTION 'revoked qualification accepted: %',h;END IF;
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,status}' IS DISTINCT FROM 'storage_leg_rolled_back' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=rid AND phase='departed') OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid) THEN RAISE EXCEPTION 'invalid crew signed departure was not rolled back: %',j;END IF;
 PERFORM set_config('test.storage_departure_roster',jsonb_set(departure_roster,'{pilots,0,absences}',jsonb_build_array(jsonb_build_object('startUtc',dep-interval '1 hour','endUtc',dep+interval '1 hour')))::text,true);
 h:=airlinerra_game.storage_crew_departure_check_v1(rid);
 IF h->>'passed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'absent pilot accepted: %',h;END IF;
 PERFORM set_config('test.storage_departure_roster',jsonb_set(departure_roster,'{pilots,0,initialAirport}',to_jsonb('WRONG'::text))::text,true);
 h:=airlinerra_game.storage_crew_departure_check_v1(rid);
 IF h->>'passed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'wrong airport accepted: %',h;END IF;
 PERFORM set_config('test.storage_departure_roster',(departure_roster||jsonb_build_object('pilots',jsonb_build_array(pilot)))::text,true);
 h:=airlinerra_game.storage_crew_departure_check_v1(rid);
 IF h->>'status' IS DISTINCT FROM 'storage_crew_employment_changed' THEN RAISE EXCEPTION 'missing employee accepted: %',h;END IF;
 PERFORM set_config('test.storage_departure_roster',(departure_roster||jsonb_build_object('unboundDeparturesLast7Days',1))::text,true);
 h:=airlinerra_game.storage_crew_departure_check_v1(rid);
 IF h->>'status' IS DISTINCT FROM 'storage_crew_current_history_unverified' THEN RAISE EXCEPTION 'unverified history accepted: %',h;END IF;
 PERFORM set_config('test.storage_departure_roster',departure_roster::text,true);
 h:=airlinerra_game.storage_crew_departure_check_v1(rid);
 IF h->>'passed' IS DISTINCT FROM 'true' OR h->>'crewCount' IS DISTINCT FROM '2' THEN RAISE EXCEPTION 'qualified reserved crew rejected: %',h;END IF;
 RAISE NOTICE 'Storage departure crew revalidation acceptance passed (synthetic current roster, actual duty fit and signed movement guard)';
 UPDATE airlinerra_game.storage_operational_departure_release_v1 SET enabled=true;
 PERFORM set_config('test.final_airport','blocked',true);
 PERFORM set_config('test.final_licence','clear',true);
 h:=airlinerra_game.storage_operational_departure_check_v1(rid);
 IF h->>'status' IS DISTINCT FROM 'storage_operational_airport_changed' THEN RAISE EXCEPTION 'changed airport accepted: %',h;END IF;
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,status}' IS DISTINCT FROM 'storage_leg_rolled_back' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=rid AND phase='departed') THEN RAISE EXCEPTION 'airport revalidation rollback failed: %',j;END IF;
 PERFORM set_config('test.final_airport','clear',true);
 PERFORM set_config('test.final_licence','blocked',true);
 h:=airlinerra_game.storage_operational_departure_check_v1(rid);
 IF h->>'status' IS DISTINCT FROM 'storage_operational_licence_changed' THEN RAISE EXCEPTION 'changed licence accepted: %',h;END IF;
 PERFORM set_config('test.final_licence','clear',true);
 h:=airlinerra_game.storage_operational_departure_check_v1(rid);
 IF h->>'passed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'valid operational recheck failed: %',h;END IF;
 RAISE NOTICE 'Final storage departure operational revalidation acceptance passed (synthetic airport and licence screens)';

 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,movementRecorded}' IS DISTINCT FROM 'true' OR j#>>'{results,0,settlement,billingStopped}' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'automatic outbound departure: %',j;END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid AND arrival_engine_event_id IS NULL)<>2 THEN RAISE EXCEPTION 'signed crew departure receipts missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_signed_crew_manifests_v1 m WHERE m.request_id=rid AND m.captain_count=1 AND m.first_officer_count=1 AND m.cabin_count=0 AND jsonb_array_length(m.seats)=2 AND airlinerra_game.storage_signed_crew_departure_covered_v1(s.airline_id,m.departure_event_id))
 THEN RAISE EXCEPTION 'in-flight signed manifest missing or uncovered';END IF;
 IF airlinerra_game.storage_signed_crew_departure_covered_v1(s.airline_id,'nonexistent-event') IS DISTINCT FROM false THEN RAISE EXCEPTION 'missing manifest accepted';END IF;

 PERFORM set_config('test.storage_hour',r.arrival_utc::text,true);
 -- Revocation after the signed departure must not prevent arrival.
 UPDATE airlinerra_game.aircraft_storage_reactivation_release_v1 SET enabled=false;
 PERFORM set_config('test.final_airport','blocked',true);
 PERFORM set_config('test.final_licence','blocked',true);
 PERFORM set_config('test.storage_fail_burn','yes',true);
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,status}' IS DISTINCT FROM 'storage_leg_rolled_back' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=rid AND phase='arrived') OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND location_status='in_flight') THEN RAISE EXCEPTION 'arrival rollback failed: %',j;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid AND arrival_engine_event_id IS NOT NULL) THEN RAISE EXCEPTION 'failed arrival completed crew duty';END IF;
 PERFORM set_config('test.storage_fail_burn','no',true);
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,settlement,status}' IS DISTINCT FROM 'aircraft_reactivated' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND fleet_status='in_service') OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=r.airline_id) IS DISTINCT FROM cash_held THEN RAISE EXCEPTION 'automatic outbound arrival: %',j;END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid AND actual_arrival_utc=r.arrival_utc AND completed_duty_end_utc=r.arrival_utc+interval '30 minutes' AND rest_complete_utc=r.arrival_utc+interval '12 hours 30 minutes')<>2 THEN RAISE EXCEPTION 'completed crew duties missing';END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='awaiting_history_handoff')<>2 THEN RAISE EXCEPTION 'crew custody released prematurely';END IF;
 h:=airlinerra_game.storage_crew_completed_duty_history_v1(s.airline_id,cap,r.arrival_utc);
 IF h->>'lastAirport' IS DISTINCT FROM r.destination_airport_key OR h->>'restComplete' IS DISTINCT FROM 'false' OR jsonb_array_length(h->'history')<>0 THEN RAISE EXCEPTION 'crew arrival read model incorrect: %',h;END IF;
 h:=airlinerra_game.storage_crew_completed_duty_history_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes');
 IF h->>'restComplete' IS DISTINCT FROM 'true' OR h->>'availableForNewDuty' IS DISTINCT FROM 'false' OR jsonb_array_length(h->'history')<>1 THEN RAISE EXCEPTION 'crew rest/handoff state incorrect: %',h;END IF;
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc,r.origin_airport_key,dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_storage_duty_pending' THEN RAISE EXCEPTION 'combined history accepted postflight: %',h;END IF;
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 29 minutes',r.origin_airport_key,dep-interval '10 days');
 IF h->>'eligibleByHistory' IS DISTINCT FROM 'false' OR h->>'lastAirport' IS DISTINCT FROM r.destination_airport_key THEN RAISE EXCEPTION 'combined history premature rest: %',h;END IF;
 PERFORM set_config('test.storage_commercial_history',jsonb_build_object('availableForNewDuty',true,'history',jsonb_build_array(jsonb_build_object('startUtc',dep-interval '2 days','endUtc',dep-interval '2 days'+interval '4 hours','origin','OURAIRPORTS:999','destination',r.origin_airport_key)))::text,true);
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes','OURAIRPORTS:999',dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_crew_history_preview' OR h->>'eligibleByHistory' IS DISTINCT FROM 'true' OR h->>'availableForNewDuty' IS DISTINCT FROM 'false' OR h->>'lastAirport' IS DISTINCT FROM r.destination_airport_key OR h->>'storageDutyCount' IS DISTINCT FROM '1' OR h->>'commercialDutyCount' IS DISTINCT FROM '1' OR jsonb_array_length(h->'history')<>2 OR h#>>'{history,0,destination}' IS DISTINCT FROM r.origin_airport_key THEN RAISE EXCEPTION 'combined history merge failed: %',h;END IF;
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes','WRONG',dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_crew_history_conflict' THEN RAISE EXCEPTION 'wrong checkpoint accepted: %',h;END IF;
 PERFORM set_config('test.storage_commercial_history',jsonb_build_object('availableForNewDuty',true,'history',jsonb_build_array(jsonb_build_object('startUtc',dep-interval '4 hours','endUtc',dep-interval '2 hours','origin','OURAIRPORTS:999','destination',r.origin_airport_key)))::text,true);
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes','OURAIRPORTS:999',dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_crew_history_conflict' THEN RAISE EXCEPTION 'inadequate inter-duty rest accepted: %',h;END IF;
 PERFORM set_config('test.storage_commercial_history',jsonb_build_object('availableForNewDuty',false,'history','[]'::jsonb)::text,true);
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes',r.origin_airport_key,dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_commercial_history_unverified' THEN RAISE EXCEPTION 'unverified commercial history accepted: %',h;END IF;
 PERFORM set_config('test.storage_commercial_history','',true);
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='awaiting_history_handoff')<>2 THEN RAISE EXCEPTION 'history preview released custody';END IF;
 RAISE NOTICE 'Combined commercial and signed storage crew history acceptance passed (synthetic commercial history)';
 PERFORM set_config('test.storage_weekly_input',jsonb_build_object('status','weekly_crew_bootstrap_input_preview','invalidOccurrenceCount',0,'cabinHeadcountReconciled',true,'flights','[]'::jsonb,'cabinMembers','[]'::jsonb,'pilots',jsonb_build_array(jsonb_build_object('id',cap,'initialAirport',r.origin_airport_key,'locationEffectiveUtc',dep-interval '10 days','permissions','[]'::jsonb)))::text,true);
 PERFORM set_config('test.storage_hour',(r.arrival_utc+interval '12 hours 29 minutes')::text,true);
 h:=airlinerra_game.owned_storage_aware_crew_input_preview_v1(owner_id,s.airline_id,r.arrival_utc+interval '13 hours');
 IF h->>'status' IS DISTINCT FROM 'storage_aware_crew_input_preview' OR jsonb_array_length(h->'pilots')<>0 OR jsonb_array_length(h->'excludedEmployees')<>1 THEN RAISE EXCEPTION 'preview included unrested pilot: %',h;END IF;
 PERFORM set_config('test.storage_hour',(r.arrival_utc+interval '12 hours 30 minutes')::text,true);
 h:=airlinerra_game.owned_storage_aware_crew_input_preview_v1(owner_id,s.airline_id,r.arrival_utc+interval '13 hours');
 IF h->>'status' IS DISTINCT FROM 'storage_aware_crew_input_preview' OR jsonb_array_length(h->'pilots')<>1 OR h#>>'{pilots,0,initialAirport}' IS DISTINCT FROM r.origin_airport_key OR h#>>'{pilots,0,history,0,destination}' IS DISTINCT FROM r.destination_airport_key OR h->>'saveAllowed' IS DISTINCT FROM 'false' OR h->>'crewReleased' IS DISTINCT FROM 'false' OR h->>'enforceRollingWeeklyDutyHours' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'storage-aware planning snapshot invalid: %',h;END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='awaiting_history_handoff')<>2 THEN RAISE EXCEPTION 'planning snapshot released custody';END IF;

 -- Restore the real reporting policy for the new commercial duty.
 UPDATE airlinerra_game.section9_crew_scheduler_policy_v2 SET preflight_minutes=120;
 new_dep:=r.arrival_utc+interval '16 hours';new_arr:=new_dep+interval '2 hours';
 pilot:=jsonb_build_object('id',cap,'initialAirport',r.origin_airport_key,'locationEffectiveUtc',dep-interval '10 days','baseTimezone','UTC','employmentFrom',(dep-interval '10 days')::date,'absences','[]'::jsonb,'permissions',jsonb_build_array(jsonb_build_object('group','fixture','issued',(dep-interval '10 days')::date,'expires',(dep+interval '30 days')::date,'active',true,'captain',true,'firstOfficer',true)));
 PERFORM set_config('test.storage_weekly_input',jsonb_build_object('status','weekly_crew_bootstrap_input_preview','invalidOccurrenceCount',0,'cabinHeadcountReconciled',true,'flights',jsonb_build_array(jsonb_build_object('id',flight_key,'aircraftId',r.aircraft_inventory_id,'group','fixture','origin',r.destination_airport_key,'destination',r.origin_airport_key,'departureUtc',new_dep,'arrivalUtc',new_arr,'cabinRequired',0)),'cabinMembers','[]'::jsonb,'pilots',jsonb_build_array(pilot,pilot||jsonb_build_object('id',fo)))::text,true);
 review_snapshot:=airlinerra_game.owned_storage_aware_crew_input_preview_v1(owner_id,s.airline_id,r.arrival_utc+interval '13 hours');
 assignments:=jsonb_build_array(jsonb_build_object('flightId',flight_key,'aircraftId',r.aircraft_inventory_id,'departureUtc',new_dep,'arrivalUtc',new_arr,'captains',jsonb_build_array(cap),'firstOfficers',jsonb_build_array(fo),'cabinCrew','[]'::jsonb,'duties',jsonb_build_array(jsonb_build_object('employeeId',cap,'role','captain','dutyStartUtc',new_dep-interval '2 hours','dutyEndUtc',new_arr+interval '30 minutes'),jsonb_build_object('employeeId',fo,'role','firstOfficer','dutyStartUtc',new_dep-interval '2 hours','dutyEndUtc',new_arr+interval '30 minutes'))));
 h:=airlinerra_game.save_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key,r.arrival_utc+interval '13 hours',review_snapshot||jsonb_build_object('saveAllowed',true),assignments);
 IF h->>'status' IS DISTINCT FROM 'storage_crew_review_snapshot_changed' THEN RAISE EXCEPTION 'modified snapshot accepted: %',h;END IF;
 h:=airlinerra_game.save_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key,r.arrival_utc+interval '13 hours',review_snapshot,jsonb_set(assignments,'{0,duties,0,dutyStartUtc}',to_jsonb(new_dep)));
 IF h->>'status' IS DISTINCT FROM 'storage_crew_review_invalid_rotation' THEN RAISE EXCEPTION 'forged report accepted: %',h;END IF;
 h:=airlinerra_game.save_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key,r.arrival_utc+interval '13 hours',review_snapshot,jsonb_set(assignments,'{0,firstOfficers}',jsonb_build_array(cap)));
 IF h->>'status' IS DISTINCT FROM 'storage_crew_review_duplicate_employee' THEN RAISE EXCEPTION 'duplicate crew accepted: %',h;END IF;
 h:=airlinerra_game.save_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key,r.arrival_utc+interval '13 hours',review_snapshot,assignments);
 IF h->>'saved' IS DISTINCT FROM 'true' OR h->>'dutyCount' IS DISTINCT FROM '2' OR h->>'crewReleased' IS DISTINCT FROM 'false' OR (SELECT jsonb_array_length(verified_duties) FROM airlinerra_game.storage_aware_crew_plan_reviews_v1 WHERE plan_id=plan_key) IS DISTINCT FROM 2 THEN RAISE EXCEPTION 'review save failed: %',h;END IF;
 h:=airlinerra_game.save_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key,r.arrival_utc+interval '13 hours',review_snapshot,assignments);
 IF h->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'review replay failed: %',h;END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='awaiting_history_handoff')<>2 THEN RAISE EXCEPTION 'review plan released crew';END IF;
 RAISE NOTICE 'Persistent storage-aware crew plan review acceptance passed (actual rotation and duty fit, synthetic roster)';
 h:=airlinerra_game.promote_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key);
 IF h->>'status' IS DISTINCT FROM 'storage_handoff_not_released' THEN RAISE EXCEPTION 'handoff gate bypass: %',h;END IF;
 UPDATE airlinerra_game.storage_crew_plan_handoff_release_v1 SET enabled=true;
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1(plan_id,airline_id,status) VALUES(gen_random_uuid(),s.airline_id,'validated_preview');
 h:=airlinerra_game.promote_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key);
 IF h->>'status' IS DISTINCT FROM 'storage_handoff_existing_plan_requires_replan' THEN RAISE EXCEPTION 'existing plan overwritten: %',h;END IF;
 DELETE FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE airline_id=s.airline_id;
 h:=airlinerra_game.promote_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key);
 IF h->>'status' IS DISTINCT FROM 'storage_handoff_rolled_back' OR EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoffs_v1 WHERE plan_id=plan_key) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE plan_id=plan_key) THEN RAISE EXCEPTION 'missing occurrence rollback failed: %',h;END IF;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(id,airline_id,aircraft_inventory_id,status,version,configuration_id) VALUES(flight_key,s.airline_id,r.aircraft_inventory_id,'active',1,1);
 INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1 VALUES(flight_key,s.airline_id,1,flight_key,1,r.aircraft_inventory_id,'open',new_dep,new_arr,r.destination_airport_key,r.origin_airport_key,(new_dep AT TIME ZONE 'UTC')::date,1,0);
 h:=airlinerra_game.promote_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key);
 IF h->>'promoted' IS DISTINCT FROM 'true' OR h->>'seatCount' IS DISTINCT FROM '2' OR h->>'crewReleased' IS DISTINCT FROM 'false' OR h->>'dispatchAuthorized' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'restricted plan promotion failed: %',h;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_planned_crew_duties_v1 WHERE plan_id=plan_key AND starting_airport=r.destination_airport_key)<>2 OR (SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=plan_key)<>2 THEN RAISE EXCEPTION 'normalized crew plan missing';END IF;
 BEGIN
  UPDATE airlinerra_game.section9_crew_plan_batches_v1 SET status='superseded' WHERE plan_id=plan_key;
  RAISE EXCEPTION 'legacy replan overwrote handoff';
 EXCEPTION WHEN check_violation THEN IF SQLERRM<>'STORAGE_AWARE_REPLAN_REQUIRED' THEN RAISE;END IF;
 END;
 BEGIN
  INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(plan_id,airline_id,pilot_id,duty_start_utc,duty_end_utc,starting_airport,ending_airport) VALUES(gen_random_uuid(),s.airline_id,cap,new_dep-interval '2 hours',new_arr+interval '30 minutes',r.destination_airport_key,r.origin_airport_key);
  RAISE EXCEPTION 'unreviewed duty accepted';
 EXCEPTION WHEN check_violation THEN IF SQLERRM<>'CREW_RESERVED_FOR_STORAGE_OR_HISTORY_HANDOFF' THEN RAISE;END IF;
 END;
 h:=airlinerra_game.promote_storage_aware_crew_plan_review_v1(owner_id,s.airline_id,plan_key);
 IF h->>'replayed' IS DISTINCT FROM 'true' OR (SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=plan_key)<>2 THEN RAISE EXCEPTION 'handoff replay failed: %',h;END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='awaiting_history_handoff')<>2 THEN RAISE EXCEPTION 'handoff released crew without dispatch integration';END IF;
 RAISE NOTICE 'Restricted storage-aware commercial plan handoff acceptance passed (synthetic occurrence and commercial plan schema)';
 h:=airlinerra_game.storage_commercial_handoff_dispatch_check_v1(s.airline_id,flight_key::text||':'||(new_dep AT TIME ZONE 'UTC')::date::text||':1');
 IF h->>'allowed' IS DISTINCT FROM 'false' OR h->>'status' IS DISTINCT FROM 'storage_handoff_dispatch_integration_required' THEN RAISE EXCEPTION 'unintegrated promoted plan passed commercial dispatch: %',h;END IF;
 h:=airlinerra_game.storage_commercial_handoff_dispatch_check_v1(s.airline_id,'unrelated-fixture');
 IF h->>'allowed' IS DISTINCT FROM 'true' OR h->>'commercialDispatchAuthorized' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'unrelated commercial operation changed: %',h;END IF;
 BEGIN
  INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
  VALUES(1,'blocked-handoff-fixture',repeat('a',64),s.airline_id,r.aircraft_inventory_id,flight_key,1,1,(new_dep AT TIME ZONE 'UTC')::date,flight_key::text||':'||(new_dep AT TIME ZONE 'UTC')::date::text||':1','departed',r.destination_airport_key,r.origin_airport_key,new_dep,new_arr,new_dep);
  RAISE EXCEPTION 'unintegrated commercial departure recorded';
 EXCEPTION WHEN check_violation THEN IF SQLERRM<>'STORAGE_COMMERCIAL_HANDOFF_DISPATCH_BLOCKED' THEN RAISE;END IF;END;
 BEGIN
  UPDATE airlinerra_game.aircraft_storage_crew_duty_receipts_v1 SET rest_complete_utc=rest_complete_utc+interval '1 hour' WHERE request_id=rid AND employee_id=cap;
  RAISE EXCEPTION 'completed receipt mutation accepted';
 EXCEPTION WHEN check_violation THEN IF SQLERRM<>'STORAGE_CREW_RECEIPT_IMMUTABLE' THEN RAISE;END IF;END;
 BEGIN
  DELETE FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid AND employee_id=cap;
  RAISE EXCEPTION 'completed receipt deletion accepted';
 EXCEPTION WHEN check_violation THEN IF SQLERRM<>'STORAGE_CREW_RECEIPT_IMMUTABLE' THEN RAISE;END IF;END;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid AND rest_complete_utc=r.arrival_utc+interval '12 hours 30 minutes')<>2 THEN RAISE EXCEPTION 'protected receipts changed';END IF;
 RAISE NOTICE 'Commercial handoff dispatch guard and immutable storage duty receipt acceptance passed';
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_signed_crew_manifests_v1 m WHERE m.request_id=rid AND airlinerra_game.storage_signed_crew_departure_covered_v1(s.airline_id,m.departure_event_id)) THEN RAISE EXCEPTION 'completed manifest not covered';END IF;
 BEGIN
  UPDATE airlinerra_game.storage_signed_crew_manifests_v1 SET rest_minutes=721 WHERE request_id=rid;
  RAISE EXCEPTION 'signed manifest mutation accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_BILLING_RECORD_IMMUTABLE' THEN RAISE;END IF;END;
 h:=airlinerra_game.storage_rolling_crew_coverage_v1(s.airline_id,airlinerra_game.section9_verified_world_instant_v1());
 IF h->>'coveredStorageDepartures' IS DISTINCT FROM '1' OR (h->>'unboundDeparturesLast7Days')::int<1 OR h->>'coverageVerified' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'legacy unbound movements were silently grandfathered: %',h;END IF;
 h:=airlinerra_game.owned_storage_aware_rolling_crew_input_v1(owner_id,s.airline_id,r.arrival_utc+interval '13 hours');
 IF h->>'status' IS DISTINCT FROM 'storage_aware_rolling_crew_history_blocked' OR h->>'crewReleased' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'unbound rolling history bypass: %',h;END IF;
 -- Once the older unsigned-history fixtures are outside the rolling window,
 -- the exact newly captured manifest is sufficient for departure coverage.
 h:=airlinerra_game.storage_rolling_crew_coverage_v1(s.airline_id,dep+interval '7 days');
 IF h->>'coveredStorageDepartures' IS DISTINCT FROM '1' OR h->>'unboundDeparturesLast7Days' IS DISTINCT FROM '0' OR h->>'coverageVerified' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'exact rolling manifest coverage failed: %',h;END IF;
 RAISE NOTICE 'Signed storage manifest coverage acceptance passed; legacy unbound movements remain blocked';



 PERFORM set_config('test.storage_hour',r.arrival_utc::text,true);
 RAISE NOTICE 'Storage-aware crew planning snapshot acceptance passed (synthetic weekly roster)';


 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'arrived');
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'worker replay: %',j;END IF;
 RAISE NOTICE 'Signed storage crew duty receipt acceptance passed (synthetic fuel, maintenance and reporting policy)';
END $test$;
ROLLBACK TO SAVEPOINT automatic_outbound;

ROLLBACK TO SAVEPOINT storage_crew_guard;
