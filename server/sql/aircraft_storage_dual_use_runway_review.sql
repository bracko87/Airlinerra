-- ROLLBACK-ONLY REVIEW. Additional conservative storage-only runway limits
-- for existing commercial airports; never changes commercial airport rows.
BEGIN;
CREATE TABLE airlinerra_game.storage_dual_use_runway_reviews_v1(
 world_id smallint NOT NULL CHECK(world_id=1),airport_key text NOT NULL,
 source_runway_id text NOT NULL CHECK(btrim(source_runway_id)<>''),
 takeoff_limit_m numeric NOT NULL CHECK(takeoff_limit_m>0 AND takeoff_limit_m<'Infinity'::numeric),
 landing_limit_m numeric NOT NULL CHECK(landing_limit_m>0 AND landing_limit_m<'Infinity'::numeric),
 evidence_reference text NOT NULL CHECK(btrim(evidence_reference)<>''),
 reviewed_at timestamptz NOT NULL,
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key)
);
ALTER TABLE airlinerra_game.storage_dual_use_runway_reviews_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_dual_use_runway_reviews_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.storage_dual_use_runway_snapshot_v1(p_airport text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE r record;w record;t timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 t:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT x.* INTO r FROM airlinerra_game.storage_dual_use_runway_reviews_v1 x
 JOIN airlinerra_game.aircraft_storage_facilities_v1 f USING(world_id,airport_key)
 WHERE x.world_id=1 AND x.airport_key=p_airport AND f.admission_scope='existing_commercial';
 IF NOT FOUND OR t IS NULL OR NOT isfinite(t) OR r.reviewed_at>t THEN RETURN jsonb_build_object('ready',false,'status','storage_dual_use_runway_review_missing');END IF;
 SELECT x.* INTO w FROM airlinerra_game.airport_runway_inventory x WHERE x.world_id=1 AND x.airport_key=p_airport AND x.source_runway_id=r.source_runway_id;
 IF NOT FOUND OR w.operational_status IS DISTINCT FROM 'operational' OR w.length_m IS NULL OR w.length_m>='Infinity'::numeric OR w.length_m<greatest(r.takeoff_limit_m,r.landing_limit_m)
 THEN RETURN jsonb_build_object('ready',false,'status','storage_dual_use_runway_unverified');END IF;
 RETURN jsonb_build_object('ready',true,'status','storage_dual_use_runway_ready','review',to_jsonb(r),'runway',to_jsonb(w));
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_dual_use_runway_snapshot_v1(text) FROM PUBLIC,anon,authenticated,service_role;

ALTER FUNCTION airlinerra_game.storage_facility_readiness_snapshot_v1(text) RENAME TO storage_facility_service_readiness_snapshot_v1;
CREATE FUNCTION airlinerra_game.storage_facility_readiness_snapshot_v1(p_airport text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE j jsonb;s jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 j:=airlinerra_game.storage_facility_service_readiness_snapshot_v1(p_airport);
 IF j->>'ready' IS DISTINCT FROM 'true' OR j#>>'{candidate,scope}' IS DISTINCT FROM 'existing_commercial' THEN RETURN j;END IF;
 s:=airlinerra_game.storage_dual_use_runway_snapshot_v1(p_airport);
 IF s->>'ready' IS DISTINCT FROM 'true' THEN RETURN s;END IF;
 RETURN j||jsonb_build_object('dualUseRunway',s);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_facility_readiness_snapshot_v1(text) FROM PUBLIC,anon,authenticated,service_role;

ALTER FUNCTION airlinerra_game.aircraft_storage_leg_airport_screen_v1(text,bigint,text,timestamptz,boolean) RENAME TO aircraft_storage_service_leg_airport_screen_v1;
CREATE FUNCTION airlinerra_game.aircraft_storage_leg_airport_screen_v1(p_airport text,p_configuration bigint,p_operation text,p_at timestamptz,p_storage_endpoint boolean)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE j jsonb;s jsonb;required_m numeric;limit_m numeric;span_m numeric;engines integer;identity_count integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 j:=airlinerra_game.aircraft_storage_service_leg_airport_screen_v1(p_airport,p_configuration,p_operation,p_at,p_storage_endpoint);
 IF j->>'passed' IS DISTINCT FROM 'true' OR NOT coalesce(p_storage_endpoint,false) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=p_airport AND admission_scope='existing_commercial') THEN RETURN j;END IF;
 s:=airlinerra_game.storage_dual_use_runway_snapshot_v1(p_airport);
 IF s->>'ready' IS DISTINCT FROM 'true' THEN RETURN s||jsonb_build_object('passed',false);END IF;
 required_m:=(j#>>'{universal,requiredGameRunwayLengthM}')::numeric;
 limit_m:=(s#>>ARRAY['review',CASE WHEN p_operation='departure' THEN 'takeoff_limit_m' ELSE 'landing_limit_m' END])::numeric;
 IF j#>>'{universal,selectedRunwaySourceId}' IS DISTINCT FROM s#>>'{review,source_runway_id}'
 OR j#>>'{universal,runwayLengthEvidence}' IS DISTINCT FROM 'FULL_WEIGHT_GAME_REFERENCE'
 OR required_m IS NULL OR required_m<=0 OR required_m>='Infinity'::numeric OR limit_m IS NULL OR required_m>limit_m THEN
 RETURN jsonb_build_object('passed',false,'status','storage_dual_use_runway_limit_blocked','requiredRunwayM',required_m,'limitM',limit_m);END IF;
 -- Proposed conservative Tarbes storage-only shoulder policy. Do not
 -- infer real-world prohibition or change ordinary commercial operations.
 IF p_airport='OURAIRPORTS:4073' THEN
  SELECT count(*),min(c.wingspan_m),min(e.representative_engine_count)
  INTO identity_count,span_m,engines
  FROM airlinerra.aircraft_catalog_configuration_inventory c
  JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 e USING(configuration_id)
  WHERE c.configuration_id=p_configuration;
  IF identity_count<>1 OR span_m IS NULL OR span_m<=0 OR span_m>='Infinity'::numeric OR engines IS NULL OR engines<=0 THEN
   RETURN jsonb_build_object('passed',false,'status','storage_tarbes_aircraft_dimensions_unverified');END IF;
  IF span_m>52 OR (engines>=4 AND span_m>36) THEN
   RETURN jsonb_build_object('passed',false,'status','storage_tarbes_shoulder_review_required','wingspanM',span_m,'engineCount',engines);END IF;
 END IF;
 RETURN j||jsonb_build_object('storageRunwayLimitM',limit_m,'storageRunwayReviewReference',s#>>'{review,evidence_reference}');
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_leg_airport_screen_v1(text,bigint,text,timestamptz,boolean) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
