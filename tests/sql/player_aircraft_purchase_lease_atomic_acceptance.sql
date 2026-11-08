-- World 1 real aircraft acquisition acceptance. Reverts EVERY test write.
-- No real airline purchases, delivery, activation or ledger changes persist.
BEGIN;
DO $tests$
DECLARE
 company uuid; player uuid; initial_cash numeric;
 purchase_offer uuid; lease_offer uuid; expensive_offer uuid;
 request uuid:=gen_random_uuid(); first_order jsonb; replay jsonb; lease_order jsonb;
 rejected boolean;
BEGIN
 SELECT a.id,a.owner_player_id,a.cash_usd INTO company,player,initial_cash
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 WHERE a.world_id=1 AND w.state='active' AND a.iata_code IS NOT NULL LIMIT 1;
 IF company IS NULL THEN RAISE EXCEPTION 'NO_ACTIVE_TEST_AIRLINE'; END IF;
 INSERT INTO airlinerra_game.aircraft_acquisition_offers_v1(
  configuration_id,transaction_type,upfront_price_usd,delivery_days,
  offer_status,pricing_basis) VALUES(3,'purchase',250000,2,'published','ROLLBACK_TEST_ONLY')
 RETURNING offer_id INTO purchase_offer;
 INSERT INTO airlinerra_game.aircraft_acquisition_offers_v1(
  configuration_id,transaction_type,upfront_price_usd,recurring_monthly_usd,
  contract_months,delivery_days,offer_status,pricing_basis)
 VALUES(3,'lease',50000,12000,12,3,'published','ROLLBACK_TEST_ONLY')
 RETURNING offer_id INTO lease_offer;

 rejected:=false;
 BEGIN
  PERFORM airlinerra_game.acquire_offered_aircraft_v1(gen_random_uuid(),company,
    purchase_offer,'REG-TES1',gen_random_uuid());
 EXCEPTION WHEN SQLSTATE '42501' THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'FOREIGN_OWNER_WAS_ALLOWED_TO_BUY'; END IF;

 first_order:=airlinerra_game.acquire_offered_aircraft_v1(
  player,company,purchase_offer,'REG-TES1',request);
 IF first_order->>'deliveryStatus'<>'awaiting_delivery'
  OR first_order->>'fleetStatus'<>'stored'
  OR first_order->>'canScheduleFlight'<>'false'
  OR first_order->>'replayed'<>'false'
  OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=company)<>initial_cash-250000
 THEN RAISE EXCEPTION 'ATOMIC_PURCHASE_AND_CASH_FAILED: %',first_order; END IF;

 replay:=airlinerra_game.acquire_offered_aircraft_v1(
  player,company,purchase_offer,'reg-tes1',request);
 IF replay->>'replayed'<>'true' OR replay->>'orderId'<>first_order->>'orderId'
  OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=company)<>initial_cash-250000
 THEN RAISE EXCEPTION 'IDEMPOTENT_RETRY_DOUBLE_CHARGED: %',replay; END IF;

 rejected:=false;
 BEGIN
  PERFORM airlinerra_game.acquire_offered_aircraft_v1(player,company,purchase_offer,
    'REG-TES2',request);
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   rejected:=SQLERRM='ACQUISITION_IDEMPOTENCY_KEY_REUSED'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'IDEMPOTENCY_REQUEST_REUSED_WITH_OTHER_REGISTRATION'; END IF;

 rejected:=false;
 BEGIN
  PERFORM airlinerra_game.acquire_offered_aircraft_v1(player,company,purchase_offer,
    'REG-TES1',gen_random_uuid());
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   rejected:=SQLERRM='AIRCRAFT_REGISTRATION_ALREADY_TAKEN'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'DUPLICATE_AIRCRAFT_REGISTRATION_ACCEPTED'; END IF;

 INSERT INTO airlinerra_game.aircraft_acquisition_offers_v1(
  configuration_id,transaction_type,upfront_price_usd,offer_status,pricing_basis)
 VALUES(57,'purchase',9000000,'published','ROLLBACK_TEST_ONLY')
 RETURNING offer_id INTO expensive_offer;
 rejected:=false;
 BEGIN
  PERFORM airlinerra_game.acquire_offered_aircraft_v1(player,company,expensive_offer,
    'REG-TES9',gen_random_uuid());
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   rejected:=SQLERRM='INSUFFICIENT_AIRLINE_CASH'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'INSUFFICIENT_CASH_CHECK_MISSING'; END IF;

 lease_order:=airlinerra_game.acquire_offered_aircraft_v1(
  player,company,lease_offer,'REG-TES3',gen_random_uuid());
 IF lease_order->>'transactionType'<>'lease'
 OR (SELECT ownership_type FROM airlinerra_game.airline_aircraft_inventory
    WHERE id=(lease_order->>'aircraftInventoryId')::uuid)<>'leased'
 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=company)<>initial_cash-300000
 THEN RAISE EXCEPTION 'LEASE_UPFRONT_OR_STATUS_INCORRECT'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger
  WHERE airline_id=company AND entry_kind IN('AIRCRAFT_PURCHASE','AIRCRAFT_LEASE'))<>2
 OR (SELECT count(*) FROM airlinerra_game.aircraft_acquisition_orders_v1
    WHERE airline_id=company)<>2 THEN
  RAISE EXCEPTION 'MISSING_LEDGER_OR_DUPLICATE_ORDER'; END IF;

 rejected:=false;
 BEGIN
  PERFORM airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
    player,company,(first_order->>'aircraftInventoryId')::uuid,'PA999',
    'OURAIRPORTS:2220','OURAIRPORTS:4001',
    '2026-11-09 10:00+00','2026-11-09 12:00+00',
    '[{"day":0,"time":"13:00"}]'::jsonb);
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   rejected:=SQLERRM='AIRCRAFT_NOT_OWNED_LEASED_OR_IN_SERVICE'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'UNDELIVERED_AIRCRAFT_PASSED_SCHEDULE_GATE'; END IF;

 IF has_function_privilege('anon','airlinerra_game.acquire_offered_aircraft_v1(uuid,uuid,uuid,text,uuid)','EXECUTE')
 OR has_function_privilege('authenticated','airlinerra_game.acquire_offered_aircraft_v1(uuid,uuid,uuid,text,uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'DIRECT_PUBLIC_PURCHASE_SQL_IS_EXPOSED'; END IF;
 RAISE NOTICE 'PASS owner, purchase/lease cash, ledger, duplicate, idempotency, delivery safety, schedule blocking and private SQL';
END $tests$;
ROLLBACK;
