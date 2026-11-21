-- Enable the tested reputation effect on direct passenger demand.
-- Existing reservations, ticket prices, connecting demand and financial settlement remain unchanged.
DO $release$
DECLARE r jsonb; changed int;
BEGIN
 PERFORM pg_advisory_xact_lock(583729,10031);
 PERFORM pg_advisory_xact_lock(583729,10062);
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_experience_release_v1 WHERE world_id=1 AND collection_enabled)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-passenger-experience-v1' AND active)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-route-passenger-demand-v1' AND active)
 THEN RAISE EXCEPTION 'REPUTATION_RELEASE_PREREQUISITES_MISSING';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE booking_status='open')
 THEN RAISE EXCEPTION 'REPUTATION_INITIAL_RELEASE_REQUIRES_EMPTY_BOOKING_QUEUE';END IF;
 r:=airlinerra_game.section9_collect_passenger_experience_v1(100);
 IF r->>'status' IS DISTINCT FROM 'passenger_experience_collection_completed' OR r->>'ledgerPosted' IS DISTINCT FROM 'false' OR r->>'bookingsChanged' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION 'REPUTATION_COLLECTION_SMOKE_FAILED: %',r;END IF;
 UPDATE airlinerra_game.section9_passenger_experience_release_v1 SET demand_effect_enabled=true WHERE world_id=1 AND collection_enabled;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'REPUTATION_RELEASE_SWITCH_FAILED';END IF;
 r:=airlinerra_game.section9_auto_reserve_verified_flight_demand_v1(50);
 IF r->>'status' IS DISTINCT FROM 'automatic_game_passenger_demand_processed' OR (r->>'blocked')::int IS DISTINCT FROM 0 OR (r->>'bookedSeats')::int IS DISTINCT FROM 0 OR r->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION 'REPUTATION_DEMAND_SMOKE_FAILED: %',r;END IF;
END $release$;
