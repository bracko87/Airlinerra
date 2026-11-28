-- ROLLBACK-ONLY REVIEW. Owner-confirmed outbound reactivation request.
-- Reuse the request identity, but explicitly exclude it from the inbound worker.
-- No aircraft movement, slot reservation, financial hold or storage closure.
BEGIN;
ALTER TABLE airlinerra_game.aircraft_storage_relocation_requests_v1
 ADD COLUMN purpose text NOT NULL DEFAULT 'storage_inbound',
 ADD COLUMN storage_session_id uuid REFERENCES airlinerra_game.aircraft_storage_sessions_v1(request_id),
 DROP CONSTRAINT aircraft_storage_request_status_v2,
 ADD CONSTRAINT aircraft_storage_request_status_v3 CHECK(status IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review','cancelled','completed')),
 ADD CONSTRAINT aircraft_storage_request_purpose_v1 CHECK(
 (purpose='storage_inbound' AND storage_session_id IS NULL AND status<>'reactivation_awaiting_review')
 OR (purpose='storage_reactivation' AND storage_session_id IS NOT NULL AND status<>'awaiting_slot_and_dispatch_release'));
DROP INDEX airlinerra_game.aircraft_storage_one_pending_request_v1;
CREATE UNIQUE INDEX aircraft_storage_one_pending_request_v1
 ON airlinerra_game.aircraft_storage_relocation_requests_v1(aircraft_inventory_id)
 WHERE status IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review');

-- Read-only due-month check; no future month is charged by a request.
-- Match the current billing rule: first month due on arrival, later monthly
-- anniversaries due on the Berlin calendar day. Departure release must
-- re-evaluate billing at actual departure.
CREATE FUNCTION airlinerra_game.aircraft_storage_reactivation_billing_check_v1(p_session uuid,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE s record; t record; n integer; max_n integer; due_count integer; next_due date; day_key date;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=p_session AND storage_ended_utc IS NULL;
 IF NOT FOUND OR p_at IS NULL OR p_at<s.storage_started_utc THEN RETURN jsonb_build_object('status','storage_session_unverified','cleared',false);END IF;
 SELECT * INTO t FROM airlinerra_game.aircraft_storage_billing_terms_v1 WHERE request_id=p_session;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_billing_terms_missing','cleared',false);END IF;
 day_key:=(p_at AT TIME ZONE 'Europe/Berlin')::date;
 due_count:=(extract(year FROM day_key)::int-extract(year FROM t.anchor_game_date)::int)*12
 +extract(month FROM day_key)::int-extract(month FROM t.anchor_game_date)::int+1;
 IF airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,due_count-1)>day_key THEN due_count:=due_count-1;END IF;
 SELECT count(*)::int,coalesce(max(month_number),0) INTO n,max_n FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 WHERE request_id=p_session;
 IF n<>max_n OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 x WHERE x.request_id=p_session AND
 (x.amount_usd<>t.monthly_usd OR x.due_game_date<>airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,x.month_number-1)
 OR x.coverage_end_game_date<>airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,x.month_number)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger l WHERE l.id=x.ledger_id AND l.airline_id=s.airline_id AND l.entry_kind='EXPENSE' AND l.amount_usd=-x.amount_usd)))
 THEN RETURN jsonb_build_object('status','storage_billing_unreconciled','cleared',false);END IF;
 next_due:=airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n);
 RETURN jsonb_build_object('status',CASE WHEN n>=due_count THEN 'storage_billing_current' ELSE 'storage_billing_due' END,
 'cleared',n>=due_count,'monthsPaid',n,'monthsDue',greatest(0,due_count-n),'arrearsUsd',greatest(0,due_count-n)*t.monthly_usd,'nextDueGameDate',next_due);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_reactivation_billing_check_v1(uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.request_aircraft_storage_reactivation_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_destination text,p_departure timestamptz,p_expected_cost numeric,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE a record; i record; s record; prior record; pos record; v_now timestamptz; q jsonb; billing jsonb; arrival timestamptz; ledger numeric; new_id uuid;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_request IS NULL OR p_destination IS NULL OR p_expected_cost IS NULL OR p_expected_cost<=0 OR p_departure IS NULL OR p_departure<>date_trunc('second',p_departure)
 THEN RETURN jsonb_build_object('status','invalid_reactivation_request','created',false);END IF;
 SELECT x.* INTO a FROM airlinerra_game.airlines x JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE x.id=p_airline AND x.world_id=1 AND x.owner_player_id=p_player FOR UPDATE OF x;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='REACTIVATION_AIRLINE_NOT_OWNED';END IF;
 SELECT * INTO i FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='REACTIVATION_AIRCRAFT_NOT_OWNED';END IF;
 SELECT * INTO prior FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE airline_id=p_airline AND request_key=p_request;
 IF FOUND THEN
 IF prior.purpose<>'storage_reactivation' OR prior.aircraft_inventory_id<>p_aircraft OR prior.destination_airport_key<>p_destination OR prior.departure_utc<>p_departure OR prior.quoted_cost_usd<>p_expected_cost
 THEN RETURN jsonb_build_object('status','storage_request_key_conflict','created',false);END IF;
 RETURN jsonb_build_object('status',prior.status,'requestId',prior.id,'created',false,'replayed',true,'flightScheduled',false);END IF;
 IF i.fleet_status<>'stored' THEN RETURN jsonb_build_object('status','aircraft_not_stored','created',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE aircraft_inventory_id=p_aircraft AND status IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review'))
 THEN RETURN jsonb_build_object('status','storage_request_already_pending','created',false);END IF;
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND storage_ended_utc IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','active_storage_session_missing','created',false);END IF;
 SELECT * INTO pos FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline FOR UPDATE;
 IF NOT FOUND OR pos.location_status<>'grounded' OR pos.airport_key IS DISTINCT FROM s.airport_key OR pos.storage_request_id IS DISTINCT FROM s.request_id OR pos.last_engine_event_id IS DISTINCT FROM s.arrival_engine_event_id
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.engine_event_id=s.arrival_engine_event_id AND m.storage_request_id=s.request_id AND m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline AND m.phase='arrived' AND m.destination_airport_key=s.airport_key AND m.actual_event_utc=s.storage_started_utc)
 THEN RETURN jsonb_build_object('status','stored_aircraft_position_unverified','created',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR v_now<s.storage_started_utc OR p_departure<v_now+interval '1 minute' OR p_departure>v_now+interval '7 days'
 THEN RETURN jsonb_build_object('status','storage_departure_unverified','created',false);END IF;
 IF s.airport_key=p_destination THEN RETURN jsonb_build_object('status','reactivation_requires_relocation','created',false);END IF;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(s.airport_key,'storage_reactivation')->>'eligible' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','storage_reactivation_not_approved','created',false);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 u WHERE u.world_id=1 AND u.airport_key=p_destination AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission)
 THEN RETURN jsonb_build_object('status','reactivation_destination_not_authorized','created',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND status='active')
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND status IN('scheduled','in_progress','payment_required'))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=p_aircraft AND status='reserved')
 THEN RETURN jsonb_build_object('status','aircraft_commitment_conflict','created',false);END IF;
 q:=airlinerra_game.aircraft_storage_relocation_cost_v1(i.configuration_id,s.airport_key,p_destination,'storage_reactivation');
 IF q->>'status' IS DISTINCT FROM 'storage_relocation_cost_estimate' OR q->>'fuelRangeConfirmed' IS DISTINCT FROM 'true'
 OR q->>'directOperatingCostUsd' IS NULL OR q#>>'{phases,totalMinutes}' IS NULL
 THEN RETURN jsonb_build_object('status','reactivation_quote_blocked','created',false,'quote',q);END IF;
 IF (q->>'directOperatingCostUsd')::numeric<>p_expected_cost THEN RETURN jsonb_build_object('status','storage_price_changed','created',false,'quote',q);END IF;
 billing:=airlinerra_game.aircraft_storage_reactivation_billing_check_v1(s.request_id,v_now);
 IF billing->>'status' NOT IN('storage_billing_current','storage_billing_due') OR billing->>'status' IS NULL THEN RETURN jsonb_build_object('status','storage_billing_unverified','created',false,'billing',billing);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO ledger FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF a.cash_usd IS DISTINCT FROM ledger OR a.cash_usd<p_expected_cost THEN RETURN jsonb_build_object('status','storage_funds_unverified_or_insufficient','created',false);END IF;
 arrival:=p_departure+make_interval(mins=>(q#>>'{phases,totalMinutes}')::integer);
 INSERT INTO airlinerra_game.aircraft_storage_relocation_requests_v1(airline_id,aircraft_inventory_id,owner_player_id,request_key,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,quoted_cost_usd,quote,status,purpose,storage_session_id)
 VALUES(p_airline,p_aircraft,p_player,p_request,s.airport_key,p_destination,p_departure,arrival,p_expected_cost,q,'reactivation_awaiting_review','storage_reactivation',s.request_id) RETURNING id INTO new_id;
 RETURN jsonb_build_object('status','reactivation_awaiting_review','created',true,'requestId',new_id,'originAirport',s.airport_key,'destinationAirport',p_destination,'departureUtc',p_departure,'arrivalUtc',arrival,'billing',billing,'flightScheduled',false,'fundsHeld',false,'slotsReserved',false,'aircraftStillStored',true,'storageBillingContinues',true);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.request_aircraft_storage_reactivation_v1(uuid,uuid,uuid,text,timestamptz,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
