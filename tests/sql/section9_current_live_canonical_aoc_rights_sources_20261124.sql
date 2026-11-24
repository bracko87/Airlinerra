-- READ-ONLY snapshot of CURRENT DEPLOYED canonical Airlinerra World 1 AOC,
-- Licence1/2 market classifier and independent operator/traffic source verifiers.
-- Captured 2026-11-24, for disposable PostgreSQL fixture ONLY.
-- Do NOT apply as Supabase migration; recertification/source changes in live
-- deployment are NEWER than some historical repo migrations.
-- No player identities, live certificate records, secrets or HMAC key values.
\set ON_ERROR_STOP on
DO $s$ BEGIN IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres' THEN RAISE EXCEPTION 'LIVE_CANONICAL_AOC_SOURCE_DISPOSABLE_ONLY';END IF;END $s$;
-- SOURCE: section9_aoc_flight_release_readiness_v1
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_flight_release_readiness_v1(p_airline uuid, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare a record; registry record; cert record; issues text[]:=ARRAY[]::text[]; live_day date;
begin
 if p_airline is null or p_game_day is null
 then return jsonb_build_object('status','AOC_INVALID_FLIGHT_SCOPE','authorized',false,
   'issues',jsonb_build_array('AOC_INVALID_FLIGHT_SCOPE'));end if;
 select * into a from airlinerra_game.airlines
 where id=p_airline and world_id=1;
 if not found then return jsonb_build_object('status','AOC_AIRLINE_NOT_FOUND','authorized',false,
   'issues',jsonb_build_array('AOC_AIRLINE_NOT_FOUND'));end if;
 if not exists(select 1 from airlinerra_game.section9_aoc_release_policy_v1 rp
 where rp.world_id=1 and rp.issuance_enabled and rp.safety_events_enabled
 and rp.renewal_enabled and rp.flight_enforcement_enabled)
 then issues:=array_append(issues,'AOC_FLIGHT_ENFORCEMENT_NOT_RELEASED');end if;
 live_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 if live_day is null or live_day is distinct from p_game_day
 then issues:=array_append(issues,'AOC_VERIFIED_GAME_DAY_MISMATCH');end if;
 select * into registry from airlinerra_game.section9_aoc_operating_companies_v1
 where airline_id=p_airline and world_id=1;
 if not found or registry.business_kind not in('passenger','regional','low_cost','cargo','charter','vip')
 then issues:=array_append(issues,'AOC_OPERATING_COMPANY_NOT_VERIFIED');end if;
 select * into cert from airlinerra_game.section9_aoc_certificates_v1
 where airline_id=p_airline and world_id=1;
 if not found or cert.status<>'active' or cert.issued_game_day>p_game_day
 or cert.expires_game_day<=p_game_day
 or cert.expires_game_day is distinct from cert.issued_game_day+365
 then issues:=array_append(issues,'AOC_ACTIVE_CERTIFICATE_NOT_VERIFIED');
 else
  if registry.company_source='original' then
   if cert.initial_issue_source is distinct from 'original_free_registration'
    or cert.initial_issue_application_id is not null
    or cert.initial_issue_ledger_id is not null
    or registry.identity_evidence_reference is distinct from
     'verified-original-airline-registration-v1-'||p_airline::text
   then issues:=array_append(issues,'AOC_ORIGINAL_ISSUE_PROVENANCE_INVALID');end if;
  elsif registry.company_source='subsidiary' then
   if cert.initial_issue_source is distinct from 'subsidiary_paid_application'
    or not exists(
     select 1 from airlinerra_game.section9_game_permission_applications_v1 app
     join airlinerra_game.airline_ledger ledger on ledger.id=app.ledger_entry_id
      and ledger.airline_id=p_airline and ledger.entry_kind='EXPENSE'
      and ledger.amount_usd=-10000
     join airlinerra_game.section9_operator_licence_evidence_v1 ev
      on ev.issued_application_id=app.id and ev.airline_id=p_airline
      and ev.evidence_status='verified'
     where app.id=cert.initial_issue_application_id
      and app.airline_id=p_airline and app.world_id=1
      and app.permission_code='AIR_OPERATOR_CERTIFICATE'
      and app.status='issued' and app.fee_usd=10000
      and app.ledger_entry_id=cert.initial_issue_ledger_id)
   then issues:=array_append(issues,'AOC_SUBSIDIARY_PAID_PROVENANCE_INVALID');end if;
  else issues:=array_append(issues,'AOC_COMPANY_ORIGIN_NOT_VERIFIED');end if;
 end if;
 if coalesce((airlinerra_game.section9_aoc_safety_score_v1(p_airline,p_game_day)->>'rating')::int,-1)<70 then issues:=array_append(issues,'AOC_SAFETY_RATING_BELOW_70');end if;
 return jsonb_build_object(
  'status',case when cardinality(issues)=0 then 'AOC_FLIGHT_READY' else 'AOC_FLIGHT_BLOCKED' end,
  'authorized',cardinality(issues)=0,'issues',to_jsonb(issues),
  'airlineId',p_airline,'gameDay',p_game_day,
  'flightActivated',false,'ledgerPosted',false);
end $function$


-- SOURCE: section9_canonical_aoc_covers_v1
CREATE OR REPLACE FUNCTION airlinerra_game.section9_canonical_aoc_covers_v1(p_airline uuid, p_day date, p_days integer)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
 SELECT coalesce(airlinerra_game.section9_aoc_flight_release_readiness_v1(p_airline,p_day)->>'authorized'='true',false)
 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 c
 WHERE c.airline_id=p_airline AND c.world_id=1 AND c.status='active'
 AND c.issued_game_day<=p_day AND c.expires_game_day>p_day+p_days)
