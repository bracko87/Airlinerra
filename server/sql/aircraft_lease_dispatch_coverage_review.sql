-- REVIEW ONLY: guarded dispatcher patch, no deployment or release toggle.
BEGIN;
DO $patch$
DECLARE fn regprocedure; src text; marker constant text := '  -- Fuel must already exist on this exact game aircraft, at this';
 injection constant text := $guard$
  IF reason IS NULL AND evt.phase='departed' AND evt.ownership_type='leased' THEN
   IF airlinerra_game.aircraft_lease_departure_coverage_v1(
      evt.airline_id,evt.aircraft_inventory_id,
      evt.effective_departure_utc,evt.effective_arrival_utc
    )->>'eligible' IS DISTINCT FROM 'true' THEN
    reason:='AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED';
   END IF;
  END IF;
$guard$;
BEGIN
 IF current_database()<>'airlinerra_disposable' THEN RAISE EXCEPTION 'DISPOSABLE_DATABASE_REQUIRED'; END IF;
 fn:=to_regprocedure('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)');
 IF fn IS NULL THEN RAISE EXCEPTION 'Dispatcher missing'; END IF;
 src:=pg_get_functiondef(fn);
 IF position('section9_effective_dispatch_window_v1' IN src)=0
 OR position('section9_capture_dispatched_crew_v1' IN src)=0
 OR position('section9_canonical_aoc_covers_v1' IN src)=0
 OR position('section9_auto_supply_game_only_fuel_v1' IN src)=0
 OR position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN src)>0
 OR length(src)-length(replace(src,marker,''))<>length(marker)
 THEN RAISE EXCEPTION 'Dispatcher drift: refuse patch'; END IF;
 EXECUTE replace(src,marker,injection||marker);
 IF position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN pg_get_functiondef(fn))=0
 THEN RAISE EXCEPTION 'Lease guard missing after patch'; END IF;
END $patch$;
-- Guard direct signed departures too, after replay handling and dated timing.
DO $signed_patch$
DECLARE fn regprocedure; src text;
 marker constant text := ' SELECT delivery_anchor.airport_key,delivery_anchor.anchored_game_date,';
 injection constant text := $signed_guard$
 IF p_phase='departed' AND EXISTS(
  SELECT 1 FROM airlinerra_game.airline_aircraft_inventory
  WHERE id=s.aircraft_inventory_id AND airline_id=p_airline AND ownership_type='leased'
 ) THEN
  IF dated_id IS NULL THEN
   RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LEASE_DATED_DEPARTURE_REQUIRED';
  END IF;
  IF airlinerra_game.aircraft_lease_departure_coverage_v1(
   p_airline,s.aircraft_inventory_id,p_event_utc,
   greatest(timing.effective_arrival_utc,p_event_utc+(scheduled_arr-scheduled_dep))
  )->>'eligible' IS DISTINCT FROM 'true' THEN
   RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED';
  END IF;
 END IF;
$signed_guard$;
BEGIN
 fn:=to_regprocedure('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)');
 IF fn IS NULL THEN RAISE EXCEPTION 'Signed movement missing'; END IF;
 src:=pg_get_functiondef(fn);
 IF position('operated_movement_replayed' IN src)=0
 OR position('section9_effective_dispatch_window_v1' IN src)=0
 OR position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN src)>0
 OR length(src)-length(replace(src,marker,''))<>length(marker)
 THEN RAISE EXCEPTION 'Signed movement drift: refuse patch'; END IF;
 EXECUTE replace(src,marker,injection||marker);
END $signed_patch$;
-- Validate patch positions on the actual captured function definitions.
DO $assert$
DECLARE d text; s text;
BEGIN
 d:=pg_get_functiondef('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'::regprocedure);
 s:=pg_get_functiondef('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'::regprocedure);
 IF position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN d)=0
 OR position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN d)>=position('  -- Fuel must already exist' IN d)
 OR position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN s)<=position('operated_movement_replayed' IN s)
 OR position('AIRCRAFT_LEASE_PAYMENT_COVERAGE_REQUIRED' IN s)>=position(' INSERT INTO airlinerra_game.section9_operated_flight_movements_v1' IN s)
 THEN RAISE EXCEPTION 'Unexpected lease guard placement'; END IF;
END $assert$;
-- Route activation still requires independent integration.
ROLLBACK;
