-- Section 9 verified capacity: never assume both catalog MAX seats and
-- catalog MAX freight can be carried simultaneously.
-- The pre-existing aircraft service payload model is the conservative
-- authoritative limit. NULL freight means UNVERIFIED, not free belly cargo.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_register_verified_schedule_capacity_v1(
 p_schedule_id uuid,p_airline_id uuid,p_passenger_seats integer,
 p_cargo_capacity_tonnes numeric,p_verification_source text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE s record; c record; m record;
 allowed_pax integer; allowed_cargo numeric;
BEGIN
 SELECT d.id,d.airline_id,d.version,d.status,d.operationally_verified,
  d.configuration_id INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 WHERE d.id=p_schedule_id AND d.airline_id=p_airline_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'active' OR s.operationally_verified IS DISTINCT FROM true THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_SCHEDULE_NOT_ACTIVATED';
 END IF;
 SELECT maximum_passenger_seats,maximum_cargo_payload_kg INTO c
 FROM airlinerra.aircraft_configurations WHERE id=s.configuration_id;
 SELECT simultaneous_passenger_seats,simultaneous_freight_kg,
   service_role,belly_hold_reference_type INTO m
 FROM airlinerra.aircraft_service_payload_game_v1
 WHERE configuration_id=s.configuration_id;
 IF c IS NULL OR m IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_AIRCRAFT_PAYLOAD_NOT_VERIFIED';
 END IF;
 allowed_pax:=least(1000,coalesce(c.maximum_passenger_seats,0),
   coalesce(m.simultaneous_passenger_seats,0));
 allowed_cargo:=least(1000,
    coalesce(m.simultaneous_freight_kg,0)/1000,
    coalesce(c.maximum_cargo_payload_kg,m.simultaneous_freight_kg,0)/1000);
 IF p_passenger_seats IS NULL OR p_passenger_seats NOT BETWEEN 0 AND allowed_pax
   OR p_cargo_capacity_tonnes IS NULL OR
     p_cargo_capacity_tonnes NOT BETWEEN 0 AND allowed_cargo
   OR p_verification_source IS NULL OR length(p_verification_source) NOT BETWEEN 6 AND 120
 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_SIMULTANEOUS_CAPACITY';
 END IF;
 -- The exact simultaneous game layout is checked here, not derived by
 -- advertising capacity from an aircraft's disconnected maxima.
 INSERT INTO airlinerra_game.section9_verified_schedule_capacity_v1(
  schedule_id,airline_id,schedule_version,passenger_seats,
  cargo_capacity_tonnes,verification_source)
 VALUES(s.id,s.airline_id,s.version,p_passenger_seats,
  p_cargo_capacity_tonnes,p_verification_source)
 ON CONFLICT(schedule_id) DO UPDATE SET
  airline_id=excluded.airline_id,schedule_version=excluded.schedule_version,
  passenger_seats=excluded.passenger_seats,
  cargo_capacity_tonnes=excluded.cargo_capacity_tonnes,
  verification_source=excluded.verification_source,verified_at=now();
 RETURN jsonb_build_object('verified',true,'scheduleId',s.id,
  'scheduleVersion',s.version,'passengerSeats',p_passenger_seats,
  'cargoCapacityTonnes',p_cargo_capacity_tonnes,
  'capacityBasis','aircraft_service_payload_game_v1',
  'source',p_verification_source);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_register_verified_schedule_capacity_v1(
 uuid,uuid,integer,numeric,text) FROM PUBLIC,anon,authenticated;
