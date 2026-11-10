-- End-to-end Group 2 aircraft / airport PREVIEW. Never consults or alters bookings.
-- Uses prepared runway length and stand capacity plus documented conditional restriction preview.
CREATE OR REPLACE FUNCTION airlinerra_game.group2_aircraft_airport_readiness_preview_v1(
 p_airport_key text,p_configuration_id bigint,p_operation text,
 p_time_utc timestamptz,p_stand_type text
) RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $$
DECLARE a record; aircraft record; restriction jsonb; runway_min numeric;
 slots_per_10m integer; runway_ok boolean; stand_ok boolean;
BEGIN
 IF p_airport_key IS NULL OR p_configuration_id IS NULL
 OR p_operation NOT IN('arrival','departure')
 OR p_stand_type NOT IN('terminal','remote','cargo')
 OR p_time_utc IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_INPUT','canBook',false,
 'canDispatch',false,'previewOnly',true);END IF;
 SELECT * INTO a FROM airlinerra_game.airport_group2_engine_input_preview_v1
 WHERE airport_key=p_airport_key AND world_id=1;
 SELECT configuration_id,model_name,takeoff_runway_m,landing_runway_m
 INTO aircraft FROM airlinerra.aircraft_catalog_configuration_inventory
 WHERE configuration_id=p_configuration_id;
 IF a.airport_key IS NULL OR aircraft.configuration_id IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_UNKNOWN_AIRPORT_OR_AIRCRAFT',
 'canBook',false,'canDispatch',false,'previewOnly',true); END IF;
 runway_min:=CASE WHEN p_operation='departure' THEN aircraft.takeoff_runway_m
 ELSE aircraft.landing_runway_m END;
 slots_per_10m:=CASE p_stand_type
 WHEN 'terminal' THEN a.game_terminal_slot_per_10m
 WHEN 'remote' THEN a.game_remote_slot_per_10m
 ELSE a.game_cargo_slot_per_10m END;
 runway_ok:=runway_min IS NOT NULL AND a.game_runway_length_m>=runway_min;
 stand_ok:=slots_per_10m IS NOT NULL AND slots_per_10m>0;
 restriction:=airlinerra_game.group2_airport_conditional_restriction_preview_v1(
 p_airport_key,p_configuration_id,p_operation,p_time_utc);
 RETURN jsonb_build_object(
 'modelVersion','GROUP2_AIRCRAFT_AIRPORT_READINESS_PREVIEW_V1',
 'airportKey',p_airport_key,'aircraftConfigurationId',p_configuration_id,
 'aircraftModel',aircraft.model_name,'operation',p_operation,
 'standType',p_stand_type,'gameStandCapacityPer10Minutes',slots_per_10m,
 'requiredCatalogRunwayM',runway_min,'airportCatalogRunwayM',a.game_runway_length_m,
 'catalogRunwayLengthCompatible',runway_ok,
 'gameStandTypeHasCapacity',stand_ok,
 'catalogInputsChecked',true,'liveSlotReservationsChecked',false,
 'fullWeightRunwayChecked',false,'licencesChecked',false,'movementPermissionsChecked',false,
 'restrictionCheck',restriction,
 'decision',CASE
 WHEN NOT coalesce(runway_ok,false) THEN 'BLOCKED_CATALOG_RUNWAY'
 WHEN NOT coalesce(stand_ok,false) THEN 'BLOCKED_STAND_TYPE_CAPACITY'
 WHEN restriction->>'decision' LIKE 'BLOCKED_%' THEN 'BLOCKED_CONDITIONAL_RESTRICTION'
 WHEN restriction->>'decision' LIKE 'REVIEW_%' THEN 'REVIEW_REQUIRED_GROUP2_RESTRICTIONS'
 ELSE 'PRELIMINARY_DATA_COMPATIBLE_NOT_OPERATIONAL' END,
 'canBook',false,'canDispatch',false,'canActivateOffice',false,
 'previewOnly',true,'airportAdmitted',false
 );
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.group2_aircraft_airport_readiness_preview_v1(text,bigint,text,timestamptz,text)
FROM PUBLIC,anon,authenticated;
DO $$
DECLARE short_runway jsonb; chapter_block jsonb; unknown_chapter jsonb; compatible jsonb;
BEGIN
 short_runway:=airlinerra_game.group2_aircraft_airport_readiness_preview_v1(
  'OURAIRPORTS:4183',239,'departure','2026-11-10T14:00:00Z','terminal');
 chapter_block:=airlinerra_game.group2_aircraft_airport_readiness_preview_v1(
  'OURAIRPORTS:46583',239,'arrival','2026-11-10T14:00:00Z','terminal');
 unknown_chapter:=airlinerra_game.group2_aircraft_airport_readiness_preview_v1(
  'OURAIRPORTS:46583',1,'arrival','2026-11-10T14:00:00Z','terminal');
 compatible:=airlinerra_game.group2_aircraft_airport_readiness_preview_v1(
  'OURAIRPORTS:20581',1,'departure','2026-11-10T14:00:00Z','terminal');
 IF chapter_block->'restrictionCheck'->>'decision'<>'BLOCKED_DOCUMENTED_GAME_CHAPTER_RULE'
 OR unknown_chapter->'restrictionCheck'->>'decision'<>'REVIEW_REQUIRED_UNSOURCED_AIRCRAFT_CHAPTER'
 OR compatible->>'decision'<>'PRELIMINARY_DATA_COMPATIBLE_NOT_OPERATIONAL'
 OR compatible->>'canBook'<>'false'
 OR compatible->>'airportAdmitted'<>'false'
 OR short_runway->>'canDispatch'<>'false'
 THEN RAISE EXCEPTION 'GROUP2_AIRCRAFT_AIRPORT_PREVIEW_POSTCHECK_FAILED';END IF;
END $$;