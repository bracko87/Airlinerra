-- Licence 5 — Dangerous Goods Transport Approval, staging only.
-- This GAME licence does not grant blanket commodity, airport, aircraft or regulatory permissions.
UPDATE airlinerra_game.business_permission_catalog_v1
 SET game_fee_usd=60000,processing_game_days=5,
 purpose='Company-specific game approval foundation for dangerous-goods cargo; requires separate commodity-class, aircraft, crew, ground handling, airport, routing and state authority approvals.',
 requirements='Registered cargo subsidiary with own active AOC, active Cargo Licence 3, safety rating at least 70, in-service cargo-capable aircraft, and company funds for the $60,000 approval charge.',
 application_guidance='Free submission; after five verified game days and re-verification of prerequisites, charge $60,000 once with approval. This licence alone DOES NOT authorize any dangerous-goods shipment or class. Commodity-specific game authorizations are separate and presently not enabled.',
 updated_at=clock_timestamp()
 WHERE permission_code='DANGEROUS_GOODS' AND enabled_in_game=false;
CREATE OR REPLACE FUNCTION airlinerra_game.licence5_dg_readiness_v1(p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
  a record; company record; day_now date;
  aircraft_count integer:=0; problems text[]:=array[]::text[];
  valid_aoc boolean:=false;fee numeric:=60000;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
   RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='DG_LICENCE5_TRUSTED_READ_ONLY';
 END IF;
 IF p_airline IS NULL THEN
   RETURN jsonb_build_object('status','AIRLINE_REQUIRED','eligible',false,'canApply',false,'feeUsd',fee,'processingGameDays',5,'issued',false,'charged',false);
 END IF;
 SELECT id,owner_player_id,world_id,cash_usd INTO a
 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('status','AIRLINE_NOT_FOUND','eligible',false,'canApply',false,'feeUsd',fee,'processingGameDays',5,'issued',false,'charged',false);
 END IF;
 SELECT o.* INTO company FROM airlinerra_game.section9_aoc_operating_companies_v1 o
 WHERE o.airline_id=p_airline AND o.world_id=1;
 IF NOT FOUND OR company.company_source IS DISTINCT FROM 'subsidiary'
    OR company.business_kind IS DISTINCT FROM 'cargo'
    OR company.holding_id IS NULL OR company.subsidiary_id IS NULL
    OR NOT EXISTS (
      SELECT 1 FROM airlinerra_game.holding_groups_v1 h
      JOIN airlinerra_game.holding_subsidiaries_v1 s
      ON s.holding_id=h.id
      WHERE h.id=company.holding_id AND s.id=company.subsidiary_id
        AND h.world_id=1 AND s.world_id=1
        AND h.owner_player_id=a.owner_player_id
        AND s.company_kind='cargo_airline'
    )
 THEN problems:=array_append(problems,'VERIFIED_HOLDING_CARGO_SUBSIDIARY_REQUIRED');END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN problems:=array_append(problems,'VERIFIED_GAME_DAY_REQUIRED');END IF;
 SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 c
   WHERE c.airline_id=p_airline AND c.world_id=1 AND c.status='active'
     AND day_now IS NOT NULL AND c.issued_game_day<=day_now AND c.expires_game_day>day_now
 ) INTO valid_aoc;
 IF NOT valid_aoc THEN problems:=array_append(problems,'ACTIVE_OWN_AOC_REQUIRED');END IF;
 IF (airlinerra_game.section9_aoc_safety_score_v1(p_airline,day_now)->>'rating')::integer<70
 THEN problems:=array_append(problems,'SAFETY_BELOW_70_FOR_LICENCE5');END IF;
 IF (airlinerra_game.licence3_cargo_flight_scope_v1(p_airline)->>'authorized') IS DISTINCT FROM 'true'
 THEN problems:=array_append(problems,'VALID_CARGO_LICENCE3_REQUIRED');END IF;
 SELECT count(*) INTO aircraft_count
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 m
   ON m.configuration_id=f.configuration_id
 WHERE f.airline_id=p_airline AND f.fleet_status='in_service' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 job WHERE job.aircraft_inventory_id=f.id AND job.airline_id=p_airline AND job.status IN ('in_progress','payment_required'))
  AND m.use_type IN ('cargo','combi');
 IF aircraft_count<1 THEN problems:=array_append(problems,'ONE_IN_SERVICE_CARGO_AIRCRAFT_REQUIRED');END IF;
 IF a.cash_usd<fee THEN problems:=array_append(problems,'INSUFFICIENT_COMPANY_CASH_FOR_FEE');END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra_game.business_permission_catalog_v1
  WHERE permission_code='DANGEROUS_GOODS' AND enabled_in_game=true)
 THEN problems:=array_append(problems,'DANGEROUS_GOODS_LICENCE_ISSUANCE_NOT_RELEASED');END IF;
 RETURN jsonb_build_object(
 'status','LICENCE5_READ_ONLY_READINESS',
 'airlineId',p_airline,'gameDay',day_now,
 'eligible',cardinality(problems)=0,'canApply',false,
 'issues',to_jsonb(problems),
 'inServiceDgAircraftCount',aircraft_count,'ownAocValid',valid_aoc,
 'feeUsd',fee,'processingGameDays',5,'applicationFeeUsd',0,
 'scope','DANGEROUS_GOODS_ADDITIONAL_APPROVAL_ONLY',
 'worldwideRoutesGranted',false,'flightActivated',false,
 'issued',false,'charged',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence5_dg_readiness_v1(uuid)
FROM public,anon,authenticated,service_role;
