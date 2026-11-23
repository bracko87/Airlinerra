-- Private gate for the independent GAME flight-execution producer.
-- This only authorizes an engine decision about an already-due, certified
-- event. It never itself attests, moves aircraft, sells tickets or charges.
-- No input from a player is trusted for a phase transition.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_independent_game_phase_gate_v1(
 p_airline uuid,p_aircraft uuid,p_utc_date date,p_event_id text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $gate$
DECLARE
 plan jsonb; event_data jsonb; now_utc timestamptz;
 position_row record; start_key text; receipt text;
 approved_count integer:=0; event_time timestamptz;
 active_state text; world_date date; starter jsonb;
BEGIN
 IF p_airline IS NULL OR p_aircraft IS NULL
 OR p_utc_date IS NULL
 OR p_utc_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 OR coalesce(p_event_id,'') !~ '^operate-v1[.][a-f0-9]{32}[.][0-9]{8}[.][1-7][.](departed|arrived)$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_INVALID_INDEPENDENT_PHASE_REQUEST';END IF;

 -- The global administrative execution release is distinct from clock
 -- availability and (still-disabled) automatic financial settlement.
 SELECT trusted_flight_execution_release INTO active_state
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1
 WHERE world_id=1;
 IF active_state IS DISTINCT FROM 'RELEASED'
 THEN RETURN jsonb_build_object('status','flight_execution_not_released',
  'verified',false,'readOnly',true,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 SELECT confirmed_game_date INTO world_date
 FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 AND clock_source='authoritative_game_engine'
 AND last_verified_at IS NOT NULL;
 IF world_date IS NULL OR world_date<p_utc_date
 THEN RETURN jsonb_build_object('status','certified_game_day_not_available',
  'verified',false,'readOnly',true,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 SELECT t.engine_event_id INTO receipt
 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 t
 WHERE t.world_id=1 AND t.game_date=p_utc_date;
 IF receipt IS NULL THEN
 RETURN jsonb_build_object('status','game_tick_receipt_missing',
  'verified',false,'readOnly',true,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 plan:=airlinerra_game.section9_due_operation_candidates_v1(
  p_airline,p_aircraft,p_utc_date);
 IF plan->>'status' IS DISTINCT FROM 'verified_due_operation_candidates_only'
 OR plan->>'readOnly' IS DISTINCT FROM 'true'
 OR plan->>'requiresTrustedOperationDecision' IS DISTINCT FROM 'true'
 OR jsonb_typeof(plan->'dueEvents') IS DISTINCT FROM 'array'
 THEN RETURN jsonb_build_object('status','certified_due_event_unavailable',
  'verified',false,'readOnly',true,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 SELECT item.value INTO event_data FROM
 jsonb_array_elements(plan->'dueEvents') AS item(value)
 WHERE item.value->>'eventId'=p_event_id LIMIT 1;
 IF event_data IS NULL
 THEN RETURN jsonb_build_object('status','event_not_due_or_already_operated',
  'verified',false,'readOnly',true,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 IF event_data->>'airlineId' IS DISTINCT FROM p_airline::text
 OR event_data->>'aircraftInventoryId' IS DISTINCT FROM p_aircraft::text
 OR event_data->>'worldId' IS DISTINCT FROM '1'
 OR event_data->>'activatedAndCapacityVerified' IS DISTINCT FROM 'true'
 OR event_data->>'eventId' IS DISTINCT FROM p_event_id
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNTRUSTED_DUE_OPERATION_IDENTITY';END IF;

 now_utc:=date_trunc('second',clock_timestamp());
 event_time:=(event_data->>'scheduledEventUtc')::timestamptz;
 IF event_time>now_utc OR now_utc>event_time+interval '3 hours'
 OR (now_utc AT TIME ZONE 'UTC')::date IS DISTINCT FROM p_utc_date
 THEN RETURN jsonb_build_object('status','event_outside_safe_clock_window',
  'verified',false,'readOnly',true,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 -- Six independently signed and non-revoked approvals for this exact
 -- version, within their validity period and tied to immutable audit events.
 SELECT count(DISTINCT cert.clearance_type)::int INTO approved_count
 FROM airlinerra_game.section9_schedule_operational_certifications_v1 cert
 JOIN airlinerra_game.section9_operational_certification_events_v1 audit
 ON audit.event_id=cert.last_verified_event_id
 AND audit.schedule_id=cert.schedule_id
 AND audit.schedule_version=cert.schedule_version
 AND audit.airline_id=cert.airline_id
 AND audit.clearance_type=cert.clearance_type
 AND audit.action='certify'
 AND audit.source_reference=cert.source_reference
 AND audit.reviewer_reference=cert.reviewer_reference
 AND audit.recorded_at=cert.reviewed_at
 WHERE cert.airline_id=p_airline
 AND cert.schedule_id=(event_data->>'scheduleId')::uuid
 AND cert.schedule_version=(event_data->>'scheduleVersion')::integer
 AND cert.review_status='certified'
 AND cert.valid_from_game_date<=p_utc_date
 AND cert.valid_to_game_date>=p_utc_date
 AND cert.clearance_type IN (
   'crew_duty','operator_licence','route_traffic_rights',
   'airport_slot_capacity','trusted_flight_execution','commercial_finance');
 IF approved_count<>6 THEN
 RETURN jsonb_build_object('status','six_signed_clearances_missing',
  'verified',false,'readOnly',true,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 SELECT pos.location_status,pos.airport_key,pos.current_flight_occurrence_id,
 pos.last_event_utc INTO position_row
 FROM airlinerra_game.section9_aircraft_current_position_v1 pos
 WHERE pos.aircraft_inventory_id=p_aircraft AND pos.airline_id=p_airline;

 IF event_data->>'phase'='departed' THEN
  IF FOUND THEN
   IF position_row.location_status IS DISTINCT FROM 'grounded'
   OR position_row.airport_key IS DISTINCT FROM event_data->>'originAirportKey'
   OR position_row.last_event_utc>now_utc
   THEN RETURN jsonb_build_object('status','aircraft_not_grounded_at_origin',
     'verified',false,'readOnly',true,'movementRecorded',false,
     'bookingsCreated',false,'ledgerPosted',false);END IF;
  ELSE
   starter:=airlinerra_game.section9_starter_origin_evidence_v1(
     p_airline,p_aircraft,p_utc_date);
   start_key:=CASE WHEN starter->>'verified'='true'
     THEN starter->>'airportKey' ELSE NULL END;
   IF start_key IS NULL THEN
    SELECT anchor.airport_key INTO start_key
    FROM airlinerra_game.section9_aircraft_delivery_position_v1 anchor
    WHERE anchor.airline_id=p_airline
    AND anchor.aircraft_inventory_id=p_aircraft
    AND anchor.anchored_game_date<=p_utc_date;
   END IF;
   IF start_key IS DISTINCT FROM event_data->>'originAirportKey'
   THEN RETURN jsonb_build_object('status','initial_departure_origin_not_verified',
     'verified',false,'readOnly',true,'movementRecorded',false,
     'bookingsCreated',false,'ledgerPosted',false);END IF;
  END IF;
 ELSIF event_data->>'phase'='arrived' THEN
  IF NOT FOUND
  OR position_row.location_status IS DISTINCT FROM 'in_flight'
  OR position_row.current_flight_occurrence_id IS DISTINCT FROM
     event_data->>'flightOccurrenceId'
  OR NOT EXISTS (
   SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 depart
   WHERE depart.world_id=1 AND depart.airline_id=p_airline
   AND depart.aircraft_inventory_id=p_aircraft
   AND depart.flight_occurrence_id=event_data->>'flightOccurrenceId'
   AND depart.phase='departed'
   AND depart.actual_event_utc<=now_utc)
  THEN RETURN jsonb_build_object('status','verified_departure_not_present',
     'verified',false,'readOnly',true,'movementRecorded',false,
     'bookingsCreated',false,'ledgerPosted',false);END IF;
 ELSE RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNEXPECTED_PHASE';END IF;

 RETURN jsonb_build_object('status','independent_game_phase_authorized',
  'verified',true,'readOnly',true,'worldId',1,
  'event',event_data,'actualEventUtc',
    to_char(now_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'certifiedClockReceiptId',receipt,
  'operationReference','game-exec-v1.'||md5(p_event_id),
  'approvedClearances',approved_count,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
END $gate$;

REVOKE ALL ON FUNCTION
 airlinerra_game.section9_independent_game_phase_gate_v1(uuid,uuid,date,text)
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION
 airlinerra_game.section9_independent_game_phase_gate_v1(uuid,uuid,date,text)
 IS 'Private server-time, certificate, position and signed-clock gate; gives no movement or financial authority by itself.';
