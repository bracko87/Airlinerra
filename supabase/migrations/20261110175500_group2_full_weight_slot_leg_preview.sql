-- Group 2 full-weight game runway + reservation-aware SINGLE-LEG slot preview.
-- No approved-airport writes, no slot reservation writes, no dispatch authority.
-- Reuses Group 1 full-weight aircraft reference with existing 0.00007112/ft ISA
-- elevation uplift observed in section5_full_weight_airport_aircraft_screen_v2.
CREATE OR REPLACE FUNCTION airlinerra_game.group2_full_weight_slot_leg_preview_v1(
 p_airport_key text,p_configuration_id bigint,p_operation text,
 p_time_utc timestamptz,p_stand_type text
) RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $$
DECLARE a record; ac record; local_dt timestamp;
 elev_factor numeric; required_m numeric; runway_ok boolean;
 ten_capacity integer; hour_capacity integer;
 ten_used integer; hour_used integer;
 wday smallint; minute_idx smallint; start_hour smallint;
 stand_pass boolean; restrictions jsonb; result_code text;
BEGIN
 IF p_airport_key IS NULL OR p_configuration_id IS NULL OR
    p_operation NOT IN('arrival','departure') OR
    p_stand_type NOT IN('terminal','remote','cargo') OR
    p_time_utc IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_INPUT',
  'previewOnly',true,'canReserve',false,'canDispatch',false);END IF;
 SELECT c.*,g.game_elevation_ft INTO a
 FROM airlinerra_game.airport_group2_engine_input_preview_v1 c
 JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
 WHERE c.world_id=1 AND c.airport_key=p_airport_key;
 SELECT configuration_id,aircraft_model,game_full_weight_takeoff_reference_m,
        game_full_weight_landing_reference_m,dispatch_certified
 INTO ac FROM airlinerra_game.section5_full_weight_aircraft_reference_v2
 WHERE configuration_id=p_configuration_id;
 IF a.airport_key IS NULL OR ac.configuration_id IS NULL OR
    a.timezone_iana IS NULL OR a.game_elevation_ft IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_MISSING_GROUP2_OR_AIRCRAFT_ENGINE_DATA',
  'previewOnly',true,'canReserve',false,'canDispatch',false);END IF;

 -- Same elevation adjustment as existing Group 1 model. This is a game
 -- approximation, NOT runway declared distance / terrain / weather clearance.
 elev_factor:=1+greatest(0,a.game_elevation_ft)*0.00007112;
 required_m:=ceil((CASE WHEN p_operation='departure'
   THEN ac.game_full_weight_takeoff_reference_m
   ELSE ac.game_full_weight_landing_reference_m END)*elev_factor);
 runway_ok:=required_m IS NOT NULL AND a.game_runway_length_m>=required_m;

 local_dt:=p_time_utc AT TIME ZONE a.timezone_iana;
 wday:=(extract(isodow FROM local_dt)::int-1)::smallint;
 minute_idx:=(extract(hour FROM local_dt)::int*60+
   (extract(minute FROM local_dt)::int/10)*10)::smallint;
 start_hour:=((minute_idx::int/60)*60)::smallint;
 ten_capacity:=CASE p_stand_type
 WHEN 'terminal' THEN a.game_terminal_slot_per_10m
 WHEN 'remote' THEN a.game_remote_slot_per_10m
 ELSE a.game_cargo_slot_per_10m END;
 hour_capacity:=CASE p_stand_type
 WHEN 'terminal' THEN a.game_terminal_stands
 WHEN 'remote' THEN a.game_remote_stands
 ELSE a.game_cargo_stands END;

 SELECT count(*) FILTER(WHERE r.minute_of_day=minute_idx)::int,
        count(*) FILTER(WHERE r.minute_of_day BETWEEN start_hour AND start_hour+59)::int
 INTO ten_used,hour_used
 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
 WHERE r.world_id=1 AND r.airport_key=p_airport_key AND
 r.stand_type=p_stand_type AND r.direction=p_operation AND r.weekday=wday;
 stand_pass:=coalesce(ten_capacity,0)>0 AND coalesce(hour_capacity,0)>0
   AND ten_used+1<=coalesce(ten_capacity,0)
   AND hour_used+1<=coalesce(hour_capacity,0);
 restrictions:=airlinerra_game.group2_airport_conditional_restriction_preview_v1(
 p_airport_key,p_configuration_id,p_operation,p_time_utc);
 result_code:=CASE
 WHEN NOT coalesce(runway_ok,false) THEN 'BLOCKED_FULL_WEIGHT_GAME_RUNWAY'
 WHEN NOT coalesce(stand_pass,false) THEN 'BLOCKED_GAME_SLOT_CAPACITY'
 WHEN restrictions->>'decision' LIKE 'BLOCKED_%' THEN 'BLOCKED_CONDITIONAL_RESTRICTION'
 WHEN restrictions->>'decision' LIKE 'REVIEW_%' THEN 'REVIEW_REQUIRED_GROUP2_RESTRICTION'
 ELSE 'PRELIMINARY_GAME_SCREEN_PASS_NOT_ADMITTED' END;
 RETURN jsonb_build_object(
  'modelVersion','GROUP2_FULL_WEIGHT_SLOT_LEG_PREVIEW_V1',
  'airportKey',p_airport_key,'aircraftConfigurationId',p_configuration_id,
  'aircraftModel',ac.aircraft_model,'operation',p_operation,
  'localAirportTime',to_char(local_dt,'YYYY-MM-DD HH24:MI:SS'),
  'timezone',a.timezone_iana,
  'airportGameRunwayM',a.game_runway_length_m,
  'elevationFt',a.game_elevation_ft,'elevationFactor',elev_factor,
  'gameFullWeightRequiredRunwayM',required_m,
  'fullWeightGameRunwayLengthCompatible',runway_ok,
  'standType',p_stand_type,'slotWeekdayMondayZero',wday,
  'slotMinuteOfDay',minute_idx,
  'tenMinuteGameCapacity',ten_capacity,
  'hourlyGameCapacity',hour_capacity,
  'existingTenMinuteReservations',ten_used,
  'existingHourlyReservations',hour_used,
  'hypotheticalOneFlightStandCapacityAvailable',stand_pass,
  'reservationSnapshotChecked',true,'reservationWritten',false,
  'restrictionCheck',restrictions,'decision',result_code,
  'dispatchWeightWeatherAndRunwayDeclaredDistancesChecked',false,
  'weeklyFullScheduleChecked',false,
  'licensesChecked',false,'aircraftMovementChecked',false,
  'airportCommerciallyAdmitted',false,
  'canReserve',false,'canDispatch',false,'canActivateOffice',false,
  'previewOnly',true
 );
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.group2_full_weight_slot_leg_preview_v1(
 text,bigint,text,timestamptz,text) FROM PUBLIC,anon,authenticated;

