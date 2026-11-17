-- Game-only fuel custody and signed departure/arrival tracking.
-- No live flights or financial release are enabled by this migration.
-- Starting fuel comes only from a game-authority automatic supply event
-- at the aircraft's independently verified starter/arrival location.
-- An airport's generic fuel_available flag is NOT a real-grade certificate.
-- Fuel burned is tracked ONCE on arrival, and game financial charges remain
-- separated until an independently approved post-flight settlement.

CREATE TABLE IF NOT EXISTS airlinerra_game."section9_aircraft_game_fuel_custody_v1" (
  "aircraft_inventory_id" uuid NOT NULL,
  "airline_id" uuid NOT NULL,
  "world_id" smallint NOT NULL DEFAULT 1,
  "configuration_id" bigint NOT NULL,
  "at_airport_key" text NOT NULL,
  "fuel_game_family" text NOT NULL,
  "onboard_kg" numeric(14,3) NOT NULL,
  "source_event_id" text NOT NULL,
  "source_event_kind" text NOT NULL,
  "evidence_reference" text NOT NULL,
  "game_hour_utc" timestamp with time zone NOT NULL,
  "revision" bigint NOT NULL DEFAULT 1,
  "recorded_at" timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT "section9_aircraft_game_fuel_c_airline_id_aircraft_inventory_key" UNIQUE (airline_id, aircraft_inventory_id),
  CONSTRAINT "section9_aircraft_game_fuel_custody__aircraft_inventory_id_fkey" FOREIGN KEY (aircraft_inventory_id) REFERENCES airlinerra_game.airline_aircraft_inventory(id),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_airline_id_fkey" FOREIGN KEY (airline_id) REFERENCES airlinerra_game.airlines(id),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_at_airport_key_check" CHECK ((length(at_airport_key) > 5)),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_evidence_reference_check" CHECK ((length(evidence_reference) >= 16)),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_fuel_game_family_check" CHECK ((length(fuel_game_family) > 3)),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_onboard_kg_check" CHECK ((onboard_kg >= (0)::numeric)),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_pkey" PRIMARY KEY (aircraft_inventory_id),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_revision_check" CHECK ((revision >= 1)),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_source_event_id_check" CHECK ((length(source_event_id) >= 16)),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_source_event_kind_check" CHECK ((source_event_kind = ANY (ARRAY['approved_game_fuel_load'::text, 'signed_arrival_burn'::text]))),
  CONSTRAINT "section9_aircraft_game_fuel_custody_v1_world_id_check" CHECK ((world_id = 1))
);
ALTER TABLE airlinerra_game."section9_aircraft_game_fuel_custody_v1" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game."section9_aircraft_game_fuel_custody_v1" FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS airlinerra_game."section9_game_approved_fuel_load_receipts_v1" (
  "source_event_id" text NOT NULL,
  "airline_id" uuid NOT NULL,
  "aircraft_inventory_id" uuid NOT NULL,
  "at_airport_key" text NOT NULL,
  "fuel_family" text NOT NULL,
  "load_added_kg" numeric(14,3) NOT NULL,
  "fuel_after_load_kg" numeric(14,3) NOT NULL,
  "game_hour_utc" timestamp with time zone NOT NULL,
  "game_supplier_reference" text NOT NULL,
  "source_status" text NOT NULL DEFAULT 'awaiting_independent_game_authority'::text,
  "created_at" timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT "section9_game_approved_fuel_load__game_supplier_reference_check" CHECK ((length(game_supplier_reference) >= 16)),
  CONSTRAINT "section9_game_approved_fuel_load_rec_aircraft_inventory_id_fkey" FOREIGN KEY (aircraft_inventory_id) REFERENCES airlinerra_game.airline_aircraft_inventory(id),
  CONSTRAINT "section9_game_approved_fuel_load_recei_fuel_after_load_kg_check" CHECK ((fuel_after_load_kg > (0)::numeric)),
  CONSTRAINT "section9_game_approved_fuel_load_receipts_source_event_id_check" CHECK ((length(source_event_id) >= 16)),
  CONSTRAINT "section9_game_approved_fuel_load_receipts_v1_airline_id_fkey" FOREIGN KEY (airline_id) REFERENCES airlinerra_game.airlines(id),
  CONSTRAINT "section9_game_approved_fuel_load_receipts_v1_pkey" PRIMARY KEY (source_event_id),
  CONSTRAINT "section9_game_approved_fuel_load_receipts_v_load_added_kg_check" CHECK ((load_added_kg > (0)::numeric)),
  CONSTRAINT "section9_game_approved_fuel_load_receipts_v_source_status_check" CHECK ((source_status = ANY (ARRAY['awaiting_independent_game_authority'::text, 'game_authority_approved'::text])))
);
ALTER TABLE airlinerra_game."section9_game_approved_fuel_load_receipts_v1" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game."section9_game_approved_fuel_load_receipts_v1" FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS airlinerra_game."section9_game_flight_fuel_departure_receipts_v1" (
  "physical_flight_id" text NOT NULL,
  "airline_id" uuid NOT NULL,
  "aircraft_inventory_id" uuid NOT NULL,
  "departure_engine_event_id" text NOT NULL,
  "departure_airport_key" text NOT NULL,
  "destination_airport_key" text NOT NULL,
  "configuration_id" bigint NOT NULL,
  "fuel_custody_source_event_id" text NOT NULL,
  "fuel_custody_revision" bigint NOT NULL,
  "onboard_at_departure_kg" numeric(14,3) NOT NULL,
  "planned_trip_burn_kg" numeric(14,3) NOT NULL,
  "planned_contingency_kg" numeric(14,3) NOT NULL,
  "planned_holding_reserve_kg" numeric(14,3) NOT NULL,
  "minimum_planned_onboard_kg" numeric(14,3) NOT NULL,
  "model_version" text NOT NULL,
  "verified_game_hour_utc" timestamp with time zone NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT "section9_game_flight_fuel_depa_planned_holding_reserve_kg_check" CHECK ((planned_holding_reserve_kg > (0)::numeric)),
  CONSTRAINT "section9_game_flight_fuel_depart_departure_engine_event_id_fkey" FOREIGN KEY (departure_engine_event_id) REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
  CONSTRAINT "section9_game_flight_fuel_departu_departure_engine_event_id_key" UNIQUE (departure_engine_event_id),
  CONSTRAINT "section9_game_flight_fuel_departu_onboard_at_departure_kg_check" CHECK ((onboard_at_departure_kg > (0)::numeric)),
  CONSTRAINT "section9_game_flight_fuel_departur_planned_contingency_kg_check" CHECK ((planned_contingency_kg > (0)::numeric)),
  CONSTRAINT "section9_game_flight_fuel_departure__aircraft_inventory_id_fkey" FOREIGN KEY (aircraft_inventory_id) REFERENCES airlinerra_game.airline_aircraft_inventory(id),
  CONSTRAINT "section9_game_flight_fuel_departure__planned_trip_burn_kg_check" CHECK ((planned_trip_burn_kg > (0)::numeric)),
  CONSTRAINT "section9_game_flight_fuel_departure_fuel_custody_revision_check" CHECK ((fuel_custody_revision >= 1)),
  CONSTRAINT "section9_game_flight_fuel_departure_re_physical_flight_id_check" CHECK ((physical_flight_id ~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'::text)),
  CONSTRAINT "section9_game_flight_fuel_departure_receipts_v1_airline_id_fkey" FOREIGN KEY (airline_id) REFERENCES airlinerra_game.airlines(id),
  CONSTRAINT "section9_game_flight_fuel_departure_receipts_v1_check" CHECK ((minimum_planned_onboard_kg = ((planned_trip_burn_kg + planned_contingency_kg) + planned_holding_reserve_kg))),
  CONSTRAINT "section9_game_flight_fuel_departure_receipts_v1_check1" CHECK ((onboard_at_departure_kg >= minimum_planned_onboard_kg)),
  CONSTRAINT "section9_game_flight_fuel_departure_receipts_v1_pkey" PRIMARY KEY (physical_flight_id)
);
ALTER TABLE airlinerra_game."section9_game_flight_fuel_departure_receipts_v1" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game."section9_game_flight_fuel_departure_receipts_v1" FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS airlinerra_game."section9_game_flight_fuel_arrival_receipts_v1" (
  "physical_flight_id" text NOT NULL,
  "airline_id" uuid NOT NULL,
  "aircraft_inventory_id" uuid NOT NULL,
  "arrival_engine_event_id" text NOT NULL,
  "trip_burn_kg" numeric(14,3) NOT NULL,
  "onboard_after_arrival_kg" numeric(14,3) NOT NULL,
  "location_airport_key" text NOT NULL,
  "receipt_source" text NOT NULL DEFAULT 'signed_game_arrival_estimated_burn_v1'::text,
  "created_at" timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT "section9_game_flight_fuel_arriva_onboard_after_arrival_kg_check" CHECK ((onboard_after_arrival_kg >= (0)::numeric)),
  CONSTRAINT "section9_game_flight_fuel_arrival__arrival_engine_event_id_fkey" FOREIGN KEY (arrival_engine_event_id) REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
  CONSTRAINT "section9_game_flight_fuel_arrival_r_arrival_engine_event_id_key" UNIQUE (arrival_engine_event_id),
  CONSTRAINT "section9_game_flight_fuel_arrival_re_aircraft_inventory_id_fkey" FOREIGN KEY (aircraft_inventory_id) REFERENCES airlinerra_game.airline_aircraft_inventory(id),
  CONSTRAINT "section9_game_flight_fuel_arrival_recei_physical_flight_id_fkey" FOREIGN KEY (physical_flight_id) REFERENCES airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id),
  CONSTRAINT "section9_game_flight_fuel_arrival_receipts_receipt_source_check" CHECK ((receipt_source = 'signed_game_arrival_estimated_burn_v1'::text)),
  CONSTRAINT "section9_game_flight_fuel_arrival_receipts_v1_airline_id_fkey" FOREIGN KEY (airline_id) REFERENCES airlinerra_game.airlines(id),
  CONSTRAINT "section9_game_flight_fuel_arrival_receipts_v1_pkey" PRIMARY KEY (physical_flight_id),
  CONSTRAINT "section9_game_flight_fuel_arrival_receipts_v_trip_burn_kg_check" CHECK ((trip_burn_kg > (0)::numeric))
);
ALTER TABLE airlinerra_game."section9_game_flight_fuel_arrival_receipts_v1" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game."section9_game_flight_fuel_arrival_receipts_v1" FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 r record;custody record; fuel_model record;
 clock_proof jsonb;fuel jsonb;
 hours_old numeric;total_minutes integer;
 taxi_out_min integer;taxi_in_min integer;climb_min integer;descent_min integer;cruise_min integer;
 qty_trip numeric(14,3);qty_min numeric(14,3);
 source_valid boolean:=false;
 origin_can_supply boolean:=false;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FUEL_PREFLIGHT_TRUSTED_GAME_WORKER_ONLY';END IF;
 IF p_physical_flight_id IS NULL OR
  p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_GAME_FUEL_FLIGHT_ID';END IF;

 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;
 SELECT o.id AS occurrence_id,o.airline_id,o.schedule_id,o.aircraft_inventory_id,
   o.schedule_version,o.weekly_entry,o.flight_local_date,
   o.departure_utc,o.arrival_utc,o.origin_airport_key,o.destination_airport_key,
   o.verified_passenger_seats,o.booked_seats,o.booking_status,o.source_kind,
   s.version AS active_schedule_version,s.status AS active_schedule_status,
   s.operationally_verified,s.configuration_id,
   fleet.fleet_status,fleet.configuration_id AS fleet_configuration_id,
   cap.passenger_capacity,cap.passengers_held,cap.cargo_held_tonnes,
   cap.schedule_version AS cap_version,cap.departure_utc AS cap_departure,
   cap.arrival_utc AS cap_arrival
 INTO r
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=o.aircraft_inventory_id AND fleet.airline_id=o.airline_id
 LEFT JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
  ON cap.physical_flight_id=p_physical_flight_id AND cap.airline_id=o.airline_id
 WHERE o.world_id=1
  AND o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
  AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
  AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::integer;
 IF NOT FOUND OR r.active_schedule_status IS DISTINCT FROM 'active'
  OR r.operationally_verified IS DISTINCT FROM true
  OR r.active_schedule_version IS DISTINCT FROM r.schedule_version
  OR r.fleet_status IS DISTINCT FROM 'in_service'
  OR r.fleet_configuration_id IS DISTINCT FROM r.configuration_id
  OR r.source_kind IS DISTINCT FROM 'game_verified_saleable_schedule_v1'
  OR r.booking_status NOT IN ('open','closed')
  OR r.verified_passenger_seats IS NULL OR r.verified_passenger_seats<=0
  OR r.booked_seats>r.verified_passenger_seats
  OR r.passenger_capacity IS DISTINCT FROM r.verified_passenger_seats
  OR r.passengers_held<r.booked_seats
  OR r.passengers_held>r.passenger_capacity
  OR r.cargo_held_tonnes IS DISTINCT FROM 0
  OR r.cap_version IS DISTINCT FROM r.schedule_version
  OR r.cap_departure IS DISTINCT FROM r.departure_utc
  OR r.cap_arrival IS DISTINCT FROM r.arrival_utc
  OR r.arrival_utc<=r.departure_utc
 THEN RETURN jsonb_build_object('status','blocked_unverified_operating_flight',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);
 END IF;

 SELECT * INTO fuel_model
 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=r.configuration_id;
 IF NOT FOUND OR fuel_model.game_calculation_ready IS DISTINCT FROM true
 OR fuel_model.tank_capacity_kg IS NULL
 OR fuel_model.fuel_game_family IS NULL
 THEN RETURN jsonb_build_object('status','blocked_incomplete_game_aircraft_fuel_model',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;
 total_minutes:=ceil(extract(epoch from(r.arrival_utc-r.departure_utc))/60)::integer;
 IF total_minutes NOT BETWEEN 30 AND 1800 THEN
 RETURN jsonb_build_object('status','blocked_invalid_game_fuel_flight_duration',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;
 taxi_out_min:=least(9,greatest(3,floor(total_minutes*0.16)::integer));
 taxi_in_min:=least(6,greatest(3,floor(total_minutes*0.10)::integer));
 climb_min:=least(15,greatest(10,floor(total_minutes*0.22)::integer));
 descent_min:=least(15,greatest(10,floor(total_minutes*0.22)::integer));
 cruise_min:=total_minutes-taxi_out_min-taxi_in_min-climb_min-descent_min;
 IF cruise_min<1 THEN RETURN jsonb_build_object(
   'status','blocked_game_fuel_flight_too_short_for_phase_model',
   'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;

 fuel:=airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(
   r.configuration_id,
   round(r.booked_seats::numeric/r.verified_passenger_seats*100,2),
   taxi_out_min,climb_min,cruise_min,descent_min,taxi_in_min);
 IF fuel->>'status' IS DISTINCT FROM 'game_reserve_aware_fuel_estimate_only'
  OR fuel->>'fuelPlanningReserveIncluded' IS DISTINCT FROM 'true'
  OR fuel->>'withinGameTankIncludingReserve' IS DISTINCT FROM 'true'
  OR fuel->>'accountingApproved' IS DISTINCT FROM 'false'
  OR fuel->>'dispatchApproved' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object('status','blocked_fuel_tank_or_game_model',
  'gameOnly',true,'fuelVerifiedForGame',false,
  'quoteStatus',fuel->>'status',
  'withinGameTankIncludingReserve',fuel->>'withinGameTankIncludingReserve',
  'readOnly',true,'ledgerPosted',false);END IF;
 qty_trip:=(fuel->>'tripBurnKg')::numeric(14,3);
 qty_min:=(fuel->>'minimumPlannedFuelOnBoardKg')::numeric(14,3);
 IF qty_trip<=0 OR qty_min<=qty_trip THEN
 RAISE EXCEPTION USING ERRCODE='23514',
  MESSAGE='SECTION9_INVALID_FUEL_TRIP_AND_RESERVE_PROOF';END IF;

 -- The airport's generic fuel_available only indicates that *some* fuel
 -- service exists. It is not proof of this aircraft's fuel grade or balance.
 SELECT coalesce(fac.fuel_available,false) INTO origin_can_supply
 FROM airlinerra_game.airport_facilities fac
 WHERE fac.world_id=1 AND fac.airport_key=r.origin_airport_key;
 origin_can_supply:=coalesce(origin_can_supply,false);

 -- Lock the physical fuel balance until the dispatcher either records
 -- the signed departure and its fuel receipt or rolls back.
 SELECT * INTO custody
 FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1 c
 WHERE c.aircraft_inventory_id=r.aircraft_inventory_id
 AND c.airline_id=r.airline_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object(
   'status','blocked_missing_verified_aircraft_fuel_onboard',
   'physicalFlightId',p_physical_flight_id,
   'minimumPlannedFuelOnBoardKg',qty_min,
   'plannedTripBurnKg',qty_trip,
   'airportFuelServiceListed',origin_can_supply,
   'fuelOnBoardKnown',false,'fuelVerifiedForGame',false,
   'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF custody.configuration_id IS DISTINCT FROM r.configuration_id
 OR custody.world_id<>1
 OR custody.at_airport_key IS DISTINCT FROM r.origin_airport_key
 OR custody.fuel_game_family IS DISTINCT FROM fuel_model.fuel_game_family
 OR custody.onboard_kg>fuel_model.tank_capacity_kg
 OR custody.game_hour_utc>(clock_proof->>'gameHourUtc')::timestamptz
 THEN RETURN jsonb_build_object(
  'status','blocked_fuel_custody_location_configuration_or_clock_mismatch',
  'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;

 IF custody.source_event_kind='approved_game_fuel_load' THEN
  SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_approved_fuel_load_receipts_v1 t
   WHERE t.source_event_id=custody.source_event_id
   AND t.source_status='game_authority_approved'
   AND t.airline_id=custody.airline_id
   AND t.aircraft_inventory_id=custody.aircraft_inventory_id
   AND t.at_airport_key=custody.at_airport_key
   AND t.fuel_family=custody.fuel_game_family
   AND t.fuel_after_load_kg=custody.onboard_kg
   AND t.game_hour_utc=custody.game_hour_utc
   AND t.game_supplier_reference=custody.evidence_reference
  ) INTO source_valid;
 ELSIF custody.source_event_kind='signed_arrival_burn' THEN
  SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 a
   WHERE a.arrival_engine_event_id=custody.source_event_id
   AND a.airline_id=custody.airline_id
   AND a.aircraft_inventory_id=custody.aircraft_inventory_id
   AND a.location_airport_key=custody.at_airport_key
   AND a.onboard_after_arrival_kg=custody.onboard_kg
  ) INTO source_valid;
 END IF;
 IF source_valid IS DISTINCT FROM true THEN RETURN jsonb_build_object(
   'status','blocked_missing_authorized_fuel_custody_source',
   'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF custody.onboard_kg<qty_min THEN RETURN jsonb_build_object(
   'status','blocked_insufficient_aircraft_fuel_including_reserve',
   'physicalFlightId',p_physical_flight_id,
   'fuelOnBoardKg',custody.onboard_kg,
   'minimumPlannedFuelOnBoardKg',qty_min,
   'plannedTripBurnKg',qty_trip,
   'airportFuelServiceListed',origin_can_supply,
   'fuelVerifiedForGame',false,
   'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 d
  WHERE d.physical_flight_id=p_physical_flight_id
 ) THEN RETURN jsonb_build_object(
  'status','blocked_departure_fuel_proof_already_recorded',
  'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 RETURN jsonb_build_object(
 'status','verified_game_fuel_onboard_available_for_planned_trip',
 'physicalFlightId',p_physical_flight_id,
 'airlineId',r.airline_id,'aircraftInventoryId',r.aircraft_inventory_id,
 'originAirport',r.origin_airport_key,'destinationAirport',r.destination_airport_key,
 'configurationId',r.configuration_id,
 'fuelGameFamily',custody.fuel_game_family,
 'fuelCustodyRevision',custody.revision,
 'fuelSourceEventId',custody.source_event_id,
 'fuelOnBoardKg',custody.onboard_kg,
 'plannedTripBurnKg',qty_trip,
 'plannedContingencyKg',(fuel->>'contingencyKg')::numeric,
 'plannedHoldingReserveKg',(fuel->>'holdingReserveKg')::numeric,
 'minimumPlannedFuelOnBoardKg',qty_min,
 'tankCapacityKg',fuel_model.tank_capacity_kg,
 'fuelQuoteModelVersion',fuel->>'modelVersion',
 'airportFuelServiceListed',origin_can_supply,
 'fuelVerifiedForGame',true,'fuelGradeCertifiedForRealAircraft',false,
 'gameOnly',true,'readOnly',true,'ledgerPosted',false,
 'dispatchApprovedByThisCheck',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 proof jsonb;hour_proof jsonb;
 flight record;state record;model record;
 pos jsonb;auto_source text;
 event_id text;expected_qty numeric(14,3);
 prior_qty numeric(14,3):=0;
 add_qty numeric(14,3);
 supplied int;updated int;current_game_date date;
 v_enabled boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_GAME_ONLY_AUTOFUEL_TRUSTED_ENGINE_ONLY';END IF;
 IF p_physical_flight_id IS NULL
  OR p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_AUTO_FUEL_INVALID_PHYSICAL_FLIGHT_ID';END IF;
 -- Cannot allocate game fuel while World 1 operations are paused.
 SELECT (a.release_state='enabled' AND a.enabled_at IS NOT NULL
  AND a.crew_mode='deferred_phase1'
  AND e.release_state='enabled' AND e.enabled_at IS NOT NULL) INTO v_enabled
 FROM airlinerra_game.section9_activation_release_policy_v1 a
 JOIN airlinerra_game.section9_trusted_execution_release_policy_v1 e
 ON e.world_id=a.world_id WHERE a.world_id=1;
 IF v_enabled IS DISTINCT FROM true THEN
 RETURN jsonb_build_object('status','blocked_game_fuel_auto_supply_unreleased',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 SELECT o.airline_id,o.aircraft_inventory_id,o.origin_airport_key,
  o.departure_utc,o.flight_local_date,o.booking_status,o.source_kind,
  s.configuration_id,s.operationally_verified,s.status AS schedule_status,
  a.owner_player_id
 INTO flight
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
 ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.airlines a ON a.id=o.airline_id AND a.world_id=1
 WHERE o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
  AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
  AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::integer
  AND o.world_id=1;
 IF NOT FOUND OR flight.operationally_verified IS DISTINCT FROM true
 OR flight.schedule_status IS DISTINCT FROM 'active'
 OR flight.booking_status IS DISTINCT FROM 'open'
 OR flight.source_kind IS DISTINCT FROM 'game_verified_saleable_schedule_v1'
 OR flight.departure_utc>(hour_proof->>'gameHourUtc')::timestamptz+interval '7 days'
 OR flight.departure_utc<=(hour_proof->>'gameHourUtc')::timestamptz-interval '10 minutes'
 THEN RETURN jsonb_build_object('status','blocked_nonoperating_or_out_of_window_flight',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(
     583731,pg_catalog.hashtext(flight.aircraft_inventory_id::text))
 THEN RETURN jsonb_build_object('status','game_auto_fuel_aircraft_busy',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 proof:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id);
 IF proof->>'status'='verified_game_fuel_onboard_available_for_planned_trip'
 AND proof->>'fuelVerifiedForGame'='true'
 THEN RETURN jsonb_build_object('status','game_fuel_already_sufficient',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 IF proof->>'status' NOT IN (
  'blocked_missing_verified_aircraft_fuel_onboard',
  'blocked_insufficient_aircraft_fuel_including_reserve'
 ) THEN RETURN jsonb_build_object('status','blocked_game_fuel_preflight_evidence',
  'preflightStatus',proof->>'status',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 IF proof->>'airportFuelServiceListed' IS DISTINCT FROM 'true' THEN
 RETURN jsonb_build_object('status','blocked_no_game_airport_fuel_service',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 SELECT * INTO model FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=flight.configuration_id;
 IF NOT FOUND OR model.game_calculation_ready IS DISTINCT FROM true
 OR model.fuel_game_family IS NULL OR model.tank_capacity_kg<=0
 THEN RETURN jsonb_build_object('status','blocked_incomplete_game_fuel_model',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 expected_qty:=(proof->>'minimumPlannedFuelOnBoardKg')::numeric(14,3);
 IF expected_qty IS NULL OR expected_qty<=0
 OR expected_qty>model.tank_capacity_kg
 THEN RETURN jsonb_build_object('status','blocked_game_fuel_minimum_exceeds_tank',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 -- Starting custody may ONLY be created at the authoritative game
 -- starter airport. Once signed arrivals exist, all future refuelling
 -- must use the fuel custody location, not the player's home airport.
 SELECT * INTO state FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1
 WHERE aircraft_inventory_id=flight.aircraft_inventory_id
 AND airline_id=flight.airline_id FOR UPDATE;
 IF NOT FOUND THEN
   current_game_date:=((hour_proof->>'gameHourUtc')::timestamptz
    AT TIME ZONE 'Europe/Berlin')::date;
   pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(
     flight.owner_player_id,flight.airline_id,
     flight.aircraft_inventory_id,current_game_date);
   IF pos->>'verified' IS DISTINCT FROM 'true'
    OR pos->>'atGroundAirport' IS DISTINCT FROM 'true'
    OR pos->>'airportKey' IS DISTINCT FROM flight.origin_airport_key
    OR pos->>'status' IS DISTINCT FROM 'verified_original_game_starter_position'
   THEN RETURN jsonb_build_object('status','blocked_unverified_aircraft_fuel_starter_location',
     'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 ELSE
   prior_qty:=state.onboard_kg;
   IF state.at_airport_key IS DISTINCT FROM flight.origin_airport_key
    OR state.fuel_game_family IS DISTINCT FROM model.fuel_game_family
    OR state.configuration_id IS DISTINCT FROM flight.configuration_id
   THEN RETURN jsonb_build_object('status','blocked_fuel_custody_not_at_departure',
    'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 END IF;
 add_qty:=expected_qty-prior_qty;
 IF add_qty<=0 THEN
 RAISE EXCEPTION USING ERRCODE='23514',
  MESSAGE='SECTION9_AUTOFUEL_NONPOSITIVE_TOPUP_WITH_UNVERIFIED_CUSTODY';END IF;

 -- A game-only airport supplier receipt. This is NOT proof that the
 -- actual aircraft's installed engines or real fuel grade were certified.
 auto_source:='GAME_ONLY_AUTO_FUEL_SERVICE_V1_'||flight.origin_airport_key;
 event_id:='game-auto-fuel-v1-'||md5(p_physical_flight_id);
 INSERT INTO airlinerra_game.section9_game_approved_fuel_load_receipts_v1(
  source_event_id,airline_id,aircraft_inventory_id,at_airport_key,
  fuel_family,load_added_kg,fuel_after_load_kg,
  game_hour_utc,game_supplier_reference,source_status
 ) VALUES(event_id,flight.airline_id,flight.aircraft_inventory_id,
  flight.origin_airport_key,model.fuel_game_family,add_qty,expected_qty,
  (hour_proof->>'gameHourUtc')::timestamptz,
  auto_source,'game_authority_approved');
 GET DIAGNOSTICS supplied=ROW_COUNT;
 IF supplied<>1 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_DUPLICATE_GAME_FUEL_AUTO_SUPPLY_EVENT';END IF;
 IF state.aircraft_inventory_id IS NULL THEN
  INSERT INTO airlinerra_game.section9_aircraft_game_fuel_custody_v1(
   aircraft_inventory_id,airline_id,configuration_id,at_airport_key,
   fuel_game_family,onboard_kg,source_event_id,source_event_kind,
   evidence_reference,game_hour_utc,revision
  ) VALUES(flight.aircraft_inventory_id,flight.airline_id,
   flight.configuration_id,flight.origin_airport_key,
   model.fuel_game_family,expected_qty,event_id,'approved_game_fuel_load',
   auto_source,(hour_proof->>'gameHourUtc')::timestamptz,1);
 ELSE
  UPDATE airlinerra_game.section9_aircraft_game_fuel_custody_v1
  SET onboard_kg=expected_qty,
   source_event_id=event_id,source_event_kind='approved_game_fuel_load',
   evidence_reference=auto_source,
   game_hour_utc=(hour_proof->>'gameHourUtc')::timestamptz,
   revision=revision+1,recorded_at=clock_timestamp()
  WHERE aircraft_inventory_id=flight.aircraft_inventory_id
  AND airline_id=flight.airline_id AND revision=state.revision;
  GET DIAGNOSTICS updated=ROW_COUNT;
  IF updated<>1 THEN RAISE EXCEPTION USING ERRCODE='40001',
   MESSAGE='SECTION9_GAME_FUEL_TOPUP_CONCURRENT_CONFLICT';END IF;
 END IF;
 proof:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id);
 IF proof->>'status' IS DISTINCT FROM
   'verified_game_fuel_onboard_available_for_planned_trip'
 OR proof->>'fuelVerifiedForGame' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_GAME_AUTO_FUEL_NOT_VERIFIED_ROLLBACK';END IF;
 RETURN jsonb_build_object(
   'status','game_only_auto_fuel_supply_recorded',
   'physicalFlightId',p_physical_flight_id,
   'fuelTopUpKg',add_qty,'fuelOnBoardKg',expected_qty,
   'gameFuelFamily',model.fuel_game_family,
   'gameSupplySource',auto_source,
   'fuelVerifiedForGame',true,
   'realWorldFuelGradeCertified',false,
   'chargedNow',false,'ledgerPosted',false,
   'gameFuelSupplierEventCreated',true);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_capture_verified_departure_fuel_v1(p_physical_flight_id text, p_departure_engine_event_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 movement record;
 proof jsonb;
 custody record;
 existing record;
 inserted integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FUEL_DEPARTURE_TRUSTED_WORKER_ONLY';END IF;
 SELECT * INTO movement FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id
  AND engine_event_id=p_departure_engine_event_id
  AND phase='departed' AND world_id=1;
 IF NOT FOUND OR movement.source_kind IS DISTINCT FROM 'signed_operated_game_flight_v1'
 THEN RETURN jsonb_build_object('status','blocked_unsigned_departure_fuel_event',
  'fuelReceiptCreated',false,'ledgerPosted',false);END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF FOUND THEN
  IF existing.departure_engine_event_id IS DISTINCT FROM p_departure_engine_event_id
   OR existing.airline_id IS DISTINCT FROM movement.airline_id
   OR existing.aircraft_inventory_id IS DISTINCT FROM movement.aircraft_inventory_id
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_FUEL_DEPARTURE_RECEIPT_REPLAY_CHANGED';END IF;
  RETURN jsonb_build_object('status','game_fuel_departure_already_proven',
   'replayed',true,'fuelReceiptCreated',false,'ledgerPosted',false);
 END IF;
 proof:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(
   p_physical_flight_id);
 IF proof->>'status' IS DISTINCT FROM 'verified_game_fuel_onboard_available_for_planned_trip'
 OR proof->>'fuelVerifiedForGame' IS DISTINCT FROM 'true'
 OR proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR proof->>'airlineId' IS DISTINCT FROM movement.airline_id::text
 OR proof->>'aircraftInventoryId' IS DISTINCT FROM movement.aircraft_inventory_id::text
 OR proof->>'originAirport' IS DISTINCT FROM movement.origin_airport_key
 OR proof->>'destinationAirport' IS DISTINCT FROM movement.destination_airport_key
 THEN RETURN jsonb_build_object(
  'status','blocked_game_fuel_departure_evidence',
  'fuelPreflightStatus',proof->>'status',
  'fuelReceiptCreated',false,'ledgerPosted',false);END IF;
 SELECT * INTO custody FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1
 WHERE aircraft_inventory_id=movement.aircraft_inventory_id
 AND airline_id=movement.airline_id FOR UPDATE;
 IF NOT FOUND OR custody.revision IS DISTINCT FROM
   (proof->>'fuelCustodyRevision')::bigint
 OR custody.source_event_id IS DISTINCT FROM proof->>'fuelSourceEventId'
 OR custody.onboard_kg IS DISTINCT FROM (proof->>'fuelOnBoardKg')::numeric
 THEN RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_FUEL_CHANGED_AFTER_TRUSTED_PREFLIGHT';END IF;
 INSERT INTO airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(
 physical_flight_id,airline_id,aircraft_inventory_id,
 departure_engine_event_id,departure_airport_key,destination_airport_key,
 configuration_id,fuel_custody_source_event_id,fuel_custody_revision,
 onboard_at_departure_kg,planned_trip_burn_kg,
 planned_contingency_kg,planned_holding_reserve_kg,
 minimum_planned_onboard_kg,model_version,verified_game_hour_utc
 ) VALUES(
 p_physical_flight_id,movement.airline_id,movement.aircraft_inventory_id,
 movement.engine_event_id,movement.origin_airport_key,movement.destination_airport_key,
 (proof->>'configurationId')::bigint,proof->>'fuelSourceEventId',
 (proof->>'fuelCustodyRevision')::bigint,
 (proof->>'fuelOnBoardKg')::numeric,
 (proof->>'plannedTripBurnKg')::numeric,
 (proof->>'plannedContingencyKg')::numeric,
 (proof->>'plannedHoldingReserveKg')::numeric,
 (proof->>'minimumPlannedFuelOnBoardKg')::numeric,
 proof->>'fuelQuoteModelVersion',movement.actual_event_utc);
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF inserted<>1 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_DEPARTURE_FUEL_RECEIPT_NOT_ATOMIC';END IF;
 RETURN jsonb_build_object('status','signed_game_fuel_departure_receipt_created',
  'physicalFlightId',p_physical_flight_id,'fuelReceiptCreated',true,
  'plannedTripBurnKg',proof->'plannedTripBurnKg',
  'onboardAtDepartureKg',proof->'fuelOnBoardKg',
  'fuelAlreadyConsumed',false,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_capture_verified_departure_fuel_v1(text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(p_physical_flight_id text, p_arrival_engine_event_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 departure record;arrival record;fuel_custody record;receipt record;
 hour_proof jsonb;new_kg numeric(14,3);inserted int;updated int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_FUEL_ARRIVAL_TRUSTED_WORKER_ONLY';END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'fuelBurnRecorded',false,'ledgerPosted',false);END IF;
 SELECT * INTO departure FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id;
 SELECT * INTO arrival FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id
  AND engine_event_id=p_arrival_engine_event_id AND phase='arrived'
  AND world_id=1;
 IF departure.physical_flight_id IS NULL OR arrival.engine_event_id IS NULL
 OR arrival.source_kind IS DISTINCT FROM 'signed_operated_game_flight_v1'
 OR arrival.airline_id IS DISTINCT FROM departure.airline_id
 OR arrival.aircraft_inventory_id IS DISTINCT FROM departure.aircraft_inventory_id
 OR arrival.origin_airport_key IS DISTINCT FROM departure.departure_airport_key
 OR arrival.destination_airport_key IS DISTINCT FROM departure.destination_airport_key
 OR arrival.actual_event_utc>(hour_proof->>'gameHourUtc')::timestamptz
 OR NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.engine_event_id=departure.departure_engine_event_id
  AND m.phase='departed'
  AND m.flight_occurrence_id=p_physical_flight_id
  AND m.actual_event_utc<arrival.actual_event_utc)
 THEN RETURN jsonb_build_object('status','blocked_missing_signed_departure_or_arrival_fuel_proof',
  'fuelBurnRecorded',false,'ledgerPosted',false);END IF;
 SELECT * INTO receipt FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF FOUND THEN
  IF receipt.arrival_engine_event_id IS DISTINCT FROM arrival.engine_event_id
  OR receipt.aircraft_inventory_id IS DISTINCT FROM departure.aircraft_inventory_id
  OR receipt.airline_id IS DISTINCT FROM departure.airline_id
  OR receipt.trip_burn_kg IS DISTINCT FROM departure.planned_trip_burn_kg
  THEN RAISE EXCEPTION USING ERRCODE='23505',
    MESSAGE='SECTION9_ARRIVAL_FUEL_REPLAY_INCONSISTENT';END IF;
  RETURN jsonb_build_object('status','signed_game_fuel_burn_already_applied',
   'replayed',true,'fuelBurnRecorded',false,'ledgerPosted',false);
 END IF;
 SELECT * INTO fuel_custody FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1 c
 WHERE c.aircraft_inventory_id=departure.aircraft_inventory_id
 AND c.airline_id=departure.airline_id FOR UPDATE;
 IF NOT FOUND
 OR fuel_custody.revision IS DISTINCT FROM departure.fuel_custody_revision
 OR fuel_custody.source_event_id IS DISTINCT FROM departure.fuel_custody_source_event_id
 OR fuel_custody.onboard_kg IS DISTINCT FROM departure.onboard_at_departure_kg
 OR fuel_custody.at_airport_key IS DISTINCT FROM departure.departure_airport_key
 THEN RAISE EXCEPTION USING ERRCODE='40001',
    MESSAGE='SECTION9_FLIGHT_FUEL_CUSTODY_CHANGED_IN_TRANSIT_ROLLBACK';END IF;
 new_kg:=fuel_custody.onboard_kg-departure.planned_trip_burn_kg;
 IF new_kg<departure.planned_contingency_kg+departure.planned_holding_reserve_kg
 OR new_kg<0 THEN RAISE EXCEPTION USING ERRCODE='23514',
   MESSAGE='SECTION9_ARRIVAL_FUEL_RESERVE_BELOW_GAME_MINIMUM';END IF;

 INSERT INTO airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1(
 physical_flight_id,airline_id,aircraft_inventory_id,arrival_engine_event_id,
 trip_burn_kg,onboard_after_arrival_kg,location_airport_key
 ) VALUES(p_physical_flight_id,arrival.airline_id,arrival.aircraft_inventory_id,
 arrival.engine_event_id,departure.planned_trip_burn_kg,new_kg,arrival.destination_airport_key);
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF inserted<>1 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_ARRIVAL_FUEL_RECEIPT_NOT_WRITTEN';END IF;
 UPDATE airlinerra_game.section9_aircraft_game_fuel_custody_v1
 SET onboard_kg=new_kg,at_airport_key=arrival.destination_airport_key,
  source_event_id=arrival.engine_event_id,
  source_event_kind='signed_arrival_burn',
  evidence_reference='signed-game-arrival-burn:'||arrival.engine_event_id,
  game_hour_utc=arrival.actual_event_utc,revision=revision+1,
  recorded_at=clock_timestamp()
 WHERE aircraft_inventory_id=departure.aircraft_inventory_id
  AND airline_id=departure.airline_id
  AND revision=departure.fuel_custody_revision;
 GET DIAGNOSTICS updated=ROW_COUNT;
 IF updated<>1 THEN RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_ARRIVAL_FUEL_CUSTODY_NOT_ATOMIC_ROLLBACK';END IF;
 RETURN jsonb_build_object(
 'status','signed_game_arrival_fuel_burn_recorded_once',
 'physicalFlightId',p_physical_flight_id,
 'tripFuelBurnKg',departure.planned_trip_burn_kg,
 'onboardAfterArrivalKg',new_kg,
 'arrivedAirport',arrival.destination_airport_key,
 'fuelBurnRecorded',true,'replayed',false,
 'fuelChargePosted',false,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_actual_ticket_postarrival_finance_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 occurrence record;
 receipt record;
 arrival record;
 old record;
 review jsonb;
 quote jsonb;
 now_guard jsonb;
 actual_seats integer;
 ticket_income numeric(16,2);
 fuel_est numeric(16,2);
 airport_est numeric(16,2);
 total_est numeric(16,2);
 inserted integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_VERIFIED_ARRIVAL_PREPARATION_TRUSTED_WORKER_ONLY';
 END IF;
 IF p_physical_flight_id IS NULL
 OR p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ACTUAL_TICKET_FINANCE_PHYSICAL_FLIGHT_ID';END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(
  583729,pg_catalog.hashtext(p_physical_flight_id))
 THEN RETURN jsonb_build_object('status','finance_preparation_running',
   'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 SELECT o.id,o.schedule_id,o.airline_id,o.flight_local_date,o.weekly_entry,
   o.booked_seats,o.verified_passenger_seats,o.booking_status,o.source_kind,
   s.status AS schedule_status,s.operationally_verified,
   o.schedule_version,s.version AS current_schedule_version,
   cap.cargo_held_tonnes,cap.passengers_held
 INTO occurrence
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
  ON cap.physical_flight_id=p_physical_flight_id
  AND cap.schedule_id=o.schedule_id AND cap.airline_id=o.airline_id
 WHERE o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
 AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
 AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::int
 FOR SHARE OF o,s,cap;
 IF NOT FOUND OR occurrence.booking_status<>'closed'
 OR occurrence.source_kind<>'game_verified_saleable_schedule_v1'
 OR occurrence.schedule_status<>'active'
 OR occurrence.operationally_verified IS DISTINCT FROM true
 OR occurrence.schedule_version IS DISTINCT FROM occurrence.current_schedule_version
 OR occurrence.verified_passenger_seats IS NULL
 OR occurrence.verified_passenger_seats<1
 OR occurrence.booked_seats>occurrence.verified_passenger_seats
 OR occurrence.passengers_held<occurrence.booked_seats
 OR occurrence.cargo_held_tonnes IS DISTINCT FROM 0
 THEN RETURN jsonb_build_object('status','blocked_unverified_arrival_or_unsupported_cargo',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 SELECT r.* INTO receipt
 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 r
 WHERE r.physical_flight_id=p_physical_flight_id;
 SELECT m.* INTO arrival
 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.flight_occurrence_id=p_physical_flight_id
 AND m.phase='arrived';
 IF receipt.physical_flight_id IS NULL OR arrival.engine_event_id IS NULL
 OR receipt.airline_id<>occurrence.airline_id
 OR arrival.airline_id<>occurrence.airline_id
 OR receipt.arrived_engine_event_id<>arrival.engine_event_id
 OR receipt.source_kind<>'signed_operated_game_arrival_usage_v1'
 THEN RETURN jsonb_build_object('status','blocked_missing_signed_arrival_and_aircraft_usage',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 now_guard:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF now_guard->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR arrival.actual_event_utc>(now_guard->>'gameHourUtc')::timestamptz
 THEN RETURN jsonb_build_object('status','blocked_unverified_postarrival_game_hour',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 burn
  JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 takeoff
    ON takeoff.physical_flight_id=burn.physical_flight_id
  WHERE burn.physical_flight_id=p_physical_flight_id
    AND burn.arrival_engine_event_id=arrival.engine_event_id
    AND burn.airline_id=occurrence.airline_id
    AND takeoff.airline_id=occurrence.airline_id
    AND takeoff.planned_trip_burn_kg=burn.trip_burn_kg
    AND burn.onboard_after_arrival_kg>=0
 ) THEN RETURN jsonb_build_object(
   'status','blocked_missing_signed_flight_fuel_burn_receipt',
   'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1
 WHERE physical_flight_id=p_physical_flight_id)
 THEN RETURN jsonb_build_object('status','blocked_already_posted_do_not_prepare_twice',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 review:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(
  p_physical_flight_id);
 quote:=airlinerra_game.section9_completed_flight_game_cost_preview_v1(
  p_physical_flight_id);
 IF review->>'status' IS DISTINCT FROM 'postarrival_ticket_totals_reconciled'
 OR review->>'reconciled' IS DISTINCT FROM 'true'
 OR review->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR review->>'financeAlreadyPosted' IS DISTINCT FROM 'false'
 OR quote->>'status' IS DISTINCT FROM 'game_only_completed_flight_cost_estimate'
 OR quote->>'sourceVersion' IS DISTINCT FROM 'GAME_COST_PREVIEW_V1_NEVER_POST'
 OR quote->>'readOnly' IS DISTINCT FROM 'true'
 OR quote->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR quote->>'readyForActualExpensePosting' IS DISTINCT FROM 'false'
 OR quote->>'accountingApproved' IS DISTINCT FROM 'false'
 OR quote->>'fuelPlanningReserveIncluded' IS DISTINCT FROM 'true'
 OR quote->>'withinGameTankIncludingReserve' IS DISTINCT FROM 'true'
 OR quote->>'reserveFuelChargedAsBurn' IS DISTINCT FROM 'false'
 OR quote->>'feeLinesAreItemized' IS DISTINCT FROM 'true'
 OR jsonb_typeof(quote->'airportFeeLinesUsd') IS DISTINCT FROM 'object'
 OR (quote->>'airportCostEstimateUsd')::numeric IS NULL
 OR (SELECT round(sum(value::numeric),2)
      FROM jsonb_each_text(quote->'airportFeeLinesUsd'))
      IS DISTINCT FROM (quote->>'airportCostEstimateUsd')::numeric
 THEN RETURN jsonb_build_object('status','blocked_ticket_or_provisional_cost_evidence',
  'ticketProofStatus',review->>'status',
  'costProofStatus',quote->>'status',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 IF review->>'physicalFlightId' IS DISTINCT FROM p_physical_flight_id
 OR quote->>'physicalFlightId' IS DISTINCT FROM p_physical_flight_id
 OR (quote->>'bookedPassengers')::integer
   IS DISTINCT FROM (review->>'ticketPassengers')::integer
 OR (quote->>'quotedTicketFareUsd')::numeric
   IS DISTINCT FROM (review->>'ticketIncomeUsd')::numeric
 THEN RAISE EXCEPTION USING ERRCODE='23505',
 MESSAGE='SECTION9_POSTARRIVAL_TICKET_COST_PROOFS_DISAGREE';END IF;

 actual_seats:=(review->>'ticketPassengers')::integer;
 ticket_income:=(review->>'ticketIncomeUsd')::numeric(16,2);
 fuel_est:=(quote->>'fuelCostEstimateUsd')::numeric(16,2);
 airport_est:=(quote->>'airportCostEstimateUsd')::numeric(16,2);
 total_est:=(quote->>'operatingCostEstimateUsd')::numeric(16,2);
 IF actual_seats<>occurrence.booked_seats
 OR ticket_income<0 OR ticket_income>1000000000
 OR fuel_est<=0 OR fuel_est>100000000
 OR airport_est<0 OR airport_est>100000000
 OR total_est IS DISTINCT FROM fuel_est+airport_est
 THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_POSTARRIVAL_FINANCE_GAME_ESTIMATE_INCONSISTENT';END IF;
 INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1(
  physical_flight_id,airline_id,schedule_id,flight_local_date,
  arrival_event_id,aircraft_usage_receipt_flight_id,
  passenger_count,ticket_quote_usd,
  provisional_fuel_cost_usd,provisional_airport_cost_usd,
  provisional_operating_cost_usd,ticket_reconciliation_proof,
  provisional_game_cost_proof
 ) VALUES(
  p_physical_flight_id,occurrence.airline_id,occurrence.schedule_id,
  occurrence.flight_local_date,arrival.engine_event_id,receipt.physical_flight_id,
  actual_seats,ticket_income,fuel_est,airport_est,total_est,review,quote
 )
 ON CONFLICT(physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 SELECT * INTO old
 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF NOT FOUND OR old.airline_id IS DISTINCT FROM occurrence.airline_id
 OR old.schedule_id IS DISTINCT FROM occurrence.schedule_id
 OR old.flight_local_date IS DISTINCT FROM occurrence.flight_local_date
 OR old.arrival_event_id IS DISTINCT FROM arrival.engine_event_id
 OR old.aircraft_usage_receipt_flight_id IS DISTINCT FROM receipt.physical_flight_id
 OR old.passenger_count IS DISTINCT FROM actual_seats
 OR old.ticket_quote_usd IS DISTINCT FROM ticket_income
 OR old.provisional_fuel_cost_usd IS DISTINCT FROM fuel_est
 OR old.provisional_airport_cost_usd IS DISTINCT FROM airport_est
 OR old.provisional_operating_cost_usd IS DISTINCT FROM total_est
 OR old.ticket_reconciliation_proof IS DISTINCT FROM review
 OR old.provisional_game_cost_proof IS DISTINCT FROM quote
 OR old.preparation_status<>'UNPOSTED_GAME_ESTIMATE'
 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_REPLAYED_ACTUAL_FINANCE_PREPARATION_PROOF_CHANGED';END IF;
 RETURN jsonb_build_object(
  'status',CASE WHEN inserted=1 THEN 'actual_ticket_estimate_prepared'
   ELSE 'actual_ticket_estimate_replayed' END,
  'physicalFlightId',p_physical_flight_id,
  'passengers',actual_seats,
  'ticketIncomeEstimateUsd',ticket_income,
  'fuelCostEstimateUsd',fuel_est,
  'airportCostEstimateUsd',airport_est,
  'gameOperatingCostEstimateUsd',total_est,
  'created',inserted=1,'replayed',inserted=0,
  'source','SIGNED_ARRIVAL_BOOKED_TICKETS_PROVISIONAL_GAME_TARIFF',
  'requiresFuelAccountingRelease',true,
  'awaitsIndependentFinancialSettlement',true,
  'readyToPost',false,'ledgerPosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_prepare_actual_ticket_postarrival_finance_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1(p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 clock_proof jsonb;now_utc timestamptz;
 activation record;execution record;engine record;
 evt record;matches jsonb;candidate jsonb;
 maintenance jsonb;movement jsonb;airframe_usage jsonb;fuel_check jsonb;fuel_receipt jsonb;fuel_supply jsonb;
 permission_code text;movement_event_id text;
 signer_key text;payload text;event_signature text;
 used integer:=0;departures integer:=0;arrivals integer:=0;
 blocked integer:=0;reason text;warnings jsonb:='{}'::jsonb;
 changed integer:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_DISPATCH_POSTGRES_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_DISPATCH_LIMIT_INVALID';END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN
  RETURN jsonb_build_object('status','blocked_game_hour_not_verified',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 now_utc:=(clock_proof->>'gameHourUtc')::timestamptz;
 SELECT * INTO activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT * INTO execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO engine
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF activation.release_state IS DISTINCT FROM 'enabled'
 OR activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR activation.enabled_at IS NULL
 OR execution.release_state IS DISTINCT FROM 'enabled'
 OR execution.enabled_at IS NULL
 OR engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_flight_engine_release',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10041) THEN
  RETURN jsonb_build_object('status','flight_dispatch_already_running',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 SELECT decrypted_secret INTO signer_key FROM vault.decrypted_secrets
 WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF signer_key IS NULL OR length(signer_key)<64 THEN
  RETURN jsonb_build_object('status','blocked_missing_private_event_signer',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;

 FOR evt IN
  SELECT o.id AS occurrence_id,o.schedule_id,o.airline_id,
   o.aircraft_inventory_id,o.schedule_version,o.flight_local_date,
   o.weekly_entry,o.departure_utc,o.arrival_utc,o.booking_status,
   o.booked_seats,o.verified_passenger_seats,
   o.origin_airport_key,o.destination_airport_key,
   o.schedule_id::text||':'||o.flight_local_date::text||':'||
     o.weekly_entry::text physical_id,
   s.reference_departure_utc,s.reference_arrival_utc,
   s.version as schedule_version_current,s.configuration_id,
   fleet.fleet_status,fleet.ownership_type,fleet.configuration_id AS fleet_configuration,
   conf.use_type,
   airline.owner_player_id,
   a_home.country_iso as home_country,
   a_origin.country_iso as origin_country,
   a_dest.country_iso as destination_country,
   cap.passenger_capacity,cap.passengers_held,
   cap.schedule_version AS capacity_version,
   cap.commercial_version AS capacity_commercial_version,
   cap.departure_utc AS capacity_departure_utc,
   cap.arrival_utc AS capacity_arrival_utc,
   plan.version AS plan_version,
   phase.phase,phase.event_time,
   (
    SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
    WHERE c.schedule_id=o.schedule_id
    AND c.airline_id=o.airline_id
    AND c.schedule_version=o.schedule_version
    AND c.review_status='verified'
    AND c.valid_from_game_date<=o.flight_local_date
    AND c.valid_to_game_date>=o.flight_local_date
   ) as certification_count
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
   ON s.id=o.schedule_id AND s.airline_id=o.airline_id
    AND s.version=o.schedule_version AND s.status='active'
    AND s.operationally_verified=true
  JOIN airlinerra_game.airline_aircraft_inventory fleet
   ON fleet.id=o.aircraft_inventory_id
    AND fleet.airline_id=o.airline_id
  JOIN airlinerra.aircraft_catalog_configuration_inventory conf
   ON conf.configuration_id=s.configuration_id
  JOIN airlinerra_game.airlines airline ON airline.id=o.airline_id
  LEFT JOIN airlinerra_game.airport_reference_profiles a_home
   ON a_home.world_id=1 AND a_home.airport_key=airline.home_airport_key
  LEFT JOIN airlinerra_game.airport_reference_profiles a_origin
   ON a_origin.world_id=1 AND a_origin.airport_key=o.origin_airport_key
  LEFT JOIN airlinerra_game.airport_reference_profiles a_dest
   ON a_dest.world_id=1 AND a_dest.airport_key=o.destination_airport_key
  LEFT JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
   ON cap.physical_flight_id=o.schedule_id::text||':'||
      o.flight_local_date::text||':'||o.weekly_entry::text
  LEFT JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
   ON plan.schedule_id=o.schedule_id AND plan.airline_id=o.airline_id
  CROSS JOIN LATERAL(VALUES('departed'::text,o.departure_utc),
                            ('arrived'::text,o.arrival_utc)) phase(phase,event_time)
  WHERE o.world_id=1
   AND o.source_kind='game_verified_saleable_schedule_v1'
   AND o.booking_status IN('open','closed')
   AND phase.event_time>now_utc-interval '10 minutes'
   AND phase.event_time<=now_utc
   AND NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
    WHERE m.flight_occurrence_id=o.schedule_id::text||':'||
      o.flight_local_date::text||':'||o.weekly_entry::text
      AND m.phase=phase.phase)
  ORDER BY phase.event_time,o.schedule_id,o.flight_local_date,o.weekly_entry,phase.phase
  LIMIT p_limit
 LOOP
  used:=used+1;reason:=NULL;
  IF evt.owner_player_id IS NULL
   OR evt.fleet_status<>'in_service'
   OR evt.ownership_type NOT IN ('owned','leased')
   OR evt.fleet_configuration IS DISTINCT FROM evt.configuration_id
   OR evt.use_type<>'passenger'
   OR evt.reference_arrival_utc<=evt.reference_departure_utc
   OR evt.verified_passenger_seats IS NULL
   OR evt.verified_passenger_seats<1
   OR evt.booked_seats>evt.verified_passenger_seats
   OR evt.passenger_capacity IS DISTINCT FROM evt.verified_passenger_seats
   OR evt.passengers_held<evt.booked_seats
   OR evt.passengers_held>evt.passenger_capacity
   OR evt.capacity_version IS DISTINCT FROM evt.schedule_version
   OR evt.capacity_commercial_version IS DISTINCT FROM evt.plan_version
   OR evt.capacity_departure_utc IS DISTINCT FROM evt.departure_utc
   OR evt.capacity_arrival_utc IS DISTINCT FROM evt.arrival_utc
   OR evt.certification_count<5
   OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_schedule_activation_preparations_v1 prep
    WHERE prep.schedule_id=evt.schedule_id
    AND prep.schedule_version=evt.schedule_version
    AND prep.airline_id=evt.airline_id
    AND prep.aircraft_inventory_id=evt.aircraft_inventory_id
    AND prep.verified_game_date<=evt.flight_local_date
    AND prep.verified_game_date+prep.certified_horizon_days>=evt.flight_local_date
    AND prep.fingerprint_md5~'^[a-f0-9]{32}$'
    AND length(prep.release_reference)>=12)
  THEN reason:='INCOMPLETE_CERTIFIED_OPERATING_SCHEDULE';END IF;
  IF reason IS NULL AND (
     NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slots
       WHERE slots.schedule_id=evt.schedule_id
        AND slots.airport_key=evt.origin_airport_key AND slots.direction='departure')
     OR NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slots
       WHERE slots.schedule_id=evt.schedule_id
        AND slots.airport_key=evt.destination_airport_key AND slots.direction='arrival')
  ) THEN reason:='AIRPORT_SLOTS_NOT_RESERVED';END IF;
  IF reason IS NULL AND NOT EXISTS(
     SELECT 1 FROM airlinerra_game.section9_operator_licence_evidence_v1 lic
     JOIN airlinerra_game.section9_game_permission_applications_v1 a
       ON a.id=lic.issued_application_id
        AND a.airline_id=lic.airline_id
        AND a.status='issued'
        AND a.permission_code='AIR_OPERATOR_CERTIFICATE'
        AND a.ledger_entry_id IS NOT NULL
        AND a.issued_game_date=lic.valid_from
        AND a.valid_until_game_date=lic.valid_until
     WHERE lic.world_id=1 AND lic.airline_id=evt.airline_id
      AND lic.jurisdiction_iso2=evt.home_country
      AND lic.evidence_status='verified'
      AND lic.valid_from<=evt.flight_local_date
      AND lic.valid_until>=evt.flight_local_date
      AND lic.evidence_reference='game-permission-issued-v1-'||a.id::text
  ) THEN reason:='ISSUED_OPERATOR_GAME_LICENCE_MISSING';END IF;
  IF reason IS NULL THEN
   permission_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
    evt.home_country,evt.origin_country,evt.destination_country,
    'passenger',evt.flight_local_date);
   IF permission_code IS NULL OR NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_route_operating_permission_evidence_v1 r
    JOIN airlinerra_game.section9_game_permission_applications_v1 a
     ON a.id=r.issued_application_id
      AND a.airline_id=r.airline_id
      AND a.status='issued'
      AND a.ledger_entry_id IS NOT NULL
      AND a.permission_code=permission_code
      AND a.issued_game_date=r.valid_from
      AND a.valid_until_game_date=r.valid_until
    WHERE r.world_id=1 AND r.airline_id=evt.airline_id
     AND r.origin_airport_key=evt.origin_airport_key
     AND r.destination_airport_key=evt.destination_airport_key
     AND r.service_type='passenger'
     AND r.evidence_status='verified'
     AND r.valid_from<=evt.flight_local_date
     AND r.valid_until>=evt.flight_local_date
     AND r.evidence_reference='game-permission-issued-v1-'||a.id::text)
    THEN reason:='ISSUED_ROUTE_GAME_RIGHTS_MISSING';END IF;
  END IF;
  IF reason IS NULL AND evt.phase='departed' THEN
   maintenance:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(
      evt.owner_player_id,evt.airline_id,evt.aircraft_inventory_id,
      evt.departure_utc,evt.arrival_utc);
   IF maintenance->>'gameMaintenanceClear' IS DISTINCT FROM 'true'
   THEN reason:='GAME_MAINTENANCE_DISPATCH_BLOCKED';END IF;
  END IF;
  -- Fuel must already exist on this exact game aircraft, at this
  -- exact departure airport, backed by an approved game-source receipt
  -- or signed prior arrival. Generic airport fuel_available is insufficient.
  IF reason IS NULL AND evt.phase='departed' THEN
    -- A trusted GAME-ONLY airport supply fills a verified fuel gap when
    -- the airplane is on the authoritative game ground airport. No
    -- client payment, no real-world fuel certification, no ledger charge.
    fuel_supply:=airlinerra_game.section9_auto_supply_game_only_fuel_v1(
       evt.physical_id);
    IF fuel_supply->>'status' NOT IN
      ('game_only_auto_fuel_supply_recorded','game_fuel_already_sufficient')
      OR fuel_supply->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN
      reason:='GAME_AIRPORT_FUEL_TOPUP_NOT_AVAILABLE';
    ELSE
      fuel_check:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(
        evt.physical_id);
      IF fuel_check->>'status' IS DISTINCT FROM
          'verified_game_fuel_onboard_available_for_planned_trip'
        OR fuel_check->>'fuelVerifiedForGame' IS DISTINCT FROM 'true'
        OR fuel_check->>'ledgerPosted' IS DISTINCT FROM 'false'
      THEN reason:='AIRCRAFT_FUEL_NOT_PROVEN_AT_ORIGIN';END IF;
    END IF;

  END IF;
  IF reason IS NULL AND evt.phase='arrived' AND
     NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
      WHERE m.flight_occurrence_id=evt.physical_id AND m.phase='departed')
  THEN reason:='ARRIVAL_WITHOUT_VERIFIED_DEPARTURE';END IF;
  IF reason IS NULL THEN
   matches:=airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
     evt.airline_id,evt.aircraft_inventory_id,
     (evt.event_time AT TIME ZONE 'UTC')::date);
   IF matches->>'status' IS DISTINCT FROM 'verified_operational_candidates_only'
    OR jsonb_typeof(matches->'candidates')<>'array'
   THEN reason:='VERIFIED_AIRCRAFT_DAY_EVENTS_MISSING';
   ELSE
    candidate:=NULL;
    SELECT value INTO candidate
    FROM jsonb_array_elements(matches->'candidates') c(value)
    WHERE c.value->>'scheduleId'=evt.schedule_id::text
     AND c.value->>'scheduleVersion'=evt.schedule_version::text
     AND c.value->>'flightLocalDate'=evt.flight_local_date::text
     AND c.value->>'weeklyEntry'=evt.weekly_entry::text
     AND c.value->>'phase'=evt.phase
     AND (c.value->>'scheduledEventUtc')::timestamptz=evt.event_time
    LIMIT 1;
    IF candidate IS NULL THEN
     reason:='SIGNED_AIRCRAFT_TIMETABLE_MISMATCH';END IF;
   END IF;
  END IF;
  IF reason IS NOT NULL THEN
    blocked:=blocked+1;
    warnings:=jsonb_set(warnings,ARRAY[reason],
      to_jsonb(coalesce((warnings->>reason)::integer,0)+1),true);
    CONTINUE;
  END IF;
  movement_event_id:=candidate->>'eventId';
  IF movement_event_id IS NULL OR length(movement_event_id) NOT BETWEEN 12 AND 128
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_INVALID_VERIFIED_DISPATCH_EVENT_ID';END IF;
  payload:=concat_ws(E'\n',
   'airlinerra-operated-game-event-v1','1',evt.airline_id::text,
   evt.schedule_id::text,evt.schedule_version::text,
   evt.flight_local_date::text,evt.weekly_entry::text,evt.phase,
   to_char(evt.event_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
   movement_event_id);
  event_signature:=encode(extensions.hmac(
   pg_catalog.convert_to(payload,'UTF8'),
   pg_catalog.convert_to(signer_key,'UTF8'),'sha256'),'hex');
  movement:=airlinerra_game.section9_record_signed_operated_flight_movement_v1(
   evt.airline_id,evt.schedule_id,evt.schedule_version,
   evt.flight_local_date,evt.weekly_entry,evt.phase,
   evt.event_time,movement_event_id,event_signature);
  IF movement->>'movementRecorded' IS DISTINCT FROM 'true'
   OR movement->>'replayed' IS DISTINCT FROM 'false'
   OR movement->>'ledgerPosted' IS DISTINCT FROM 'false'
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_AUTOMATIC_DISPATCH_MOVEMENT_NOT_CONFIRMED_ROLLBACK';END IF;
  IF evt.phase='departed' THEN
    fuel_receipt:=airlinerra_game.section9_capture_verified_departure_fuel_v1(
      evt.physical_id,movement_event_id);
    IF fuel_receipt->>'status' IS DISTINCT FROM
       'signed_game_fuel_departure_receipt_created'
      OR fuel_receipt->>'fuelReceiptCreated' IS DISTINCT FROM 'true'
      OR fuel_receipt->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='SECTION9_UNVERIFIED_DEPARTURE_FUEL_ROLLS_BACK_MOVEMENT';END IF;
    UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
    SET booking_status='closed' WHERE id=evt.occurrence_id
      AND booking_status='open';
    GET DIAGNOSTICS changed=ROW_COUNT;
    IF changed<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
       MESSAGE='SECTION9_DEPARTURE_BOOKING_CLOSE_UNCONFIRMED_ROLLBACK';END IF;
    departures:=departures+1;
  ELSE
    airframe_usage:=airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(
      evt.physical_id);
    IF airframe_usage->>'status' IS DISTINCT FROM 'arrived_airframe_usage_recorded_once'
    OR airframe_usage->>'usageApplied' IS DISTINCT FROM 'true'
    OR airframe_usage->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
       MESSAGE='SECTION9_ARRIVAL_AIRFRAME_USAGE_NOT_ATOMIC_ROLLBACK';END IF;
    fuel_receipt:=airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(
      evt.physical_id,movement_event_id);
    IF fuel_receipt->>'status' IS DISTINCT FROM
        'signed_game_arrival_fuel_burn_recorded_once'
      OR fuel_receipt->>'fuelBurnRecorded' IS DISTINCT FROM 'true'
      OR fuel_receipt->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='SECTION9_UNVERIFIED_ARRIVAL_FUEL_ROLLS_BACK_MOVEMENT';END IF;
    arrivals:=arrivals+1;
  END IF;
 END LOOP;
 RETURN jsonb_build_object(
   'status','trusted_game_dispatch_cycle_completed',
   'verifiedGameHourUtc',now_utc,
   'candidatesChecked',used,
   'departuresRecorded',departures,'arrivalsRecorded',arrivals,
   'blocked',blocked,'blockerCounts',warnings,
   'signingSecretExposed',false,
   'ticketRevenueRecognized',false,'ledgerPosted',false,
   'actualFuelSettlementConnected',false,'gameFuelCustodyTrackingConnected',true);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer) FROM PUBLIC,anon,authenticated,service_role;