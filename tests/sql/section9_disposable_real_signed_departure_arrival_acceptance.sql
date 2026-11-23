-- Full signed game flight departure/arrival through the original private
-- writer with the reviewed row-lock candidate installed in disposable PG17.
-- HMAC is computed by the real writer using a disposable synthetic secret.
-- Position/dispatch prerequisite helpers are synthetic and NOT production proof.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_aircraft_current_position_v1') IS NOT NULL
 OR to_regclass('public.airlinerra_game_worlds') IS NOT NULL
 THEN RAISE EXCEPTION 'REAL_SIGNED_DEPARTURE_DISPOSABLE_ONLY';END IF;
END $guard$;

CREATE TABLE public.airlinerra_game_worlds(id smallint PRIMARY KEY,state text,opens_at timestamptz);
INSERT INTO public.airlinerra_game_worlds VALUES(1,'active','2026-11-20T00:00:00Z');
CREATE TABLE airlinerra_game.holding_world_clock_v1(
 world_id smallint PRIMARY KEY,clock_source text,confirmed_game_date date,
 last_verified_at timestamptz,engine_proof_ref text);
INSERT INTO airlinerra_game.holding_world_clock_v1 VALUES(
 1,'authoritative_game_engine','2026-11-23',now(),'disposable-world-tick-20261123');
CREATE TABLE airlinerra_game.section9_verified_game_tick_receipts_v1(
 world_id smallint,game_date date,engine_event_id text,
 PRIMARY KEY(world_id,game_date));
INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1
 VALUES(1,'2026-11-21','disposable-game-tick-20261121');
CREATE TABLE airlinerra_game.airport_reference_profiles(
 world_id smallint,airport_key text,timezone_iana text,
 PRIMARY KEY(world_id,airport_key));
INSERT INTO airlinerra_game.airport_reference_profiles VALUES
 (1,'OURAIRPORTS:2212','UTC'),(1,'OURAIRPORTS:2218','UTC');

ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 ADD COLUMN reference_departure_utc timestamptz,
 ADD COLUMN reference_arrival_utc timestamptz;
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ADD COLUMN world_id smallint NOT NULL DEFAULT 1,
 ADD COLUMN engine_event_id text,
 ADD COLUMN event_hmac_sha256 text,
 ADD COLUMN airline_id uuid,
 ADD COLUMN aircraft_inventory_id uuid,
 ADD COLUMN schedule_version int,
 ADD COLUMN origin_airport_key text,
 ADD COLUMN destination_airport_key text,
 ADD COLUMN scheduled_departure_utc timestamptz,
 ADD COLUMN scheduled_arrival_utc timestamptz,
 ADD COLUMN source_kind text NOT NULL DEFAULT 'signed_operated_game_flight_v1';
CREATE UNIQUE INDEX fixture_movement_unique_event
 ON airlinerra_game.section9_operated_flight_movements_v1(engine_event_id)
 WHERE engine_event_id IS NOT NULL;
CREATE UNIQUE INDEX fixture_movement_unique_phase
 ON airlinerra_game.section9_operated_flight_movements_v1(flight_occurrence_id,phase)
 WHERE flight_occurrence_id IS NOT NULL;

-- Existing capacity verification view needs its real source field.
CREATE OR REPLACE VIEW airlinerra_game.section9_verified_schedule_capacity_v1 AS
 SELECT d.id AS schedule_id,d.airline_id,d.version AS schedule_version,
  110::int AS passenger_seats,
  'disposable-certified-aircraft-capacity'::text AS verification_source
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 WHERE d.status='active' AND d.operationally_verified;

CREATE TABLE airlinerra_game.section9_aircraft_delivery_position_v1(
 aircraft_inventory_id uuid,airline_id uuid,acquisition_order_id uuid,
 inspection_id uuid,airport_key text,anchored_game_date date,
 inspection_reviewed_at timestamptz,reviewer_reference text);
CREATE TABLE airlinerra_game.aircraft_acquisition_orders_v1(
 order_id uuid,airline_id uuid,aircraft_inventory_id uuid,
 registration text,configuration_id bigint,
 delivery_home_airport_key text,order_status text);
CREATE TABLE airlinerra_game.aircraft_delivery_inspections_v1(
 inspection_id uuid,order_id uuid,inspection_status text,
 reviewed_at timestamptz,reviewer_reference text);

