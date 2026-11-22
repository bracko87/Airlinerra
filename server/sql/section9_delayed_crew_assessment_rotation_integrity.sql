CREATE OR REPLACE FUNCTION airlinerra_game.section9_assess_delayed_crew_rotation_v1(p_player uuid, p_airline uuid, p_occurrence uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE pl record; t record; pol record; seat record; leg record; leg_t record; dep timestamptz; arr timestamptz; prev_arr timestamptz; prev_dest text; last_arr timestamptz; next_report timestamptz; reason text; fit jsonb; details jsonb:='[]'; failures int:=0; assessed int:=0; ext int; moved record; arrived record; external_ok jsonb; schedule record; eligible boolean; leg_count int; expected_legs int;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT o.* INTO schedule FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=p_occurrence AND o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','crew_occurrence_unavailable','dispatchEnforced',false);END IF;
 SELECT * INTO t FROM airlinerra_game.section9_effective_dispatch_window_v1(p_occurrence);
 IF NOT FOUND OR t.is_delayed IS DISTINCT FROM true OR t.dispatch_allowed IS DISTINCT FROM true THEN RETURN jsonb_build_object('status','verified_delay_window_required','dispatchEnforced',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.flight_occurrence_id=schedule.schedule_id||':'||schedule.flight_local_date||':'||schedule.weekly_entry AND m.phase='departed') THEN RETURN jsonb_build_object('status','crew_flight_already_departed','dispatchEnforced',false);END IF;
 SELECT pf.* INTO pl FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview'
 WHERE pf.occurrence_id=p_occurrence AND pf.airline_id=p_airline AND pf.schedule_version=schedule.schedule_version AND pf.aircraft_inventory_id=schedule.aircraft_inventory_id AND pf.departure_utc=schedule.departure_utc AND pf.arrival_utc=schedule.arrival_utc AND pf.origin_airport_key=schedule.origin_airport_key AND pf.destination_airport_key=schedule.destination_airport_key;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','crew_current_plan_missing','dispatchEnforced',false);END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 ext:=pl.external_captain_count+pl.external_first_officer_count+pl.external_cabin_count;
 FOR seat IN SELECT s.seat_role,d.* FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id WHERE s.plan_id=pl.plan_id AND s.occurrence_id=p_occurrence LOOP
  reason:=NULL;fit:=NULL;prev_arr:=NULL;prev_dest:=seat.starting_airport;last_arr:=NULL;leg_count:=0;
  SELECT count(*) INTO expected_legs FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pl.plan_id AND s.duty_id=seat.duty_id;
  FOR leg IN SELECT f.*,s.seat_role AS leg_role,o.booking_status,o.schedule_id,o.flight_local_date,o.weekly_entry FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 f ON f.plan_id=s.plan_id AND f.occurrence_id=s.occurrence_id AND f.airline_id=s.airline_id JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=f.occurrence_id AND o.airline_id=f.airline_id AND o.schedule_version=f.schedule_version AND o.departure_utc=f.departure_utc AND o.arrival_utc=f.arrival_utc
   WHERE s.plan_id=pl.plan_id AND s.duty_id=seat.duty_id ORDER BY f.departure_utc,f.occurrence_id LOOP
   leg_count:=leg_count+1;
   IF leg.booking_status='cancelled' THEN reason:='crew_rotation_cancelled_leg_requires_review';EXIT;END IF;
   SELECT * INTO leg_t FROM airlinerra_game.section9_effective_dispatch_window_v1(leg.occurrence_id);
   IF NOT FOUND OR leg_t.dispatch_allowed IS DISTINCT FROM true THEN reason:='crew_rotation_timing_unverified';EXIT;END IF;
   dep:=leg_t.effective_departure_utc;arr:=leg_t.effective_arrival_utc;
   SELECT m.* INTO moved FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.flight_occurrence_id=leg.physical_flight_id AND m.phase='departed';
   IF FOUND THEN
    SELECT m.* INTO arrived FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.flight_occurrence_id=leg.physical_flight_id AND m.phase='arrived' AND m.aircraft_inventory_id=leg.aircraft_inventory_id AND m.schedule_version=leg.schedule_version AND m.origin_airport_key=leg.origin_airport_key AND m.destination_airport_key=leg.destination_airport_key;
    IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b WHERE b.airline_id=p_airline AND b.physical_flight_id=leg.physical_flight_id AND b.plan_id=leg.plan_id AND b.occurrence_id=leg.occurrence_id AND b.departure_event_id=moved.engine_event_id) THEN reason:='crew_prior_movement_unverified';EXIT;END IF;
    dep:=moved.actual_event_utc;arr:=arrived.actual_event_utc;
   END IF;
   IF dep IS NULL OR arr IS NULL OR arr<=dep OR dep<seat.duty_start_utc OR prev_dest IS DISTINCT FROM leg.origin_airport_key OR (prev_arr IS NOT NULL AND dep<prev_arr) THEN reason:='crew_rotation_overlap_or_location';EXIT;END IF;
   -- Recheck current employment/qualification at every changed leg, not just the original date.
   IF moved.engine_event_id IS NULL THEN
    IF leg.leg_role='cabin' THEN
     SELECT EXISTS(SELECT 1 FROM airlinerra_game.section9_cabin_crew_members_v1 c JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=c.world_id AND ap.airport_key=c.base_airport_key WHERE c.airline_id=p_airline AND c.member_id=seat.employee_id AND c.employment_status='employed' AND c.role IN('flight_attendant','cabin_supervisor','purser') AND c.effective_game_date<=(seat.duty_start_utc AT TIME ZONE ap.timezone_iana)::date) INTO eligible;
    ELSE
     SELECT EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_profiles_v1 pr JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=pr.airline_id AND r.crew_id=pr.crew_id JOIN airlinerra_game.section9_pilot_base_assignments_v1 b ON b.airline_id=pr.airline_id AND b.crew_id=pr.crew_id JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.base_airport_key JOIN airlinerra_game.section9_pilot_family_permissions_v1 q ON q.airline_id=pr.airline_id AND q.crew_id=pr.crew_id AND q.qualification_group=leg.qualification_group WHERE pr.airline_id=p_airline AND pr.crew_id=seat.employee_id AND r.employment_status='verified_employed' AND r.game_effective_date<=(seat.duty_start_utc AT TIME ZONE ap.timezone_iana)::date AND q.qualification_status='active' AND q.issued_game_date<=(dep AT TIME ZONE ap.timezone_iana)::date AND q.expires_game_date>(arr AT TIME ZONE ap.timezone_iana)::date AND airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,leg.leg_role)) INTO eligible;
    END IF;
    IF NOT eligible THEN reason:='crew_employment_or_qualification_changed';EXIT;END IF;
   END IF;
   prev_arr:=arr;prev_dest:=leg.destination_airport_key;last_arr:=arr;
  END LOOP;
  IF reason IS NULL AND leg_count<>expected_legs THEN reason:='crew_rotation_leg_missing';END IF;
  IF reason IS NULL THEN
   SELECT min(d.duty_start_utc) INTO next_report FROM airlinerra_game.section9_planned_crew_duties_v1 d WHERE d.plan_id=pl.plan_id AND d.airline_id=p_airline AND d.employee_id=seat.employee_id AND d.duty_start_utc>seat.duty_start_utc;
   fit:=airlinerra_game.section9_delayed_crew_duty_window_v1(seat.duty_start_utc,last_arr,next_report,pol.postflight_minutes,pol.maximum_duty_minutes,pol.minimum_rest_minutes);
   IF fit->>'eligible' IS DISTINCT FROM 'true' THEN reason:=fit->>'status';
   ELSIF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 a WHERE a.airline_id=p_airline AND a.status='active' AND (a.pilot_id=seat.pilot_id OR a.cabin_member_id=seat.cabin_member_id) AND a.start_utc<(fit->>'dutyEndUtc')::timestamptz AND a.end_utc>seat.duty_start_utc) THEN reason:='crew_employee_unavailable';END IF;
  END IF;
  assessed:=assessed+1;
  IF reason IS NOT NULL THEN failures:=failures+1;END IF;
  details:=details||jsonb_build_array(jsonb_build_object('employeeId',seat.employee_id,'role',seat.seat_role,'status',coalesce(reason,'duty_window_fits'),'dutyWindow',fit));
 END LOOP;
 IF assessed<>pl.captain_count+pl.first_officer_count+pl.cabin_count THEN RETURN jsonb_build_object('status','crew_seat_count_changed','dispatchEnforced',false);END IF;
 RETURN jsonb_build_object('status',CASE WHEN failures>0 THEN 'delayed_crew_replacement_required' WHEN ext>0 THEN 'delayed_external_contract_review_required' ELSE 'delayed_crew_duty_windows_fit' END,
 'occurrenceId',p_occurrence,'originalDepartureUtc',schedule.departure_utc,'revisedDepartureUtc',t.effective_departure_utc,'revisedArrivalUtc',t.effective_arrival_utc,'employeesAssessed',assessed,'employeesRequiringReplacementOrReview',failures,'externalCrewRequiresReview',ext,'employees',details,'dispatchEnforced',false,'planChanged',false,'contractsChanged',false);
END $function$
;