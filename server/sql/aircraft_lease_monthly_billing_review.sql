-- REVIEW ONLY: recurring factory lease billing. Not a migration, release switch
-- or cron installation. Existing market publication guards remain unchanged.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_lease_monthly_receipts_v1 (
 order_id uuid NOT NULL REFERENCES airlinerra_game.aircraft_acquisition_orders_v1(order_id) ON DELETE RESTRICT,
 month_number integer NOT NULL CHECK(month_number BETWEEN 1 AND 240),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE RESTRICT,
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 due_game_date date NOT NULL,
 coverage_end_game_date date NOT NULL CHECK(coverage_end_game_date>due_game_date),
 amount_usd numeric(14,2) NOT NULL CHECK(amount_usd>0),
 ledger_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id) ON DELETE RESTRICT,
 paid_at timestamptz NOT NULL,
 PRIMARY KEY(order_id,month_number)
);
ALTER TABLE airlinerra_game.aircraft_lease_monthly_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_lease_monthly_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.reject_aircraft_lease_receipt_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LEASE_RECEIPT_IMMUTABLE';
END $$;
CREATE TRIGGER aircraft_lease_receipt_immutable
 BEFORE UPDATE OR DELETE ON airlinerra_game.aircraft_lease_monthly_receipts_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_aircraft_lease_receipt_mutation_v1();
REVOKE ALL ON FUNCTION airlinerra_game.reject_aircraft_lease_receipt_mutation_v1() FROM PUBLIC,anon,authenticated,service_role;

-- Each installment covers one calendar-month interval, starting on the
-- signed delivery game date. Calculate anniversaries from the original
-- anchor (Jan 31 -> Feb 28 -> Mar 31), not the prior clipped anniversary.
CREATE FUNCTION airlinerra_game.aircraft_lease_anniversary_v1(p_anchor date,p_offset integer)
RETURNS date LANGUAGE sql IMMUTABLE STRICT SET search_path=pg_catalog AS $$
 SELECT (p_anchor+make_interval(months=>p_offset))::date
$$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_lease_anniversary_v1(date,integer) FROM PUBLIC,anon,authenticated,service_role;

