-- Licence 3 Charter / VIP Operations: read-only, release-locked eligibility foundation.
-- Rules: owned charter/VIP subsidiary, own active AOC, one in-service cargo/combi aircraft,
-- $40,000 game fee at successful issuance, 3 verified game days processing.
-- Worldwide charter/VIP SERVICE scope, never automatic airport, slot, traffic or flight rights.
UPDATE airlinerra_game.business_permission_catalog_v1
 SET game_fee_usd=40000, processing_game_days=3,
     purpose='Company-wide Airlinerra game approval for ordinary charter or VIP passenger services worldwide, subject to independent route, airport, safety and AOC checks.',
     requirements='Registered charter/VIP airline subsidiary of an owned holding; company-specific active AOC; at least one in-service passenger or combi aircraft owned or leased by this company; available company funds for $40,000 game licence fee.',
     application_guidance='Application is free. After 3 verified game days, approve only if requirements still pass and charge $40,000 to this charter/VIP airline exactly once together with issuance. The licence does not grant foreign-network route rights, airport slots or actual flight activation.',
     updated_at=clock_timestamp()
 WHERE permission_code='CHARTER_VIP_SCOPE' AND enabled_in_game=false;
CREATE OR REPLACE FUNCTION airlinerra_game.licence4_charter_readiness_v1(p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
  a record; company record; day_now date;
  aircraft_count integer:=0; problems text[]:=array[]::text[];
  valid_aoc boolean:=false;fee numeric:=40000;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
   RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='CHARTER_VIP_LICENCE4_TRUSTED_READ_ONLY';
 END IF;
 IF p_airline IS NULL THEN
   RETURN jsonb_build_object('status','AIRLINE_REQUIRED','eligible',false,'canApply',false,'feeUsd',fee,'processingGameDays',3,'issued',false,'charged',false);
 END IF;
 SELECT id,owner_player_id,world_id,cash_usd INTO a
 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('status','AIRLINE_NOT_FOUND','eligible',false,'canApply',false,'feeUsd',fee,'processingGameDays',3,'issued',false,'charged',false);
 END IF;
 SELECT o.* INTO company FROM airlinerra_game.section9_aoc_operating_companies_v1 o
 WHERE o.airline_id=p_airline AND o.world_id=1;
 IF NOT FOUND OR company.company_source IS DISTINCT FROM 'subsidiary'
    OR company.business_kind NOT IN ('charter','vip')
    OR company.holding_id IS NULL OR company.subsidiary_id IS NULL
    OR NOT EXISTS (
      SELECT 1 FROM airlinerra_game.holding_groups_v1 h
      JOIN airlinerra_game.holding_subsidiaries_v1 s
      ON s.holding_id=h.id
      WHERE h.id=company.holding_id AND s.id=company.subsidiary_id
        AND h.world_id=1 AND s.world_id=1
        AND h.owner_player_id=a.owner_player_id
        AND s.company_kind='charter_airline' AND s.formation_state='registered'
    )
 THEN problems:=array_append(problems,'VERIFIED_HOLDING_CHARTER_SUBSIDIARY_REQUIRED');END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN problems:=array_append(problems,'VERIFIED_GAME_DAY_REQUIRED');END IF;
 SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 c
   WHERE c.airline_id=p_airline AND c.world_id=1 AND c.status='active'
     AND day_now IS NOT NULL AND c.issued_game_day<=day_now AND c.expires_game_day>day_now
 ) INTO valid_aoc;
 IF NOT valid_aoc THEN problems:=array_append(problems,'ACTIVE_OWN_AOC_REQUIRED');END IF;
 SELECT count(*) INTO aircraft_count
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 m
   ON m.configuration_id=f.configuration_id
 WHERE f.airline_id=p_airline AND f.fleet_status='in_service'
  AND m.use_type IN ('passenger','combi');
 IF aircraft_count<1 THEN problems:=array_append(problems,'ONE_IN_SERVICE_PASSENGER_AIRCRAFT_REQUIRED');END IF;
 IF a.cash_usd<fee THEN problems:=array_append(problems,'INSUFFICIENT_COMPANY_CASH_FOR_FEE');END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra_game.business_permission_catalog_v1
  WHERE permission_code='CHARTER_VIP_SCOPE' AND enabled_in_game=true)
 THEN problems:=array_append(problems,'CHARTER_VIP_LICENCE_ISSUANCE_NOT_RELEASED');END IF;
 RETURN jsonb_build_object(
 'status','LICENCE4_READ_ONLY_READINESS',
 'airlineId',p_airline,'gameDay',day_now,
 'eligible',cardinality(problems)=0,'canApply',false,
 'issues',to_jsonb(problems),
 'inServiceCharterAircraftCount',aircraft_count,'ownAocValid',valid_aoc,
 'feeUsd',fee,'processingGameDays',3,'applicationFeeUsd',0,
 'scope','CHARTER_VIP_SERVICE_ONLY',
 'worldwideRoutesGranted',false,'flightActivated',false,
 'issued',false,'charged',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence4_charter_readiness_v1(uuid)
FROM public,anon,authenticated,service_role;
