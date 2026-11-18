-- Licence 2 route-rights classification (private, read-only).
-- Classifies home-market L1 vs foreign network L2 using unified airport countries.
-- Does not grant a permit, create a base, reserve a route, or activate a flight.
create or replace function airlinerra_game.licence2_country_market_v1(p_iso text)
returns text language sql immutable set search_path='pg_catalog' as $$
 select case
 when upper(coalesce(p_iso,''))=any(array[
 'AT','BE','BG','HR','CY','CZ','DK','EE','FI','FR','DE','GR','HU',
 'IE','IT','LV','LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','SE',
 'IS','LI','NO']) then 'L2-EU'
 when upper(coalesce(p_iso,''))='US' then 'L2-US'
 when upper(coalesce(p_iso,''))='GB' then 'L2-UK'
 when upper(coalesce(p_iso,''))='JP' then 'L2-JP'
 else null end
$$;
create or replace function airlinerra_game.licence2_foreign_route_preview_v1(
 p_airline uuid,p_origin text,p_destination text,p_market text default null)
returns jsonb language plpgsql stable
set search_path='airlinerra_game','pg_catalog' as $$
declare
 v_company record;
 v_origin record;
 v_destination record;
 v_home text;
 v_origin_market text;
 v_destination_market text;
 v_target_market text;
 v_home_is_eea boolean;
 v_is_home_origin boolean;
 v_is_home_destination boolean;
 v_level record;
 v_policy record;
 v_permit record;
 v_category_rank int;
 v_allowed_rank int;
 v_base_active boolean;
