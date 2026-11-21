-- Enable passenger experience collection only; leave demand effect gated.
DO $release$
DECLARE result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(583729,10062);
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-passenger-experience-v1' AND active) THEN RAISE EXCEPTION 'PASSENGER_EXPERIENCE_SCHEDULER_MISSING';END IF;
 UPDATE airlinerra_game.section9_passenger_experience_release_v1 SET collection_enabled=true,demand_effect_enabled=false WHERE world_id=1;
 result:=airlinerra_game.section9_collect_passenger_experience_v1(100);
 IF result->>'status' IS DISTINCT FROM 'passenger_experience_collection_completed' OR result->>'ledgerPosted' IS DISTINCT FROM 'false' OR result->>'bookingsChanged' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'PASSENGER_EXPERIENCE_COLLECTION_SMOKE_FAILED: %',result;END IF;
END $release$;