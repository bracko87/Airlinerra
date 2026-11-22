-- Phase 14F. Bind an on-time signed departure to its independently validated
-- planned roster; no crew-shortage cancellation or invented reserve employees.
CREATE TABLE airlinerra_game.section9_crew_movement_capture_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),capture_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_crew_movement_capture_release_v1 VALUES(1,false);
CREATE TABLE airlinerra_game.section9_operated_crew_bindings_v1(
 physical_flight_id text PRIMARY KEY REFERENCES airlinerra_game.section9_pilot_departure_manifests_v1(physical_flight_id),
 airline_id uuid NOT NULL,plan_id uuid NOT NULL,occurrence_id uuid NOT NULL,
 departure_event_id text NOT NULL UNIQUE REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 cabin_member_ids uuid[] NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(airline_id,plan_id,occurrence_id) REFERENCES airlinerra_game.section9_planned_flight_crews_v1(airline_id,plan_id,occurrence_id),
 UNIQUE(plan_id,occurrence_id),CHECK(cardinality(cabin_member_ids)<=40)
);
CREATE TABLE airlinerra_game.section9_operated_crew_capture_issues_v1(
 engine_event_id text PRIMARY KEY REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),physical_flight_id text NOT NULL,
 issue_code text NOT NULL,recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_crew_movement_capture_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_operated_crew_bindings_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_operated_crew_capture_issues_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_crew_movement_capture_release_v1,airlinerra_game.section9_operated_crew_bindings_v1,airlinerra_game.section9_operated_crew_capture_issues_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_capture_dispatched_crew_v1(p_airline uuid,p_physical text,p_event text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE m record;pl record;existing record;seat record;prior record;location record;cps uuid[];fos uuid[];cabin uuid[];outcome jsonb;issue text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','crew_capture_disabled');END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT d.*,r.configuration_id INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 d JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 r ON r.departure_engine_event_id=d.engine_event_id AND r.physical_flight_id=d.flight_occurrence_id AND r.airline_id=d.airline_id AND r.aircraft_inventory_id=d.aircraft_inventory_id
 WHERE d.engine_event_id=p_event AND d.flight_occurrence_id=p_physical AND d.airline_id=p_airline AND d.world_id=1 AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1' AND d.schedule_id IS NOT NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','crew_departure_evidence_missing');END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_operated_crew_bindings_v1 WHERE physical_flight_id=p_physical;
 IF FOUND THEN
 IF existing.airline_id<>p_airline OR existing.departure_event_id<>p_event THEN RAISE EXCEPTION 'CREW_BINDING_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','crew_departure_already_bound','replayed',true);
 END IF;
 SELECT pf.* INTO pl FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview'
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=pf.occurrence_id AND o.airline_id=pf.airline_id AND o.schedule_id=m.schedule_id AND o.schedule_version=pf.schedule_version AND o.flight_local_date=m.flight_local_date AND o.weekly_entry=m.weekly_entry AND o.booking_status<>'cancelled' AND o.departure_utc=pf.departure_utc AND o.arrival_utc=pf.arrival_utc
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=m.configuration_id AND pol.qualification_group=pf.qualification_group
 WHERE pf.airline_id=p_airline AND pf.physical_flight_id=p_physical AND pf.schedule_version=m.schedule_version AND pf.aircraft_inventory_id=m.aircraft_inventory_id AND pf.origin_airport_key=m.origin_airport_key AND pf.destination_airport_key=m.destination_airport_key AND pf.departure_utc=m.scheduled_departure_utc AND pf.arrival_utc=m.scheduled_arrival_utc;
 IF NOT FOUND THEN issue:='crew_current_plan_missing';
 ELSIF m.actual_event_utc<>pl.departure_utc THEN issue:='crew_delayed_rotation_requires_replan';
 END IF;
 IF issue IS NULL THEN
 SELECT coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='captain'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='first_officer'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='cabin'),'{}') INTO cps,fos,cabin FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=pl.plan_id AND occurrence_id=pl.occurrence_id;
 IF cardinality(cps)<>pl.captain_count OR cardinality(fos)<>pl.first_officer_count OR cardinality(cabin)<>pl.cabin_count THEN issue:='crew_seat_count_changed';END IF;
 END IF;
 IF issue IS NULL THEN
 FOR seat IN SELECT s.employee_id,s.seat_role,d.pilot_id,d.cabin_member_id,d.duty_id,d.duty_start_utc,d.duty_end_utc
 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id WHERE s.plan_id=pl.plan_id AND s.occurrence_id=pl.occurrence_id LOOP
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 a WHERE a.airline_id=p_airline AND a.status='active' AND (a.pilot_id=seat.pilot_id OR a.cabin_member_id=seat.cabin_member_id) AND a.start_utc<seat.duty_end_utc AND a.end_utc>seat.duty_start_utc) THEN issue:='crew_employee_unavailable';EXIT;END IF;
 IF seat.seat_role='cabin' THEN
 SELECT c.initial_airport_key,c.location_effective_utc,ap.timezone_iana INTO location FROM airlinerra_game.section9_cabin_crew_members_v1 c JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=c.world_id AND ap.airport_key=c.base_airport_key WHERE c.airline_id=p_airline AND c.member_id=seat.cabin_member_id AND c.employment_status='employed' AND c.role IN('flight_attendant','cabin_supervisor','purser') AND c.effective_game_date<=(seat.duty_start_utc AT TIME ZONE ap.timezone_iana)::date;
 ELSE
 SELECT b.initial_airport_key,b.location_effective_utc,ap.timezone_iana INTO location FROM airlinerra_game.section9_pilot_profiles_v1 pr JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=pr.airline_id AND r.crew_id=pr.crew_id
 JOIN airlinerra_game.section9_pilot_base_assignments_v1 b ON b.airline_id=pr.airline_id AND b.crew_id=pr.crew_id
 JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.base_airport_key
 JOIN airlinerra_game.section9_pilot_family_permissions_v1 q ON q.airline_id=pr.airline_id AND q.crew_id=pr.crew_id AND q.qualification_group=pl.qualification_group
 WHERE pr.airline_id=p_airline AND pr.crew_id=seat.pilot_id AND r.employment_status='verified_employed' AND r.game_effective_date<=(seat.duty_start_utc AT TIME ZONE ap.timezone_iana)::date AND q.qualification_status='active'
 AND q.issued_game_date<=(pl.departure_utc AT TIME ZONE ap.timezone_iana)::date AND q.expires_game_date>(pl.arrival_utc AT TIME ZONE ap.timezone_iana)::date
 AND airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,seat.seat_role);
 END IF;
 IF NOT FOUND OR location.location_effective_utc>seat.duty_start_utc THEN issue:='crew_employment_or_qualification_changed';EXIT;END IF;
 -- Every prior planned leg must have genuinely operated with this roster.
 -- Full actual duty history and disruption reallocation are phase 14G.
 SELECT pf.*,ps.duty_id AS prior_duty_id,pd.duty_end_utc AS prior_duty_end INTO prior FROM airlinerra_game.section9_planned_crew_seats_v1 ps JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=ps.plan_id AND pf.occurrence_id=ps.occurrence_id JOIN airlinerra_game.section9_planned_crew_duties_v1 pd ON pd.duty_id=ps.duty_id
 WHERE ps.plan_id=pl.plan_id AND ps.employee_id=seat.employee_id AND pf.departure_utc<pl.departure_utc ORDER BY pf.departure_utc DESC LIMIT 1;
 IF FOUND THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.flight_occurrence_id=b.physical_flight_id AND a.airline_id=b.airline_id AND a.phase='arrived' AND a.destination_airport_key=pl.origin_airport_key
 WHERE b.plan_id=prior.plan_id AND b.occurrence_id=prior.occurrence_id AND a.actual_event_utc<=pl.departure_utc
 AND (CASE WHEN prior.prior_duty_id=seat.duty_id THEN a.actual_event_utc+interval '30 minutes'<=pl.departure_utc ELSE greatest(prior.prior_duty_end,a.actual_event_utc+interval '30 minutes')+interval '12 hours'<=seat.duty_start_utc END))
 THEN issue:='crew_prior_arrival_or_rest_unverified';EXIT;END IF;
 ELSIF location.initial_airport_key<>pl.origin_airport_key THEN issue:='crew_initial_airport_mismatch';EXIT;
 END IF;
 END LOOP;
 END IF;
 IF issue IS NULL THEN
 outcome:=airlinerra_game.section9_record_pilot_departure_manifest_v1(p_airline,p_physical,cps,fos);
 IF outcome->>'status' NOT IN('pilot_manifest_recorded','manifest_already_recorded') THEN issue:=coalesce(outcome->>'status','crew_manifest_unverified');
 ELSE
 INSERT INTO airlinerra_game.section9_operated_crew_bindings_v1(physical_flight_id,airline_id,plan_id,occurrence_id,departure_event_id,cabin_member_ids) VALUES(p_physical,p_airline,pl.plan_id,pl.occurrence_id,p_event,cabin);
 RETURN jsonb_build_object('status','crew_departure_bound','pilotCount',cardinality(cps)+cardinality(fos),'cabinCount',cardinality(cabin),'replayed',false);
 END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_operated_crew_capture_issues_v1(engine_event_id,airline_id,physical_flight_id,issue_code) VALUES(p_event,p_airline,p_physical,issue) ON CONFLICT(engine_event_id) DO NOTHING;
 RETURN jsonb_build_object('status',issue,'crewCancellationTriggered',false);
END $$;
CREATE FUNCTION airlinerra_game.section9_complete_bound_crew_arrival_v1(p_airline uuid,p_physical text,p_event text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE b record;outcome jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO b FROM airlinerra_game.section9_operated_crew_bindings_v1 WHERE airline_id=p_airline AND physical_flight_id=p_physical;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','crew_arrival_no_bound_roster');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=p_event AND phase='arrived' AND airline_id=p_airline AND flight_occurrence_id=p_physical) THEN RETURN jsonb_build_object('status','crew_arrival_evidence_missing');END IF;
 outcome:=airlinerra_game.section9_credit_completed_pilot_flight_v1(p_airline,p_physical);
 RETURN outcome||jsonb_build_object('crewRosterBound',true,'cabinCrewCount',cardinality(b.cabin_member_ids));
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_capture_dispatched_crew_v1(uuid,text,text),airlinerra_game.section9_complete_bound_crew_arrival_v1(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;
