-- Candidate installation prerequisite; read-only assertion, no fixture rows.
-- Existing registry can contain other airports. Check only the nine identities.
-- Hold the registry stable throughout the preview transaction.
LOCK TABLE airlinerra.airport_registry IN SHARE MODE;
DO $registry$
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF EXISTS(
 SELECT 1 FROM (VALUES
 ('OURAIRPORTS:20507','20507','US','KMHV','KMHV'),
 ('OURAIRPORTS:20594','20594','US','KMZJ','KMZJ'),
 ('OURAIRPORTS:21315','21315','US','KVCV','KVCV'),
 ('OURAIRPORTS:2395','2395','GB','EGBP','EGBP'),
 ('OURAIRPORTS:2409','2409','GB','EGDX','EGSY'),
 ('OURAIRPORTS:26900','26900','AU','YBAS','YBAS'),
 ('OURAIRPORTS:316427','316427','ES','LETL','LETL'),
 ('OURAIRPORTS:3856','3856','US','KROW','KROW'),
 ('OURAIRPORTS:4073','4073','FR','LFBT','LFBT')
 ) AS wanted(airport_key,source_airport_id,country_iso,source_ident,source_gps_code)
 LEFT JOIN airlinerra.airport_registry a USING(airport_key)
 WHERE a.airport_key IS NULL OR a.source_type IS DISTINCT FROM 'OURAIRPORTS'
 OR a.source_airport_id IS DISTINCT FROM wanted.source_airport_id
 OR a.country_iso IS DISTINCT FROM wanted.country_iso
 OR a.source_ident IS DISTINCT FROM wanted.source_ident
 OR a.source_gps_code IS DISTINCT FROM wanted.source_gps_code
 ) THEN RAISE EXCEPTION 'STORAGE_EXISTING_REGISTRY_IDENTITY_MISMATCH';END IF;
 IF EXISTS(
 SELECT 1 FROM (VALUES
 ('airlinerra_game.section9_auto_supply_game_only_fuel_v1(text)','ec884e2b3c7fae76b7fe129067f32e2c'),
 ('airlinerra_game.section9_verify_game_fuel_before_departure_v1(text)','8485598ffa10225b14b17adbc2a45867'),
 ('airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(uuid,uuid,uuid,timestamptz,timestamptz)','55a3903eb1fa311df18a51e90f666676'),
 ('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','7ef977a05bec5b899d52d1548afbf1d8')
 ) AS wanted(signature,expected_hash)
 WHERE md5(pg_get_functiondef(to_regprocedure(wanted.signature))) IS DISTINCT FROM wanted.expected_hash
 ) OR NOT EXISTS(
 SELECT 1 FROM pg_constraint WHERE conrelid=to_regclass('airlinerra_game.airline_ledger')
 AND conname='valid_entry_kind' AND contype='c' AND convalidated
 AND md5(pg_get_constraintdef(oid))='8acbb97bdb2207e8ceae41f2d6f3f216'
 ) THEN RAISE EXCEPTION 'STORAGE_INSTALLATION_SOURCE_DRIFT';END IF;
 RAISE NOTICE 'All nine existing storage airport registry identities and five source fingerprints matched';
END $registry$;
