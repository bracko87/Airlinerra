-- Combined airport catalog integration preview: read-only and fail-closed.
-- It is intentionally NOT connected to live route scheduling or commercial admission.
-- No authenticated/anon execution grant, no writes, no activation.
CREATE OR REPLACE FUNCTION airlinerra_game.airport_sections1_8_preview_aircraft_v1(
 p_airport_key text,p_configuration_id bigint,p_operation text
) RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $function$
DECLARE a record; ac record; required_m numeric; eligible boolean;
BEGIN
 IF nullif(btrim(coalesce(p_airport_key,'')),'') IS NULL
  OR p_configuration_id IS NULL OR p_operation NOT IN ('departure','arrival')
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_INPUT',
 'previewOnly',true,'canActivateNormalFlight',false,'canBookSlots',false);END IF;

 SELECT * INTO a FROM airlinerra_game.airport_sections1_8_combined_catalog_v1
 WHERE airport_key=p_airport_key AND world_id=1;
 SELECT configuration_id,model_name,takeoff_runway_m,landing_runway_m INTO ac
 FROM airlinerra.aircraft_catalog_configuration_inventory
 WHERE configuration_id=p_configuration_id;
 IF a.airport_key IS NULL OR ac.configuration_id IS NULL THEN
  RETURN jsonb_build_object('decision','BLOCKED_UNKNOWN_AIRPORT_OR_AIRCRAFT',
   'previewOnly',true,'canActivateNormalFlight',false,'canBookSlots',false);
 END IF;
 required_m:=CASE WHEN p_operation='departure' THEN ac.takeoff_runway_m
  ELSE ac.landing_runway_m END;
 eligible:=required_m IS NOT NULL AND a.game_runway_length_m>=required_m;
 RETURN jsonb_build_object(
  'modelVersion','COMBINED_AIRPORT_SECTIONS1_8_AIRCRAFT_PREVIEW_V1',
  'airportKey',p_airport_key,'airportName',a.airport_name,
  'sourceGroup',a.source_group,'airportCategory',a.game_category,
  'aircraftConfigurationId',p_configuration_id,'aircraftModel',ac.model_name,
  'operation',p_operation,'gameRunwayLengthM',a.game_runway_length_m,
  'runwayIsFictional',a.runway_is_fictional,
  'catalogRequiredRunwayM',required_m,'catalogRunwayLengthEnough',eligible,
  'runwayRuleVerified',false,
  'standCapacityPer10Minutes',jsonb_build_object(
    'terminal',a.game_terminal_slot_per_10m,
    'remote',a.game_remote_slot_per_10m,
    'cargo',a.game_cargo_slot_per_10m),
  'nighttimeBanGameFlag',a.game_nighttime_ban,
  'noiseRestrictionsGameFlag',a.game_noise_restrictions,
  'restrictionDataBasis',a.restriction_basis,
  'fullCurfewTimesChecked',false,
  'aircraftNoiseChapterCompatibilityChecked',false,
  'actualSlotAvailabilityChecked',false,
  'commercialAccessScope',a.commercial_access_scope,
  'decision',CASE
    WHEN a.source_group='GROUP_2' THEN 'PREPARED_NOT_ADMITTED'
    WHEN NOT coalesce(eligible,false) THEN 'BLOCKED_CATALOG_RUNWAY_LENGTH'
    ELSE 'REVIEW_REQUIRED_EXISTING_OPERATIONAL_GATES' END,
  'previewOnly',true,'canActivateNormalFlight',false,'canBookSlots',false,
  'fullOperationalGateRun',false,'realWorldDispatchApproved',false
 );
END $function$;
REVOKE ALL ON FUNCTION airlinerra_game.airport_sections1_8_preview_aircraft_v1(text,bigint,text)
 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_sections1_8_integration_status_v1
WITH (security_invoker=true) AS
SELECT c.source_group,count(*)::integer airports,
 count(*) FILTER(WHERE c.game_runway_length_m>0)::integer airports_with_game_runway,
 count(*) FILTER(WHERE c.game_terminal_slot_per_10m>=0
  AND c.game_remote_slot_per_10m>=0
  AND c.game_cargo_slot_per_10m>=0)::integer airports_with_game_slot_capacity,
 count(*) FILTER(WHERE c.game_nighttime_ban IS NOT NULL
  AND c.game_noise_restrictions IS NOT NULL)::integer airports_with_game_restrictions,
 count(*) FILTER(WHERE s.airport_key IS NOT NULL)::integer airports_in_existing_slot_engine,
 count(*) FILTER(WHERE p.airport_key IS NOT NULL)::integer airports_in_existing_operating_policy_engine,
 count(*) FILTER(WHERE a.airport_key IS NOT NULL)::integer airports_in_existing_approved_registry,
 false AS group2_commercial_activation_by_catalog
FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 c
LEFT JOIN airlinerra_game.section6_airport_slot_capacity_v1 s
 ON s.world_id=c.world_id AND s.airport_key=c.airport_key
LEFT JOIN airlinerra_game.section5_airport_operating_policy_v1 p
 ON p.world_id=c.world_id AND p.airport_key=c.airport_key
LEFT JOIN airlinerra_game.approved_game_airports a
 ON a.world_id=c.world_id AND a.airport_key=c.airport_key
GROUP BY c.source_group;
REVOKE ALL ON airlinerra_game.airport_sections1_8_integration_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
DECLARE v jsonb;
BEGIN
 IF (SELECT total_airports FROM airlinerra_game.airport_sections1_8_combined_status_v1)<>4259
 OR (SELECT airports_in_existing_approved_registry FROM airlinerra_game.airport_sections1_8_integration_status_v1
 WHERE source_group='GROUP_1')<>3141
 OR (SELECT airports_in_existing_approved_registry FROM airlinerra_game.airport_sections1_8_integration_status_v1
 WHERE source_group='GROUP_2')<>0
 OR (SELECT airports_in_existing_slot_engine FROM airlinerra_game.airport_sections1_8_integration_status_v1
 WHERE source_group='GROUP_2')<>0
 OR (SELECT airports_in_existing_operating_policy_engine FROM airlinerra_game.airport_sections1_8_integration_status_v1
 WHERE source_group='GROUP_2')<>0
 THEN RAISE EXCEPTION 'COMBINED_AIRPORT_INTEGRATION_COVERAGE_UNEXPECTED';END IF;
 v:=airlinerra_game.airport_sections1_8_preview_aircraft_v1('OURAIRPORTS:20581',1,'departure');
 IF v->>'decision'<>'PREPARED_NOT_ADMITTED'
 OR v->>'canActivateNormalFlight'<>'false'
 OR v->>'previewOnly'<>'true'
 THEN RAISE EXCEPTION 'GROUP2_PREVIEW_FAIL_OPEN';END IF;
 v:=airlinerra_game.airport_sections1_8_preview_aircraft_v1('OURAIRPORTS:113',1,'departure');
 IF v->>'decision'<>'BLOCKED_CATALOG_RUNWAY_LENGTH'
 OR v->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION 'GROUP1_CATALOG_RUNWAY_GUARD_FAILED';END IF;
END $$;