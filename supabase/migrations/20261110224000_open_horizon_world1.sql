-- Horizon World 1 is open. Keep the separate global release-gate policy unchanged,
-- and never synthesize authoritative game ticks or enable Group2 flight admission.
DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.airlinerra_game_worlds WHERE id=1 AND state='planned' AND opens_at IS NULL)
 THEN RAISE EXCEPTION 'HORIZON_WORLD_STATE_PREFLIGHT_CHANGED';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 WHERE world_id=1)<>4259
 OR (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 WHERE world_id=2)<>4259
 OR (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 WHERE world_id=3)<>4259
 THEN RAISE EXCEPTION 'SHARED_AIRPORT_CATALOG_NOT_READY';END IF;
END $$;
UPDATE public.airlinerra_game_worlds
SET state='active',opens_at=clock_timestamp()
WHERE id=1 AND state='planned' AND opens_at IS NULL;
DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.airlinerra_game_worlds WHERE id=1 AND state='active' AND opens_at<=clock_timestamp())
 THEN RAISE EXCEPTION 'HORIZON_WORLD_DID_NOT_OPEN';END IF;
 IF EXISTS(SELECT 1 FROM public.airlinerra_game_worlds WHERE id IN (2,3) AND state<>'planned')
 THEN RAISE EXCEPTION 'OTHER_WORLD_STATES_WERE_CHANGED';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'GROUP2_FLIGHTS_UNEXPECTEDLY_ACTIVATED';END IF;
END $$;