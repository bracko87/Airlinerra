BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_relocation_leg_expense_receipts_v1(
 physical_flight_id text PRIMARY KEY REFERENCES airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1(physical_flight_id),
 trip_id uuid NOT NULL REFERENCES airlinerra_game.section9_maintenance_relocation_trips_v1(id),
 leg_number integer NOT NULL CHECK(leg_number IN (1,2)),airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 fuel_burn_kg numeric(14,3) NOT NULL CHECK(fuel_burn_kg>0),fuel_cost_usd numeric(14,2) NOT NULL CHECK(fuel_cost_usd>0),airport_fees_usd numeric(14,2) NOT NULL CHECK(airport_fees_usd>=0),
 ledger_entry_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 settled_at timestamptz NOT NULL,UNIQUE(trip_id,leg_number)
);
ALTER TABLE airlinerra_game.section9_relocation_leg_expense_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_relocation_leg_expense_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_settle_relocation_leg_v1(p_trip uuid,p_leg int,p_physical text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE t record; m record; b record; prior record; leg_quote jsonb; rate numeric; fuel_cost numeric; fees numeric; ledger_id bigint; balance numeric; total numeric;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_RELOCATION_SETTLEMENT_ONLY';END IF;
 SELECT * INTO t FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE id=p_trip AND status='reserved' FOR UPDATE;
 IF NOT FOUND OR p_leg NOT IN (1,2) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND execution_enabled AND reservation_enabled) THEN RAISE EXCEPTION 'RELOCATION_SETTLEMENT_NOT_RELEASED';END IF;
 SELECT * INTO prior FROM airlinerra_game.section9_relocation_leg_expense_receipts_v1 WHERE trip_id=p_trip AND leg_number=p_leg;
 IF FOUND THEN
  IF prior.physical_flight_id<>p_physical THEN RAISE EXCEPTION 'RELOCATION_SETTLEMENT_REPLAY_CONFLICT';END IF;
  RETURN jsonb_build_object('status','already_settled','ledgerPosted',false,'replayed',true);
 END IF;
 SELECT * INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=p_physical AND phase='arrived' AND relocation_trip_id=p_trip AND weekly_entry=p_leg AND airline_id=t.airline_id AND aircraft_inventory_id=t.aircraft_inventory_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'RELOCATION_ARRIVAL_NOT_PROVEN';END IF;
 SELECT * INTO b FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 WHERE physical_flight_id=p_physical AND arrival_engine_event_id=m.engine_event_id AND airline_id=t.airline_id AND aircraft_inventory_id=t.aircraft_inventory_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'RELOCATION_BURN_NOT_PROVEN';END IF;
 leg_quote:=t.quote->(CASE WHEN p_leg=1 THEN 'outbound' ELSE 'return' END);
 rate:=(leg_quote->>'fuelCostUsd')::numeric/nullif((leg_quote->>'fuelBurnKg')::numeric,0);
 -- The quote locks the game's per-leg fuel charge and fee estimate, with
 -- verified matching burn. No passenger revenue or commercial fare rows.
 IF b.trip_burn_kg IS DISTINCT FROM (leg_quote->>'fuelBurnKg')::numeric OR rate IS NULL OR rate<=0 THEN RAISE EXCEPTION 'RELOCATION_BURN_QUOTE_MISMATCH';END IF;
 fuel_cost:=(leg_quote->>'fuelCostUsd')::numeric;fees:=(leg_quote->>'airportFeesUsd')::numeric;total:=fuel_cost+fees;
 IF fuel_cost<=0 OR fees<0 OR total IS DISTINCT FROM (leg_quote->>'totalUsd')::numeric THEN RAISE EXCEPTION 'RELOCATION_EXPENSE_QUOTE_INVALID';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=t.airline_id FOR UPDATE;
 SELECT coalesce(sum(amount_usd),0) INTO balance FROM airlinerra_game.airline_ledger WHERE airline_id=t.airline_id;
 -- The arrival must not be silently rolled back for an aircraft already in flight.
 -- Until a protected funds-hold mechanism exists, the committed expense is
 -- posted exactly once even if another purchase has depleted available funds.
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd,recorded_at) VALUES(t.airline_id,'EXPENSE',-total,m.actual_event_utc) RETURNING id INTO ledger_id;
 INSERT INTO airlinerra_game.section9_relocation_leg_expense_receipts_v1 VALUES(p_physical,p_trip,p_leg,t.airline_id,b.trip_burn_kg,fuel_cost,fees,ledger_id,m.actual_event_utc);
 RETURN jsonb_build_object('status','relocation_expense_settled','ledgerPosted',true,'totalUsd',total,'fuelCostUsd',fuel_cost,'airportFeesUsd',fees,'balanceBeforeUsd',balance,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_settle_relocation_leg_v1(uuid,int,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_create_reserved_relocation_service_v1(p_trip uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE t record; q jsonb; offer jsonb; j uuid; start_at timestamptz; end_at timestamptz; hours numeric; condition numeric; v_now timestamptz; pos jsonb; actual_arr timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_RELOCATION_SERVICE_ONLY';END IF;
 SELECT * INTO t FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE id=p_trip AND status='reserved' FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND execution_enabled AND reservation_enabled) THEN RAISE EXCEPTION 'RELOCATION_SERVICE_NOT_RELEASED';END IF;
 IF t.maintenance_job_id IS NOT NULL THEN RETURN jsonb_build_object('status','relocation_service_already_reserved','jobId',t.maintenance_job_id,'created',false);END IF;
 SELECT actual_event_utc INTO actual_arr FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND phase='arrived' AND weekly_entry=1 AND destination_airport_key=t.provider_airport_key AND aircraft_inventory_id=t.aircraft_inventory_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'RELOCATION_SERVICE_ARRIVAL_NOT_PROVEN';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(t.owner_player_id,t.airline_id,t.aircraft_inventory_id,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR pos->>'airportKey' IS DISTINCT FROM t.provider_airport_key THEN RAISE EXCEPTION 'RELOCATION_PROVIDER_POSITION_NOT_PROVEN';END IF;
 q:=t.quote->'maintenance';offer:=t.quote->'provider';start_at:=(q->>'startUtc')::timestamptz;end_at:=(q->>'endUtc')::timestamptz;
 IF start_at<actual_arr OR end_at<=start_at OR end_at-start_at<>make_interval(mins=>(offer->>'durationMinutes')::int) OR (q->>'priceUsd')::numeric IS DISTINCT FROM (offer->>'priceUsd')::numeric THEN RAISE EXCEPTION 'RELOCATION_SERVICE_QUOTE_INCONSISTENT';END IF;
 SELECT tracked_flight_hours INTO hours FROM airlinerra_game.aircraft_maintenance_state_v1 WHERE aircraft_inventory_id=t.aircraft_inventory_id AND airline_id=t.airline_id;
 condition:=(airlinerra_game.section9_game_airframe_condition_v1(t.airline_id,t.aircraft_inventory_id,v_now)->>'conditionPct')::numeric;
 IF hours IS NULL OR condition IS NULL THEN RAISE EXCEPTION 'RELOCATION_SERVICE_AIRFRAME_DATA_MISSING';END IF;
 INSERT INTO airlinerra_game.section9_game_maintenance_jobs_v1(owner_player_id,airline_id,aircraft_inventory_id,check_code,airport_key,game_start_utc,game_end_utc,duration_hours,duration_minutes,condition_before_game_pct,flight_hours_at_book,quoted_cost_usd,provider_key,provider_name,provider_quality)
 VALUES(t.owner_player_id,t.airline_id,t.aircraft_inventory_id,t.check_code,t.provider_airport_key,start_at,end_at,ceil((offer->>'durationMinutes')::numeric/60)::int,(offer->>'durationMinutes')::int,condition,hours,(q->>'priceUsd')::numeric,t.provider_key,offer->>'providerName',(offer->>'qualityRating')::int) RETURNING job_id INTO j;
 UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET maintenance_job_id=j WHERE id=p_trip;
 RETURN jsonb_build_object('status','relocation_service_reserved','jobId',j,'created',true,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_create_reserved_relocation_service_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_execute_relocation_leg_event_v1(p_trip uuid,p_leg integer,p_phase text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE t record; l record; pos record; has_position boolean; anchor jsonb; resolution jsonb; q jsonb; clock_proof jsonb; v_now timestamptz; event_time timestamptz; physical text; event_id text; signature text; signer text; usage jsonb; fuel jsonb; movement jsonb; maint jsonb; settlement jsonb; service jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELOCATION_EXECUTION_ONLY';END IF;
 IF p_leg NOT IN (1,2) OR p_phase NOT IN ('departed','arrived') OR p_phase IS NULL THEN RAISE EXCEPTION 'INVALID_RELOCATION_EVENT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND reservation_enabled AND execution_enabled) THEN RETURN jsonb_build_object('status','relocation_execution_not_released','movementRecorded',false);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_activation_release_policy_v1 a JOIN airlinerra_game.section9_trusted_execution_release_policy_v1 e ON e.world_id=a.world_id JOIN airlinerra_game.section9_flight_engine_readiness_audit_v1 g ON g.world_id=a.world_id WHERE a.world_id=1 AND a.release_state='enabled' AND e.release_state='enabled' AND g.trusted_flight_execution_release='ACTIVATED' AND g.fuel_transaction_release='ACTIVATED' AND g.automatic_flight_and_fuel_settlement_enabled) THEN RETURN jsonb_build_object('status','flight_engine_unreleased','movementRecorded',false);END IF;
 SELECT * INTO t FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE id=p_trip FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','unknown_relocation_trip','movementRecorded',false);END IF;
 physical:=t.id::text||':'||((t.quote->(CASE WHEN p_leg=1 THEN 'outbound' ELSE 'return' END)->>'departureUtc')::timestamptz AT TIME ZONE 'UTC')::date::text||':'||p_leg::text;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND flight_occurrence_id=physical AND phase=p_phase) THEN RETURN jsonb_build_object('status','relocation_movement_replayed','movementRecorded',false,'replayed',true);END IF;
 SELECT * INTO l FROM airlinerra_game.section9_relocation_leg_evidence_v1(physical);
 IF NOT FOUND THEN RETURN jsonb_build_object('status','relocation_leg_not_ready','movementRecorded',false);END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','game_clock_unverified','movementRecorded',false);END IF;
 v_now:=(clock_proof->>'gameHourUtc')::timestamptz;
 event_time:=CASE WHEN p_phase='departed' THEN l.departure_utc ELSE l.arrival_utc END;
 IF event_time>v_now OR event_time>clock_timestamp() OR event_time<>date_trunc('second',event_time) OR (p_phase='departed' AND event_time<=v_now-interval '10 minutes') THEN RETURN jsonb_build_object('status','relocation_event_outside_window','movementRecorded',false);END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=l.aircraft_inventory_id AND airline_id=l.airline_id AND fleet_status='in_service' AND configuration_id=l.configuration_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aircraft_unavailable','movementRecorded',false);END IF;
 SELECT * INTO pos FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=l.aircraft_inventory_id AND airline_id=l.airline_id FOR UPDATE;
 has_position:=FOUND;
 anchor:=airlinerra_game.section9_owned_aircraft_operational_position_v1(l.owner_player_id,l.airline_id,l.aircraft_inventory_id,(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date);
 IF anchor->>'verified' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_position_unverified','movementRecorded',false);END IF;
 IF p_phase='departed' THEN
  IF anchor->>'atGroundAirport' IS DISTINCT FROM 'true' OR anchor->>'airportKey' IS DISTINCT FROM l.origin_airport_key THEN RETURN jsonb_build_object('status','relocation_at_wrong_airport','movementRecorded',false);END IF;
  IF NOT airlinerra_game.section9_canonical_aoc_covers_v1(l.airline_id,airlinerra_game.section9_verified_permission_game_day_v1(),0) OR airlinerra_game.section9_game_route_licence_scope_v1(l.airline_id,l.origin_airport_key,l.destination_airport_key,airlinerra_game.section9_verified_permission_game_day_v1(),0)->>'allowed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_licence_blocked','movementRecorded',false);END IF;
  q:=airlinerra_game.section5_universal_route_restriction_gate_v1(1::smallint,l.origin_airport_key,l.destination_airport_key,l.configuration_id,l.departure_utc,l.arrival_utc,NULL,NULL);
  IF NOT airlinerra_game.section9_game_route_restrictions_valid_v1(l.origin_airport_key,l.destination_airport_key,jsonb_build_object('weeklyTimetableChecked',true,'gameHardBlocked',(q->>'gameHardBlocked')::boolean,'occurrences',jsonb_build_array(q))) THEN RETURN jsonb_build_object('status','relocation_airport_restrictions_blocked','movementRecorded',false);END IF;
  maint:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(l.owner_player_id,l.airline_id,l.aircraft_inventory_id,l.departure_utc,l.arrival_utc);
  IF maint->>'gameMaintenanceClear' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_maintenance_blocked','movementRecorded',false,'blockers',maint->'blockers');END IF;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND flight_occurrence_id=physical AND phase='departed') THEN RETURN jsonb_build_object('status','relocation_arrival_without_departure','movementRecorded',false);END IF;
 END IF;
 resolution:=airlinerra_game.section9_aircraft_movement_decision_v1(p_phase,CASE WHEN has_position THEN pos.location_status ELSE 'grounded' END,CASE WHEN has_position THEN pos.airport_key ELSE anchor->>'airportKey' END,CASE WHEN has_position THEN pos.current_flight_occurrence_id ELSE NULL END,CASE WHEN has_position THEN pos.last_event_utc ELSE NULL END,CASE WHEN has_position THEN pos.last_departure_utc ELSE NULL END,l.origin_airport_key,l.destination_airport_key,physical,event_time);
 IF resolution->>'allowed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_movement_blocked','movementRecorded',false,'reason',resolution->>'reason');END IF;
 event_id:='relocation-v1:'||physical||':'||p_phase;
 SELECT decrypted_secret INTO signer FROM vault.decrypted_secrets WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF signer IS NULL OR length(signer)<64 THEN RETURN jsonb_build_object('status','private_signer_unavailable','movementRecorded',false);END IF;
 signature:=encode(extensions.hmac(convert_to(concat_ws(E'\n','airlinerra-relocation-event-v1',l.airline_id::text,l.aircraft_inventory_id::text,physical,p_phase,l.origin_airport_key,l.destination_airport_key,to_char(event_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),event_id),'UTF8'),convert_to(signer,'UTF8'),'sha256'),'hex');
 IF p_phase='departed' THEN
  fuel:=airlinerra_game.section9_auto_supply_game_only_fuel_v1(physical);
  IF fuel->>'status' NOT IN ('game_only_auto_fuel_supply_recorded','game_fuel_already_sufficient') THEN RAISE EXCEPTION 'RELOCATION_FUEL_SUPPLY_BLOCKED';END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,relocation_trip_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,event_id,signature,l.airline_id,l.aircraft_inventory_id,NULL,p_trip,1,p_leg,l.flight_local_date,physical,p_phase,l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,event_time);
 INSERT INTO airlinerra_game.section9_aircraft_current_position_v1(aircraft_inventory_id,world_id,airline_id,location_status,airport_key,current_flight_occurrence_id,last_event_utc,last_departure_utc,last_arrival_utc,last_engine_event_id)
 VALUES(l.aircraft_inventory_id,1,l.airline_id,resolution->>'newState',resolution->>'newAirport',CASE WHEN p_phase='departed' THEN physical ELSE NULL END,event_time,CASE WHEN p_phase='departed' THEN event_time ELSE pos.last_departure_utc END,CASE WHEN p_phase='arrived' THEN event_time ELSE pos.last_arrival_utc END,event_id)
 ON CONFLICT(aircraft_inventory_id) DO UPDATE SET location_status=excluded.location_status,airport_key=excluded.airport_key,current_flight_occurrence_id=excluded.current_flight_occurrence_id,last_event_utc=excluded.last_event_utc,last_departure_utc=excluded.last_departure_utc,last_arrival_utc=excluded.last_arrival_utc,last_engine_event_id=excluded.last_engine_event_id,updated_at=clock_timestamp()
 WHERE airlinerra_game.section9_aircraft_current_position_v1.airline_id=excluded.airline_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'RELOCATION_POSITION_UPDATE_FAILED';END IF;
 IF p_phase='departed' THEN
  fuel:=airlinerra_game.section9_capture_verified_departure_fuel_v1(physical,event_id);
  IF fuel->>'fuelReceiptCreated' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'RELOCATION_DEPARTURE_FUEL_NOT_RECORDED';END IF;
 ELSE
  usage:=airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(physical);
  IF usage->>'usageApplied' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'RELOCATION_USAGE_NOT_RECORDED';END IF;
  fuel:=airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(physical,event_id);
  IF fuel->>'fuelBurnRecorded' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'RELOCATION_ARRIVAL_FUEL_NOT_RECORDED';END IF;
  settlement:=airlinerra_game.section9_settle_relocation_leg_v1(p_trip,p_leg,physical);
  IF settlement->>'ledgerPosted' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'RELOCATION_EXPENSE_NOT_RECORDED';END IF;
  IF p_leg=1 THEN service:=airlinerra_game.section9_create_reserved_relocation_service_v1(p_trip);END IF;
 END IF;
 RETURN jsonb_build_object('status','relocation_movement_recorded','movementRecorded',true,'replayed',false,'flightOccurrenceId',physical,'phase',p_phase,'airportKey',resolution->>'newAirport','usage',usage,'fuel',fuel,'settlement',settlement,'service',service,'passengers',0,'ticketRevenueUsd',0,'ledgerPosted',coalesce((settlement->>'ledgerPosted')::boolean,false));
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_execute_relocation_leg_event_v1(uuid,integer,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
