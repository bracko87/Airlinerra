-- Fix collision of PL/pgSQL local variable iso2 with aviation_countries.iso2.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_operator_licence_v1(
 p_airline uuid,p_schedule uuid,p_expected_version integer,p_game_day date
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
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
  target.status IS DISTINCT FROM 'draft' OR
  target.operationally_verified IS DISTINCT FROM false
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

 -- The licence category is still disabled globally by a hard CHECK.
 -- A reference-only legal text or an evidence row is NOT an issued game
 -- operating licence. All three layers must be present and valid.
 SELECT * INTO catalog_row
 FROM airlinerra_game.business_permission_catalog_v1 c
 WHERE c.permission_code='AIR_OPERATOR_CERTIFICATE' FOR SHARE;
 IF NOT FOUND OR catalog_row.category IS DISTINCT FROM 'airline'
  OR catalog_row.holder_scope IS DISTINCT FROM 'operating_company'
  OR catalog_row.enabled_in_game IS DISTINCT FROM true
  OR catalog_row.game_fee_usd IS NULL
  OR catalog_row.processing_game_days IS NULL
 THEN blockers:=array_append(blockers,'GAME_OPERATOR_LICENCE_ISSUANCE_DISABLED');END IF;
 SELECT * INTO licence_row
 FROM airlinerra_game.section9_operator_licence_evidence_v1 l
 WHERE l.world_id=1 AND l.airline_id=p_airline
  AND l.jurisdiction_iso2=country_code FOR SHARE;
 IF NOT FOUND OR licence_row.evidence_status IS DISTINCT FROM 'verified'
  OR licence_row.reviewed_at IS NULL OR
  licence_row.reviewed_at>clock_timestamp() OR
  char_length(coalesce(licence_row.evidence_reference,''))<16 OR
  licence_row.valid_from IS NULL OR
  licence_row.valid_from>p_game_day OR
  licence_row.valid_until IS NULL OR
  licence_row.valid_until<p_game_day+28
 THEN blockers:=array_append(blockers,'VERIFIED_GAME_OPERATOR_LICENCE_MISSING_OR_EXPIRED');END IF;

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
END $f$;
