-- REVIEW ONLY: current single-route first departure gate; disposable only.
BEGIN;
DO $patch$
DECLARE fn regprocedure; src text;
 marker constant text := '   maintenance:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1';
 injection constant text := $guard$
   IF EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i
    WHERE i.id=target.aircraft_inventory_id AND i.airline_id=p_airline AND i.ownership_type='leased')
   AND airlinerra_game.aircraft_lease_departure_coverage_v1(p_airline,target.aircraft_inventory_id,occ.dep,occ.arr)->>'eligible' IS DISTINCT FROM 'true'
   THEN RETURN jsonb_build_object('valid',false,'reason','AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED');END IF;
$guard$;
BEGIN
 IF current_database()<>'airlinerra_disposable' THEN RAISE EXCEPTION 'DISPOSABLE_DATABASE_REQUIRED';END IF;
 fn:=to_regprocedure('airlinerra_game.section9_single_route_first_departure_v1(uuid,uuid,uuid,date)');
 IF fn IS NULL THEN RAISE EXCEPTION 'Missing first departure function';END IF;
 src:=pg_get_functiondef(fn);
 IF position('AIRCRAFT_CANNOT_REACH_FIRST_DEPARTURE' IN src)=0
 OR position('FIRST_DEPARTURE_TURNAROUND_CONFLICT' IN src)=0
 OR position('MAINTENANCE_FLIGHT_WINDOW_BLOCKED' IN src)=0
 OR length(src)-length(replace(src,marker,''))<>length(marker)
 OR position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN src)>0
 THEN RAISE EXCEPTION 'First departure source drift';END IF;
 EXECUTE replace(src,marker,injection||marker);
 IF position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN pg_get_functiondef(fn))=0
 THEN RAISE EXCEPTION 'Lease activation gate missing';END IF;
END $patch$;
-- Do not require payment for the entire recurring timetable horizon.
-- Separate ticket occurrence admission and alternate activation paths need review.
ROLLBACK;
