-- Independently enforce aircraft grace for whichever licence has been released.
CREATE OR REPLACE FUNCTION airlinerra_game.licence34_review_aircraft_grace_v1(p_limit integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE d date; row_data record; first_day date;
 count_checked integer:=0;count_revoked integer:=0; count_recovered integer:=0;
 own_count integer; old_state record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE34_PRIVATE_REVIEW_ONLY';
 END IF;
 IF p_limit IS NULL OR p_limit<1 OR p_limit>1000 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE34_INVALID_REVIEW_LIMIT';
 END IF;
 -- Each licence is independently enabled. One locked licence must not
 -- suppress monitoring of the other licence after it is independently released.
 IF NOT EXISTS (SELECT 1 FROM airlinerra_game.licence3_cargo_release_v1
                WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified)
 AND NOT EXISTS (SELECT 1 FROM airlinerra_game.licence4_charter_release_v1
                WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified)
 THEN RETURN jsonb_build_object('status','NOT_RELEASED','checked',0,'revoked',0);END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NULL OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
   WHERE world_id=1 AND game_date=d)
 THEN RETURN jsonb_build_object('status','GAME_CLOCK_UNVERIFIED','checked',0,'revoked',0);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10034)
 THEN RETURN jsonb_build_object('status','BUSY','checked',0,'revoked',0);END IF;
 FOR row_data IN
  SELECT airline_id,'CARGO_OPERATIONS_SCOPE'::text licence_code
  FROM airlinerra_game.licence3_cargo_approvals_v1
  UNION ALL
  SELECT airline_id,'CHARTER_VIP_SCOPE'::text licence_code
  FROM airlinerra_game.licence4_charter_approvals_v1
  ORDER BY airline_id,licence_code LIMIT p_limit
 LOOP
  IF row_data.licence_code='CARGO_OPERATIONS_SCOPE' AND NOT EXISTS(
   SELECT 1 FROM airlinerra_game.licence3_cargo_release_v1
   WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified)
   OR row_data.licence_code='CHARTER_VIP_SCOPE' AND NOT EXISTS(
   SELECT 1 FROM airlinerra_game.licence4_charter_release_v1
   WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified)
  THEN CONTINUE;END IF;
  INSERT INTO airlinerra_game.licence34_company_compliance_v1(airline_id,licence_code)
  VALUES(row_data.airline_id,row_data.licence_code) ON CONFLICT DO NOTHING;
  SELECT * INTO old_state FROM airlinerra_game.licence34_company_compliance_v1
   WHERE airline_id=row_data.airline_id AND licence_code=row_data.licence_code FOR UPDATE;
  IF old_state.revoked_game_day IS NOT NULL THEN CONTINUE;END IF;
  -- A stale or backwards clock cannot shorten or reset the continuous outage.
  IF old_state.last_checked_game_day>d THEN CONTINUE;END IF;
  SELECT count(*) INTO own_count FROM airlinerra_game.airline_aircraft_inventory f
  JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 m
    ON m.configuration_id=f.configuration_id
  WHERE f.airline_id=row_data.airline_id AND f.fleet_status='in_service'
    AND ((row_data.licence_code='CARGO_OPERATIONS_SCOPE' AND m.use_type IN('cargo','combi'))
      OR (row_data.licence_code='CHARTER_VIP_SCOPE' AND m.use_type IN('passenger','combi')));
  count_checked:=count_checked+1;
  IF own_count>0 THEN
   IF old_state.no_aircraft_since_game_day IS NOT NULL THEN
     count_recovered:=count_recovered+1;END IF;
   UPDATE airlinerra_game.licence34_company_compliance_v1
   SET no_aircraft_since_game_day=NULL,last_checked_game_day=d,updated_at=clock_timestamp()
   WHERE airline_id=row_data.airline_id AND licence_code=row_data.licence_code;
   CONTINUE;
  END IF;
  first_day:=coalesce(old_state.no_aircraft_since_game_day,d);
  IF d>first_day+90 THEN
   UPDATE airlinerra_game.licence34_company_compliance_v1
   SET no_aircraft_since_game_day=first_day,last_checked_game_day=d,revoked_game_day=d,
    revocation_reason='NO_OPERATIONAL_AIRCRAFT_OVER_90_GAME_DAYS',
    updated_at=clock_timestamp()
   WHERE airline_id=row_data.airline_id AND licence_code=row_data.licence_code
    AND revoked_game_day IS NULL;
   INSERT INTO airlinerra_game.licence34_revocation_history_v1
   (airline_id,licence_code,application_id,approval_reference,game_day,reason)
   SELECT row_data.airline_id,row_data.licence_code,l.application_id,l.approval_reference,d,
      'NO_OPERATIONAL_AIRCRAFT_OVER_90_GAME_DAYS'
   FROM (
    SELECT application_id,approval_reference FROM airlinerra_game.licence3_cargo_approvals_v1
    WHERE airline_id=row_data.airline_id AND row_data.licence_code='CARGO_OPERATIONS_SCOPE'
    UNION ALL
    SELECT application_id,approval_reference FROM airlinerra_game.licence4_charter_approvals_v1
    WHERE airline_id=row_data.airline_id AND row_data.licence_code='CHARTER_VIP_SCOPE'
   ) l ON CONFLICT(licence_code,application_id) DO NOTHING;
   count_revoked:=count_revoked+1;
  ELSE
   UPDATE airlinerra_game.licence34_company_compliance_v1
   SET no_aircraft_since_game_day=first_day,last_checked_game_day=d,updated_at=clock_timestamp()
   WHERE airline_id=row_data.airline_id AND licence_code=row_data.licence_code;
  END IF;
 END LOOP;
 RETURN jsonb_build_object('status','REVIEWED','checked',count_checked,
 'revoked',count_revoked,'recovered',count_recovered,'gameDay',d,'flightActivated',false);
END $fn$;
