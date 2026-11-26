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
-- No arrival guard; no payment or fuel side effects for rejected departures.
-- Direct signed movement and activation still require independent integration.
ROLLBACK;
