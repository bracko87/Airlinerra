-- World 1 Section 8 game airline fee acceptance; no persistent changes.
-- Executable before release (within same rollback transaction as migration)
-- or afterward as standalone regression. Never alters airline ledger.
BEGIN;
DO $test$
DECLARE t jsonb;r jsonb;short jsonb;long jsonb;free jsonb;cargo jsonb;
 n integer;cash_before bigint;bad boolean;
BEGIN
 SELECT count(*) INTO n FROM airlinerra_game.section8_airport_operating_tariffs_v1;
 IF n<>3141 THEN RAISE EXCEPTION 'FEE_COVERAGE %',n;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section8_fee_category_policy_v1)<>6
 THEN RAISE EXCEPTION 'MISSING_SIX_GAME_CATEGORIES';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section8_repriced_airport_fee_audit_v1
     WHERE new_row IS NOT NULL AND prior_row IS NOT NULL)<>90
 OR (SELECT count(*) FROM airlinerra_game.airport_game_fees
     WHERE world_id=1 AND price_model_version LIKE '%pending_section8%')<>0
 THEN RAISE EXCEPTION 'AUDITED_TIER_REPRICING_UNFINISHED';END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.section8_airport_operating_tariffs_v1
   WHERE terminal_stand_multiplier<=remote_stand_multiplier
    OR cargo_handling_per_tonne_usd<=0
    OR terminal_navigation_unit_usd<=0
    OR new_service_background_factor<1
    OR landing_base_for_reference_aircraft_usd<=0)
 THEN RAISE EXCEPTION 'BAD_TERMINAL_REMOTE_OR_CARGO_PRICE';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section8_airport_operating_tariffs_v1
     WHERE game_airport_background='tourism'
      AND new_service_background_factor=1.10)<>1112
 THEN RAISE EXCEPTION 'TOURIST_GAME_FEE_PREMIUM_MISSING';END IF;
 IF (SELECT landing_base_for_reference_aircraft_usd
    FROM airlinerra_game.section8_airport_operating_tariffs_v1
    WHERE airport_key='OURAIRPORTS:5235')<=3000
 THEN RAISE EXCEPTION 'DXB_CATEGORY_REPRICE_STILL_UNDONE';END IF;
 SELECT count(*) INTO cash_before FROM airlinerra_game.airline_ledger;

 t:=airlinerra_game.section8_quote_flight_operating_fees_v1(
  1,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,'terminal','terminal',100,0,180);
 r:=airlinerra_game.section8_quote_flight_operating_fees_v1(
  1,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,'remote','remote',100,0,180);
 free:=airlinerra_game.section8_quote_flight_operating_fees_v1(
  1,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,'terminal','terminal',100,0,60);
 IF t->>'status'<>'game_operating_fee_preview_only'
 OR (t->>'fuelIncluded')::boolean OR
 (t->>'cashPosted')::boolean OR (t->>'canPostToLedger')::boolean OR
 (t->>'operationAuthorized')::boolean OR
 (t->>'isOfficialAviationTariff')::boolean
 OR (t->>'aircraftMtowKg')::numeric<>82190
 THEN RAISE EXCEPTION 'PREVIEW_SAFETY_OR_MASS_WRONG: %',t;END IF;
 IF (t->'fees'->>'departureGroundHandlingUsd')::numeric<=
    (r->'fees'->>'departureGroundHandlingUsd')::numeric
 OR (t->'fees'->>'arrivalStandParkingUsd')::numeric<=
    (r->'fees'->>'arrivalStandParkingUsd')::numeric
 OR (t->>'totalGameOperatingFeesUsd')::numeric<=
    (r->>'totalGameOperatingFeesUsd')::numeric
 THEN RAISE EXCEPTION 'TERMINAL_STAND_NOT_MORE_EXPENSIVE';END IF;
 IF (free->'fees'->>'arrivalStandParkingUsd')::numeric<>0 OR
    (t->'fees'->>'arrivalStandParkingUsd')::numeric<=0
 THEN RAISE EXCEPTION 'PARKING_GRACE_PERIOD_WRONG';END IF;
 IF (t->'fees'->>'departureTerminalAirTrafficControlUsd')::numeric<=0 OR
    (t->'fees'->>'enrouteAirTrafficControlUsd')::numeric<=0 OR
    (t->'fees'->>'internationalPassengerProcessingUsd')::numeric<=0 OR
    (t->'fees'->>'departingPassengerFacilityUsd')::numeric<=0 OR
    (t->'fees'->>'departureAirportMovementUsd')::numeric<=0 OR
    (t->'fees'->>'arrivalLandingUsd')::numeric<=0 OR
    (t->'fees'->>'departingPassengerSecurityUsd')::numeric<=0
 THEN RAISE EXCEPTION 'MISSING_REQUIRED_COST_LINE';END IF;
 IF (t->'fees'->>'originCargoHandlingUsd')::numeric<>0 OR
   (t->'fees'->>'destinationCargoHandlingUsd')::numeric<>0
 THEN RAISE EXCEPTION 'EMPTY_FREIGHT_CREATED_CARGO_CHARGE';END IF;

 short:=airlinerra_game.section8_quote_flight_operating_fees_v1(
  1,'OURAIRPORTS:2212','OURAIRPORTS:2218',2,'terminal','terminal',100,0,180);
 long:=airlinerra_game.section8_quote_flight_operating_fees_v1(
  1,'OURAIRPORTS:2212','OURAIRPORTS:3622',2,'terminal','terminal',100,0,180);
 IF (short->>'international')::boolean
 OR NOT (long->>'international')::boolean
 OR (short->'fees'->>'internationalPassengerProcessingUsd')::numeric<>0 OR
 (long->'fees'->>'enrouteAirTrafficControlUsd')::numeric<=
   (short->'fees'->>'enrouteAirTrafficControlUsd')::numeric
 THEN RAISE EXCEPTION 'INTERNATIONAL_AND_ROUTE_DISTANCES_WRONG';END IF;

 cargo:=airlinerra_game.section8_quote_flight_operating_fees_v1(
  1,'OURAIRPORTS:2212','OURAIRPORTS:4013',4,'cargo','cargo',0,2.0,180);
 IF (cargo->'fees'->>'originCargoHandlingUsd')::numeric<=0 OR
    (cargo->'fees'->>'destinationCargoHandlingUsd')::numeric<=0 OR
    (cargo->'fees'->>'departingPassengerFacilityUsd')::numeric<>0 OR
    (cargo->'fees'->>'departingPassengerSecurityUsd')::numeric<>0 OR
    (cargo->>'fuelIncluded')::boolean
 THEN RAISE EXCEPTION 'CARGO_ONLY_QUOTE_BAD: %',cargo;END IF;

 bad:=false;
 BEGIN
  PERFORM airlinerra_game.section8_quote_flight_operating_fees_v1(
    1,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,
    'remote','remote',1000,0,180);
 EXCEPTION WHEN SQLSTATE '22023' THEN bad:=true;END;
 IF NOT bad THEN RAISE EXCEPTION 'OVER_CAPACITY_PREVIEW_ALLOWED';END IF;
 bad:=false;
 BEGIN
  PERFORM airlinerra_game.section8_quote_flight_operating_fees_v1(
    1,'OURAIRPORTS:2212','OURAIRPORTS:4013',4,
    'cargo','cargo',0,20,180);
 EXCEPTION WHEN SQLSTATE '22023' THEN bad:=true;END;
 IF NOT bad THEN RAISE EXCEPTION 'OVER_CAPACITY_CARGO_PREVIEW_ALLOWED';END IF;
 bad:=false;
 BEGIN
  PERFORM airlinerra_game.section8_quote_flight_operating_fees_v1(
    1,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,
    'madeup_stand','remote',100,0,180);
 EXCEPTION WHEN SQLSTATE '22023' THEN bad:=true;END;
 IF NOT bad THEN RAISE EXCEPTION 'UNKNOWN_STAND_ACCEPTED';END IF;
 bad:=false;
 BEGIN
  PERFORM airlinerra_game.section8_quote_flight_operating_fees_v1(
    1,'OURAIRPORTS:2212','OURAIRPORTS:4013',99999999,
    'terminal','terminal',100,0,180);
 EXCEPTION WHEN SQLSTATE '22023' THEN bad:=true;END;
 IF NOT bad THEN RAISE EXCEPTION 'MADEUP_AIRCRAFT_ACCEPTED';END IF;
 bad:=false;
 BEGIN
  PERFORM airlinerra_game.section8_quote_flight_operating_fees_v1(
    1,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,
    'terminal','terminal',100,-1,180);
 EXCEPTION WHEN SQLSTATE '22023' THEN bad:=true;END;
 IF NOT bad THEN RAISE EXCEPTION 'NEGATIVE_CARGO_ACCEPTED';END IF;

 IF cash_before<>(SELECT count(*) FROM airlinerra_game.airline_ledger)
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 OR (SELECT status FROM airlinerra_game.airport_data_master_categories
   WHERE category_number=8)<>'game_complete_estimated'
 OR (SELECT live_operations_certified FROM
    airlinerra_game.world1_game_data_section_acceptance_v1
    WHERE world_id=1 AND category_number=8)
 THEN RAISE EXCEPTION 'SECTION8_FINANCES_OR_LIVE_WORLD_CHANGED';END IF;
 RAISE NOTICE 'PASS Section8: 3141 airports, 90 rebalanced, tourist/terminal/cargo/ATC/route fees, quote fail-closed, 0 ledger writes';
END $test$;
ROLLBACK;
