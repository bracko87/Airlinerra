-- Disposable operational review test. The inserted reviewer input is synthetic.
DO $test$
DECLARE j jsonb; before_profiles int;
BEGIN
 SELECT count(*) INTO before_profiles FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_only_service_candidates_v1)<>6
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_only_service_candidates_v1 WHERE fuel_evidence_status='listed')<>5
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_only_service_candidates_v1 WHERE airport_key='OURAIRPORTS:19330') THEN RAISE EXCEPTION 'storage service evidence scope incorrect';END IF;
 j:=airlinerra_game.stage_storage_only_operational_profile_v1('OURAIRPORTS:316427');
 IF j->>'status' IS DISTINCT FROM 'storage_profile_review_required' THEN RAISE EXCEPTION 'unreviewed profile accepted: %',j;END IF;
 j:=airlinerra_game.stage_storage_only_operational_profile_v1('OURAIRPORTS:26900');
 IF j->>'status' IS DISTINCT FROM 'storage_profile_candidate_invalid' THEN RAISE EXCEPTION 'commercial scope accepted: %',j;END IF;
 INSERT INTO airlinerra_game.aircraft_storage_only_profile_reviews_v1 VALUES(1,'OURAIRPORTS:316427',2825,45,'ASP',1.2,30,false,NULL,NULL,false,NULL,true,'synthetic runway','synthetic restrictions','synthetic access',airlinerra_game.section9_verified_world_instant_v1());
 j:=airlinerra_game.stage_storage_only_operational_profile_v1('OURAIRPORTS:316427');
 IF j->>'status' IS DISTINCT FROM 'storage_profile_review_mismatch' THEN RAISE EXCEPTION 'overstated runway accepted: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_only_profile_reviews_v1 SET reviewed_runway_length_m=2539 WHERE airport_key='OURAIRPORTS:316427';
 j:=airlinerra_game.stage_storage_only_operational_profile_v1('OURAIRPORTS:316427');
 IF j->>'staged' IS DISTINCT FROM 'true' OR j->>'fuelSupplierAuthorized' IS DISTINCT FROM 'false' OR j->>'storageCapacityUnlimited' IS DISTINCT FROM 'true'
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1)<>before_profiles+1
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 WHERE airport_key='OURAIRPORTS:316427' AND runway_length_m=2539 AND landing_fee_usd=1000 AND departure_fee_usd=160)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_only_airport_rules_v1 WHERE airport_key='OURAIRPORTS:316427' AND runway_elevation_factor=1.2)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_tariffs_v1 WHERE airport_key='OURAIRPORTS:316427' AND departure_ground_handling_usd=200)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_only_movement_limits_v1 WHERE airport_key='OURAIRPORTS:316427' AND movements_per_direction_hour=2 AND movements_per_direction_10m=1)
 OR airlinerra_game.aircraft_storage_airport_admission_v1('OURAIRPORTS:316427','storage_inbound')->>'eligible' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION 'storage-only staging mismatch: %',j;END IF;
 j:=airlinerra_game.stage_storage_only_operational_profile_v1('OURAIRPORTS:316427');
 IF j->>'status' IS DISTINCT FROM 'storage_profile_staging_conflict' OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1)<>before_profiles+1 THEN RAISE EXCEPTION 'repeat changed profile: %',j;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE review_state<>'candidate') THEN RAISE EXCEPTION 'facility admission unexpectedly changed';END IF;
 RAISE NOTICE 'Six storage-only service records and reviewed profile staging acceptance passed (synthetic Teruel review)';
END $test$;
