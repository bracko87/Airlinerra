-- Fresh disposable database only. Run after candidate and billing table DDL.
DO $test$
DECLARE j jsonb;
BEGIN
 IF current_database()<>'storage_billing_review' THEN RAISE EXCEPTION 'disposable review database required';END IF;
 INSERT INTO airlinerra.aircraft_catalog_configuration_inventory
 SELECT configuration_id,family_id,variant_id,configuration_code FROM airlinerra_game.storage_billing_class_candidates_v1;
 j:=airlinerra_game.stage_storage_billing_classes_v1('synthetic review');
 IF j->>'status' IS DISTINCT FROM 'storage_billing_class_review_not_released' OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_billing_classes_v1) THEN RAISE EXCEPTION 'disabled review bypass: %',j;END IF;
 UPDATE airlinerra_game.storage_billing_class_release_v1 SET enabled=true,approval_reference='synthetic review';
 j:=airlinerra_game.stage_storage_billing_classes_v1('wrong review');
 IF j->>'staged' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'approval reference bypass';END IF;
 UPDATE airlinerra.aircraft_catalog_configuration_inventory SET variant_id=variant_id+99999 WHERE configuration_id=1;
 j:=airlinerra_game.stage_storage_billing_classes_v1('synthetic review');
 IF j->>'status' IS DISTINCT FROM 'storage_billing_catalogue_changed' OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_billing_classes_v1) THEN RAISE EXCEPTION 'changed identity accepted: %',j;END IF;
 UPDATE airlinerra.aircraft_catalog_configuration_inventory SET variant_id=variant_id-99999 WHERE configuration_id=1;
 INSERT INTO airlinerra.aircraft_catalog_configuration_inventory VALUES(999999,6,1,'TEST');
 j:=airlinerra_game.stage_storage_billing_classes_v1('synthetic review');
 IF j->>'status' IS DISTINCT FROM 'storage_billing_catalogue_changed' THEN RAISE EXCEPTION 'new configuration accepted: %',j;END IF;
 DELETE FROM airlinerra.aircraft_catalog_configuration_inventory WHERE configuration_id=999999;
 INSERT INTO airlinerra_game.aircraft_storage_billing_classes_v1 VALUES(1,'regional','other review');
 j:=airlinerra_game.stage_storage_billing_classes_v1('synthetic review');
 IF j->>'status' IS DISTINCT FROM 'storage_billing_existing_class_conflict' OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_billing_classes_v1)<>1 THEN RAISE EXCEPTION 'existing classification overwritten: %',j;END IF;
 DELETE FROM airlinerra_game.aircraft_storage_billing_classes_v1 WHERE configuration_id=1;
 j:=airlinerra_game.stage_storage_billing_classes_v1('synthetic review');
 IF j->>'staged' IS DISTINCT FROM 'true' OR j->>'inserted' IS DISTINCT FROM '271' THEN RAISE EXCEPTION 'staging failed: %',j;END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_billing_classes_v1 WHERE billing_class='regional')<>129
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_billing_classes_v1 WHERE billing_class='narrowbody')<>75
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_billing_classes_v1 WHERE billing_class='widebody')<>67 THEN RAISE EXCEPTION 'billing counts mismatch';END IF;
 j:=airlinerra_game.stage_storage_billing_classes_v1('synthetic review');
 IF j->>'staged' IS DISTINCT FROM 'true' OR j->>'inserted' IS DISTINCT FROM '0' THEN RAISE EXCEPTION 'staging replay not idempotent: %',j;END IF;
 RAISE NOTICE 'Billing classification staging acceptance passed: 271 exact configurations, release and reference checks, drift and conflict rejection, idempotent replay';
END $test$;