-- Internal transaction: charge only the earliest unpaid due month.
-- Never accept player-provided prices, contract length, game time or aircraft.
-- No financial writes before a matching immutable approved delivery anchor.
CREATE FUNCTION airlinerra_game.post_aircraft_lease_month_v1(p_airline uuid,p_order uuid,p_month integer)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE company record; terms record; prior record; n integer; max_month integer; due date; ends date;
 game_now timestamptz; game_day date; ledger_total numeric; lid bigint;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_order IS NULL OR p_month IS NULL OR p_month<1 OR p_month>240
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_LEASE_PAYMENT_SCOPE';END IF;
 game_now:=airlinerra_game.section9_verified_world_instant_v1();
 game_day:=(game_now AT TIME ZONE 'Europe/Berlin')::date;
 -- Airline cash is the shared serialization point for simultaneous payment
 -- requests and other balance/ledger transactions.
 SELECT a.id,a.cash_usd INTO company FROM airlinerra_game.airlines a
 WHERE a.id=p_airline AND a.world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LEASE_AIRLINE_NOT_FOUND';END IF;
 SELECT o.*,i.fleet_status,i.ownership_type,i.registration AS current_registration,i.configuration_id AS current_configuration,
 d.anchored_game_date,d.recorded_at AS anchor_recorded_at,d.inspection_reviewed_at
 INTO terms
 FROM airlinerra_game.aircraft_acquisition_orders_v1 o
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=o.aircraft_inventory_id AND i.airline_id=o.airline_id
 LEFT JOIN airlinerra_game.section9_aircraft_delivery_position_v1 d
 ON d.acquisition_order_id=o.order_id AND d.aircraft_inventory_id=i.id AND d.airline_id=o.airline_id AND d.world_id=o.world_id
 WHERE o.order_id=p_order AND o.airline_id=p_airline AND o.world_id=1 AND o.transaction_type='lease'
 FOR SHARE OF o,i;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LEASE_ORDER_NOT_OWNED';END IF;
 -- Idempotent replay returns the original receipt even if delivery status
 -- later changes. Never post a second amount for the same installment.
 SELECT * INTO prior FROM airlinerra_game.aircraft_lease_monthly_receipts_v1 WHERE order_id=p_order AND month_number=p_month;
 IF FOUND THEN
  IF prior.airline_id<>p_airline OR prior.aircraft_inventory_id<>terms.aircraft_inventory_id
  OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger l WHERE l.id=prior.ledger_id AND l.airline_id=p_airline AND l.entry_kind='AIRCRAFT_LEASE' AND l.amount_usd=-prior.amount_usd)
  THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='LEASE_RECEIPT_LEDGER_MISMATCH';END IF;
  RETURN jsonb_build_object('status','already_paid','month',p_month,'ledgerId',prior.ledger_id,'amountUsd',prior.amount_usd,'ledgerPosted',false);
 END IF;
 IF terms.order_status<>'delivered_pending_inspection' OR terms.anchored_game_date IS NULL
 OR terms.anchored_game_date>game_day OR terms.anchor_recorded_at IS NULL OR terms.anchor_recorded_at>game_now
 OR terms.inspection_reviewed_at IS NULL OR terms.inspection_reviewed_at>game_now OR terms.delivery_due_at>game_now
 OR terms.ownership_type<>'leased' OR terms.fleet_status NOT IN('in_service','maintenance')
 OR terms.registration IS DISTINCT FROM terms.current_registration OR terms.configuration_id IS DISTINCT FROM terms.current_configuration
 THEN RETURN jsonb_build_object('status','delivery_not_verified','ledgerPosted',false);END IF;
 IF terms.contract_months IS NULL OR terms.contract_months NOT BETWEEN 1 AND 240
 OR terms.recurring_monthly_usd IS NULL OR terms.recurring_monthly_usd<=0
 OR terms.recurring_monthly_usd<>round(terms.recurring_monthly_usd,2)
 THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='INVALID_LEASE_TERMS';END IF;
 IF p_month>terms.contract_months THEN RETURN jsonb_build_object('status','contract_term_complete','ledgerPosted',false);END IF;
 SELECT count(*)::int,coalesce(max(month_number),0) INTO n,max_month FROM airlinerra_game.aircraft_lease_monthly_receipts_v1 WHERE order_id=p_order;
 IF n<>max_month OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_lease_monthly_receipts_v1 x WHERE x.order_id=p_order AND
  (x.airline_id<>p_airline OR x.aircraft_inventory_id<>terms.aircraft_inventory_id OR x.month_number>terms.contract_months
   OR x.amount_usd<>terms.recurring_monthly_usd OR x.due_game_date<>airlinerra_game.aircraft_lease_anniversary_v1(terms.anchored_game_date,x.month_number-1)
   OR x.coverage_end_game_date<>airlinerra_game.aircraft_lease_anniversary_v1(terms.anchored_game_date,x.month_number)
   OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger l WHERE l.id=x.ledger_id AND l.airline_id=p_airline AND l.entry_kind='AIRCRAFT_LEASE' AND l.amount_usd=-x.amount_usd)))
 THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='LEASE_PAYMENT_HISTORY_INCONSISTENT';END IF;
 IF p_month<>n+1 THEN RETURN jsonb_build_object('status','requires_next_month','nextMonth',n+1,'ledgerPosted',false);END IF;
 due:=airlinerra_game.aircraft_lease_anniversary_v1(terms.anchored_game_date,p_month-1);
 ends:=airlinerra_game.aircraft_lease_anniversary_v1(terms.anchored_game_date,p_month);
 IF due>game_day THEN RETURN jsonb_build_object('status','not_due','dueGameDate',due,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO ledger_total FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF ledger_total IS DISTINCT FROM company.cash_usd THEN
  RETURN jsonb_build_object('status','cash_ledger_unreconciled','ledgerPosted',false);END IF;
 IF company.cash_usd<terms.recurring_monthly_usd THEN
  RETURN jsonb_build_object('status','insufficient_cash','amountDueUsd',terms.recurring_monthly_usd,'ledgerPosted',false);END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-terms.recurring_monthly_usd WHERE id=p_airline;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
 VALUES(p_airline,'AIRCRAFT_LEASE',-terms.recurring_monthly_usd) RETURNING id INTO lid;
 INSERT INTO airlinerra_game.aircraft_lease_monthly_receipts_v1(order_id,month_number,airline_id,aircraft_inventory_id,due_game_date,coverage_end_game_date,amount_usd,ledger_id,paid_at)
 VALUES(p_order,p_month,p_airline,terms.aircraft_inventory_id,due,ends,terms.recurring_monthly_usd,lid,game_now);
 RETURN jsonb_build_object('status','paid','month',p_month,'dueGameDate',due,'coverageEndGameDate',ends,'amountUsd',terms.recurring_monthly_usd,'ledgerId',lid,'ledgerPosted',true);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.post_aircraft_lease_month_v1(uuid,uuid,integer) FROM PUBLIC,anon,authenticated,service_role;

-- Private bounded worker entry point, not scheduled or released. Every
-- attempted installment uses the same serialized exact-once writer.
CREATE FUNCTION airlinerra_game.run_aircraft_lease_billing_v1(p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE game_day date; candidate record; result jsonb; results jsonb:='[]'::jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_LEASE_BATCH_LIMIT';END IF;
 game_day:=(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date;
 FOR candidate IN
  SELECT o.airline_id,o.order_id,paid.n+1 AS next_month,
   airlinerra_game.aircraft_lease_anniversary_v1(d.anchored_game_date,paid.n) AS due
  FROM airlinerra_game.aircraft_acquisition_orders_v1 o
  JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=o.aircraft_inventory_id AND i.airline_id=o.airline_id
  JOIN airlinerra_game.section9_aircraft_delivery_position_v1 d ON d.acquisition_order_id=o.order_id AND d.aircraft_inventory_id=i.id AND d.airline_id=o.airline_id AND d.world_id=o.world_id
  CROSS JOIN LATERAL (SELECT count(*)::integer AS n FROM airlinerra_game.aircraft_lease_monthly_receipts_v1 x WHERE x.order_id=o.order_id) paid
  WHERE o.world_id=1 AND o.transaction_type='lease' AND o.order_status='delivered_pending_inspection'
  AND i.ownership_type='leased' AND i.fleet_status IN('in_service','maintenance')
  AND o.contract_months BETWEEN 1 AND 240 AND paid.n<o.contract_months
  AND airlinerra_game.aircraft_lease_anniversary_v1(d.anchored_game_date,paid.n)<=game_day
  ORDER BY due,o.order_id LIMIT p_limit
 LOOP
  result:=airlinerra_game.post_aircraft_lease_month_v1(candidate.airline_id,candidate.order_id,candidate.next_month);
  results:=results||jsonb_build_array(result||jsonb_build_object('orderId',candidate.order_id));
 END LOOP;
 RETURN jsonb_build_object('status','lease_batch_checked','gameDate',game_day,'results',results);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.run_aircraft_lease_billing_v1(integer) FROM PUBLIC,anon,authenticated,service_role;

-- Read-only contract coverage verdict for a trusted proposed departure.
-- It is intentionally not wired into the dispatcher in this review.
-- Never use it to block arrival or safety recovery of an airborne aircraft.
CREATE FUNCTION airlinerra_game.aircraft_lease_departure_coverage_v1(p_airline uuid,p_aircraft uuid,p_departure timestamptz,p_arrival timestamptz)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE game_now timestamptz; start_day date; end_day date; plane record; terms record;
 first_day date; expiry date; n integer; max_month integer; paid_until date;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_aircraft IS NULL OR p_departure IS NULL OR p_arrival IS NULL OR p_arrival<=p_departure THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_LEASE_COVERAGE_SCOPE';END IF;
 game_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF p_arrival<=game_now THEN RETURN jsonb_build_object('eligible',false,'status','flight_window_elapsed');END IF;
 start_day:=(greatest(p_departure,game_now) AT TIME ZONE 'Europe/Berlin')::date;
 end_day:=(p_arrival AT TIME ZONE 'Europe/Berlin')::date;
 SELECT * INTO plane FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LEASE_AIRCRAFT_NOT_OWNED';END IF;
 IF plane.ownership_type='owned' THEN RETURN jsonb_build_object('eligible',true,'status','not_leased');END IF;
 IF plane.ownership_type<>'leased' OR plane.fleet_status<>'in_service' THEN RETURN jsonb_build_object('eligible',false,'status','aircraft_unavailable');END IF;
 SELECT o.*,d.anchored_game_date,d.recorded_at AS anchor_recorded_at,d.inspection_reviewed_at INTO terms
 FROM airlinerra_game.aircraft_acquisition_orders_v1 o
 JOIN airlinerra_game.section9_aircraft_delivery_position_v1 d ON d.acquisition_order_id=o.order_id AND d.aircraft_inventory_id=p_aircraft AND d.airline_id=p_airline AND d.world_id=1
 WHERE o.aircraft_inventory_id=p_aircraft AND o.airline_id=p_airline AND o.world_id=1 AND o.transaction_type='lease'
 AND o.order_status='delivered_pending_inspection';
 IF NOT FOUND OR terms.contract_months IS NULL OR terms.contract_months NOT BETWEEN 1 AND 240 OR terms.recurring_monthly_usd IS NULL OR terms.recurring_monthly_usd<=0
 OR terms.registration IS DISTINCT FROM plane.registration OR terms.configuration_id IS DISTINCT FROM plane.configuration_id
 OR terms.anchor_recorded_at IS NULL OR terms.anchor_recorded_at>game_now OR terms.inspection_reviewed_at IS NULL OR terms.inspection_reviewed_at>game_now OR terms.delivery_due_at>game_now
 THEN RETURN jsonb_build_object('eligible',false,'status','lease_terms_unverified');END IF;
 first_day:=terms.anchored_game_date;
 expiry:=airlinerra_game.aircraft_lease_anniversary_v1(first_day,terms.contract_months);
 IF first_day IS NULL OR start_day<first_day THEN RETURN jsonb_build_object('eligible',false,'status','lease_not_started');END IF;
 IF end_day>=expiry THEN RETURN jsonb_build_object('eligible',false,'status','lease_term_expired','expiryGameDate',expiry);END IF;
 SELECT count(*)::integer,coalesce(max(month_number),0) INTO n,max_month FROM airlinerra_game.aircraft_lease_monthly_receipts_v1 WHERE order_id=terms.order_id;
 IF n<>max_month OR n>terms.contract_months OR EXISTS(
 SELECT 1 FROM airlinerra_game.aircraft_lease_monthly_receipts_v1 x WHERE x.order_id=terms.order_id AND
 (x.airline_id<>p_airline OR x.aircraft_inventory_id<>p_aircraft OR x.amount_usd<>terms.recurring_monthly_usd
 OR x.due_game_date<>airlinerra_game.aircraft_lease_anniversary_v1(first_day,x.month_number-1)
 OR x.coverage_end_game_date<>airlinerra_game.aircraft_lease_anniversary_v1(first_day,x.month_number)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger l WHERE l.id=x.ledger_id AND l.airline_id=p_airline AND l.entry_kind='AIRCRAFT_LEASE' AND l.amount_usd=-x.amount_usd)))
 THEN RETURN jsonb_build_object('eligible',false,'status','lease_receipts_unreconciled');END IF;
 paid_until:=airlinerra_game.aircraft_lease_anniversary_v1(first_day,n);
 RETURN jsonb_build_object('eligible',end_day<paid_until,'status',CASE WHEN end_day<paid_until THEN 'lease_paid_coverage' ELSE 'lease_payment_due' END,'paidThroughExclusive',paid_until,'expiryGameDate',expiry);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_lease_departure_coverage_v1(uuid,uuid,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
-- Private post-delivery handoff. Call only after the inspection transaction
-- has committed, so the payment writer acquires cash before order/inventory locks.
-- A failed first payment leaves the delivery evidence intact, not dispatch-ready.
CREATE FUNCTION airlinerra_game.start_delivered_aircraft_lease_v1(p_airline uuid,p_aircraft uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $lease_start$
DECLARE oid uuid; result jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501'; END IF;
 IF p_airline IS NULL OR p_aircraft IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023'; END IF;
 SELECT o.order_id INTO STRICT oid
 FROM airlinerra_game.aircraft_acquisition_orders_v1 o
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=o.aircraft_inventory_id AND i.airline_id=o.airline_id
 WHERE o.airline_id=p_airline AND o.aircraft_inventory_id=p_aircraft AND o.world_id=1 AND o.transaction_type='lease';
 result:=airlinerra_game.post_aircraft_lease_month_v1(p_airline,oid,1);
 RETURN result||jsonb_build_object('orderId',oid,'aircraftInventoryId',p_aircraft,
 'firstInstallmentPaid',coalesce(result->>'status' IN ('paid','already_paid'),false),
 'flightActivationReleased',false);
EXCEPTION WHEN NO_DATA_FOUND THEN
 RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LEASE_DELIVERY_ORDER_NOT_OWNED';
END $lease_start$;
REVOKE ALL ON FUNCTION airlinerra_game.start_delivered_aircraft_lease_v1(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
