-- Initial production release for currently supported passenger commercial operations.
-- The scheduler retains signed aircraft movements, original weekly schedules,
-- airport/permit/maintenance/fuel checks and independent finance settlement.
DO $release$
DECLARE r jsonb; changed int;
BEGIN
 PERFORM pg_advisory_xact_lock(583729,10041);
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1
  WHERE world_id=1 AND world_state='active' AND authoritative_clock_connected
  AND trusted_flight_execution_release='ACTIVATED' AND fuel_transaction_release='ACTIVATED'
  AND automatic_flight_and_fuel_settlement_enabled) THEN RAISE EXCEPTION 'DISRUPTION_RELEASE_BASE_ENGINE_NOT_READY';END IF;
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-operated-flight-dispatch-v1' AND active
  AND command='SELECT airlinerra_game.section9_auto_dispatch_due_flight_events_v1(40);')
 THEN RAISE EXCEPTION 'DISRUPTION_RELEASE_SCHEDULER_NOT_READY';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE booking_status IN('open','closed'))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_atomic_itinerary_holds_v1 WHERE status='preflight_only' AND cargo_tonnes>0)
 THEN RAISE EXCEPTION 'INITIAL_DISRUPTION_RELEASE_REQUIRES_EMPTY_ACTIVE_OCCURRENCE_QUEUE';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i JOIN airlinerra_game.airlines a ON a.id=i.airline_id
 WHERE a.world_id=1 AND i.fleet_status='in_service' AND NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section9_starter_game_airframe_baselines_v1 b WHERE b.aircraft_inventory_id=i.id AND b.airline_id=i.airline_id))
 THEN RAISE EXCEPTION 'DISRUPTION_RELEASE_MISSING_AIRCRAFT_CONDITION_BASELINE';END IF;
 UPDATE airlinerra_game.section9_disruption_release_v1
 SET decision_enabled=true,cancellation_enabled=true,replacement_reservation_enabled=true,
 delayed_execution_enabled=true,rotation_rescheduling_enabled=true,connecting_recovery_enabled=true,automatic_disruption_enabled=true
 WHERE world_id=1;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 OR NOT airlinerra_game.section9_automatic_disruption_ready_v1() THEN RAISE EXCEPTION 'DISRUPTION_RELEASE_FLAGS_NOT_ATOMIC';END IF;
 r:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(40);
 IF r->>'status' IS DISTINCT FROM 'trusted_game_dispatch_cycle_completed'
 OR r->'disruptionCycle'->>'status' IS DISTINCT FROM 'automatic_disruption_cycle_completed'
 OR (r->>'blocked')::int IS DISTINCT FROM 0 OR (r->'disruptionCycle'->>'blocked')::int IS DISTINCT FROM 0
 THEN RAISE EXCEPTION 'DISRUPTION_RELEASE_SMOKE_TEST_FAILED: %',r;END IF;
END $release$;
