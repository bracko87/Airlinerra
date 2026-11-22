CREATE OR REPLACE FUNCTION airlinerra_game.section9_bind_approved_delayed_crew_v1(p_airline uuid, p_occurrence uuid, p_event text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE ap record;pl record;existing record;proof jsonb;d jsonb;duty uuid;emp uuid;role_name text;basis timestamptz;ref text;next_leg record;onward_id uuid;onward_ref text;final_airport text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO ap FROM airlinerra_game.section9_delayed_crew_approvals_v1 WHERE airline_id=p_airline AND occurrence_id=p_occurrence;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_binding_approval_missing');END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_operated_crew_bindings_v1 WHERE physical_flight_id=ap.physical_flight_id;
 IF FOUND THEN
 IF existing.airline_id<>p_airline OR existing.plan_id<>ap.approval_id OR existing.departure_event_id<>p_event THEN RAISE EXCEPTION 'DELAYED_CREW_BINDING_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','approved_delayed_crew_already_bound','replayed',true);
 END IF;
 proof:=airlinerra_game.section9_check_delayed_crew_binding_v1(p_airline,p_occurrence,ap.revised_departure_utc,p_event);
 IF proof->>'status'<>'delayed_crew_binding_ready' THEN RETURN proof;END IF;
 SELECT * INTO STRICT pl FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=ap.source_plan_id AND occurrence_id=p_occurrence;
 basis:=date_trunc('day',ap.revised_departure_utc);
 ref:=proof->>'contractReference';
 final_airport:=pl.destination_airport_key;
 onward_id:=(ap.validation_receipt->'residualReplacement'->>'onwardOccurrenceId')::uuid;
 IF onward_id IS NOT NULL THEN
 SELECT * INTO STRICT next_leg FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=ap.source_plan_id AND occurrence_id=onward_id;
 final_airport:=next_leg.destination_airport_key;
 onward_ref:=CASE WHEN ap.external_captains+ap.external_first_officers+ap.external_cabin>0 THEN 'residual-rotation-v1:'||ap.approval_id END;
 END IF;
 -- This non-current projection is linked exclusively through the actual
 -- signed departure binding. Current-plan uniqueness is preserved.
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1(plan_id,airline_id,window_start_utc,window_end_utc,source_snapshot,proposed_assignments,status) VALUES(ap.approval_id,p_airline,basis,basis+interval '168 hours',jsonb_build_object('status','delayed_approved_actual_projection','sourcePlanId',ap.source_plan_id),ap.request_payload,'superseded');
 INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(ap.approval_id,p_airline,p_occurrence,pl.schedule_version,pl.aircraft_inventory_id,pl.physical_flight_id,pl.qualification_group,ap.revised_departure_utc,ap.revised_arrival_utc,pl.origin_airport_key,pl.destination_airport_key,cardinality(ap.internal_captains),cardinality(ap.internal_first_officers),cardinality(ap.internal_cabin),ap.external_captains,ap.external_first_officers,ap.external_cabin,ref);
 IF onward_id IS NOT NULL THEN
 INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(ap.approval_id,p_airline,onward_id,next_leg.schedule_version,next_leg.aircraft_inventory_id,next_leg.physical_flight_id,next_leg.qualification_group,next_leg.departure_utc,next_leg.arrival_utc,next_leg.origin_airport_key,next_leg.destination_airport_key,cardinality(ap.internal_captains),cardinality(ap.internal_first_officers),cardinality(ap.internal_cabin),ap.external_captains,ap.external_first_officers,ap.external_cabin,onward_ref);
 END IF;
 FOR d IN SELECT value FROM jsonb_array_elements(proof->'duties') LOOP
 duty:=gen_random_uuid();emp:=(d->>'employeeId')::uuid;role_name:=d->>'role';
 INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(duty_id,plan_id,airline_id,pilot_id,cabin_member_id,duty_start_utc,duty_end_utc,report_date,starting_airport,ending_airport)
 VALUES(duty,ap.approval_id,p_airline,CASE WHEN role_name<>'cabin' THEN emp END,CASE WHEN role_name='cabin' THEN emp END,(d->>'dutyStartUtc')::timestamptz,(d->>'dutyEndUtc')::timestamptz,(d->>'reportDate')::date,d->>'startingAirport',final_airport);
 INSERT INTO airlinerra_game.section9_planned_crew_seats_v1(plan_id,airline_id,occurrence_id,employee_id,duty_id,seat_role) VALUES(ap.approval_id,p_airline,p_occurrence,emp,duty,role_name);
 IF onward_id IS NOT NULL THEN INSERT INTO airlinerra_game.section9_planned_crew_seats_v1(plan_id,airline_id,occurrence_id,employee_id,duty_id,seat_role) VALUES(ap.approval_id,p_airline,onward_id,emp,duty,role_name);END IF;
 END LOOP;
 INSERT INTO airlinerra_game.section9_pilot_departure_manifests_v1(physical_flight_id,airline_id,departure_event_id,configuration_id,qualification_group,captain_ids,first_officer_ids,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(ap.physical_flight_id,p_airline,p_event,(proof->>'configurationId')::bigint,pl.qualification_group,ap.internal_captains,ap.internal_first_officers,ap.external_captains,ap.external_first_officers,ap.external_cabin,ref);
 INSERT INTO airlinerra_game.section9_operated_crew_bindings_v1(physical_flight_id,airline_id,plan_id,occurrence_id,departure_event_id,cabin_member_ids,external_cabin_count,external_contract_reference,external_captain_count,external_first_officer_count)
 VALUES(ap.physical_flight_id,p_airline,ap.approval_id,p_occurrence,p_event,ap.internal_cabin,ap.external_cabin,ref,ap.external_captains,ap.external_first_officers);
 RETURN jsonb_build_object('status','approved_delayed_crew_bound','approvalId',ap.approval_id,'externalPilotCount',ap.external_captains+ap.external_first_officers,'externalCabinCount',ap.external_cabin,'replayed',false,'ledgerPosted',false);
END $function$;