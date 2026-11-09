-- Airlinerra Section 8 / World 1 game airline operating tariffs.
-- All USD figures are GAME MODEL amounts, never official published airport tariffs.
-- Separate charges: airport departure/arrival, ground services, stand parking,
-- passenger/security, cargo, terminal ATC, and global approximation of en-route ATC.
-- FUEL / operational passenger bookings / cash settlement are NOT activated here.
-- Current World 1 is planned: quote is strictly private/read-only/non-postable.

CREATE TABLE airlinerra_game.section8_fee_category_policy_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_category text NOT NULL
   CHECK(airport_category IN ('Local','Regional','Medium','Large','Major Hub','Mega Hub')),
 departure_movement_fraction numeric(5,3) NOT NULL CHECK(departure_movement_fraction BETWEEN 0 AND 1),
 ground_handling_fraction numeric(5,3) NOT NULL CHECK(ground_handling_fraction BETWEEN 0 AND 1),
 terminal_stand_multiplier numeric(5,3) NOT NULL CHECK(terminal_stand_multiplier BETWEEN 1 AND 3),
 remote_stand_multiplier numeric(5,3) NOT NULL CHECK(remote_stand_multiplier BETWEEN 0 AND 1),
 cargo_stand_multiplier numeric(5,3) NOT NULL CHECK(cargo_stand_multiplier BETWEEN 0 AND 2),
 terminal_navigation_unit_usd numeric(10,2) NOT NULL CHECK(terminal_navigation_unit_usd>0),
 security_per_departing_passenger_usd numeric(10,2) NOT NULL CHECK(security_per_departing_passenger_usd>=0),
 international_processing_per_departing_passenger_usd numeric(10,2) NOT NULL CHECK(international_processing_per_departing_passenger_usd>=0),
 cargo_handling_per_tonne_usd numeric(10,2) NOT NULL CHECK(cargo_handling_per_tonne_usd>0),
 price_source text NOT NULL DEFAULT 'owner_requested_game_airport_pricing_20261109_not_real_tariff',
 PRIMARY KEY(world_id,airport_category),
 CHECK(terminal_stand_multiplier>remote_stand_multiplier)
);
ALTER TABLE airlinerra_game.section8_fee_category_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section8_fee_category_policy_v1 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.section8_fee_category_policy_v1
(world_id,airport_category,departure_movement_fraction,ground_handling_fraction,
 terminal_stand_multiplier,remote_stand_multiplier,cargo_stand_multiplier,
 terminal_navigation_unit_usd,security_per_departing_passenger_usd,
 international_processing_per_departing_passenger_usd,cargo_handling_per_tonne_usd)
VALUES
(1,'Local',     0.120,0.220,1.55,0.70,0.85,  25,1.00,1.00, 20),
(1,'Regional',  0.140,0.260,1.55,0.70,0.85,  50,1.50,2.00, 35),
(1,'Medium',    0.160,0.280,1.60,0.70,0.90,  95,2.50,3.00, 60),
(1,'Large',     0.180,0.300,1.65,0.70,0.92, 160,3.50,4.00, 90),
(1,'Major Hub', 0.200,0.330,1.70,0.70,0.95, 250,4.50,5.00,125),
(1,'Mega Hub',  0.220,0.360,1.75,0.72,0.98, 360,5.50,6.00,160);
COMMENT ON TABLE airlinerra_game.section8_fee_category_policy_v1 IS
 'Provisional but game-accepted USD fee components by six canonical airport categories. Not published real-world charges or dispatch authority.';

