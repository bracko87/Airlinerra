-- ROLLBACK-ONLY REVIEW. Install after operational screen and final admission
-- definitions. No real airport policy is seeded. No permission is granted.
BEGIN;
CREATE TABLE airlinerra_game.storage_service_policy_v1(
 world_id smallint NOT NULL CHECK(world_id=1),airport_key text NOT NULL,
 time_basis text NOT NULL CHECK(time_basis IN('UTC','airport_local')),
 valid_from date NOT NULL,valid_until date NOT NULL CHECK(valid_until>valid_from),
 access_mode text NOT NULL CHECK(access_mode IN('routine_game_access','prior_permission_required')),
 review_reference text NOT NULL CHECK(btrim(review_reference)<>''),
 reviewed_at timestamptz NOT NULL,
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key)
);
CREATE TABLE airlinerra_game.storage_service_windows_v1(
 world_id smallint NOT NULL,airport_key text NOT NULL,
 operation text NOT NULL CHECK(operation IN('departure','arrival')),
 weekday smallint NOT NULL CHECK(weekday BETWEEN 1 AND 7),
 valid_from date NOT NULL,valid_until date NOT NULL CHECK(valid_until>valid_from),
 open_minute integer NOT NULL CHECK(open_minute BETWEEN 0 AND 1439),
 close_minute integer NOT NULL CHECK(close_minute BETWEEN 1 AND 1440 AND close_minute>open_minute),
 PRIMARY KEY(world_id,airport_key,operation,weekday,valid_from,valid_until,open_minute,close_minute),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.storage_service_policy_v1(world_id,airport_key)
);
CREATE TABLE airlinerra_game.storage_service_closures_v1(
 world_id smallint NOT NULL,airport_key text NOT NULL,closed_date date NOT NULL,
 reason text NOT NULL CHECK(btrim(reason)<>''),
 PRIMARY KEY(world_id,airport_key,closed_date),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.storage_service_policy_v1(world_id,airport_key)
);
ALTER TABLE airlinerra_game.storage_service_policy_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.storage_service_windows_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.storage_service_closures_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_service_policy_v1,airlinerra_game.storage_service_windows_v1,airlinerra_game.storage_service_closures_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.storage_service_policy_snapshot_v1(p_airport text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE p record; tz text; now_utc timestamptz; day_key date; windows jsonb; closures jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT x.* INTO p FROM airlinerra_game.storage_service_policy_v1 x JOIN airlinerra_game.aircraft_storage_facilities_v1 f USING(world_id,airport_key)
 WHERE x.world_id=1 AND x.airport_key=p_airport AND f.admission_scope='relocation_only';
 IF NOT FOUND THEN RETURN jsonb_build_object('ready',false,'status','storage_service_policy_missing');END IF;
 SELECT CASE WHEN p.time_basis='UTC' THEN 'UTC' ELSE a.timezone_iana END INTO tz FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 a WHERE a.world_id=1 AND a.airport_key=p_airport;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR NOT isfinite(now_utc) OR p.reviewed_at>now_utc OR tz IS NULL OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=tz) THEN RETURN jsonb_build_object('ready',false,'status','storage_service_policy_unverified');END IF;
 day_key:=(now_utc AT TIME ZONE tz)::date;
 IF day_key<p.valid_from OR day_key>=p.valid_until THEN RETURN jsonb_build_object('ready',false,'status','storage_service_policy_expired');END IF;
 IF p.access_mode<>'routine_game_access' THEN RETURN jsonb_build_object('ready',false,'status','storage_service_prior_permission_required');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.storage_service_windows_v1 w WHERE w.world_id=1 AND w.airport_key=p_airport AND (w.valid_from<p.valid_from OR w.valid_until>p.valid_until))
 OR EXISTS(SELECT 1 FROM airlinerra_game.storage_service_closures_v1 c WHERE c.world_id=1 AND c.airport_key=p_airport AND (c.closed_date<p.valid_from OR c.closed_date>=p.valid_until))
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_service_windows_v1 w WHERE w.world_id=1 AND w.airport_key=p_airport AND w.operation='departure' AND w.valid_until>day_key)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_service_windows_v1 w WHERE w.world_id=1 AND w.airport_key=p_airport AND w.operation='arrival' AND w.valid_until>day_key)
 THEN RETURN jsonb_build_object('ready',false,'status','storage_service_windows_incomplete');END IF;
 SELECT jsonb_agg(to_jsonb(w) ORDER BY operation,weekday,valid_from,valid_until,open_minute,close_minute) INTO windows FROM airlinerra_game.storage_service_windows_v1 w WHERE world_id=1 AND airport_key=p_airport;
 SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY closed_date),'[]'::jsonb) INTO closures FROM airlinerra_game.storage_service_closures_v1 c WHERE world_id=1 AND airport_key=p_airport;
 RETURN jsonb_build_object('ready',true,'status','storage_service_policy_ready','timezone',tz,'policy',to_jsonb(p),'windows',windows,'closures',closures);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_service_policy_snapshot_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.storage_service_availability_v1(p_airport text,p_operation text,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE j jsonb; local_at timestamp; day_key date; minute_key numeric;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_operation IS NULL OR p_operation NOT IN('departure','arrival') OR p_at IS NULL OR NOT isfinite(p_at) THEN RETURN jsonb_build_object('passed',false,'status','storage_service_invalid_event');END IF;
 j:=airlinerra_game.storage_service_policy_snapshot_v1(p_airport);
 IF j->>'ready' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status',j->>'status');END IF;
 local_at:=p_at AT TIME ZONE (j->>'timezone');day_key:=local_at::date;
 IF day_key<(j#>>'{policy,valid_from}')::date OR day_key>=(j#>>'{policy,valid_until}')::date THEN RETURN jsonb_build_object('passed',false,'status','storage_service_event_outside_review');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.storage_service_closures_v1 WHERE world_id=1 AND airport_key=p_airport AND closed_date=day_key) THEN RETURN jsonb_build_object('passed',false,'status','storage_service_date_closed');END IF;
 minute_key:=extract(epoch FROM local_at::time)/60;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_service_windows_v1 w WHERE w.world_id=1 AND w.airport_key=p_airport AND w.operation=p_operation AND w.weekday=extract(isodow FROM day_key) AND day_key>=w.valid_from AND day_key<w.valid_until AND minute_key>=w.open_minute AND minute_key<w.close_minute)
 THEN RETURN jsonb_build_object('passed',false,'status','storage_service_outside_hours');END IF;
 RETURN jsonb_build_object('passed',true,'status','storage_service_window_pass','dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_service_availability_v1(text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

-- Keep existing screens intact; add the new policy before granting readiness.
ALTER FUNCTION airlinerra_game.storage_facility_readiness_snapshot_v1(text) RENAME TO storage_facility_base_readiness_snapshot_v1;
CREATE FUNCTION airlinerra_game.storage_facility_readiness_snapshot_v1(p_airport text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE j jsonb;s jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 j:=airlinerra_game.storage_facility_base_readiness_snapshot_v1(p_airport);
 IF j->>'ready' IS DISTINCT FROM 'true' OR j#>>'{candidate,scope}' IS DISTINCT FROM 'relocation_only' THEN RETURN j;END IF;
 s:=airlinerra_game.storage_service_policy_snapshot_v1(p_airport);
 IF s->>'ready' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('ready',false,'status',s->>'status');END IF;
 RETURN j||jsonb_build_object('servicePolicy',s);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_facility_readiness_snapshot_v1(text) FROM PUBLIC,anon,authenticated,service_role;

ALTER FUNCTION airlinerra_game.aircraft_storage_leg_airport_screen_v1(text,bigint,text,timestamptz,boolean) RENAME TO aircraft_storage_base_leg_airport_screen_v1;
CREATE FUNCTION airlinerra_game.aircraft_storage_leg_airport_screen_v1(p_airport text,p_configuration bigint,p_operation text,p_at timestamptz,p_storage_endpoint boolean)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE j jsonb;s jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_storage_endpoint AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=p_airport AND admission_scope='relocation_only') THEN
  s:=airlinerra_game.storage_service_availability_v1(p_airport,p_operation,p_at);
  IF s->>'passed' IS DISTINCT FROM 'true' THEN RETURN s;END IF;
 END IF;
 j:=airlinerra_game.aircraft_storage_base_leg_airport_screen_v1(p_airport,p_configuration,p_operation,p_at,p_storage_endpoint);
 IF s IS NOT NULL THEN RETURN j||jsonb_build_object('serviceAvailability',s);END IF;
 RETURN j;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_leg_airport_screen_v1(text,bigint,text,timestamptz,boolean) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