DO $$
DECLARE good jsonb; no_stand jsonb; restricted jsonb; no_airport jsonb;
BEGIN
 good:=airlinerra_game.group2_full_weight_slot_leg_preview_v1(
  'OURAIRPORTS:20581',1,'departure','2026-11-10T14:00:00Z','terminal');
 no_stand:=airlinerra_game.group2_full_weight_slot_leg_preview_v1(
  'OURAIRPORTS:4183',194,'departure','2026-11-10T14:00:00Z','terminal');
 restricted:=airlinerra_game.group2_full_weight_slot_leg_preview_v1(
  'OURAIRPORTS:46583',239,'arrival','2026-11-10T14:00:00Z','terminal');
 no_airport:=airlinerra_game.group2_full_weight_slot_leg_preview_v1(
  'OURAIRPORTS:113',1,'departure','2026-11-10T14:00:00Z','terminal');
 IF good->>'decision'<>'PRELIMINARY_GAME_SCREEN_PASS_NOT_ADMITTED'
 OR good->>'reservationWritten'<>'false' OR good->>'canReserve'<>'false'
 OR no_stand->>'decision'<>'BLOCKED_GAME_SLOT_CAPACITY'
 OR restricted->>'decision'<>'BLOCKED_CONDITIONAL_RESTRICTION'
 OR no_airport->>'decision'<>'BLOCKED_MISSING_GROUP2_OR_AIRCRAFT_ENGINE_DATA'
 THEN RAISE EXCEPTION 'GROUP2_FULL_WEIGHT_SLOT_PREVIEW_TESTS_FAILED';END IF;
END $$;