$function$


-- SOURCE: licence2_country_market_v1
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_country_market_v1(p_iso text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
 select case
 when upper(coalesce(p_iso,''))=any(array[
 'AT','BE','BG','HR','CY','CZ','DK','EE','FI','FR','DE','GR','HU',
 'IE','IT','LV','LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','SE',
 'IS','LI','NO']) then 'L2-EU'
 when upper(coalesce(p_iso,''))='US' then 'L2-US'
 when upper(coalesce(p_iso,''))='GB' then 'L2-UK'
 when upper(coalesce(p_iso,''))='JP' then 'L2-JP'
 else null end
$function$


-- SOURCE: licence2_foreign_route_preview_v1
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_foreign_route_preview_v1(p_airline uuid, p_origin text, p_destination text, p_market text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
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
 select * into v_level from airlinerra_game.licence2_market_levels_v1
 where market_code=v_target_market and level=v_permit.level;
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
end $function$


-- SOURCE: section9_game_route_licence_scope_v1
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_route_licence_scope_v1(p_airline uuid, p_origin text, p_destination text, p_day date, p_days integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE scope jsonb; market text;
BEGIN
 IF NOT airlinerra_game.section9_canonical_aoc_covers_v1(p_airline,p_day,p_days) THEN
 RETURN jsonb_build_object('allowed',false,'decision','VALID_LICENCE_1_REQUIRED');END IF;
 scope:=airlinerra_game.licence2_foreign_route_preview_v1(p_airline,p_origin,p_destination,NULL);
 IF scope->>'decision'='L1_HOME_MARKET_ROUTE' THEN
 RETURN jsonb_build_object('allowed',true,'decision','L1_HOME_MARKET_ROUTE','licence',1,'applicationRequired',false);END IF;
 IF scope->>'requiresLicence2' IS DISTINCT FROM 'true' THEN
 RETURN jsonb_build_object('allowed',false,'decision',coalesce(scope->>'decision','INVALID_ROUTE'));END IF;
 market:=scope->>'market';
 IF scope->>'decision'='L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK' AND EXISTS(
 SELECT 1 FROM airlinerra_game.licence2_directed_route_allocations_v1 x WHERE x.world_id=1 AND x.airline_id=p_airline AND x.origin_airport_key=p_origin AND x.destination_airport_key=p_destination AND x.market_code=market AND x.allocation_state IN ('reserved','active'))
 THEN RETURN jsonb_build_object('allowed',true,'decision','L2_APPROVED_MARKET_ROUTE','licence',2,'market',market,'applicationRequired',false);END IF;
 RETURN jsonb_build_object('allowed',false,'decision',coalesce(scope->>'decision','L2_REQUIRED'),'licence',2,'market',market);
END $function$


-- SOURCE: section9_verify_game_operator_licence_v1
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_operator_licence_v1(p_airline uuid, p_schedule uuid, p_expected_version integer, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 target record;world_row record;clock_row record;
 licence_row record;catalog_row record;
 blockers text[]:=ARRAY[]::text[];
 source_hash text;country_code text;
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL OR
  p_expected_version IS NULL OR p_expected_version<1 OR
  p_game_day IS NULL OR
  p_game_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_GAME_LICENCE_VERIFICATION_REQUEST';END IF;
 SELECT sched.*,airline.home_airport_key,airline.owner_player_id,
  home.country_iso AS home_iso, fleet.configuration_id AS fleet_config,
  fleet.fleet_status
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 sched
 JOIN airlinerra_game.airlines airline ON airline.id=sched.airline_id
  AND airline.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=sched.aircraft_inventory_id
  AND fleet.airline_id=sched.airline_id
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=airline.home_airport_key
 WHERE sched.id=p_schedule AND sched.airline_id=p_airline AND sched.world_id=1
 FOR SHARE OF sched;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_GAME_LICENCE_SCHEDULE_UNKNOWN';END IF;
 IF target.version IS DISTINCT FROM p_expected_version OR
  ((target.status IS DISTINCT FROM 'draft' OR target.operationally_verified IS DISTINCT FROM false) AND NOT (current_user='postgres' AND current_setting('airlinerra.active_recertification',true) IS NOT DISTINCT FROM p_schedule::text AND target.status='active' AND target.operationally_verified=true))
 THEN RETURN jsonb_build_object(
  'status','blocked_stale_or_non_draft_schedule','worldId',1,
  'verified',false,'readOnly',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT state,opens_at INTO world_row
 FROM public.airlinerra_game_worlds WHERE id=1 FOR SHARE;
 SELECT confirmed_game_date,clock_source,last_verified_at,engine_proof_ref
 INTO clock_row FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF world_row.state IS DISTINCT FROM 'active' OR
  world_row.opens_at IS NULL OR world_row.opens_at>clock_timestamp() OR
  clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine' OR
  clock_row.confirmed_game_date IS DISTINCT FROM p_game_day OR
  clock_row.last_verified_at IS NULL OR
  length(coalesce(clock_row.engine_proof_ref,''))<12 OR
  NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 r
   WHERE r.world_id=1 AND r.game_date=p_game_day)
 THEN RETURN jsonb_build_object(
  'status','blocked_unverified_world_or_game_day','worldId',1,
  'verified',false,'readOnly',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 country_code:=target.home_iso;
 IF country_code IS NULL OR country_code !~ '^[A-Z]{2}$' OR
  NOT EXISTS(SELECT 1 FROM airlinerra_game.aviation_countries_v1 c
   WHERE c.iso2=country_code)
 THEN blockers:=array_append(blockers,'AIRLINE_JURISDICTION_UNVERIFIED');END IF;
 IF target.fleet_status IS DISTINCT FROM 'in_service' OR
  target.fleet_config IS DISTINCT FROM target.configuration_id
 THEN blockers:=array_append(blockers,'AIRCRAFT_FLEET_CONFIGURATION_CHANGED');END IF;

 SELECT * INTO licence_row FROM airlinerra_game.section9_aoc_certificates_v1 WHERE airline_id=p_airline AND world_id=1 FOR SHARE;
 SELECT * INTO catalog_row FROM airlinerra_game.section9_aoc_release_policy_v1 WHERE world_id=1 FOR SHARE;
 IF NOT airlinerra_game.section9_canonical_aoc_covers_v1(p_airline,p_game_day,28)
 THEN blockers:=array_append(blockers,'VALID_COMPANY_AOC_REQUIRED');END IF;

 IF cardinality(blockers)>0 THEN RETURN jsonb_build_object(
  'status','blocked_game_operator_licence',
  'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
  'scheduleVersion',p_expected_version,'gameDate',p_game_day,
  'verified',false,'readOnly',true,'blockers',to_jsonb(blockers),
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;
 source_hash:=md5(jsonb_build_object(
  'source','game_operator_licence_v1','scheduleId',target.id,
  'scheduleVersion',target.version,'airlineId',p_airline,
  'gameDate',p_game_day,'jurisdiction',country_code,
  'gamePermissionPolicy',to_jsonb(catalog_row),
  'licenceEvidence',to_jsonb(licence_row),
  'fleetConfig',target.configuration_id)::text);
 RETURN jsonb_build_object(
  'status','verified_game_operator_licence',
  'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
  'scheduleVersion',p_expected_version,'gameDate',p_game_day,
  'validThroughGameDate',p_game_day+28,
  'clearanceType','operator_licence',
  'sourceKind','verified_game_licence_engine',
  'sourceReference','game-operator-licence-v1-'||source_hash,
  'reviewerReference','independent-game-licence-authority-v1',
  'proofFingerprint',source_hash,'jurisdictionIso2',country_code,
  'verified',true,'readOnly',true,'gameLicenceOnly',true,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $function$


-- SOURCE: section9_verify_game_route_traffic_rights_v1
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_route_traffic_rights_v1(p_airline uuid, p_schedule uuid, p_expected_version integer, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 target record;operator_source jsonb;
 role_name text;role_names text[];required_permission_code text;
 preview jsonb;game_grant record;catalog_row record;
 blockers text[]:=ARRAY[]::text[];
 rights_details jsonb:='[]'::jsonb;proof_hash text;
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL OR
  p_expected_version IS NULL OR p_expected_version<1 OR
  p_game_day IS NULL OR
  p_game_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_GAME_TRAFFIC_RIGHTS_REQUEST';END IF;
 SELECT sched.*,airline.owner_player_id,
  home.country_iso AS operator_country,
  origin.country_iso AS origin_country,
  destination.country_iso AS destination_country,
  aircraft.use_type
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 sched
 JOIN airlinerra_game.airlines airline ON airline.id=sched.airline_id
  AND airline.world_id=1
 JOIN airlinerra.aircraft_configurations aircraft
  ON aircraft.id=sched.configuration_id
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=airline.home_airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles origin
  ON origin.world_id=1 AND origin.airport_key=sched.origin_airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles destination
  ON destination.world_id=1 AND
  destination.airport_key=sched.destination_airport_key
 WHERE sched.id=p_schedule AND sched.airline_id=p_airline AND sched.world_id=1
 FOR SHARE OF sched;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_GAME_RIGHTS_SCHEDULE_UNKNOWN';END IF;
 IF target.version IS DISTINCT FROM p_expected_version OR
  ((target.status IS DISTINCT FROM 'draft' OR target.operationally_verified IS DISTINCT FROM false) AND NOT (current_user='postgres' AND current_setting('airlinerra.active_recertification',true) IS NOT DISTINCT FROM p_schedule::text AND target.status='active' AND target.operationally_verified=true))
 THEN RETURN jsonb_build_object(
  'status','blocked_stale_or_non_draft_schedule',
  'worldId',1,'verified',false,'readOnly',true,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 -- A route permission cannot outlive or bypass a verified operator
 -- licence, even when route evidence is marked "verified".
 operator_source:=airlinerra_game.section9_verify_game_operator_licence_v1(
  p_airline,p_schedule,p_expected_version,p_game_day);
 IF operator_source->>'status'<>'verified_game_operator_licence'
  OR operator_source->>'verified' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object(
  'status','blocked_game_route_operator_not_licensed',
  'worldId',1,'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'verified',false,'readOnly',true,
  'blockers',jsonb_build_array('VERIFIED_GAME_OPERATOR_LICENCE_REQUIRED'),
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;
 IF target.operator_country IS NULL OR target.origin_country IS NULL
  OR target.destination_country IS NULL OR
  target.origin_country !~ '^[A-Z]{2}$' OR
  target.destination_country !~ '^[A-Z]{2}$'
 THEN RETURN jsonb_build_object(
  'status','blocked_game_route_country_unknown','worldId',1,
  'scheduleId',p_schedule,'verified',false,'readOnly',true,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 role_names:=CASE target.use_type
  WHEN 'cargo' THEN ARRAY['cargo']::text[]
  WHEN 'combi' THEN ARRAY['passenger','cargo']::text[]
  WHEN 'passenger' THEN ARRAY['passenger']::text[]
  ELSE ARRAY[]::text[] END;
 IF cardinality(role_names)=0 THEN
  blockers:=array_append(blockers,'AIRCRAFT_SERVICE_TYPE_UNKNOWN');END IF;

 FOREACH role_name IN ARRAY role_names LOOP
  preview:=airlinerra_game.section9_game_route_licence_scope_v1(p_airline,target.origin_airport_key,target.destination_airport_key,p_game_day,28);
  IF preview->>'allowed' IS DISTINCT FROM 'true' THEN
   blockers:=array_append(blockers,upper(role_name)||'_'||coalesce(preview->>'decision','LICENCE_SCOPE_UNAVAILABLE'));CONTINUE;
  END IF;
  IF role_name='cargo' THEN
   -- Cargo remains subject to the existing separate Licence 3 release.
   blockers:=array_append(blockers,'CARGO_COMMERCIAL_EXECUTION_NOT_RELEASED');CONTINUE;
  END IF;
  rights_details:=rights_details||jsonb_build_array(jsonb_build_object('serviceType',role_name,'gameLicenceScope',preview,'gameOnly',true));
 END LOOP;

 IF cardinality(blockers)>0 OR
    jsonb_array_length(rights_details)<>cardinality(role_names)
 THEN RETURN jsonb_build_object(
  'status','blocked_game_route_traffic_rights','worldId',1,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'verified',false,'readOnly',true,'blockers',to_jsonb(blockers),
  'requiredServiceTypes',to_jsonb(role_names),
  'verifiedServiceTypes',jsonb_array_length(rights_details),
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 proof_hash:=md5(jsonb_build_object(
  'source','game_route_rights_v1',
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'gameDate',p_game_day,
  'operatorLicenceSourceReference',operator_source->>'sourceReference',
  'origin',target.origin_airport_key,
  'destination',target.destination_airport_key,
  'serviceGrants',rights_details)::text);
 RETURN jsonb_build_object(
  'status','verified_game_route_traffic_rights',
  'worldId',1,'airlineId',p_airline,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'gameDate',p_game_day,'validThroughGameDate',p_game_day+28,
  'clearanceType','route_traffic_rights',
  'sourceKind','verified_game_traffic_rights_engine',
  'sourceReference','game-route-rights-v1-'||proof_hash,
  'reviewerReference','independent-game-traffic-rights-v1',
  'proofFingerprint',proof_hash,
  'verified',true,'readOnly',true,
  'gameRightsOnly',true,'requiredServiceTypes',to_jsonb(role_names),
  'verifiedServiceTypes',jsonb_array_length(rights_details),
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $function$;
