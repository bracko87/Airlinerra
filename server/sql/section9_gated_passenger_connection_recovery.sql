-- Passenger-only two-leg itinerary recovery. No ledger write and no live activation.
ALTER TABLE airlinerra_game.section9_disruption_release_v1
 ADD COLUMN IF NOT EXISTS connecting_recovery_enabled boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_connection_recovery_receipts_v1(
 source_allocation_key text PRIMARY KEY REFERENCES airlinerra_game.section9_atomic_itinerary_holds_v1(source_allocation_key),
 replacement_allocation_key text UNIQUE REFERENCES airlinerra_game.section9_atomic_itinerary_holds_v1(source_allocation_key),
 first_ticket_key text NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 result jsonb NOT NULL CHECK(jsonb_typeof(result)='object')
);
ALTER TABLE airlinerra_game.section9_connection_recovery_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_connection_recovery_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_recover_connecting_passengers_v1(
 p_allocation text,p_cancelled_leg text DEFAULT NULL,p_max_wait_minutes integer DEFAULT 1440
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE h record; f record; s record; t record; fcap record; scap record; tcap record; fb record; sb record;
 ft record; st record; tt record; now_utc timestamptz; ready timestamptz; mct integer;
 first_key text; second_key text; new_key text; replacement text; physical text; receipt jsonb;
 first_departed boolean; first_has_ticket boolean; second_has_ticket boolean; second_departed boolean;
 reason text; result jsonb; n integer; first_released boolean:=false; target_id uuid;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_CONNECTION_RECOVERY';END IF;
 IF p_allocation IS NULL OR p_max_wait_minutes IS NULL OR p_max_wait_minutes NOT BETWEEN 60 AND 2880 THEN RAISE EXCEPTION 'INVALID_CONNECTION_RECOVERY_INPUT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_disruption_release_v1 WHERE world_id=1 AND connecting_recovery_enabled) THEN
  RETURN jsonb_build_object('status','connection_recovery_not_released','recovered',false);END IF;
 IF NOT pg_try_advisory_xact_lock(583729,10041) THEN RETURN jsonb_build_object('status','connection_dispatch_busy','recovered',false);END IF;
 SELECT r.result INTO receipt FROM airlinerra_game.section9_connection_recovery_receipts_v1 r WHERE r.source_allocation_key=p_allocation;
 IF FOUND THEN RETURN receipt||jsonb_build_object('replayed',true);END IF;
 SELECT * INTO h FROM airlinerra_game.section9_atomic_itinerary_holds_v1 WHERE source_allocation_key=p_allocation FOR UPDATE;
 IF NOT FOUND OR h.status<>'preflight_only' OR cardinality(h.physical_flight_ids)<>2 OR h.passengers<=0 OR h.cargo_tonnes<>0 THEN
 RETURN jsonb_build_object('status','passenger_connection_unavailable_or_mixed_cargo','recovered',false);END IF;
 IF p_cancelled_leg IS NOT NULL AND NOT p_cancelled_leg=ANY(h.physical_flight_ids) THEN RAISE EXCEPTION 'CANCELLATION_NOT_IN_CONNECTION';END IF;
 SELECT o.* INTO f FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text=h.physical_flight_ids[1];
 SELECT o.* INTO s FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text=h.physical_flight_ids[2];
 IF f.id IS NULL OR s.id IS NULL OR f.destination_airport_key<>s.origin_airport_key OR f.world_id<>1 OR s.world_id<>1 THEN
 RETURN jsonb_build_object('status','connection_occurrences_unverified','recovered',false);END IF;
 SELECT minimum_transfer_minutes INTO mct FROM airlinerra_game.section9_airport_transfer_policy_v1 WHERE world_id=1 AND airport_key=f.destination_airport_key;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR mct IS NULL THEN RETURN jsonb_build_object('status','connection_clock_or_transfer_policy_missing','recovered',false);END IF;
 SELECT * INTO ft FROM airlinerra_game.section9_effective_dispatch_window_v1(f.id);
 SELECT * INTO st FROM airlinerra_game.section9_effective_dispatch_window_v1(s.id);
 SELECT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=h.physical_flight_ids[1] AND phase='departed'),
 EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=h.physical_flight_ids[2] AND phase='departed') INTO first_departed,second_departed;
 IF second_departed OR s.booking_status<>'open' OR (NOT first_departed AND f.booking_status<>'open') THEN
 RETURN jsonb_build_object('status','connection_recovery_requires_unflown_open_leg','recovered',false);END IF;
 IF p_cancelled_leg=h.physical_flight_ids[1] AND first_departed THEN RETURN jsonb_build_object('status','first_leg_already_departed','recovered',false);END IF;
 SELECT coalesce((SELECT m.actual_event_utc FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=h.physical_flight_ids[1] AND m.phase='arrived'),ft.effective_arrival_utc)+make_interval(mins=>mct) INTO ready;
 IF p_cancelled_leg=h.physical_flight_ids[1] THEN reason:='first_leg_cancelled';
 ELSIF p_cancelled_leg=h.physical_flight_ids[2] THEN reason:='second_leg_cancelled';
 ELSIF ready>st.effective_departure_utc THEN reason:='minimum_transfer_time_missed';
 ELSE RETURN jsonb_build_object('status','connection_still_valid','recovered',false,'minimumTransferMinutes',mct);END IF;
 SELECT r.first_ticket_key INTO first_key FROM airlinerra_game.section9_connection_recovery_receipts_v1 r WHERE r.replacement_allocation_key=p_allocation;
 first_key:=coalesce(first_key,'demand.'||p_allocation);second_key:='demand.'||p_allocation;
 -- Search a certified same-outbound-airline flight to the original final destination.
 -- No partner substitution or new fare is inferred.
 IF reason<>'first_leg_cancelled' THEN
 SELECT o.id,c.physical_flight_id INTO target_id,replacement
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 c ON c.physical_flight_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 d ON d.id=o.schedule_id AND d.airline_id=o.airline_id AND d.version=o.schedule_version AND d.status='active' AND d.operationally_verified
 JOIN airlinerra_game.section9_verified_schedule_capacity_v1 v ON v.schedule_id=d.id AND v.airline_id=d.airline_id AND v.schedule_version=d.version
 JOIN airlinerra_game.section9_route_commercial_plans_v1 cp ON cp.schedule_id=d.id AND cp.airline_id=d.airline_id AND cp.version=c.commercial_version
 JOIN airlinerra_game.airline_aircraft_inventory fleet ON fleet.id=o.aircraft_inventory_id AND fleet.airline_id=o.airline_id AND fleet.fleet_status='in_service'
 CROSS JOIN LATERAL airlinerra_game.section9_effective_dispatch_window_v1(o.id) timing
 WHERE o.id NOT IN(f.id,s.id) AND o.world_id=1 AND o.airline_id=s.airline_id
 AND o.origin_airport_key=s.origin_airport_key AND o.destination_airport_key=s.destination_airport_key
 AND o.booking_status='open' AND o.source_kind='game_verified_saleable_schedule_v1' AND timing.dispatch_allowed
 AND timing.effective_departure_utc>=greatest(ready,now_utc+interval '1 minute')
 AND timing.effective_departure_utc<=ready+make_interval(mins=>p_max_wait_minutes)
 AND c.status='preflight_only' AND c.airline_id=o.airline_id AND c.schedule_version=o.schedule_version
 AND c.departure_utc=o.departure_utc AND c.arrival_utc=o.arrival_utc AND c.passenger_capacity=v.passenger_seats
 AND c.passenger_capacity=o.verified_passenger_seats AND c.passengers_held+h.passengers<=c.passenger_capacity
 AND o.booked_seats+h.passengers<=o.verified_passenger_seats
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=c.physical_flight_id)
 AND (f.airline_id=o.airline_id OR EXISTS(SELECT 1 FROM airlinerra_game.section9_interline_agreements_v1 ag
  WHERE ag.world_id=1 AND ag.agreement_status='active' AND ag.left_approved_at IS NOT NULL AND ag.right_approved_at IS NOT NULL
  AND ((ag.left_airline_id=f.airline_id AND ag.right_airline_id=o.airline_id) OR (ag.right_airline_id=f.airline_id AND ag.left_airline_id=o.airline_id))
  AND ag.valid_from<=ft.effective_departure_utc AND (ag.valid_until IS NULL OR ag.valid_until>timing.effective_arrival_utc)))
 ORDER BY timing.effective_arrival_utc,timing.effective_departure_utc,o.id LIMIT 1;
 END IF;
 -- Capacity before booked-seat rows, in physical key order.
 PERFORM 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 c
 WHERE c.physical_flight_id=ANY(h.physical_flight_ids) OR c.physical_flight_id=replacement ORDER BY c.physical_flight_id FOR UPDATE;
 PERFORM 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id IN(f.id,s.id,target_id) ORDER BY o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text FOR UPDATE;
 SELECT * INTO fcap FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id=h.physical_flight_ids[1];
 SELECT * INTO scap FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id=h.physical_flight_ids[2];
 SELECT * INTO f FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=f.id;
 SELECT * INTO s FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=s.id;
 IF fcap.physical_flight_id IS NULL OR scap.physical_flight_id IS NULL OR fcap.passengers_held<h.passengers OR scap.passengers_held<h.passengers
 OR s.booking_status<>'open' OR (NOT first_departed AND f.booking_status<>'open') THEN
 RETURN jsonb_build_object('status','connection_inventory_reconciliation_required','recovered',false);END IF;
 SELECT * INTO fb FROM airlinerra_game.section9_passenger_reservation_batches_v1 WHERE occurrence_id=f.id AND reservation_key=first_key FOR UPDATE;first_has_ticket:=FOUND;
 SELECT * INTO sb FROM airlinerra_game.section9_passenger_reservation_batches_v1 WHERE occurrence_id=s.id AND reservation_key=second_key FOR UPDATE;second_has_ticket:=FOUND;
 IF first_has_ticket<>second_has_ticket OR (first_departed AND NOT first_has_ticket)
 OR (first_has_ticket AND (fb.reservation_status<>'reserved' OR sb.reservation_status<>'reserved' OR fb.seats_requested<>h.passengers OR sb.seats_requested<>h.passengers OR fb.paid_upfront OR sb.paid_upfront OR fb.recognized_revenue_usd<>0 OR sb.recognized_revenue_usd<>0 OR f.booked_seats<h.passengers OR s.booked_seats<h.passengers))
 THEN RETURN jsonb_build_object('status','connection_ticket_reconciliation_required','recovered',false);END IF;
 -- Unissued holds cannot be promoted under a mutated demand-plan proof; release them.
 IF NOT second_has_ticket THEN replacement:=NULL;target_id:=NULL;END IF;
 IF replacement IS NOT NULL THEN
 SELECT * INTO tcap FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id=replacement;
 SELECT * INTO t FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=target_id;
 SELECT * INTO tt FROM airlinerra_game.section9_effective_dispatch_window_v1(target_id);
 IF t.booking_status<>'open' OR NOT tt.dispatch_allowed OR tt.effective_departure_utc<greatest(ready,now_utc+interval '1 minute') OR tcap.passengers_held+h.passengers>tcap.passenger_capacity OR t.booked_seats+h.passengers>t.verified_passenger_seats THEN
 RETURN jsonb_build_object('status','replacement_capacity_changed_retry','recovered',false);END IF;
 END IF;
 -- Release missed second leg; preserve all unrelated passengers.
 UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1 SET passengers_held=passengers_held-h.passengers WHERE physical_flight_id=h.physical_flight_ids[2];
 IF second_has_ticket THEN
 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1 SET reservation_status='cancelled' WHERE id=sb.id;
 UPDATE airlinerra_game.section9_dated_flight_occurrences_v1 SET booked_seats=booked_seats-h.passengers WHERE id=s.id;
 END IF;
 UPDATE airlinerra_game.section9_atomic_itinerary_holds_v1 SET status='cancelled' WHERE source_allocation_key=p_allocation;
 IF replacement IS NOT NULL THEN
 new_key:='s9r1:'||md5(p_allocation||':'||replacement);
 INSERT INTO airlinerra_game.section9_atomic_itinerary_holds_v1(source_allocation_key,physical_flight_ids,passengers,cargo_tonnes)
 VALUES(new_key,ARRAY[h.physical_flight_ids[1],replacement],h.passengers,0);
 INSERT INTO airlinerra_game.section9_atomic_itinerary_hold_legs_v1(source_allocation_key,leg_number,physical_flight_id) VALUES(new_key,1,h.physical_flight_ids[1]),(new_key,2,replacement);
 UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1 SET passengers_held=passengers_held+h.passengers WHERE physical_flight_id=replacement;
 UPDATE airlinerra_game.section9_dated_flight_occurrences_v1 SET booked_seats=booked_seats+h.passengers WHERE id=target_id;
 INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1(occurrence_id,reservation_key,fare_class,seats_requested,quoted_fare_usd,reservation_status,paid_upfront,recognized_revenue_usd)
 VALUES(target_id,'demand.'||new_key,sb.fare_class,h.passengers,sb.quoted_fare_usd,'reserved',false,0);
 ELSE
 IF NOT first_departed THEN
  UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1 SET passengers_held=passengers_held-h.passengers WHERE physical_flight_id=h.physical_flight_ids[1];
  IF first_has_ticket THEN
   UPDATE airlinerra_game.section9_passenger_reservation_batches_v1 SET reservation_status='cancelled' WHERE id=fb.id;
   UPDATE airlinerra_game.section9_dated_flight_occurrences_v1 SET booked_seats=booked_seats-h.passengers WHERE id=f.id;
  END IF;
  first_released:=true;
 END IF;
 END IF;
 result:=jsonb_build_object('status',CASE WHEN replacement IS NOT NULL THEN 'connection_rebooked' ELSE 'connection_unflown_seats_released' END,
 'reason',reason,'recovered',true,'replayed',false,'passengers',h.passengers,'originalSecondFlight',h.physical_flight_ids[2],
 'replacementFlight',replacement,'replacementAllocationKey',new_key,'minimumTransferMinutes',mct,'firstLegAlreadyDeparted',first_departed,'firstLegReleased',first_released,
 'originalSecondFareUsd',CASE WHEN second_has_ticket THEN sb.quoted_fare_usd ELSE 0 END,'foregoneUnflownQuoteUsd',CASE WHEN replacement IS NULL AND second_has_ticket THEN sb.quoted_fare_usd*h.passengers+CASE WHEN first_released THEN fb.quoted_fare_usd*h.passengers ELSE 0 END ELSE 0 END,
 'additionalChargeUsd',0,'refundUsd',0,'ledgerPosted',false,'revenueRecognized',false);
 INSERT INTO airlinerra_game.section9_connection_recovery_receipts_v1(source_allocation_key,replacement_allocation_key,first_ticket_key,result) VALUES(p_allocation,new_key,first_key,result);
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_recover_connecting_passengers_v1(text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
