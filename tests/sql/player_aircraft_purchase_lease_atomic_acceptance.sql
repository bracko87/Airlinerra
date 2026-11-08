-- Original acquisition acceptance upgraded for seeded production game-market offers.
-- Same rollback-only tests as the new pricing+delivery fixture; no duplicate published offers.
-- World 1 aircraft game-pricing + delivery lifecycle acceptance.
-- Every fixture is transient: no game cash, aircraft or inspection writes persist.
BEGIN;
DO $check$
DECLARE
 v_airline uuid; v_player uuid; v_cash numeric;
 v_offer uuid; v_lease uuid; v_expensive uuid; v_cost numeric;
 v_token uuid:=gen_random_uuid(); v_order uuid; v_fleet uuid;
 v_purchase jsonb; v_replay jsonb; v_before jsonb; v_due jsonb; v_again jsonb;
 v_refused boolean;
BEGIN
 SELECT a.id,a.owner_player_id,a.cash_usd INTO v_airline,v_player,v_cash
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 WHERE a.world_id=1 AND w.state='active' LIMIT 1;
 IF v_airline IS NULL THEN RAISE EXCEPTION 'NO_ACTIVE_AIRLINE'; END IF;
 SELECT o.offer_id,o.upfront_price_usd INTO v_offer,v_cost
 FROM airlinerra_game.aircraft_acquisition_offers_v1 o
 WHERE o.configuration_id=93 AND o.transaction_type='purchase'
  AND o.offer_status='published' LIMIT 1;
 SELECT o.offer_id INTO v_lease
 FROM airlinerra_game.aircraft_acquisition_offers_v1 o
 WHERE o.configuration_id=93 AND o.transaction_type='lease'
  AND o.offer_status='draft' LIMIT 1;
 SELECT o.offer_id INTO v_expensive
 FROM airlinerra_game.aircraft_acquisition_offers_v1 o
 WHERE o.configuration_id=3 AND o.transaction_type='purchase'
  AND o.offer_status='published' LIMIT 1;
 IF v_offer IS NULL OR v_lease IS NULL OR v_expensive IS NULL
 THEN RAISE EXCEPTION 'SEED_PRICES_MISSING'; END IF;

 v_refused:=false;
 BEGIN
  PERFORM airlinerra_game.acquire_offered_aircraft_v1(
   gen_random_uuid(),v_airline,v_offer,'TEST-DELI-1',gen_random_uuid());
 EXCEPTION WHEN SQLSTATE '42501' THEN v_refused:=true; END;
 IF NOT v_refused THEN RAISE EXCEPTION 'NON_OWNER_BUY_ACCEPTED'; END IF;
 v_refused:=false;
 BEGIN
  PERFORM airlinerra_game.acquire_offered_aircraft_v1(
   v_player,v_airline,v_lease,'TEST-DELI-2',gen_random_uuid());
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  v_refused:=SQLERRM='AIRCRAFT_OFFER_NOT_AVAILABLE'; END;
 IF NOT v_refused THEN RAISE EXCEPTION 'UNBILLED_LEASE_ACCEPTED'; END IF;

 v_purchase:=airlinerra_game.acquire_offered_aircraft_v1(
  v_player,v_airline,v_offer,'TEST-DELI-1',v_token);
 v_order:=(v_purchase->>'orderId')::uuid;
 v_fleet:=(v_purchase->>'aircraftInventoryId')::uuid;
 IF v_purchase->>'deliveryStatus'<>'awaiting_delivery'
 OR v_purchase->>'fleetStatus'<>'stored'
 OR v_purchase->>'canScheduleFlight'<>'false'
 OR (SELECT a.cash_usd FROM airlinerra_game.airlines a WHERE a.id=v_airline)<>v_cash-v_cost
 THEN RAISE EXCEPTION 'BAD_PURCHASE_RECEIPT_OR_CASH: %',v_purchase; END IF;
 v_replay:=airlinerra_game.acquire_offered_aircraft_v1(
  v_player,v_airline,v_offer,'test-deli-1',v_token);
 IF v_replay->>'replayed'<>'true'
 OR v_replay->>'orderId'<>v_purchase->>'orderId'
 OR (SELECT a.cash_usd FROM airlinerra_game.airlines a WHERE a.id=v_airline)<>v_cash-v_cost
 THEN RAISE EXCEPTION 'REPLAY_DOUBLE_DEBITED'; END IF;

 v_refused:=false;
 BEGIN
  PERFORM airlinerra_game.acquire_offered_aircraft_v1(
   v_player,v_airline,v_expensive,'TEST-DELI-3',gen_random_uuid());
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  v_refused:=SQLERRM='INSUFFICIENT_AIRLINE_CASH'; END;
 IF NOT v_refused THEN RAISE EXCEPTION 'INSUFFICIENT_CASH_NOT_BLOCKED'; END IF;
 v_refused:=false;
 BEGIN
  PERFORM airlinerra_game.acquire_offered_aircraft_v1(
   v_player,v_airline,v_offer,'TEST-DELI-1',gen_random_uuid());
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  v_refused:=SQLERRM='AIRCRAFT_REGISTRATION_ALREADY_TAKEN'; END;
 IF NOT v_refused THEN RAISE EXCEPTION 'DUPLICATE_REGISTRATION_ACCEPTED'; END IF;

 v_before:=airlinerra_game.check_owned_aircraft_delivery_v1(
  v_player,v_airline,v_order);
 IF v_before->>'deliveryStatus'<>'awaiting_delivery'
  OR v_before->>'inspectionStatus'<>'not_requested'
  OR v_before->>'fleetStatus'<>'stored' THEN
  RAISE EXCEPTION 'BEFORE_DUE_DELIVERY_ADVANCED: %',v_before; END IF;
 v_refused:=false;
 BEGIN
  PERFORM airlinerra_game.check_owned_aircraft_delivery_v1(
   gen_random_uuid(),v_airline,v_order);
 EXCEPTION WHEN SQLSTATE '42501' THEN v_refused:=true; END;
 IF NOT v_refused THEN RAISE EXCEPTION 'FOREIGN_USER_CHECKED_DELIVERY'; END IF;
 v_refused:=false;
 BEGIN
  PERFORM airlinerra_game.check_owned_aircraft_delivery_v1(
   v_player,v_airline,gen_random_uuid());
 EXCEPTION WHEN SQLSTATE '42501' THEN v_refused:=true; END;
 IF NOT v_refused THEN RAISE EXCEPTION 'FOREIGN_ORDER_CHECKED'; END IF;

 UPDATE airlinerra_game.aircraft_acquisition_orders_v1 o
 SET delivery_due_at=now()-interval '15 minutes'
 WHERE o.order_id=v_order;
 v_due:=airlinerra_game.check_owned_aircraft_delivery_v1(
  v_player,v_airline,v_order);
 IF v_due->>'deliveryStatus'<>'delivered_pending_inspection'
 OR v_due->>'inspectionStatus'<>'pending_inspection'
 OR v_due->>'fleetStatus'<>'stored'
 OR v_due->>'canActivateFlight'<>'false'
 THEN RAISE EXCEPTION 'DELIVERY_INSPECTION_UNSAFE: %',v_due; END IF;
 v_again:=airlinerra_game.check_owned_aircraft_delivery_v1(
  v_player,v_airline,v_order);
 IF v_again->>'deliveryStatus'<>'delivered_pending_inspection'
 OR (SELECT count(*) FROM airlinerra_game.aircraft_delivery_inspections_v1 i
     WHERE i.aircraft_inventory_id=v_fleet)<>1
 THEN RAISE EXCEPTION 'DELIVERY_RECHECK_CREATED_DUPLICATE'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger l
     WHERE l.airline_id=v_airline AND l.entry_kind='AIRCRAFT_PURCHASE')<>1
 THEN RAISE EXCEPTION 'DELIVERY_ADDED_FINANCIAL_EVENT'; END IF;

 v_refused:=false;
 BEGIN
  PERFORM airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
   v_player,v_airline,v_fleet,'PA919','OURAIRPORTS:2220','OURAIRPORTS:4001',
   '2026-11-09 10:00+00','2026-11-09 12:00+00',
   '[{"day":0,"time":"13:00"}]'::jsonb);
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  v_refused:=SQLERRM='AIRCRAFT_NOT_OWNED_LEASED_OR_IN_SERVICE'; END;
 IF NOT v_refused THEN RAISE EXCEPTION 'UNINSPECTED_PLANE_WAS_SCHEDULED'; END IF;
 RAISE NOTICE 'PASS curated World1 prices, owner, cash/ledger, retries, blocked lease, due delivery, pending inspection and scheduling';
END $check$;
ROLLBACK;