CREATE TABLE airlinerra_game.section9_aircraft_current_position_v1(
 aircraft_inventory_id uuid PRIMARY KEY,world_id smallint,airline_id uuid,
 location_status text,airport_key text,current_flight_occurrence_id text,
 last_event_utc timestamptz NOT NULL,last_departure_utc timestamptz,
 last_arrival_utc timestamptz,last_engine_event_id text,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE FUNCTION airlinerra_game.section9_starter_origin_evidence_v1(
 p_airline uuid,p_aircraft uuid,p_date date)
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{"verified":true,"airportKey":"OURAIRPORTS:2212"}'::jsonb $fn$;
CREATE FUNCTION airlinerra_game.section9_delayed_turnaround_clear_v1(
 p_aircraft uuid,p_occ uuid,p_event timestamptz)
 RETURNS boolean LANGUAGE sql STABLE AS $fn$ SELECT true $fn$;
DROP FUNCTION airlinerra_game.section9_effective_dispatch_window_v1(uuid);
CREATE FUNCTION airlinerra_game.section9_effective_dispatch_window_v1(p_occ uuid)
 RETURNS TABLE(is_delayed boolean,effective_departure_utc timestamptz,
 effective_arrival_utc timestamptz,dispatch_allowed boolean)
 LANGUAGE sql STABLE AS $fn$
 SELECT false,o.departure_utc,o.arrival_utc,true
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=p_occ
 $fn$;

CREATE FUNCTION airlinerra_game.section9_aircraft_movement_decision_v1(
 p_phase text,p_location text,p_airport text,p_current_flight text,
 p_last_event timestamptz,p_last_departure timestamptz,
 p_origin text,p_destination text,p_flight text,p_event timestamptz)
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT CASE
 WHEN p_phase='departed' AND coalesce(p_location,'grounded')='grounded'
 AND p_airport=p_origin THEN
 jsonb_build_object('allowed',true,'newState','in_flight','newAirport',p_origin)
 WHEN p_phase='arrived' AND p_location='in_flight'
 AND p_current_flight=p_flight THEN
 jsonb_build_object('allowed',true,'newState','grounded','newAirport',p_destination)
 ELSE jsonb_build_object('allowed',false,'reason','SYNTHETIC_POSITION_INVALID')
 END $fn$;

CREATE TABLE airlinerra_game.fixture_signed_flight_names(
 scenario text PRIMARY KEY,schedule_id uuid,occurrence_id uuid,aircraft_id uuid);
INSERT INTO airlinerra_game.fixture_signed_flight_names VALUES
 ('normal','abababab-1111-4111-8111-abababababab',
  'abababab-2222-4222-8222-abababababab',
  'abababab-3333-4333-8333-abababababab'),
 ('movement_first','bcbcbcbc-1111-4111-8111-bcbcbcbcbcbc',
  'bcbcbcbc-2222-4222-8222-bcbcbcbcbcbc',
  'bcbcbcbc-3333-4333-8333-bcbcbcbcbcbc'),
 ('cancel_first','cdcdcdcd-1111-4111-8111-cdcdcdcdcdcd',
  'cdcdcdcd-2222-4222-8222-cdcdcdcdcdcd',
  'cdcdcdcd-3333-4333-8333-cdcdcdcdcdcd');

INSERT INTO airlinerra_game.airline_aircraft_inventory
 SELECT aircraft_id,'11111111-1111-4111-8111-111111111111',
 'in_service','owned',100
 FROM airlinerra_game.fixture_signed_flight_names;
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
 id,world_id,airline_id,aircraft_inventory_id,configuration_id,
 version,status,operationally_verified,origin_airport_key,
 destination_airport_key,flight_number,weekly_schedule,
 reference_departure_utc,reference_arrival_utc)
 SELECT schedule_id,1,'11111111-1111-4111-8111-111111111111',
 aircraft_id,100,1,'active',true,'OURAIRPORTS:2212',
 'OURAIRPORTS:2218','TEST'||
 CASE scenario WHEN 'normal' THEN '501'
 WHEN 'movement_first' THEN '502' ELSE '503' END,
 '[{"day":5,"time":"16:00"}]'::jsonb,
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z'
 FROM airlinerra_game.fixture_signed_flight_names;
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
 id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,
 weekly_entry,flight_local_date,verified_passenger_seats,booked_seats,
 booking_status,source_kind,departure_utc,arrival_utc,world_id,
 recognized_revenue_usd)
 SELECT occurrence_id,'11111111-1111-4111-8111-111111111111',
 schedule_id,aircraft_id,1,1,'2026-11-21',110,0,
 'open','game_verified_saleable_schedule_v1',
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z',1,0
 FROM airlinerra_game.fixture_signed_flight_names;
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,
 commercial_version,passenger_capacity,passengers_held,status,
 departure_utc,arrival_utc,cargo_held_tonnes)
 SELECT schedule_id::text||':2026-11-21:1',schedule_id,
 '11111111-1111-4111-8111-111111111111',
 1,1,110,0,'preflight_only',
 '2026-11-21T16:00:00Z','2026-11-21T17:00:00Z',0
 FROM airlinerra_game.fixture_signed_flight_names;

