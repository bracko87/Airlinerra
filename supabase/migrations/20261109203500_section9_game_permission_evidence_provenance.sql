-- Require game licence/traffic evidence provenance from a settled,
-- currently issued application; manual/legacy verified flags are insufficient.
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
  licence_row.valid_until<p_game_day+28 OR
  licence_row.issued_application_id IS NULL OR
  NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 app
   WHERE app.id=licence_row.issued_application_id
    AND app.airline_id=p_airline
    AND app.permission_code='AIR_OPERATOR_CERTIFICATE'
    AND app.status='issued'
    AND app.jurisdiction_iso2=country_code
    AND app.issued_game_date=licence_row.valid_from
    AND app.valid_until_game_date=licence_row.valid_until
    AND app.ledger_entry_id IS NOT NULL
    AND licence_row.evidence_reference=
      'game-permission-issued-v1-'||app.id::text)
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

CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_route_traffic_rights_v1(
 p_airline uuid,p_schedule uuid,p_expected_version integer,p_game_day date
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE
 target record;operator_source jsonb;
 role_name text;role_names text[];permission_code text;
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
  target.status IS DISTINCT FROM 'draft' OR
  target.operationally_verified IS DISTINCT FROM false
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
  preview:=airlinerra_game.aviation_route_rights_preview_v1(
   target.operator_country,target.origin_country,target.destination_country,
   role_name,p_game_day);

  -- Legal data is REFERENCE ONLY and always returns
  -- operationally_authorized=false. Never turn a legal "principle"
  -- into a game grant. Explicit legal prohibitions block outright.
  IF preview->>'operationally_authorized' IS DISTINCT FROM 'false'
   OR preview->>'status' IN ('invalid_input','forbidden','agreement_check_required')
  THEN
   blockers:=array_append(blockers,upper(role_name)||'_LEGAL_REFERENCE_UNRESOLVED');
   CONTINUE;
  END IF;

  permission_code:=CASE
   WHEN preview->>'reason'='domestic_airline_own_jurisdiction'
    THEN 'DOMESTIC_TRAFFIC'
   WHEN preview->>'reason'='eea_licenced_carrier_intra_market'
    THEN 'INTEGRATED_MARKET'
   WHEN preview->>'reason'='foreign_domestic_cabotage_not_automatically_granted'
    OR preview->>'reason'='anz_designation_for_foreign_domestic'
    THEN 'CABOTAGE'
   WHEN (preview->>'required_freedom') IN ('3','4')
    THEN 'THIRD_FOURTH_FREEDOM'
   WHEN (preview->>'required_freedom')='7'
    THEN 'SEVENTH_FREEDOM'
   WHEN preview->>'reason' IN (
    'serbia_ecaa_third_fourth_freedom_principle',
    'us_open_skies_international_principle')
     AND (target.operator_country=target.origin_country OR
       target.operator_country=target.destination_country)
    THEN 'THIRD_FOURTH_FREEDOM'
   ELSE NULL END;

  IF permission_code IS NULL THEN
   blockers:=array_append(blockers,upper(role_name)||'_RIGHTS_CLASSIFICATION_UNVERIFIED');
   CONTINUE;
  END IF;
  SELECT * INTO catalog_row
  FROM airlinerra_game.business_permission_catalog_v1 c
  WHERE c.permission_code=permission_code FOR SHARE;
  IF NOT FOUND OR catalog_row.category IS DISTINCT FROM 'traffic_rights'
   OR catalog_row.holder_scope IS DISTINCT FROM 'route'
   OR catalog_row.enabled_in_game IS DISTINCT FROM true
   OR catalog_row.game_fee_usd IS NULL
   OR catalog_row.processing_game_days IS NULL
  THEN
   blockers:=array_append(blockers,upper(role_name)||'_GAME_RIGHTS_GRANTS_DISABLED');
   CONTINUE;
  END IF;

  SELECT * INTO game_grant
  FROM airlinerra_game.section9_route_operating_permission_evidence_v1 r
  WHERE r.world_id=1 AND r.airline_id=p_airline
   AND r.origin_airport_key=target.origin_airport_key
   AND r.destination_airport_key=target.destination_airport_key
   AND r.service_type=role_name FOR SHARE;
  IF NOT FOUND OR game_grant.evidence_status IS DISTINCT FROM 'verified'
   OR game_grant.reviewed_at IS NULL OR
   game_grant.reviewed_at>clock_timestamp() OR
   char_length(coalesce(game_grant.evidence_reference,''))<16 OR
   game_grant.valid_from IS NULL OR game_grant.valid_from>p_game_day OR
   game_grant.valid_until IS NULL OR
   game_grant.valid_until<p_game_day+28 OR
   game_grant.issued_application_id IS NULL OR
   NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 app
    WHERE app.id=game_grant.issued_application_id
     AND app.airline_id=p_airline
     AND app.status='issued'
     AND app.permission_code=permission_code
     AND app.origin_airport_key=target.origin_airport_key
     AND app.destination_airport_key=target.destination_airport_key
     AND app.service_type=role_name
     AND app.issued_game_date=game_grant.valid_from
     AND app.valid_until_game_date=game_grant.valid_until
     AND app.ledger_entry_id IS NOT NULL
     AND game_grant.evidence_reference=
       'game-permission-issued-v1-'||app.id::text)
  THEN
   blockers:=array_append(blockers,upper(role_name)||'_GAME_RIGHTS_GRANT_MISSING_OR_EXPIRED');
   CONTINUE;
  END IF;
  rights_details:=rights_details||jsonb_build_array(jsonb_build_object(
   'serviceType',role_name,'gamePermissionCode',permission_code,
   'legalReferenceStatus',preview->>'status',
   'legalReferenceOperationallyAuthorizes',false,
   'gameGrant',to_jsonb(game_grant),'gamePolicy',to_jsonb(catalog_row)
  ));
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
END $f$;