begin
 if p_airline is null or p_origin is null or p_destination is null
   or p_origin=p_destination or
   (p_market is not null and p_market not in ('L2-EU','L2-US','L2-UK','L2-JP'))
 then return jsonb_build_object('decision','INVALID_ROUTE','canActivateFlights',false);end if;
 select a.world_id,a.id,a.home_airport_key,h.country_iso as home_country
 into v_company from airlinerra_game.airlines a
 left join airlinerra_game.airport_unified_operations_v1 h
 on h.world_id=a.world_id and h.airport_key=a.home_airport_key
 where a.id=p_airline and a.world_id=1;
 if not found or v_company.home_country is null
 then return jsonb_build_object('decision','AIRLINE_HOME_COUNTRY_UNVERIFIED','canActivateFlights',false);end if;
 select airport_key,country_iso,game_category,dispatch_eligible_by_airport_admission
 into v_origin from airlinerra_game.airport_unified_operations_v1
 where world_id=1 and airport_key=p_origin;
 if not found then return jsonb_build_object('decision','ORIGIN_NOT_IN_UNIFIED_CATALOGUE','canActivateFlights',false);end if;
 select airport_key,country_iso,game_category,dispatch_eligible_by_airport_admission
 into v_destination from airlinerra_game.airport_unified_operations_v1
 where world_id=1 and airport_key=p_destination;
 if not found then return jsonb_build_object('decision','DESTINATION_NOT_IN_UNIFIED_CATALOGUE','canActivateFlights',false);end if;
 if v_origin.dispatch_eligible_by_airport_admission is distinct from true
    or v_destination.dispatch_eligible_by_airport_admission is distinct from true
 then return jsonb_build_object('decision','AIRPORT_ADMISSION_NOT_PASSED','canActivateFlights',false);end if;
 v_home:=airlinerra_game.licence2_country_market_v1(v_company.home_country);
 v_origin_market:=airlinerra_game.licence2_country_market_v1(v_origin.country_iso);
 v_destination_market:=airlinerra_game.licence2_country_market_v1(v_destination.country_iso);
 v_home_is_eea:=v_home='L2-EU';
 v_is_home_origin:=v_origin.country_iso=v_company.home_country
  or (v_home_is_eea and v_origin_market='L2-EU');
 v_is_home_destination:=v_destination.country_iso=v_company.home_country
  or (v_home_is_eea and v_destination_market='L2-EU');
 if v_is_home_origin or v_is_home_destination
 then return jsonb_build_object('decision','L1_HOME_MARKET_ROUTE',
 'requiresLicence2',false,'canActivateFlights',false,
 'note','Licence 1 market classification only; actual AOC and flight gates remain separate');
 end if;
 if p_market is not null then v_target_market:=p_market;
 elsif v_origin_market is not null and v_origin_market=v_destination_market
 then v_target_market:=v_origin_market;
 elsif v_origin_market is not null and v_destination_market is null
 then v_target_market:=v_origin_market;
 elsif v_destination_market is not null and v_origin_market is null
 then v_target_market:=v_destination_market;
 else return jsonb_build_object('decision','L2_TARGET_MARKET_SELECTION_REQUIRED_OR_UNAVAILABLE',
 'canActivateFlights',false,'requiresLicence2',true);end if;
 if v_target_market is null or v_target_market not in
 (coalesce(v_origin_market,''),coalesce(v_destination_market,''))
 then return jsonb_build_object('decision','L2_MARKET_NOT_ON_ROUTE',
 'canActivateFlights',false,'requiresLicence2',true);end if;
 if v_target_market=v_home
 then return jsonb_build_object('decision','L2_CANNOT_ISSUE_FOR_HOME_MARKET',
 'canActivateFlights',false,'requiresLicence2',true);end if;
 select * into v_policy from airlinerra_game.licence2_market_policy_v1
 where market_code=v_target_market;
 select * into v_permit from airlinerra_game.licence2_airline_market_permits_v1
 where world_id=1 and airline_id=p_airline and market_code=v_target_market;
 if found then
   select * into v_level from airlinerra_game.licence2_market_levels_v1
   where market_code=v_target_market and level=v_permit.level;
 end if;
 v_category_rank:=case when v_origin_market=v_target_market then
 array_position(array['Local','Regional','Medium','Large','Major Hub','Mega Hub'],v_origin.game_category)
 else array_position(array['Local','Regional','Medium','Large','Major Hub','Mega Hub'],v_destination.game_category) end;
 v_allowed_rank:=array_position(array['Local','Regional','Medium','Large','Major Hub','Mega Hub'],v_level.max_category);
 select exists(select 1 from airlinerra_game.airport_offices o
 where o.world_id=1 and o.airline_id=p_airline and o.office_type='hub'
   and o.office_status='active'
   and o.airport_key in (p_origin,p_destination)
   and o.airport_key in (
    select airport_key from airlinerra_game.airport_unified_operations_v1
    where world_id=1 and
     airlinerra_game.licence2_country_market_v1(country_iso)=v_target_market))
 into v_base_active;
 return jsonb_build_object(
  'decision',case
   when coalesce(v_policy.issuance_enabled,false)=false then 'L2_ISSUANCE_NOT_RELEASED'
   when v_permit.status is distinct from 'approved' then 'L2_MARKET_PERMIT_NOT_APPROVED'
   when v_level.quota_approved is distinct from true then 'L2_MARKET_LEVEL_RULES_NOT_APPROVED'
   when v_category_rank is null or v_allowed_rank is null or v_category_rank>v_allowed_rank then 'L2_AIRPORT_CATEGORY_ABOVE_LEVEL'
   when not v_base_active then 'L2_ACTIVE_FOREIGN_HUB_NOT_VERIFIED'
   when coalesce(v_policy.enforcement_enabled,false)=false then 'L2_ENFORCEMENT_NOT_RELEASED'
   else 'L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK'
  end,
  'market',v_target_market,'level',v_permit.level,
  'directedRouteLimit',v_level.max_active_directed_routes,
  'maxAirportCategory',v_level.max_category,
  'requiresLicence2',true,'canActivateFlights',false,
  'hubVerified',v_base_active,
  'quotaNote','Route-count ledger and atomic quota allocation required before activation');
end $$;
revoke all on function airlinerra_game.licence2_country_market_v1(text) from public,anon,authenticated;
revoke all on function airlinerra_game.licence2_foreign_route_preview_v1(uuid,text,text,text) from public,anon,authenticated;