CREATE TABLE airlinerra_game.section8_airspace_navigation_policy_v1(
 world_id smallint PRIMARY KEY DEFAULT 1 CHECK(world_id=1),
 route_charge_per_100km_at_50t_usd numeric(10,2) NOT NULL CHECK(route_charge_per_100km_at_50t_usd>0),
 terminal_excluded_distance_km numeric(8,2) NOT NULL CHECK(terminal_excluded_distance_km BETWEEN 0 AND 200),
 free_parking_minutes integer NOT NULL CHECK(free_parking_minutes BETWEEN 0 AND 240),
 tariff_model_version text NOT NULL,
 global_route_proxy boolean NOT NULL DEFAULT true CHECK(global_route_proxy=true),
 excludes_fuel boolean NOT NULL DEFAULT true CHECK(excludes_fuel=true),
 permits_ledger_posting boolean NOT NULL DEFAULT false CHECK(permits_ledger_posting=false),
 notes text NOT NULL
);
ALTER TABLE airlinerra_game.section8_airspace_navigation_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section8_airspace_navigation_policy_v1
 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.section8_airspace_navigation_policy_v1
(world_id,route_charge_per_100km_at_50t_usd,terminal_excluded_distance_km,free_parking_minutes,
 tariff_model_version,notes)
VALUES (1,65,40,60,'section8_airline_operating_fees_game_v1_20261109',
 'Global great-circle route-navigation GAME proxy using weight and distance, NOT actual state/FIR-by-FIR fees. Tower/terminal fee is independent and charged only at departure. Fuel/de-icing/real tax not included. Quote cannot post money.');
COMMENT ON TABLE airlinerra_game.section8_airspace_navigation_policy_v1 IS
 'World 1 global GAME route navigation rate and free parking window; legal real route-zone tariff mapping deferred to later research.';

-- Backup only the 90 records that were explicitly left for Section 8
-- repricing after six-tier changes. Preserve all other 3,051 game rates.
CREATE TABLE airlinerra_game.section8_repriced_airport_fee_audit_v1(
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL,
 prior_row jsonb NOT NULL,
 new_row jsonb,
 reason text NOT NULL,
 effective_on date NOT NULL DEFAULT DATE '2026-11-09',
 PRIMARY KEY(world_id,airport_key)
);
ALTER TABLE airlinerra_game.section8_repriced_airport_fee_audit_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section8_repriced_airport_fee_audit_v1
 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.section8_repriced_airport_fee_audit_v1
(world_id,airport_key,prior_row,reason)
SELECT world_id,airport_key,to_jsonb(f),
 'CATEGORY_REPRICE_FROM_CURRENT_GAME_TIER_MEDIAN_PRESERVING_EXISTING_BACKGROUND_VARIATION'
FROM airlinerra_game.airport_game_fees f
WHERE world_id=1 AND price_model_version LIKE '%pending_section8%';
DO $check$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.section8_repriced_airport_fee_audit_v1)<>90
 THEN RAISE EXCEPTION 'SECTION8_EXPECTED_90_PENDING_TIER_REPRICES'; END IF;
END $check$;

-- Use medians from 3,051 unflagged game prices for the CURRENT category.
-- Retain airport-specific variation and lightly weighted gameplay city/tourism.
WITH medians AS (
 SELECT category,
  (percentile_cont(.5) WITHIN GROUP (ORDER BY landing_fee_usd))::numeric AS l,
  (percentile_cont(.5) WITHIN GROUP (ORDER BY parking_per_day_usd))::numeric AS k,
  (percentile_cont(.5) WITHIN GROUP (ORDER BY departing_passenger_fee_usd))::numeric AS p
 FROM airlinerra_game.airport_game_fees WHERE world_id=1
  AND price_model_version='background_adjusted_v3'
 GROUP BY category
), rebalanced AS (
 SELECT f.world_id,f.airport_key,f.category,
  (0.90+coalesce(f.pricing_variation_pct,50)::numeric*0.0020) AS variance,
  CASE f.airport_background
    WHEN 'tourism' THEN 1.08::numeric
    WHEN 'capital_city' THEN 1.08::numeric
    WHEN 'major_city' THEN 1.05::numeric
    WHEN 'regional_business' THEN 1.02::numeric
    ELSE 1.00::numeric END AS background_factor,
  m.l,m.k,m.p
 FROM airlinerra_game.airport_game_fees f
 JOIN medians m ON m.category=f.category
 WHERE f.world_id=1 AND f.price_model_version LIKE '%pending_section8%'
)
UPDATE airlinerra_game.airport_game_fees f
SET landing_fee_usd=greatest(1,round(r.l*r.variance*r.background_factor)::integer),
 parking_per_day_usd=greatest(1,round(r.k*r.variance*r.background_factor)::integer),
 departing_passenger_fee_usd=greatest(1,round(r.p*r.variance*r.background_factor)::integer),
 base_landing_fee_usd=greatest(1,round(r.l*r.variance)::integer),
 base_parking_per_day_usd=greatest(1,round(r.k*r.variance)::integer),
 base_departing_passenger_fee_usd=greatest(1,round(r.p*r.variance)::integer),
 price_model_version='section8_category_rebalanced_game_v1_20261109',
 pricing_basis='section8_category_median_tourism_game_only_not_official_tariff'
