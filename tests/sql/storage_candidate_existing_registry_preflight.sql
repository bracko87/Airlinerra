-- Candidate installation prerequisite; read-only assertion, no fixture rows.
-- Existing registry can contain other airports. Check only the nine identities.
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
 RAISE NOTICE 'All nine existing storage airport registry identities matched';
END $registry$;