UPDATE airlinerra_game.section9_activation_release_policy_v1
 SET release_state='enabled',enabled_at=now() WHERE world_id=1;
UPDATE airlinerra_game.section9_trusted_execution_release_policy_v1
 SET release_state='enabled',enabled_at=now() WHERE world_id=1;
UPDATE airlinerra_game.section9_flight_engine_readiness_audit_v1
 SET trusted_flight_execution_release='ACTIVATED',
 fuel_transaction_release='ACTIVATED',
 automatic_flight_and_fuel_settlement_enabled=true WHERE world_id=1;

DO $live_synthetic_departure_arrival$
DECLARE v_airline uuid:='11111111-1111-4111-8111-111111111111';
 v_schedule uuid:='abababab-1111-4111-8111-abababababab';
 v_depart timestamptz:='2026-11-21T16:00:00Z';
 v_arrive timestamptz:='2026-11-21T17:00:00Z';
 v_phase text;v_event timestamptz;v_event_id text;v_sig text;
 v_payload text;v_result jsonb;
BEGIN
 FOR v_phase IN SELECT unnest(ARRAY['departed','arrived'])
 LOOP
  v_event:=CASE WHEN v_phase='departed' THEN v_depart ELSE v_arrive END;
  v_event_id:='signed-synthetic-'||v_phase||'-20261123';
  v_payload:=concat_ws(E'\n',
   'airlinerra-operated-game-event-v1','1',v_airline::text,
   v_schedule::text,'1','2026-11-21','1',v_phase,
   to_char(v_event AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),v_event_id);
  v_sig:=encode(extensions.hmac(convert_to(v_payload,'UTF8'),
   convert_to(repeat('t',80),'UTF8'),'sha256'),'hex');
  v_result:=airlinerra_game.section9_record_signed_operated_flight_movement_v1(
   v_airline,v_schedule,1,'2026-11-21',1,v_phase,v_event,v_event_id,v_sig);
  IF v_result->>'status'<>(CASE WHEN v_phase='departed'
    THEN 'operated_flight_departure_recorded'
    ELSE 'operated_flight_arrival_recorded' END)
   OR v_result->>'movementRecorded'<>'true'
  THEN RAISE EXCEPTION 'Actual signed movement failed %: %',v_phase,v_result;END IF;
  v_result:=airlinerra_game.section9_record_signed_operated_flight_movement_v1(
   v_airline,v_schedule,1,'2026-11-21',1,v_phase,v_event,v_event_id,v_sig);
  IF v_result->>'status'<>'operated_movement_replayed'
   OR v_result->>'replayed'<>'true' THEN
   RAISE EXCEPTION 'Actual signed movement replay failed %: %',v_phase,v_result;
  END IF;
 END LOOP;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1
   WHERE flight_occurrence_id=v_schedule::text||':2026-11-21:1')<>2
 OR (SELECT location_status FROM airlinerra_game.section9_aircraft_current_position_v1
  WHERE aircraft_inventory_id='abababab-3333-4333-8333-abababababab')<>'grounded'
 OR (SELECT airport_key FROM airlinerra_game.section9_aircraft_current_position_v1
  WHERE aircraft_inventory_id='abababab-3333-4333-8333-abababababab')<>'OURAIRPORTS:2218'
 THEN RAISE EXCEPTION 'Signed movement created inconsistent final airplane position';END IF;
 RAISE NOTICE 'PASS original patched signed writer recorded departure and arrival, replayed both, and updated aircraft position';
END $live_synthetic_departure_arrival$;
