-- Section 9 route finance: rollback-only full occupancy, load and
-- eight SYNTHETIC posted-flight ledger snapshots. Not real flights!
BEGIN;
DO $test$
DECLARE v_airline uuid;v_player uuid;v_aircraft uuid;v_schedule uuid;
 v jsonb;w jsonb;flight text;event text;
 rev_id bigint;cost_id bigint;i integer;
 before_ledger bigint;before_moves bigint;before_schedules bigint;
BEGIN
 SELECT a.id,a.owner_player_id INTO v_airline,v_player
 FROM airlinerra_game.airlines a WHERE a.world_id=1 LIMIT 1;
 IF v_airline IS NULL THEN RAISE EXCEPTION 'NO_AIRLINE_TEST_OWNER';END IF;
 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO before_moves FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO before_schedules FROM airlinerra_game.airline_flight_schedule_drafts_v1;
 IF has_table_privilege('anon',
  'airlinerra_game.section9_route_posted_flight_financials_v1','SELECT')
 OR has_table_privilege('authenticated',
  'airlinerra_game.section9_route_posted_flight_financials_v1','INSERT')
 OR has_function_privilege('anon',
  'airlinerra_game.section9_owned_route_financial_dashboard_v1(uuid,uuid,uuid,integer,integer)',
  'EXECUTE')
 THEN RAISE EXCEPTION 'ROUTE_FINANCIAL_PRIVACY_FAILED';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
 airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(v_airline,2,'ROUTE-FIN-ROLLBACK','owned','in_service')
 RETURNING id INTO v_aircraft;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
 airline_id,aircraft_inventory_id,configuration_id,flight_number,
 origin_airport_key,destination_airport_key,
 reference_departure_utc,reference_arrival_utc,
 weekly_schedule,restriction_snapshot,created_by_player_id,
 departure_stand_type,arrival_stand_type)
 VALUES(v_airline,v_aircraft,2,'QZ959',
  'OURAIRPORTS:2212','OURAIRPORTS:4013',
  '2000-01-03T09:00:00Z','2000-01-03T11:00:00Z',
  '[{"day":0,"time":"09:00"}]'::jsonb,'{}'::jsonb,v_player,
  'terminal','terminal') RETURNING id INTO v_schedule;
 v:=airlinerra_game.section9_owned_route_financial_dashboard_v1(
  v_player,v_airline,v_schedule,100,180);
 IF v->>'status'<>'route_financial_dashboard_read_only' OR
   v->>'cashPosted'<>'false' OR
   v->'history'->>'completedFlightCount'<>'0' OR
   v->'estimate'->>'potentialRevenueUsd' IS NOT NULL OR
   v->'estimate'->>'partialMarginBeforeOtherCostsUsd' IS NOT NULL OR
   (v->'estimate'->>'passengers')::integer<>197
 THEN RAISE EXCEPTION 'NO_FARE_RESULT_NOT_FAIL_CLOSED: %',v;END IF;
 INSERT INTO airlinerra_game.section9_route_commercial_plans_v1(
 schedule_id,airline_id,economy_fare_usd,cargo_rate_usd_per_tonne,
 marketing_budget_usd_per_day)
 VALUES(v_schedule,v_airline,150,0,0);
 v:=airlinerra_game.section9_owned_route_financial_dashboard_v1(
  v_player,v_airline,v_schedule,100,180);
 IF (v->'estimate'->>'passengers')::integer<>197 OR
   (v->'estimate'->>'potentialRevenueUsd')::numeric<>29550 OR
   (v->'estimate'->>'knownAirportNavigationCostsUsd')::numeric<>14306.25 OR
   (v->'estimate'->>'partialMarginBeforeOtherCostsUsd')::numeric<>15243.75 OR
   (v->'estimate'->'airportFeeQuote'->>'fuelIncluded')::boolean
 THEN RAISE EXCEPTION 'FULL_LOAD_FORECAST_WRONG: %',v->'estimate';END IF;
 w:=airlinerra_game.section9_owned_route_financial_dashboard_v1(
  v_player,v_airline,v_schedule,50,60);
 IF (w->'estimate'->>'passengers')::integer<>99 OR
  (w->'estimate'->'airportFeeQuote'->'fees'->>'arrivalStandParkingUsd')::numeric<>0
 THEN RAISE EXCEPTION 'LOAD_OR_PARKING_SENSITIVITY_WRONG';END IF;
 BEGIN
  PERFORM airlinerra_game.section9_owned_route_financial_dashboard_v1(
   '11111111-1111-4111-8111-111111111111',
   v_airline,v_schedule,100,180);
  RAISE EXCEPTION 'CROSS_ACCOUNT_FINANCIAL_ACCESS';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN
  PERFORM airlinerra_game.section9_owned_route_financial_dashboard_v1(
   v_player,v_airline,v_schedule,101,180);
  RAISE EXCEPTION 'OVER_100_LOAD_ACCEPTED';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN
  PERFORM airlinerra_game.section9_owned_route_financial_dashboard_v1(
   v_player,v_airline,v_schedule,100,-1);
  RAISE EXCEPTION 'NEGATIVE_PARKING_ACCEPTED';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 -- Eight synthetic arrivals and matching +/- ledgers inside ROLLBACK.
 FOR i IN 0..7 LOOP
  flight:=v_schedule::text||':'||
   (DATE '2000-01-03'+i)::text||':1';
  event:='route-finance-rollback-arrived-'||i::text;
  INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(
   engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,
   schedule_id,schedule_version,weekly_entry,flight_local_date,
   flight_occurrence_id,phase,
   origin_airport_key,destination_airport_key,
   scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
  VALUES(event,repeat('a',64),v_airline,v_aircraft,v_schedule,1,1,
   DATE '2000-01-03'+i,flight,'arrived',
   'OURAIRPORTS:2212','OURAIRPORTS:4013',
   '2000-01-03T09:00:00Z'::timestamptz+make_interval(days=>i),
   '2000-01-03T11:00:00Z'::timestamptz+make_interval(days=>i),
   '2000-01-03T11:00:00Z'::timestamptz+make_interval(days=>i));
  INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
   VALUES(v_airline,'REVENUE',20000+i) RETURNING id INTO rev_id;
  INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
   VALUES(v_airline,'EXPENSE',-10000) RETURNING id INTO cost_id;
  INSERT INTO airlinerra_game.section9_route_posted_flight_financials_v1(
   physical_flight_id,schedule_id,airline_id,flown_game_day,
   arrived_event_id,passenger_count,cargo_tonnes,ticket_income_usd,
   cargo_income_usd,airport_navigation_cost_usd,fuel_cost_usd,
   crew_cost_usd,maintenance_cost_usd,ownership_cost_usd,
   airport_fee_lines,revenue_ledger_id,expense_ledger_id,
   tariff_model_version,settlement_source_reference)
  VALUES(flight,v_schedule,v_airline,DATE '2000-01-03'+i,
   event,100,0,20000+i,0,5000,2000,1000,1000,1000,
   '{"departureAirportMovementUsd":300,"arrivalLandingUsd":1000}'::jsonb,
   rev_id,cost_id,'section8_airline_operating_fees_game_v1_20261109',
   'ROLLBACK_TEST_RECONCILED_POSTED_FINANCE');
 END LOOP;
 v:=airlinerra_game.section9_owned_route_financial_dashboard_v1(
  v_player,v_airline,v_schedule,100,180);
 IF (v->'history'->>'completedFlightCount')::integer<>8 OR
   (v->'history'->>'olderFlightCount')::integer<>1 OR
   jsonb_array_length(v->'history'->'lastSevenFlights')<>7 OR
   (v->'history'->>'totalProfitLossUsd')::numeric<>80028 OR
   (v->'history'->>'olderProfitLossUsd')::numeric<>10000 OR
   (v->'history'->'lastSevenFlights'->0->>'gameDate')<>'2000-01-10' OR
   (v->'history'->'lastSevenFlights'->0->>'profitLossUsd')::numeric<>10007
 THEN RAISE EXCEPTION 'LAST_SEVEN_AND_ARCHIVE_SUMMARY_WRONG: %',v->'history';END IF;
 -- Mismatch ledger amount should exclude a snapshot, never invent results.
 UPDATE airlinerra_game.airline_ledger
 SET amount_usd=19999
 WHERE id=(SELECT revenue_ledger_id FROM
   airlinerra_game.section9_route_posted_flight_financials_v1
   WHERE schedule_id=v_schedule ORDER BY flown_game_day DESC LIMIT 1);
 w:=airlinerra_game.section9_owned_route_financial_dashboard_v1(
  v_player,v_airline,v_schedule,100,180);
 IF (w->'history'->>'completedFlightCount')::integer<>7
 THEN RAISE EXCEPTION 'UNRECONCILED_LEDGER_WAS_COUNTED';END IF;
 RAISE NOTICE 'PASS: owner-only full/half-load fee planning; eight SYNTHETIC arrived+posted flights show last seven and older aggregate; invalid ledger excluded; no flight activated';
END $test$;
ROLLBACK;
