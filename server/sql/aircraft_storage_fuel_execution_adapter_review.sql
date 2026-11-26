-- ROLLBACK-ONLY REVIEW. Existing source fingerprint required.
-- This adapter does not authorize dispatch or alter commercial airport admission.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_execution_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 fuel_adapter_enabled boolean NOT NULL DEFAULT false,
 execution_enabled boolean NOT NULL DEFAULT false,
 CHECK(NOT execution_enabled OR fuel_adapter_enabled)
);
INSERT INTO airlinerra_game.aircraft_storage_execution_release_v1(world_id) VALUES(1);
ALTER TABLE airlinerra_game.aircraft_storage_execution_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_execution_release_v1 FROM PUBLIC,anon,authenticated,service_role;
-- Explicit game-only supplier approval, not a commercial airport facility.
CREATE TABLE airlinerra_game.aircraft_storage_fuel_services_v1(
 world_id smallint NOT NULL CHECK(world_id=1),
 airport_key text NOT NULL,
 fuel_game_family text NOT NULL CHECK(btrim(fuel_game_family)<>''),
 approval_reference text NOT NULL CHECK(btrim(approval_reference)<>''),
 PRIMARY KEY(world_id,airport_key,fuel_game_family),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_airport_operational_profiles_v1(world_id,airport_key)
);
ALTER TABLE airlinerra_game.aircraft_storage_fuel_services_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_fuel_services_v1 FROM PUBLIC,anon,authenticated,service_role;
-- Return the original relocation row shape, for compatibility with both
-- existing fuel routines. Storage evidence never masquerades as maintenance.
CREATE FUNCTION airlinerra_game.aircraft_storage_fuel_leg_lookup_v1(p_physical text)
RETURNS TABLE(airline_id uuid,aircraft_inventory_id uuid,owner_player_id uuid,configuration_id bigint,
 origin_airport_key text,destination_airport_key text,departure_utc timestamptz,arrival_utc timestamptz,
 is_storage boolean,storage_purpose text)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT l.airline_id,l.aircraft_inventory_id,l.owner_player_id,l.configuration_id,
 l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,false,NULL::text
 FROM airlinerra_game.section9_relocation_leg_evidence_v1(p_physical) l
 UNION ALL
 SELECT l.airline_id,l.aircraft_inventory_id,l.owner_player_id,l.configuration_id,
 l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,true,l.purpose
 FROM airlinerra_game.aircraft_storage_any_leg_evidence_v1(p_physical) l
 WHERE EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_execution_release_v1
 WHERE world_id=1 AND fuel_adapter_enabled AND execution_enabled)
 AND (l.purpose='storage_inbound' OR (l.purpose='storage_reactivation' AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled)))
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_leg_evidence_v1(p_physical));
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_fuel_leg_lookup_v1(text) FROM PUBLIC,anon,authenticated,service_role;
DO $patch$
DECLARE f record; original text; updated text;
 lookup_old text:='SELECT * INTO relocation FROM airlinerra_game.section9_relocation_leg_evidence_v1(p_physical_flight_id);';
 lookup_new text:='SELECT * INTO relocation FROM airlinerra_game.aircraft_storage_fuel_leg_lookup_v1(p_physical_flight_id);';
 phase_old text:='phase_profile:=airlinerra_game.section9_game_route_phase_profile_v1(r.configuration_id,r.origin_airport_key,r.destination_airport_key,total_minutes);';
 phase_new text:='IF is_storage_relocation THEN
 phase_profile:=airlinerra_game.aircraft_storage_route_phase_profile_v1(r.configuration_id,r.origin_airport_key,r.destination_airport_key,storage_purpose,total_minutes);
 ELSE
 '||phase_old||'
 END IF;';
BEGIN
 FOR f IN SELECT * FROM (VALUES
 ('airlinerra_game.section9_auto_supply_game_only_fuel_v1(text)','ec884e2b3c7fae76b7fe129067f32e2c',false),
 ('airlinerra_game.section9_verify_game_fuel_before_departure_v1(text)','8485598ffa10225b14b17adbc2a45867',true)
 ) v(signature,expected_hash,preflight)
 LOOP
  original:=pg_get_functiondef(to_regprocedure(f.signature));
  IF original IS NULL OR md5(original)<>f.expected_hash THEN RAISE EXCEPTION 'STORAGE_FUEL_SOURCE_DRIFT: %',f.signature;END IF;
  IF (length(original)-length(replace(original,lookup_old,'')))/length(lookup_old)<>1 THEN RAISE EXCEPTION 'STORAGE_FUEL_LOOKUP_DRIFT';END IF;
  updated:=replace(original,lookup_old,lookup_new);
  IF f.preflight THEN
   IF strpos(updated,phase_old)=0 OR strpos(updated,'is_relocation boolean:=false;')=0 OR strpos(updated,'is_relocation:=true;')=0 THEN RAISE EXCEPTION 'STORAGE_FUEL_PHASE_DRIFT';END IF;
   updated:=replace(updated,'is_relocation boolean:=false;','is_relocation boolean:=false; is_storage_relocation boolean:=false; storage_purpose text;');
   updated:=replace(updated,'is_relocation:=true;','is_relocation:=true; is_storage_relocation:=relocation.is_storage; storage_purpose:=relocation.storage_purpose;');
   updated:=replace(updated,phase_old,phase_new);
  END IF;
  IF f.preflight THEN
   IF strpos(updated,'origin_can_supply:=coalesce(origin_can_supply,false);')=0 THEN RAISE EXCEPTION 'STORAGE_FUEL_SERVICE_DRIFT';END IF;
   updated:=replace(updated,'origin_can_supply:=coalesce(origin_can_supply,false);','origin_can_supply:=coalesce(origin_can_supply,false);
   IF storage_purpose=''storage_reactivation'' AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=r.origin_airport_key AND admission_scope=''relocation_only'') THEN
    origin_can_supply:=EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1 WHERE world_id=1 AND airport_key=r.origin_airport_key AND fuel_game_family=fuel_model.fuel_game_family);
   END IF;');
  END IF;
  EXECUTE updated;
 END LOOP;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_execution_release_v1 WHERE fuel_adapter_enabled OR execution_enabled) THEN RAISE EXCEPTION 'STORAGE_REVIEW_RELEASE_ENABLED';END IF;
 RAISE NOTICE 'Storage fuel adapter definitions installed for rollback-only review';
END $patch$;
ROLLBACK;