FROM rebalanced r
WHERE f.world_id=r.world_id AND f.airport_key=r.airport_key;
UPDATE airlinerra_game.section8_repriced_airport_fee_audit_v1 a
SET new_row=to_jsonb(f)
FROM airlinerra_game.airport_game_fees f
WHERE f.world_id=a.world_id AND f.airport_key=a.airport_key;

CREATE OR REPLACE VIEW airlinerra_game.section8_airport_operating_tariffs_v1
WITH (security_invoker=true) AS
SELECT f.world_id,f.airport_key,f.category AS game_category,
 f.airport_background AS game_airport_background,
 f.background_verified,
 f.pricing_basis AS game_pricing_basis,f.price_model_version,
 f.landing_fee_usd::numeric AS landing_base_for_reference_aircraft_usd,
 f.parking_per_day_usd::numeric AS remote_parking_reference_per_day_usd,
 f.departing_passenger_fee_usd::numeric AS passenger_facility_per_departure_usd,
 c.departure_movement_fraction,c.ground_handling_fraction,
 c.terminal_stand_multiplier,c.remote_stand_multiplier,c.cargo_stand_multiplier,
 c.terminal_navigation_unit_usd,
 c.security_per_departing_passenger_usd,
 c.international_processing_per_departing_passenger_usd,
 round(c.cargo_handling_per_tonne_usd*
   CASE f.airport_background
    WHEN 'tourism' THEN 1.10::numeric
    WHEN 'capital_city' THEN 1.06::numeric
    WHEN 'major_city' THEN 1.05::numeric
    ELSE 1.00::numeric END,2) AS cargo_handling_per_tonne_usd,
 CASE f.airport_background
    WHEN 'tourism' THEN 1.10::numeric
    WHEN 'capital_city' THEN 1.06::numeric
    WHEN 'major_city' THEN 1.05::numeric
    ELSE 1.00::numeric END AS new_service_background_factor,
 'GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'::text AS evidence_class
FROM airlinerra_game.airport_game_fees f
JOIN airlinerra_game.section8_fee_category_policy_v1 c
 ON c.world_id=f.world_id AND c.airport_category=f.category
JOIN airlinerra_game.approved_game_airports a
 ON a.world_id=f.world_id AND a.airport_key=f.airport_key
WHERE f.world_id=1;
REVOKE ALL ON airlinerra_game.section8_airport_operating_tariffs_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.section8_airport_operating_tariffs_v1 IS
 'Complete 3141-airport game-only operator tariff model. Existing airport-specific landing/parking/pax fee already reflects background; only NEW services get background uplift.';

