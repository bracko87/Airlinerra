-- Two-phase Airlinerra operational roundtrip certification bridge.
-- Stage BOTH draft IDs and weekly slots only after a real game operator
-- licence and BOTH directional traffic rights were issued and verified.
-- Independent signed certifications are produced later against persisted
-- draft ID/version. ONLY THEN can the atomic finalizer activate the pair
-- and open the next seven days of verified ticket inventory.
-- All functions are trusted-postgres-only, no client direct access;
-- World1 releases are paused and no money is charged at staging.

-- Private intermediate state: two actual draft IDs are necessary for
-- independent version-bound signed certification. Not an operating route.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_private_roundtrip_certification_queue_v1(
 pair_key uuid PRIMARY KEY,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 player_id uuid NOT NULL,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 outbound_schedule_id uuid NOT NULL UNIQUE REFERENCES
  airlinerra_game.airline_flight_schedule_drafts_v1(id),
 return_schedule_id uuid NOT NULL UNIQUE REFERENCES
  airlinerra_game.airline_flight_schedule_drafts_v1(id),
 outbound_version integer NOT NULL CHECK(outbound_version>=1),
 return_version integer NOT NULL CHECK(return_version>=1),
 request_fingerprint_md5 text NOT NULL CHECK(request_fingerprint_md5~'^[a-f0-9]{32}$'),
 approval_start_game_date date NOT NULL,
 certification_days integer NOT NULL CHECK(certification_days BETWEEN 7 AND 42),
 status text NOT NULL DEFAULT 'awaiting_independent_certification'
  CHECK(status IN ('awaiting_independent_certification','activated')),
 staged_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 activated_at timestamptz,
 CHECK(outbound_schedule_id<>return_schedule_id),
 CHECK(status<>'activated' OR activated_at IS NOT NULL)
);
ALTER TABLE airlinerra_game.section9_private_roundtrip_certification_queue_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_private_roundtrip_certification_queue_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_stage_permitted_roundtrip_for_certification_v1(p_request_key uuid, p_player uuid, p_airline uuid, p_aircraft uuid, p_out_flight text, p_back_flight text, p_origin text, p_destination text, p_out_depart timestamp with time zone, p_out_arrive timestamp with time zone, p_back_depart timestamp with time zone, p_back_arrive timestamp with time zone, p_out_weekly jsonb, p_back_weekly jsonb, p_out_depart_stand text, p_out_arrive_stand text, p_back_depart_stand text, p_back_arrive_stand text, p_turnaround integer, p_out_fare_usd numeric, p_back_fare_usd numeric, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 v_game_hour jsonb;v_launch jsonb;v_owner record;v_fleet record;
 v_old record;v_out jsonb;v_back jsonb;v_out_plan jsonb;v_back_plan jsonb;
 v_out_id uuid;v_back_id uuid;v_out_ver int;v_back_ver int;
 v_game_date date;
 v_request_md5 text;
 v_locked integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_PRIVATE_CERTIFICATION_QUEUE_TRUSTED_GAME_SERVER_ONLY';END IF;
 IF p_request_key IS NULL OR p_player IS NULL OR p_airline IS NULL
 OR p_aircraft IS NULL OR p_origin IS NULL OR p_destination IS NULL
 OR p_origin=p_destination OR p_out_flight IS NULL OR p_back_flight IS NULL
 OR p_out_flight=p_back_flight
 OR p_out_flight !~ '^[A-Z0-9]{2}[0-9]{1,4}$'
 OR p_back_flight !~ '^[A-Z0-9]{2}[0-9]{1,4}$'
 OR p_out_fare_usd IS NULL OR p_out_fare_usd NOT BETWEEN 1 AND 100000
 OR p_back_fare_usd IS NULL OR p_back_fare_usd NOT BETWEEN 1 AND 100000
 OR p_days NOT BETWEEN 7 AND 42 OR p_turnaround NOT BETWEEN 45 AND 360
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_CERTIFICATION_QUEUE_INVALID_PAIR_OR_FARES';END IF;
 v_request_md5:=md5(jsonb_build_object(
  'player',p_player,'airline',p_airline,'aircraft',p_aircraft,
  'outFlight',p_out_flight,'returnFlight',p_back_flight,
  'origin',p_origin,'destination',p_destination,
  'outDepart',p_out_depart,'outArrive',p_out_arrive,
  'backDepart',p_back_depart,'backArrive',p_back_arrive,
  'outWeekly',p_out_weekly,'backWeekly',p_back_weekly,
  'stands',jsonb_build_array(p_out_depart_stand,p_out_arrive_stand,
  p_back_depart_stand,p_back_arrive_stand),
  'turnaroundMinutes',p_turnaround,
  'outFare',p_out_fare_usd,'backFare',p_back_fare_usd,
  'days',p_days)::text);
 SELECT * INTO v_old FROM airlinerra_game.section9_private_roundtrip_certification_queue_v1
 WHERE pair_key=p_request_key FOR UPDATE;
 IF FOUND THEN
  IF v_old.player_id IS DISTINCT FROM p_player
  OR v_old.airline_id IS DISTINCT FROM p_airline
  OR v_old.aircraft_inventory_id IS DISTINCT FROM p_aircraft
  OR v_old.request_fingerprint_md5 IS DISTINCT FROM v_request_md5
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_CERTIFICATION_REQUEST_REPLAY_CONFLICT';END IF;
  RETURN jsonb_build_object(
   'status','certification_pair_already_staged',
   'outboundScheduleId',v_old.outbound_schedule_id,
   'returnScheduleId',v_old.return_schedule_id,
   'certificationStatus',v_old.status,
   'operatingRouteCreated',v_old.status='activated',
   'ticketsOpenedByThisCall',0,'ledgerPosted',false,
   'replayed',true);
 END IF;
 v_game_hour:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF v_game_hour->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object(
  'status','blocked_unverified_game_hour',
  'pairStaged',false,'operatingRouteCreated',false,'ledgerPosted',false);END IF;
 v_game_date:=(v_game_hour->>'gameDate')::date;
 SELECT a.id,a.iata_code INTO v_owner
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id
 AND w.player_id=p_player AND w.state='active'
 WHERE a.id=p_airline AND a.world_id=1 AND a.owner_player_id=p_player
 FOR UPDATE OF a;
 IF NOT FOUND OR v_owner.iata_code IS NULL
 OR left(p_out_flight,2) IS DISTINCT FROM v_owner.iata_code
 OR left(p_back_flight,2) IS DISTINCT FROM v_owner.iata_code
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_CERTIFICATION_PAIR_NOT_OWNED_OR_INVALID_CALLSIGN';END IF;
 SELECT * INTO v_fleet FROM airlinerra_game.airline_aircraft_inventory f
 WHERE f.id=p_aircraft AND f.airline_id=p_airline FOR UPDATE;
 IF NOT FOUND OR v_fleet.fleet_status IS DISTINCT FROM 'in_service'
 OR v_fleet.ownership_type NOT IN('owned','leased')
 THEN RETURN jsonb_build_object('status','blocked_aircraft_not_in_service',
  'pairStaged',false,'operatingRouteCreated',false,'ledgerPosted',false);END IF;

 -- These two drafts cannot be created until the GAME has actually
 -- issued and recorded the AOC and BOTH directional route rights.
 -- Never generate or charge those approvals as a side effect of staging.
 v_launch:=airlinerra_game.section9_owned_roundtrip_launch_readiness_v1(
  p_player,p_airline,p_aircraft,p_origin,p_destination,
  p_out_depart,p_out_arrive,p_back_depart,p_back_arrive,
  p_out_weekly,p_back_weekly,p_out_depart_stand,p_out_arrive_stand,
  p_back_depart_stand,p_back_arrive_stand,p_turnaround,p_days);
 IF v_launch->>'gameRoundtripModelSuitable' IS DISTINCT FROM 'true'
 OR v_launch->>'operatorLicenceValid' IS DISTINCT FROM 'true'
 OR v_launch->>'outboundGameTrafficRightValid' IS DISTINCT FROM 'true'
 OR v_launch->>'returnGameTrafficRightValid' IS DISTINCT FROM 'true'
 OR v_launch->>'aircraftGamePositionVerified' IS DISTINCT FROM 'true'
 OR v_launch->>'gamePermissionApplicationFeeCharged' IS DISTINCT FROM 'false'
 OR v_launch->>'newSchedulesCreated' IS DISTINCT FROM '0'
 OR v_launch->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object(
  'status','blocked_issued_permissions_or_route_preview',
  'previewStatus',v_launch->>'launchStatus',
  'launchBlockers',v_launch->'launchBlockers',
  'pairStaged',false,'operatingRouteCreated',false,
  'slotsReserved',false,'ledgerPosted',false);END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.airline_id=p_airline AND s.flight_number IN(p_out_flight,p_back_flight))
 THEN RETURN jsonb_build_object('status','blocked_flight_number_already_reserved',
  'pairStaged',false,'operatingRouteCreated',false,'ledgerPosted',false);END IF;
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN(p_origin,p_destination)
 ORDER BY c.airport_key FOR UPDATE;
 GET DIAGNOSTICS v_locked=ROW_COUNT;
 IF v_locked<>2 THEN RETURN jsonb_build_object(
  'status','blocked_airport_slot_capacity_not_configured',
  'pairStaged',false,'operatingRouteCreated',false,'ledgerPosted',false);END IF;
 -- Recheck actual route preview under locks.
 v_launch:=airlinerra_game.section9_owned_roundtrip_launch_readiness_v1(
  p_player,p_airline,p_aircraft,p_origin,p_destination,
  p_out_depart,p_out_arrive,p_back_depart,p_back_arrive,
  p_out_weekly,p_back_weekly,p_out_depart_stand,p_out_arrive_stand,
  p_back_depart_stand,p_back_arrive_stand,p_turnaround,p_days);
 IF v_launch->>'gameRoundtripModelSuitable' IS DISTINCT FROM 'true'
 OR v_launch->>'operatorLicenceValid' IS DISTINCT FROM 'true'
 OR v_launch->>'outboundGameTrafficRightValid' IS DISTINCT FROM 'true'
 OR v_launch->>'returnGameTrafficRightValid' IS DISTINCT FROM 'true'
 OR v_launch->>'aircraftGamePositionVerified' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object(
   'status','blocked_certification_staging_capacity_or_rights_changed',
   'pairStaged',false,'operatingRouteCreated',false,
   'slotsReserved',false,'ledgerPosted',false);END IF;

 v_out:=airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
  p_player,p_airline,p_aircraft,p_out_flight,p_origin,p_destination,
  p_out_depart,p_out_arrive,p_out_weekly,
  NULL::uuid,p_out_depart_stand,p_out_arrive_stand);
 v_back:=airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
  p_player,p_airline,p_aircraft,p_back_flight,p_destination,p_origin,
  p_back_depart,p_back_arrive,p_back_weekly,
  NULL::uuid,p_back_depart_stand,p_back_arrive_stand);
 IF v_out->>'status' IS DISTINCT FROM 'draft'
 OR v_back->>'status' IS DISTINCT FROM 'draft'
 OR v_out->>'slotsReserved' IS DISTINCT FROM 'true'
 OR v_back->>'slotsReserved' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CERTIFICATION_PAIR_SCHEDULE_OR_SLOT_NOT_SAVED_ROLLBACK';END IF;
 v_out_id:=(v_out->>'scheduleId')::uuid;
 v_back_id:=(v_back->>'scheduleId')::uuid;
 v_out_ver:=(v_out->>'version')::integer;
 v_back_ver:=(v_back->>'version')::integer;
 IF v_out_id IS NULL OR v_back_id IS NULL OR v_out_id=v_back_id
 OR v_out_ver IS NULL OR v_back_ver IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_CERTIFICATION_PAIR_BAD_SAVED_SCHEDULES_ROLLBACK';END IF;
 v_out_plan:=airlinerra_game.section9_save_owned_commercial_plan_v1(
  p_player,p_airline,v_out_id,p_out_fare_usd,0,0);
 v_back_plan:=airlinerra_game.section9_save_owned_commercial_plan_v1(
  p_player,p_airline,v_back_id,p_back_fare_usd,0,0);
 IF (v_out_plan->>'economyFareUsd')::numeric IS DISTINCT FROM p_out_fare_usd
 OR (v_back_plan->>'economyFareUsd')::numeric IS DISTINCT FROM p_back_fare_usd
 OR v_out_plan->>'bookingsEnabled' IS DISTINCT FROM 'false'
 OR v_back_plan->>'bookingsEnabled' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CERTIFICATION_PAIR_FARE_SAVE_FAILED_ROLLBACK';END IF;

 INSERT INTO airlinerra_game.section9_private_roundtrip_certification_queue_v1(
  pair_key,player_id,airline_id,aircraft_inventory_id,
  outbound_schedule_id,return_schedule_id,
  outbound_version,return_version,request_fingerprint_md5,
  approval_start_game_date,certification_days
 ) VALUES(p_request_key,p_player,p_airline,p_aircraft,
  v_out_id,v_back_id,v_out_ver,v_back_ver,v_request_md5,
  v_game_date,p_days);
 RETURN jsonb_build_object(
  'status','paired_drafts_saved_for_independent_certification',
  'pairKey',p_request_key,
  'outboundScheduleId',v_out_id,'returnScheduleId',v_back_id,
  'outboundScheduleVersion',v_out_ver,'returnScheduleVersion',v_back_ver,
  'certificationRequired',true,'pairStaged',true,
  'operatingRouteCreated',false,
  'ticketsOpened',0,'ticketSalesAvailable',false,
  'licenceIssuedByThisCall',false,'licenceFeeCharged',false,
  'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_stage_permitted_roundtrip_for_certification_v1(uuid,uuid,uuid,uuid,text,text,text,text,timestamptz,timestamptz,timestamptz,timestamptz,jsonb,jsonb,text,text,text,text,integer,numeric,numeric,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_finish_staged_certified_roundtrip_v1(p_pair_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE v_pair record; v_clock jsonb;v_result jsonb;v_updated int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PRIVATE_CERTIFICATION_FINISHER_ONLY';END IF;
 IF p_pair_key IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_CERTIFICATION_FINISHER_KEY_REQUIRED';END IF;
 SELECT * INTO v_pair FROM airlinerra_game.section9_private_roundtrip_certification_queue_v1
 WHERE pair_key=p_pair_key FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object(
  'status','blocked_unknown_certification_pair',
  'operatingRouteCreated',false,'ledgerPosted',false);END IF;
 IF v_pair.status='activated' THEN
   IF NOT EXISTS(
    SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
    WHERE s.id=v_pair.outbound_schedule_id AND s.airline_id=v_pair.airline_id
     AND s.status='active' AND s.operationally_verified=true)
   OR NOT EXISTS(
    SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
    WHERE s.id=v_pair.return_schedule_id AND s.airline_id=v_pair.airline_id
     AND s.status='active' AND s.operationally_verified=true)
   THEN RAISE EXCEPTION USING ERRCODE='23505',
    MESSAGE='SECTION9_STAGED_PAIR_ACTIVATION_REPLAY_CONFLICT';END IF;
   RETURN jsonb_build_object(
    'status','certified_roundtrip_pair_already_active',
    'pairKey',p_pair_key,'replayed',true,
    'operatingRouteCreatedNow',false,
    'ledgerPosted',false);
 END IF;
 IF v_pair.status IS DISTINCT FROM 'awaiting_independent_certification'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_UNEXPECTED_CERTIFICATION_PAIR_STATE';END IF;
 v_clock:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF v_clock->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
   'operatingRouteCreated',false,'ledgerPosted',false);END IF;
 v_result:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
   v_pair.player_id,v_pair.airline_id,
   v_pair.outbound_schedule_id,v_pair.return_schedule_id,
   v_pair.outbound_version,v_pair.return_version,
   (v_clock->>'gameDate')::date,v_pair.certification_days);
 IF v_result->>'status'='certified_roundtrip_schedules_activated_and_tickets_open'
 AND v_result->>'operatingSchedulesActivated'='true'
 AND v_result->>'ticketSalesOpen'='true'
 AND v_result->>'ledgerPosted'='false'
 AND (v_result->>'outboundSaleableOccurrences')::int>0
 AND (v_result->>'returnSaleableOccurrences')::int>0
 THEN
  UPDATE airlinerra_game.section9_private_roundtrip_certification_queue_v1
  SET status='activated',activated_at=clock_timestamp()
  WHERE pair_key=p_pair_key
  AND status='awaiting_independent_certification';
  GET DIAGNOSTICS v_updated=ROW_COUNT;
  IF v_updated<>1 THEN RAISE EXCEPTION USING ERRCODE='40001',
   MESSAGE='SECTION9_PAIR_STATE_UPDATE_FAILED_FULL_ROLLBACK';END IF;
  RETURN v_result || jsonb_build_object(
    'pairKey',p_pair_key,
    'status','certified_roundtrip_operating_inventory_committed',
    'operatingRouteCreatedNow',true,'ledgerPosted',false);
 END IF;
 IF v_result->>'status' IN(
   'blocked_operating_or_finance_release',
   'blocked_pair_draft_not_found_or_aircraft_mismatch',
   'blocked_aircraft_or_draft_lock_changed',
   'blocked_pair_stale_or_not_a_return_route',
   'blocked_unreleased_game_fuel_or_unverified_passenger_payload',
   'blocked_missing_or_unsupported_commercial_fare',
   'blocked_ten_independent_signed_certifications_missing')
 AND v_result->>'pairActivated'='false'
 AND v_result->>'ledgerPosted'='false'
 THEN RETURN jsonb_build_object(
   'status','certification_pair_waiting_for_independent_approvals',
   'underlyingStatus',v_result->>'status',
   'signedCertificationsFound',v_result->'certificationsFound',
   'operatingRouteCreated',false,
   'ticketSalesOpen',false,'ledgerPosted',false);
 END IF;
 RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_CERTIFICATION_PAIR_UNEXPECTED_FINALIZATION_ROLLBACK';
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_finish_staged_certified_roundtrip_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_finish_certified_roundtrip_batch_v1(p_limit integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE v_activate record;v_execution record;v_finance record;v_engine record;
 item record;result jsonb;
 checked int:=0;finished int:=0;waiting int:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_CERTIFICATION_BATCH_POSTGRES_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_CERTIFICATION_BATCH_LIMIT_INVALID';END IF;
 SELECT * INTO v_activate FROM airlinerra_game.section9_activation_release_policy_v1
 WHERE world_id=1;
 SELECT * INTO v_execution FROM airlinerra_game.section9_trusted_execution_release_policy_v1
 WHERE world_id=1;
 SELECT * INTO v_finance FROM airlinerra_game.section9_flight_finance_posting_release_v1
 WHERE world_id=1;
 SELECT * INTO v_engine FROM airlinerra_game.section9_flight_engine_readiness_audit_v1
 WHERE world_id=1;
 IF v_activate.release_state IS DISTINCT FROM 'enabled'
 OR v_execution.release_state IS DISTINCT FROM 'enabled'
 OR v_finance.release_state IS DISTINCT FROM 'approved'
 OR v_engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object(
  'status','blocked_certification_activation_release',
  'checked',0,'activated',0,'ledgerPosted',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583732,10051)
 THEN RETURN jsonb_build_object(
  'status','certification_batch_already_running',
  'checked',0,'activated',0,'ledgerPosted',false);END IF;
 FOR item IN
 SELECT q.pair_key
 FROM airlinerra_game.section9_private_roundtrip_certification_queue_v1 q
 WHERE q.status='awaiting_independent_certification'
 ORDER BY q.staged_at,q.pair_key LIMIT p_limit
 LOOP
  checked:=checked+1;
  result:=airlinerra_game.section9_finish_staged_certified_roundtrip_v1(
    item.pair_key);
  IF result->>'status'='certified_roundtrip_operating_inventory_committed'
   AND result->>'operatingRouteCreatedNow'='true'
   AND result->>'ledgerPosted'='false'
  THEN finished:=finished+1;
  ELSIF result->>'status' IN(
    'certification_pair_waiting_for_independent_approvals',
    'blocked_unverified_game_hour')
    AND result->>'ledgerPosted'='false'
  THEN waiting:=waiting+1;
  ELSE RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_CERTIFICATION_BATCH_UNKNOWN_RESULT_ROLLBACK';END IF;
 END LOOP;
 RETURN jsonb_build_object(
  'status','certification_batch_checked',
  'pairsChecked',checked,
  'operatingPairsActivated',finished,'waiting',waiting,
  'ticketSalesAreRealOnlyAfterCertification',true,
  'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_finish_certified_roundtrip_batch_v1(integer) FROM PUBLIC,anon,authenticated,service_role;

DO $certification_cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job
  WHERE jobname='airlinerra-game-certified-roundtrip-finalizer-v1') THEN
  PERFORM cron.schedule(
    'airlinerra-game-certified-roundtrip-finalizer-v1',
    '2,7,12,17,22,27,32,37,42,47,52,57 * * * *',
    'SELECT airlinerra_game.section9_auto_finish_certified_roundtrip_batch_v1(10);');
 END IF;
END $certification_cron$;
