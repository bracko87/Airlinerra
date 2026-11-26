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
 OR terms.registration<>terms.current_registration OR terms.configuration_id<>terms.current_configuration
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
COMMIT;
