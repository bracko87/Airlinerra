-- Minimal airport identity metadata from 2026-11-27 read-only catalogue audit.
-- Local schema-only rehearsal fixture, not an import of production rows.
-- No user, airline, operational approval, runway status or tariff data.
DO $fixture$
BEGIN
 IF current_user<>'postgres' OR EXISTS(SELECT 1 FROM airlinerra.airport_registry) THEN RAISE EXCEPTION 'STORAGE_CANDIDATE_EMPTY_CLONE_REQUIRED';END IF;
END $fixture$;
INSERT INTO airlinerra.airport_registry(airport_key,source_type,source_airport_id,country_iso,airport_name,source_ident,source_gps_code) VALUES
('OURAIRPORTS:20507','OURAIRPORTS','20507','US','Mojave Air &  Space Port','KMHV','KMHV'),
('OURAIRPORTS:20594','OURAIRPORTS','20594','US','Pinal Airpark','KMZJ','KMZJ'),
('OURAIRPORTS:21315','OURAIRPORTS','21315','US','Southern California Logistics Airport','KVCV','KVCV'),
('OURAIRPORTS:2395','OURAIRPORTS','2395','GB','Cotswold Airport','EGBP','EGBP'),
('OURAIRPORTS:2409','OURAIRPORTS','2409','GB','MOD St Athan','EGDX','EGSY'),
('OURAIRPORTS:26900','OURAIRPORTS','26900','AU','Alice Springs Airport','YBAS','YBAS'),
('OURAIRPORTS:316427','OURAIRPORTS','316427','ES','Teruel Airport','LETL','LETL'),
('OURAIRPORTS:3856','OURAIRPORTS','3856','US','Roswell Air Center Airport','KROW','KROW'),
('OURAIRPORTS:4073','OURAIRPORTS','4073','FR','Tarbes-Lourdes-Pyrénées Airport','LFBT','LFBT');
