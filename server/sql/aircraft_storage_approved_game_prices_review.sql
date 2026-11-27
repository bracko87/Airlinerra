-- ROLLBACK-ONLY REVIEW. Apply the player-approved game tariff to candidates.
-- No facility approval, existing storage agreement or commercial tariff changes.
BEGIN;
DO $prices$
DECLARE n integer;
BEGIN
 LOCK TABLE airlinerra_game.aircraft_storage_facilities_v1 IN SHARE ROW EXCLUSIVE MODE;
 LOCK TABLE airlinerra_game.aircraft_storage_airport_candidate_data_v1 IN SHARE MODE;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1)<>9
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 f LEFT JOIN airlinerra_game.aircraft_storage_airport_candidate_data_v1 c USING(world_id,airport_key) WHERE c.airport_key IS NULL)
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 WHERE world_id=1)<>9
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 c
 WHERE c.world_id<>1 OR c.airport_key='OURAIRPORTS:19330' OR c.proposed_monthly_regional_usd IS DISTINCT FROM 4000::numeric
 OR c.proposed_monthly_narrowbody_usd IS DISTINCT FROM 8000::numeric OR c.proposed_monthly_widebody_usd IS DISTINCT FROM 15000::numeric)
 THEN RAISE EXCEPTION 'APPROVED_STORAGE_PRICE_DATA_MISMATCH';END IF;
 -- Serialize changes to candidate records; refuse mixed release states.
 PERFORM 1 FROM airlinerra_game.aircraft_storage_facilities_v1 f JOIN airlinerra_game.aircraft_storage_airport_candidate_data_v1 c USING(world_id,airport_key) ORDER BY f.airport_key FOR UPDATE OF f;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 c LEFT JOIN airlinerra_game.aircraft_storage_facilities_v1 f USING(world_id,airport_key)
 WHERE f.review_state IS DISTINCT FROM 'candidate' OR f.admission_scope IS DISTINCT FROM c.scope)
 THEN RAISE EXCEPTION 'STORAGE_PRICE_REVIEW_SCOPE_CHANGED';END IF;
 UPDATE airlinerra_game.aircraft_storage_facilities_v1 f SET
 monthly_regional_usd=c.proposed_monthly_regional_usd,
 monthly_narrowbody_usd=c.proposed_monthly_narrowbody_usd,
 monthly_widebody_usd=c.proposed_monthly_widebody_usd
 FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 c
 WHERE f.world_id=c.world_id AND f.airport_key=c.airport_key AND f.review_state='candidate';
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>9 THEN RAISE EXCEPTION 'STORAGE_PRICE_UPDATE_INCOMPLETE';END IF;
END $prices$;
ROLLBACK;
