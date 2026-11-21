-- Private game-engine certification automation. Existing five independent
-- source readers and atomic receipt sink are unchanged. Each authority uses
-- a distinct Vault-held signing key; only postgres may invoke this worker.
-- No release switch is changed, no new licence or permission is granted.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_issue_queued_game_clearance_v1(
 p_airline uuid,p_schedule uuid,p_version integer,p_day date,p_type text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE proof jsonb;receipt jsonb;source_kind text;prefix text;expected_status text;
 reviewer text;source_ref text;fingerprint text;event_id text;payload text;signature text;key_material text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_GAME_CLEARANCE_ONLY';END IF;
 CASE p_type
 WHEN 'operator_licence' THEN
  proof:=airlinerra_game.section9_verify_game_operator_licence_v1(p_airline,p_schedule,p_version,p_day);
  expected_status:='verified_game_operator_licence';source_kind:='verified_game_licence_engine';
  prefix:='game-licence-cert-v1';reviewer:='independent-game-licence-authority-v1';
 WHEN 'route_traffic_rights' THEN
  proof:=airlinerra_game.section9_verify_game_route_traffic_rights_v1(p_airline,p_schedule,p_version,p_day);
  expected_status:='verified_game_route_traffic_rights';source_kind:='verified_game_traffic_rights_engine';
  prefix:='game-route-rights-cert-v1';reviewer:='independent-game-traffic-rights-v1';
 WHEN 'airport_slot_capacity' THEN
  proof:=airlinerra_game.section9_verify_slot_clearance_source_v1(p_airline,p_schedule,p_version,p_day);
  expected_status:='verified_game_airport_slots';source_kind:='verified_airport_slot_engine';
  prefix:='slot-clearance-v1';reviewer:='independent-game-slot-authority-v1';
 WHEN 'trusted_flight_execution' THEN
  proof:=airlinerra_game.section9_execution_finance_source_snapshot_v1(p_airline,p_schedule,p_version,p_day,p_type);
  expected_status:='source_snapshot_candidate_not_authorized';source_kind:='trusted_flight_operations_engine';
  prefix:='flight-exec-cert-v1';reviewer:='independent-trusted-flight-execution-authority-v1';
 WHEN 'commercial_finance' THEN
  proof:=airlinerra_game.section9_execution_finance_source_snapshot_v1(p_airline,p_schedule,p_version,p_day,p_type);
  expected_status:='source_snapshot_candidate_not_authorized';source_kind:='verified_commercial_settlement_engine';
  prefix:='commercial-finance-cert-v1';reviewer:='independent-commercial-finance-authority-v1';
 ELSE RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='UNKNOWN_GAME_CLEARANCE';END CASE;
 IF proof->>'status' IS DISTINCT FROM expected_status
 OR proof->>'airlineId' IS DISTINCT FROM p_airline::text
 OR proof->>'scheduleId' IS DISTINCT FROM p_schedule::text
 OR proof->>'scheduleVersion' IS DISTINCT FROM p_version::text
 OR proof->>'gameDate' IS DISTINCT FROM p_day::text
 OR proof->>'clearanceType' IS DISTINCT FROM p_type
 OR proof->>'worldId' IS DISTINCT FROM '1'
 OR proof->>'readOnly' IS DISTINCT FROM 'true'
 OR proof->>'flightActivated' IS DISTINCT FROM 'false'
 OR proof->>'movementRecorded' IS DISTINCT FROM 'false'
 OR proof->>'bookingsCreated' IS DISTINCT FROM 'false'
 OR proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object('status','game_clearance_source_blocked','clearanceType',p_type,'sourceStatus',proof->>'status','blockers',coalesce(proof->'blockers','[]'::jsonb));END IF;
 IF p_type IN ('trusted_flight_execution','commercial_finance') THEN
  fingerprint:=proof->>'sourceFingerprint';
  IF proof->>'candidateReady' IS DISTINCT FROM 'true' OR proof->'blockers' IS DISTINCT FROM '[]'::jsonb
   OR proof->>'sourceAuthorityReleased' IS DISTINCT FROM 'false'
   OR proof->>'sourceReference' IS DISTINCT FROM 'candidate-execution-finance-v1-'||fingerprint
  THEN RETURN jsonb_build_object('status','game_clearance_source_blocked','clearanceType',p_type);END IF;
 ELSE
  fingerprint:=proof->>'proofFingerprint';
  IF proof->>'verified' IS DISTINCT FROM 'true'
   OR proof->>'reviewerReference' IS DISTINCT FROM reviewer
   OR proof->>'sourceKind' IS DISTINCT FROM source_kind
   OR proof->>'validThroughGameDate' IS DISTINCT FROM (p_day+28)::text
  THEN RETURN jsonb_build_object('status','game_clearance_source_blocked','clearanceType',p_type);END IF;
 END IF;
 source_ref:=proof->>'sourceReference';
 IF fingerprint IS NULL OR fingerprint !~ '^[a-f0-9]{32}$' OR source_ref IS NULL
 THEN RETURN jsonb_build_object('status','game_clearance_source_blocked','clearanceType',p_type);END IF;
 SELECT decrypted_secret INTO key_material FROM vault.decrypted_secrets WHERE name='airlinerra_game_clearance_'||p_type||'_v1';
 IF key_material IS NULL OR length(key_material)<64 THEN
  RETURN jsonb_build_object('status','game_clearance_key_missing','clearanceType',p_type);
 END IF;
 event_id:=concat_ws('.',prefix,replace(p_schedule::text,'-',''),p_version::text,to_char(p_day,'YYYYMMDD'),left(fingerprint,12));
 payload:=concat_ws(E'\n','airlinerra-verified-operations-certification-v1','1','1',
  p_airline::text,p_schedule::text,p_version::text,p_type,source_kind,'certify',event_id,
  source_ref,reviewer,p_day::text,(p_day+28)::text);
 signature:=encode(extensions.hmac(convert_to(payload,'UTF8'),convert_to(key_material,'UTF8'),'sha256'),'hex');
 -- Real sink independently recomputes the source fingerprint under a
 -- row lock and persists only an eligible, version-bound current decision.
 receipt:=airlinerra_game.section9_record_verified_certification_event_v1(
  p_airline,p_schedule,p_version,p_type,'certify',event_id,source_ref,reviewer,p_day,p_day+28,signature);
 IF receipt->>'status' NOT IN ('certification_event_recorded','certification_event_replayed')
 OR receipt->>'eventId' IS DISTINCT FROM event_id
 OR receipt->>'scheduleId' IS DISTINCT FROM p_schedule::text
 OR receipt->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR receipt->>'flightActivated' IS DISTINCT FROM 'false'
 OR receipt->>'movementRecorded' IS DISTINCT FROM 'false'
 OR receipt->>'bookingsCreated' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='GAME_CLEARANCE_RECEIPT_UNCONFIRMED';END IF;
 RETURN receipt;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_certify_queued_roundtrips_v1(p_limit integer DEFAULT 10)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE clock_proof jsonb;day date;q record;leg record;kind text;r jsonb;finished integer:=0;checked integer:=0;waiting integer:=0;
 blocked boolean;key_count int;distinct_count int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_GAME_CLEARANCE_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='GAME_CLEARANCE_BATCH_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1 AND release_state='enabled' AND crew_mode='deferred_phase1')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1 AND release_state='enabled')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1 AND release_state='approved')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1 AND trusted_flight_execution_release='ACTIVATED' AND fuel_transaction_release='ACTIVATED' AND automatic_flight_and_fuel_settlement_enabled)
 THEN RETURN jsonb_build_object('status','game_clearance_release_blocked','checked',0,'activated',0);END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' OR clock_proof->>'gameDate' IS NULL
 THEN RETURN jsonb_build_object('status','game_clearance_clock_blocked','checked',0,'activated',0);END IF;
 day:=(clock_proof->>'gameDate')::date;
 SELECT count(*),count(DISTINCT decrypted_secret) INTO key_count,distinct_count FROM vault.decrypted_secrets
 WHERE name IN (SELECT 'airlinerra_game_clearance_'||v||'_v1' FROM unnest(ARRAY['operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance']) v)
 AND length(decrypted_secret)>=64;
 IF key_count<>5 OR distinct_count<>5 THEN RETURN jsonb_build_object('status','game_clearance_keys_unavailable','checked',0,'activated',0);END IF;
 IF NOT pg_try_advisory_xact_lock(583732,10052) THEN RETURN jsonb_build_object('status','game_clearance_batch_running','checked',0,'activated',0);END IF;
 FOR q IN SELECT * FROM airlinerra_game.section9_private_roundtrip_certification_queue_v1
 WHERE world_id=1 AND status='awaiting_independent_certification' ORDER BY staged_at,pair_key LIMIT p_limit FOR UPDATE SKIP LOCKED
 LOOP
  checked:=checked+1;blocked:=false;
  -- Every pair is its own subtransaction. Denied or stale proof rolls
  -- back this pair and does not prevent a different player from proceeding.
  BEGIN
   FOR leg IN SELECT q.outbound_schedule_id AS schedule_id,q.outbound_version AS version UNION ALL SELECT q.return_schedule_id,q.return_version
   LOOP
    FOREACH kind IN ARRAY ARRAY['operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance'] LOOP
     r:=airlinerra_game.section9_issue_queued_game_clearance_v1(q.airline_id,leg.schedule_id,leg.version,day,kind);
     IF r->>'status' NOT IN ('certification_event_recorded','certification_event_replayed') THEN
      RAISE EXCEPTION USING ERRCODE='P9001',MESSAGE='GAME_CLEARANCE_WAITING';
     END IF;
    END LOOP;
   END LOOP;
   r:=airlinerra_game.section9_finish_staged_certified_roundtrip_v1(q.pair_key);
   IF r->>'status'='certified_roundtrip_operating_inventory_committed' AND r->>'operatingRouteCreatedNow'='true'
    AND r->>'ticketSalesOpen'='true' AND r->>'ledgerPosted'='false'
   THEN finished:=finished+1;
   ELSE RAISE EXCEPTION USING ERRCODE='P9001',MESSAGE='GAME_CLEARANCE_PAIR_WAITING';END IF;
  EXCEPTION WHEN SQLSTATE 'P9001' OR SQLSTATE '42501' OR SQLSTATE '40001' OR SQLSTATE '23505' THEN
   blocked:=true;
  END;
  IF blocked THEN waiting:=waiting+1;END IF;
 END LOOP;
 RETURN jsonb_build_object('status','game_clearance_batch_completed','checked',checked,'activated',finished,'waiting',waiting,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_certify_queued_roundtrips_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
