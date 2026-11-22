CREATE OR REPLACE FUNCTION airlinerra_game.section9_downstream_crew_reconciliation_v1(p_airline uuid, p_occurrence uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE ap record;cur record;n timestamptz;arrival_at timestamptz;count_ap int:=0;postflight int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','downstream_airline_missing');END IF;
 n:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT postflight_minutes INTO STRICT postflight FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 FOR ap IN SELECT x.* FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND x.occurrence_id<>p_occurrence AND EXISTS(
 SELECT 1 FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.airline_id=pf.airline_id
 JOIN airlinerra_game.section9_planned_crew_seats_v1 original ON original.plan_id=s.plan_id AND original.airline_id=s.airline_id AND original.employee_id=s.employee_id AND original.occurrence_id=x.occurrence_id
 WHERE pf.plan_id=x.source_plan_id AND pf.airline_id=x.airline_id AND pf.occurrence_id=p_occurrence AND pf.departure_utc>=x.original_departure_utc)
 ORDER BY x.authorized_game_utc,x.approval_id LOOP
 count_ap:=count_ap+1;
 SELECT a.actual_event_utc INTO arrival_at FROM airlinerra_game.section9_operated_crew_bindings_v1 b JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=b.departure_event_id AND d.airline_id=b.airline_id AND d.flight_occurrence_id=b.physical_flight_id AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1'
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.airline_id=d.airline_id AND a.flight_occurrence_id=d.flight_occurrence_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1' AND a.aircraft_inventory_id=d.aircraft_inventory_id AND a.schedule_id=d.schedule_id AND a.schedule_version=d.schedule_version AND a.weekly_entry=d.weekly_entry AND a.flight_local_date=d.flight_local_date AND a.origin_airport_key=d.origin_airport_key AND a.destination_airport_key=d.destination_airport_key
 WHERE b.airline_id=p_airline AND b.plan_id=ap.approval_id AND b.occurrence_id=ap.occurrence_id AND b.physical_flight_id=ap.physical_flight_id AND d.actual_event_utc=ap.revised_departure_utc AND a.actual_event_utc>d.actual_event_utc;
 IF NOT FOUND OR n IS NULL OR n<arrival_at+make_interval(mins=>postflight) THEN RETURN jsonb_build_object('status','downstream_waiting_for_actual_arrival','affected',true);END IF;
 -- Only the exact unchanged roster with a genuine same-duty arrival
 -- can continue without a fresh rolling plan.
 IF ap.validation_receipt->>'sameDutyContinuation'='true' AND EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_plan_batches_v1 b WHERE b.plan_id=ap.source_plan_id AND b.airline_id=p_airline AND b.status='validated_preview') THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.airline_id=p_airline) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.airline_id=p_airline AND NOT coalesce((SELECT airlinerra_game.section9_same_duty_prior_sector_v1(p_airline,ap.source_plan_id,prev.occurrence_id,s.employee_id,p_occurrence) FROM airlinerra_game.section9_planned_crew_seats_v1 ps JOIN airlinerra_game.section9_planned_flight_crews_v1 prev ON prev.plan_id=ps.plan_id AND prev.occurrence_id=ps.occurrence_id AND prev.airline_id=ps.airline_id JOIN airlinerra_game.section9_planned_flight_crews_v1 cur_leg ON cur_leg.plan_id=s.plan_id AND cur_leg.occurrence_id=s.occurrence_id WHERE ps.plan_id=s.plan_id AND ps.airline_id=s.airline_id AND ps.employee_id=s.employee_id AND ps.duty_id=s.duty_id AND prev.departure_utc<cur_leg.departure_utc ORDER BY prev.departure_utc DESC,prev.occurrence_id LIMIT 1),false)) THEN RETURN jsonb_build_object('status','downstream_same_duty_continuity_unverified','affected',true);END IF;
 CONTINUE;
 END IF;
 SELECT b.plan_id,b.source_snapshot INTO cur FROM airlinerra_game.section9_crew_plan_batches_v1 b JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=b.plan_id AND pf.airline_id=b.airline_id AND pf.occurrence_id=p_occurrence WHERE b.airline_id=p_airline AND b.status='validated_preview';
 IF NOT FOUND OR cur.plan_id=ap.source_plan_id OR cur.source_snapshot->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR (cur.source_snapshot->>'planningCutoffUtc')::timestamptz<arrival_at+make_interval(mins=>postflight) THEN RETURN jsonb_build_object('status','downstream_rolling_replan_required','affected',true);END IF;
 END LOOP;
 RETURN jsonb_build_object('status',CASE WHEN count_ap>0 THEN 'downstream_crew_reconciled' ELSE 'downstream_unaffected' END,'affected',count_ap>0,'dependencies',count_ap);
END $function$;