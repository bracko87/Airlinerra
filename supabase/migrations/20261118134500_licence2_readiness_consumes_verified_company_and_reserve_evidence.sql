-- Use independently reviewed company game-day and financial reserve evidence in Licence 2 readiness.
-- Never infer game age from account timestamp or operating reserves from cash alone.
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_application_readiness_v1(p_airline uuid, p_market text, p_level smallint DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare
 a record; policy record; tier record; cert record; clock_row record; evidence record;
 v_delivered int; v_incidents int; v_safety int; v_age int;
 v_home_iso text; v_home_market text;
 v_issues text[]:=array[]::text[];
begin
 if p_airline is null or p_market not in ('L2-EU','L2-US','L2-UK','L2-JP')
 or p_level is null or p_level not between 1 and 4
 then return jsonb_build_object('status','INVALID_REQUEST','eligible',false);end if;
 select * into a from airlinerra_game.airlines
 where id=p_airline and world_id=1;
 if not found then return jsonb_build_object('status','AIRLINE_NOT_FOUND','eligible',false);end if;
 select * into policy from airlinerra_game.licence2_market_policy_v1 where market_code=p_market;
 select * into tier from airlinerra_game.licence2_market_levels_v1
 where market_code=p_market and level=p_level;
 if policy.market_code is null or tier.level is null or tier.quota_approved is distinct from true
 then v_issues:=array_append(v_issues,'MARKET_LEVEL_RULES_NOT_FINAL');end if;
 if policy.issuance_enabled is distinct from true
 then v_issues:=array_append(v_issues,'APPLICATION_ISSUANCE_NOT_RELEASED');end if;
 select * into clock_row from airlinerra_game.holding_world_clock_v1
 where world_id=1 and clock_source='authoritative_game_engine';
 if clock_row.confirmed_game_date is null
 then v_issues:=array_append(v_issues,'AUTHORITATIVE_GAME_DATE_MISSING');end if;
 select country_iso into v_home_iso
 from airlinerra_game.airport_unified_operations_v1
 where world_id=1 and airport_key=a.home_airport_key;
 v_home_market:=airlinerra_game.licence2_country_market_v1(v_home_iso);
 if v_home_iso is null then v_issues:=array_append(v_issues,'REGISTERED_HOME_COUNTRY_NOT_VERIFIED');
 elsif v_home_market=p_market then v_issues:=array_append(v_issues,'HOME_MARKET_DOES_NOT_REQUIRE_L2');end if;
 -- The game registration day must have an independently verified receipt.
 -- A calendar created_at timestamp is insufficient for licence maturity.
 select * into evidence from airlinerra_game.licence2_airline_verified_evidence_readiness_v1
 where world_id=1 and airline_id=p_airline;
 v_age:=evidence.verified_company_game_days;
 if v_age is null then
   v_issues:=array_append(v_issues,'COMPANY_90_GAME_DAY_AGE_NOT_VERIFIED');
 elsif v_age<90 then
   v_issues:=array_append(v_issues,'COMPANY_YOUNGER_THAN_90_GAME_DAYS');
 end if;
 select * into cert from airlinerra_game.section9_aoc_certificates_v1
 where world_id=1 and airline_id=p_airline
 and status='active'
 and issued_game_day<=clock_row.confirmed_game_date
 and expires_game_day>clock_row.confirmed_game_date
 order by issued_game_day desc limit 1;
 if cert.certificate_id is null
 then v_issues:=array_append(v_issues,'ACTIVE_OWN_AOC_NOT_VERIFIED');end if;
 select count(*)::int into v_delivered
 from airlinerra_game.airline_aircraft_inventory
 where airline_id=p_airline and fleet_status='in_service' and ownership_type in ('owned','leased');
 if v_delivered<1 then v_issues:=array_append(v_issues,'NO_IN_SERVICE_OWNED_OR_LEASED_AIRCRAFT');end if;
 select count(*)::int,100-coalesce(sum(penalty_points),0)::int
 into v_incidents,v_safety
 from airlinerra_game.section9_aoc_safety_incidents_v1
 where airline_id=p_airline and world_id=1 and resolved_game_day is null;
 if cert.certificate_id is null then v_safety:=null;
 elsif v_safety<80 then v_issues:=array_append(v_issues,'SAFETY_RATING_BELOW_80');end if;
 -- Cash alone is insufficient: require a fresh, independently reviewed
 -- daily operating-cost projection and a verified 90-day reserve threshold.
 if evidence.ninety_day_cash_reserve_passes is distinct from true then
   v_issues:=array_append(v_issues,case
    when evidence.verified_90_day_reserve_required_usd is null
     then 'NINETY_DAY_OPERATING_COST_RESERVE_NOT_VERIFIED'
    else 'INSUFFICIENT_VERIFIED_NINETY_DAY_OPERATING_RESERVE' end);
 end if;
 v_issues:=array_append(v_issues,'CRITICAL_MAINTENANCE_CLEARANCE_NOT_VERIFIED');
 return jsonb_build_object(
  'status','READ_ONLY_PREAPPLICATION_ASSESSMENT',
  'eligible',cardinality(v_issues)=0,
  'airlineId',p_airline,'market',p_market,'requestedLevel',p_level,
  'maximumDirectedRoutes',tier.max_active_directed_routes,
  'maximumAirportCategory',tier.max_category,
  'activeAircraftCount',v_delivered,'safetyScoreIfAocVerified',v_safety,
  'verifiedCompanyGameDays',v_age,
  'verified90DayReserveRequiredUsd',evidence.verified_90_day_reserve_required_usd,
  'ninetyDayCashReservePasses',evidence.ninety_day_cash_reserve_passes,
  'applicationOpen',coalesce(policy.issuance_enabled,false),
  'issues',to_jsonb(v_issues),
  'rightsGranted',false,'feeCharged',false,'flightsActivated',false);
end $function$
;
