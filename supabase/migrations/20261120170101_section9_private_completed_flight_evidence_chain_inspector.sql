-- World 1 completed-flight evidence chain inspector. READ-ONLY, NO RELEASE.
-- Checks durable source presence, NOT cryptographic authenticity or approval
-- for flight operation. Independent post-arrival settlement verifies signatures.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_inspect_completed_flight_chain_v1(
 p_physical_flight_id text
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
 v_occ record; v_depart record;v_arrive record;v_usage record;
 v_prepare record;v_cost record;v_posted record;
 v_matches integer:=0;v_status text;v_blockers text[]:=ARRAY[]::text[];
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_PRIVATE_FLIGHT_CHAIN_INSPECTION_ONLY';
 END IF;
 IF p_physical_flight_id IS NULL OR
 p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_INVALID_PHYSICAL_FLIGHT_ID';
 END IF;

 SELECT count(*)::int INTO v_matches
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.schedule_id::text||':'||o.flight_local_date::text||':'||
       o.weekly_entry::text=p_physical_flight_id;
 IF v_matches>1 THEN
  RETURN jsonb_build_object('status','CHAIN_INTEGRITY_CONFLICT',
   'readOnly',true,'canPost',false,'ledgerPosted',false,
   'flightActivated',false,'bookingsCreated',false,
   'issues',jsonb_build_array('DUPLICATE_OCCURRENCE'));
 END IF;
 SELECT o.* INTO v_occ
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.schedule_id::text||':'||o.flight_local_date::text||':'||
       o.weekly_entry::text=p_physical_flight_id;
 IF NOT FOUND THEN v_blockers:=array_append(v_blockers,'VERIFIED_OCCURRENCE_MISSING');END IF;
 
 SELECT m.* INTO v_depart FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.world_id=1 AND m.flight_occurrence_id=p_physical_flight_id
 AND m.phase='departed' ORDER BY m.recorded_at DESC LIMIT 1;
 SELECT m.* INTO v_arrive FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.world_id=1 AND m.flight_occurrence_id=p_physical_flight_id
 AND m.phase='arrived' ORDER BY m.recorded_at DESC LIMIT 1;
 IF v_depart.engine_event_id IS NULL THEN
  v_blockers:=array_append(v_blockers,'SIGNED_DEPARTURE_MISSING');END IF;
 IF v_arrive.engine_event_id IS NULL THEN
  v_blockers:=array_append(v_blockers,'SIGNED_ARRIVAL_MISSING');END IF;
 IF v_depart.engine_event_id IS NOT NULL AND v_arrive.engine_event_id IS NOT NULL
  AND (v_depart.engine_event_id=v_arrive.engine_event_id OR
  v_depart.airline_id IS DISTINCT FROM v_arrive.airline_id OR
  v_depart.schedule_id IS DISTINCT FROM v_arrive.schedule_id OR
  v_depart.schedule_version IS DISTINCT FROM v_arrive.schedule_version OR
  v_depart.aircraft_inventory_id IS DISTINCT FROM v_arrive.aircraft_inventory_id OR
  v_depart.actual_event_utc>v_arrive.actual_event_utc) THEN
  v_blockers:=array_append(v_blockers,'OPERATED_MOVEMENT_PAIR_MISMATCH');
 END IF;
 IF v_occ.id IS NOT NULL AND v_depart.engine_event_id IS NOT NULL AND
  (v_occ.airline_id IS DISTINCT FROM v_depart.airline_id OR
   v_occ.schedule_version IS DISTINCT FROM v_depart.schedule_version OR
   v_occ.aircraft_inventory_id IS DISTINCT FROM v_depart.aircraft_inventory_id)
 THEN v_blockers:=array_append(v_blockers,'OCCURRENCE_MOVEMENT_MISMATCH');END IF;
 SELECT r.* INTO v_usage
 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 r
 WHERE r.physical_flight_id=p_physical_flight_id;
 IF v_usage.physical_flight_id IS NULL THEN
  v_blockers:=array_append(v_blockers,'ARRIVED_USAGE_RECEIPT_MISSING');
 ELSIF v_arrive.engine_event_id IS NULL OR
  v_usage.arrived_engine_event_id IS DISTINCT FROM v_arrive.engine_event_id OR
  v_usage.departed_engine_event_id IS DISTINCT FROM v_depart.engine_event_id THEN
  v_blockers:=array_append(v_blockers,'ARRIVED_USAGE_RECEIPT_MISMATCH');
 END IF;

 SELECT p.* INTO v_prepare
 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1 p
 WHERE p.physical_flight_id=p_physical_flight_id;
 IF v_prepare.physical_flight_id IS NULL THEN
  v_blockers:=array_append(v_blockers,'ACTUAL_TICKET_FINANCE_NOT_PREPARED');
 ELSIF v_arrive.engine_event_id IS NULL OR
  v_prepare.arrival_event_id IS DISTINCT FROM v_arrive.engine_event_id
 THEN v_blockers:=array_append(v_blockers,'FINANCE_ARRIVAL_PROOF_MISMATCH');END IF;

 SELECT c.* INTO v_cost
 FROM airlinerra_game.section9_flight_final_cost_approvals_v1 c
 WHERE c.physical_flight_id=p_physical_flight_id;
 IF v_cost.physical_flight_id IS NULL OR
  v_cost.approval_state IS DISTINCT FROM 'approved' THEN
  v_blockers:=array_append(v_blockers,'FINAL_GAME_COST_NOT_APPROVED');
 ELSIF v_arrive.engine_event_id IS NULL OR
  v_cost.arrived_event_id IS DISTINCT FROM v_arrive.engine_event_id THEN
  v_blockers:=array_append(v_blockers,'COST_APPROVAL_ARRIVAL_MISMATCH');END IF;
 SELECT f.* INTO v_posted
 FROM airlinerra_game.section9_route_posted_flight_financials_v1 f
 WHERE f.physical_flight_id=p_physical_flight_id;
 IF v_posted.physical_flight_id IS NULL THEN
  v_blockers:=array_append(v_blockers,'COMPLETED_FLIGHT_FINANCE_NOT_POSTED');
 ELSIF v_posted.revenue_ledger_id IS NULL OR v_posted.expense_ledger_id IS NULL OR
  v_arrive.engine_event_id IS NULL OR
  v_posted.arrived_event_id IS DISTINCT FROM v_arrive.engine_event_id THEN
  v_blockers:=array_append(v_blockers,'POSTED_FINANCE_RECEIPT_MISMATCH');END IF;
 v_status:=CASE WHEN array_length(v_blockers,1) IS NULL
  THEN 'EVIDENCE_CHAIN_PRESENT_REQUIRES_INDEPENDENT_SIGNATURE_AND_LEDGER_VERIFICATION'
  ELSE 'EVIDENCE_CHAIN_INCOMPLETE' END;
 RETURN jsonb_build_object(
  'status',v_status,'physicalFlightId',p_physical_flight_id,
  'readOnly',true,'canPost',false,'flightActivated',false,
  'bookingsCreated',false,'ledgerPosted',false,
  'occurrenceFound',v_occ.id IS NOT NULL,
  'reservedSeats',coalesce(v_occ.booked_seats,0),
  'passengerCapacity',v_occ.verified_passenger_seats,
  'departureRecorded',v_depart.engine_event_id IS NOT NULL,
  'arrivalRecorded',v_arrive.engine_event_id IS NOT NULL,
  'usageReceiptFound',v_usage.physical_flight_id IS NOT NULL,
  'financePrepared',v_prepare.physical_flight_id IS NOT NULL,
  'costApproved',v_cost.approval_state='approved',
  'alreadyPosted',v_posted.physical_flight_id IS NOT NULL,
  'issues',to_jsonb(v_blockers));
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_inspect_completed_flight_chain_v1(text)
 FROM PUBLIC,anon,authenticated,service_role;