CREATE OR REPLACE FUNCTION airlinerra_game.section8_quote_flight_operating_fees_v1(
 p_world smallint,
 p_origin_airport_key text,
 p_destination_airport_key text,
 p_configuration_id bigint,
 p_departure_stand_type text,
 p_arrival_stand_type text,
 p_departing_passengers integer,
 p_cargo_tonnes numeric,
 p_arrival_parking_minutes integer
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path=pg_catalog,airlinerra_game,airlinerra
AS $quote$
DECLARE o record; d record; v_ac record; v_service record; v_policy record;
 v_gc numeric; v_h numeric; v_mass numeric; v_nav_mass numeric;
 v_origin_stand numeric;v_destination_stand numeric;
 v_departure numeric;v_arrival numeric;v_handling numeric;v_parking numeric;
 v_terminal_atc numeric;v_enroute_atc numeric;v_passenger numeric;
 v_security numeric;v_border numeric;v_cargo_out numeric;v_cargo_in numeric;
 v_total numeric;v_international boolean; v_aircraft_capacity integer;
 v_cargo_capacity_kg numeric;
BEGIN
 IF p_world<>1 OR p_origin_airport_key IS NULL OR
    p_destination_airport_key IS NULL OR
    p_origin_airport_key=p_destination_airport_key OR
    p_configuration_id IS NULL OR
    p_departure_stand_type NOT IN ('terminal','remote','cargo') OR
    p_arrival_stand_type NOT IN ('terminal','remote','cargo') OR
    p_departing_passengers IS NULL OR p_departing_passengers<0 OR
    p_departing_passengers>1000 OR p_cargo_tonnes IS NULL OR
    p_cargo_tonnes<0 OR p_cargo_tonnes>500 OR
    p_arrival_parking_minutes IS NULL OR
    p_arrival_parking_minutes<0 OR p_arrival_parking_minutes>44640
 THEN RAISE EXCEPTION 'SECTION8_INVALID_FLIGHT_COST_PREVIEW_ARGUMENTS'
 USING ERRCODE='22023'; END IF;

 SELECT t.*,p.country_iso,p.latitude_deg,p.longitude_deg,
    s.terminal_stands,s.remote_stands,s.cargo_stands
 INTO o FROM airlinerra_game.section8_airport_operating_tariffs_v1 t
 JOIN airlinerra_game.airport_reference_profiles p
  ON p.world_id=t.world_id AND p.airport_key=t.airport_key
 JOIN airlinerra_game.section6_airport_slot_capacity_v1 s
  ON s.world_id=t.world_id AND s.airport_key=t.airport_key
 WHERE t.world_id=1 AND t.airport_key=p_origin_airport_key;
 SELECT t.*,p.country_iso,p.latitude_deg,p.longitude_deg,
    s.terminal_stands,s.remote_stands,s.cargo_stands
 INTO d FROM airlinerra_game.section8_airport_operating_tariffs_v1 t
 JOIN airlinerra_game.airport_reference_profiles p
  ON p.world_id=t.world_id AND p.airport_key=t.airport_key
 JOIN airlinerra_game.section6_airport_slot_capacity_v1 s
  ON s.world_id=t.world_id AND s.airport_key=t.airport_key
 WHERE t.world_id=1 AND t.airport_key=p_destination_airport_key;
 IF o.airport_key IS NULL OR d.airport_key IS NULL OR
   o.latitude_deg IS NULL OR o.longitude_deg IS NULL OR
   d.latitude_deg IS NULL OR d.longitude_deg IS NULL OR
   o.country_iso IS NULL OR d.country_iso IS NULL THEN
  RAISE EXCEPTION 'SECTION8_NO_VERIFIED_GAME_AIRPORT_GEOMETRY'
   USING ERRCODE='22023';END IF;

 IF (p_departure_stand_type='terminal' AND o.terminal_stands=0)
 OR (p_departure_stand_type='remote' AND o.remote_stands=0)
 OR (p_departure_stand_type='cargo' AND o.cargo_stands=0)
 OR (p_arrival_stand_type='terminal' AND d.terminal_stands=0)
 OR (p_arrival_stand_type='remote' AND d.remote_stands=0)
 OR (p_arrival_stand_type='cargo' AND d.cargo_stands=0)
 OR (p_departing_passengers>0
 AND (p_departure_stand_type='cargo' OR p_arrival_stand_type='cargo'))
 THEN RAISE EXCEPTION 'SECTION8_STAND_NOT_COMPATIBLE_WITH_GAME_AIRPORT'
 USING ERRCODE='22023';END IF;

 SELECT configuration_id,mtow_kg,model_name,reference_passenger_capacity,
   maximum_cargo_payload_kg INTO v_ac
 FROM airlinerra.aircraft_catalog_configuration_inventory
 WHERE configuration_id=p_configuration_id;
 IF v_ac.configuration_id IS NULL OR v_ac.mtow_kg IS NULL OR v_ac.mtow_kg<=0
 THEN RAISE EXCEPTION 'SECTION8_NO_TRUSTED_GAME_AIRCRAFT_MASS'
 USING ERRCODE='22023';END IF;
 SELECT simultaneous_passenger_seats,simultaneous_freight_kg
 INTO v_service FROM airlinerra.aircraft_service_payload_game_v1
 WHERE configuration_id=p_configuration_id;
 v_aircraft_capacity:=coalesce(v_service.simultaneous_passenger_seats,
    v_ac.reference_passenger_capacity,0);
 v_cargo_capacity_kg:=coalesce(v_service.simultaneous_freight_kg,
    v_ac.maximum_cargo_payload_kg,0);
 IF p_departing_passengers>v_aircraft_capacity OR
   p_cargo_tonnes*1000>v_cargo_capacity_kg
 THEN RAISE EXCEPTION 'SECTION8_PREVIEW_EXCEEDS_CATALOG_AIRCRAFT_CAPACITY'
 USING ERRCODE='22023';END IF;

 SELECT * INTO v_policy
 FROM airlinerra_game.section8_airspace_navigation_policy_v1
 WHERE world_id=1;
 IF v_policy.tariff_model_version IS NULL
 THEN RAISE EXCEPTION 'SECTION8_NAVIGATION_GAME_POLICY_MISSING';END IF;

 v_origin_stand:=CASE p_departure_stand_type
  WHEN 'terminal' THEN o.terminal_stand_multiplier
  WHEN 'remote' THEN o.remote_stand_multiplier
  ELSE o.cargo_stand_multiplier END;
 v_destination_stand:=CASE p_arrival_stand_type
  WHEN 'terminal' THEN d.terminal_stand_multiplier
  WHEN 'remote' THEN d.remote_stand_multiplier
  ELSE d.cargo_stand_multiplier END;
 -- Airport's original USD landing fee is the category/background game
 -- reference for a 70-tonne aircraft. MTOW is read from server catalogue.
 v_mass:=greatest(.35::numeric,least(3.50::numeric,
   round(sqrt((v_ac.mtow_kg::numeric/70000)::double precision)::numeric,4)));
 v_nav_mass:=round(sqrt((v_ac.mtow_kg::numeric/50000)::double precision)::numeric,5);
 -- Haversine on persisted GAME coordinates; not an actual FIR route.
 v_h:=power(sin(radians((d.latitude_deg-o.latitude_deg)::double precision)/2),2)+
 cos(radians(o.latitude_deg::double precision))*
 cos(radians(d.latitude_deg::double precision))*
 power(sin(radians((d.longitude_deg-o.longitude_deg)::double precision)/2),2);
 v_gc:=round((6371*2*asin(sqrt(greatest(0::double precision,
     least(1::double precision,v_h::double precision)))))::numeric,2);
 v_international:=o.country_iso<>d.country_iso;

 v_departure:=round(o.landing_base_for_reference_aircraft_usd*
   o.departure_movement_fraction*v_mass,2);
 v_arrival:=round(d.landing_base_for_reference_aircraft_usd*v_mass,2);
 v_handling:=round(o.landing_base_for_reference_aircraft_usd*
   o.ground_handling_fraction*v_mass*v_origin_stand*
   o.new_service_background_factor,2);
 v_parking:=round(d.remote_parking_reference_per_day_usd*
   v_destination_stand*v_mass*d.new_service_background_factor*
   greatest(0,p_arrival_parking_minutes-v_policy.free_parking_minutes)/1440.0,2);
 v_terminal_atc:=round(o.terminal_navigation_unit_usd*
   power((v_ac.mtow_kg::numeric/50000),0.7::numeric),2);
 v_enroute_atc:=round(v_policy.route_charge_per_100km_at_50t_usd*
  v_nav_mass*greatest(0::numeric,
    v_gc-v_policy.terminal_excluded_distance_km)/100,2);
 v_passenger:=round(p_departing_passengers*
   o.passenger_facility_per_departure_usd,2);
 v_security:=round(p_departing_passengers*
   o.security_per_departing_passenger_usd,2);
 v_border:=CASE WHEN v_international
  THEN round(p_departing_passengers*
   o.international_processing_per_departing_passenger_usd,2)
  ELSE 0::numeric END;
 v_cargo_out:=round(p_cargo_tonnes*o.cargo_handling_per_tonne_usd,2);
 v_cargo_in:=round(p_cargo_tonnes*d.cargo_handling_per_tonne_usd,2);
 v_total:=v_departure+v_arrival+v_handling+v_parking+
   v_terminal_atc+v_enroute_atc+v_passenger+v_security+
   v_border+v_cargo_out+v_cargo_in;
 RETURN jsonb_build_object(
  'status','game_operating_fee_preview_only',
  'worldId',1,'modelVersion',v_policy.tariff_model_version,
  'currency','USD','fuelIncluded',false,
  'cashPosted',false,'canPostToLedger',false,
  'isOfficialAviationTariff',false,
  'operationAuthorized',false,
  'originAirportKey',o.airport_key,
  'destinationAirportKey',d.airport_key,
  'originCategory',o.game_category,
  'destinationCategory',d.game_category,
  'originBackground',o.game_airport_background,
  'destinationBackground',d.game_airport_background,
  'aircraftConfigurationId',v_ac.configuration_id,
  'aircraftModel',v_ac.model_name,
  'aircraftMtowKg',v_ac.mtow_kg,
  'departureStand',p_departure_stand_type,
  'arrivalStand',p_arrival_stand_type,
  'passengers',p_departing_passengers,
  'cargoTonnes',p_cargo_tonnes,
  'arrivalParkingMinutes',p_arrival_parking_minutes,
  'freeParkingMinutes',v_policy.free_parking_minutes,
  'greatCircleDistanceKm',v_gc,
  'gameDistanceForAirspaceBillingKm',greatest(0::numeric,
    v_gc-v_policy.terminal_excluded_distance_km),
  'international',v_international,
  'fees',jsonb_build_object(
   'departureAirportMovementUsd',v_departure,
   'arrivalLandingUsd',v_arrival,
   'departureGroundHandlingUsd',v_handling,
   'arrivalStandParkingUsd',v_parking,
   'departureTerminalAirTrafficControlUsd',v_terminal_atc,
   'enrouteAirTrafficControlUsd',v_enroute_atc,
   'departingPassengerFacilityUsd',v_passenger,
   'departingPassengerSecurityUsd',v_security,
   'internationalPassengerProcessingUsd',v_border,
   'originCargoHandlingUsd',v_cargo_out,
   'destinationCargoHandlingUsd',v_cargo_in
  ),
  'totalGameOperatingFeesUsd',v_total,
  'unpricedItems',jsonb_build_array(
    'fuel_and_refuelling','conditional_deicing','aircraft_maintenance',
    'crew_salary','real_country_airspace_tarrifs','taxes_and_optional_services'),
  'costBasis','airlinerra_game_model_only',
  'note','No money is charged by this quote. Final actual-flight fees require separately verified operated-flight data and Section 9 settlement.'
 );
END $quote$;
REVOKE ALL ON FUNCTION airlinerra_game.section8_quote_flight_operating_fees_v1
(smallint,text,text,bigint,text,text,integer,numeric,integer)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section8_quote_flight_operating_fees_v1
(smallint,text,text,bigint,text,text,integer,numeric,integer)
IS 'Private non-posting game quote. Aircraft mass, category, distance and regional/tourism modifiers come from database, not user-reported rates. No airline ledger access.';

DO $accept$
DECLARE n integer;bad integer;
BEGIN
 SELECT count(*) INTO n FROM airlinerra_game.section8_airport_operating_tariffs_v1
 WHERE world_id=1 AND landing_base_for_reference_aircraft_usd>0
 AND remote_parking_reference_per_day_usd>0
 AND passenger_facility_per_departure_usd>0
 AND terminal_stand_multiplier>remote_stand_multiplier
 AND cargo_handling_per_tonne_usd>0 AND
 terminal_navigation_unit_usd>0;
 IF n<>3141 THEN RAISE EXCEPTION 'SECTION8_TARIFF_COVERAGE_NOT_COMPLETE: %',n;END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_game_fees WHERE world_id=1
    AND price_model_version LIKE '%pending_section8%')<>0
 OR (SELECT count(*) FROM airlinerra_game.section8_repriced_airport_fee_audit_v1
    WHERE new_row IS NOT NULL)<>90
 THEN RAISE EXCEPTION 'SECTION8_CATEGORY_REPRICING_NOT_COMPLETE'; END IF;
 IF (SELECT count(*) FROM airlinerra.aircraft_catalog_configuration_inventory
  WHERE mtow_kg>0)<>271
 THEN RAISE EXCEPTION 'SECTION8_AIRCRAFT_GAME_MTOW_COVERAGE_NOT_COMPLETE';END IF;
 IF (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'SECTION8_WORLD_IS_NOT_PLANNED';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
   WHERE world_id=1 AND status='active')
 THEN RAISE EXCEPTION 'SECTION8_COMMERCIAL_RELEASE_MUST_REMAIN_CLOSED';END IF;
 UPDATE airlinerra_game.airport_data_master_categories
 SET status='game_complete_estimated',updated_on=DATE '2026-11-09',
  scope_summary=scope_summary||
   ' | SECTION8 GAME-ONLY AIRLINE OPERATING FEES COMPLETED 2026-11-09: all 3141 categorized airport tariffs, 90 audited rebalanced classifications, parking terminal>remote, cargo and ground handling, takeoff/landing, terminal ATC and distance/MTOW route ATC, passenger/security/international processing. Fuel excluded. All fees are invented game prices, not authority tariff; airline cash postings and actual flights Section9. Real-world source verification Section10.'
 WHERE category_number=8 AND world_id=1;
 UPDATE airlinerra_game.world1_game_data_section_acceptance_v1
 SET game_data_result='game_complete_estimated',
  evidence=jsonb_build_object(
  'tariffAirports',3141,'aircraftMtowConfigurations',271,
  'categoryPricesRebalancedWithSnapshots',90,
  'terminalStandPremium',true,'cargoFee',true,
  'terminalAtcAndGlobalEnrouteProxy',true,
  'publishedAirportTariffVerified',false,
  'actualFlightLedgerIntegrated',false,
  'fuelPricingIncluded',false),
 outstanding_boundary=
  'Game fee model complete. Actual operated-flight costs, fuel sourcing/route decisions, local FIR navigation rates, conditional real charges and protected airline settlement remain in Sections9/10.',
 accepted_on=DATE '2026-11-09',
 checked_at=clock_timestamp()
 WHERE world_id=1 AND category_number=8;
 IF (SELECT status FROM airlinerra_game.airport_data_master_categories
     WHERE category_number=8)<>'game_complete_estimated' OR
    (SELECT game_data_result FROM
     airlinerra_game.world1_game_data_section_acceptance_v1
     WHERE world_id=1 AND category_number=8)<>'game_complete_estimated'
 THEN RAISE EXCEPTION 'SECTION8_GAME_DATA_ACCEPTANCE_FAILED';END IF;
END $accept$;
