-- Rollback-only acceptance: world opening, signed engine day admission,
-- strict +1 tick, replay, duplicate evidence, read-only forecast gating.
-- Fake proof values are used ONLY in this rolled-back database fixture.
BEGIN;
DO $tests$
DECLARE world_before record;clock_before record;tick jsonb;again jsonb;
 denied bool;before_jobs bigint;before_ledger bigint;before_receipts bigint;
BEGIN
 SELECT * INTO world_before FROM public.airlinerra_game_worlds WHERE id=1;
 SELECT * INTO clock_before FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 SELECT count(*) INTO before_jobs FROM airlinerra_game.section9_demand_jobs_v1;
 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO before_receipts FROM
  airlinerra_game.section9_verified_game_tick_receipts_v1;
 IF world_before.state<>'planned' OR
  clock_before.clock_source<>'not_connected'
 THEN RAISE EXCEPTION 'Current production world state changed; do not use planned world fixture';END IF;

 tick:=airlinerra_game.section9_accept_verified_game_tick_v1(
  1,'2000-01-01','engine-world1-day0001',repeat('a',64));
 IF tick->>'status'<>'blocked_world_not_open' OR
  tick->>'clockAdvanced'<>'false' THEN
   RAISE EXCEPTION 'A planned world was allowed to advance: %',tick;END IF;
 IF (SELECT clock_source FROM airlinerra_game.holding_world_clock_v1
  WHERE world_id=1)<>'not_connected' THEN
  RAISE EXCEPTION 'Clock changed while the world was planned';END IF;

 -- Only within this transaction, simulate a trusted admin opening World1.
 UPDATE public.airlinerra_game_worlds
 SET state='active',opens_at=clock_timestamp()-interval '1 day' WHERE id=1;

 tick:=airlinerra_game.section9_accept_verified_game_tick_v1(
  1,'2000-01-01','engine-world1-day0001',repeat('a',64));
 IF tick->>'status'<>'verified_tick_accepted' OR
  tick->>'clockAdvanced'<>'true' OR
  tick->>'forecastEnqueued'<>'false' OR
  tick->>'payrollPosted'<>'false' OR
  tick->>'bookingsCreated'<>'false'
 THEN RAISE EXCEPTION 'Safe first tick failed: %',tick;END IF;

 again:=airlinerra_game.section9_accept_verified_game_tick_v1(
  1,'2000-01-01','engine-world1-day0001',repeat('a',64));
 IF again->>'status'<>'already_applied' OR again->>'replayed'<>'true'
 THEN RAISE EXCEPTION 'Replay advanced the clock or failed: %',again;END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_accept_verified_game_tick_v1(
   1,'2000-01-01','engine-world1-day0001',repeat('b',64));
 EXCEPTION WHEN unique_violation THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Conflicting event evidence accepted';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_accept_verified_game_tick_v1(
   1,'2000-01-03','engine-world1-day0003',repeat('c',64));
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Skipped day accepted';END IF;
 tick:=airlinerra_game.section9_accept_verified_game_tick_v1(
  1,'2000-01-02','engine-world1-day0002',repeat('d',64));
 IF tick->>'clockAdvanced'<>'true' THEN
  RAISE EXCEPTION 'Valid consecutive day not accepted';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_accept_verified_game_tick_v1(
   1,'2000-01-02','engine-world1-day-different',repeat('e',64));
 EXCEPTION WHEN unique_violation THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Different event replaced existing tick';END IF;

 IF (SELECT confirmed_game_date FROM airlinerra_game.holding_world_clock_v1
  WHERE world_id=1)<>DATE '2000-01-02' OR
  (SELECT count(*) FROM airlinerra_game.section9_verified_game_tick_receipts_v1)
   <>before_receipts+2 OR
  (SELECT count(*) FROM airlinerra_game.section9_demand_jobs_v1)<>before_jobs OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_ledger
 THEN RAISE EXCEPTION 'Unexpected forecast, ledger or clock state';END IF;
 IF has_table_privilege('anon',
  'airlinerra_game.section9_verified_game_tick_receipts_v1','SELECT') OR
  has_function_privilege('authenticated',
   'airlinerra_game.section9_accept_verified_game_tick_v1(smallint,date,text,text)',
    'EXECUTE') THEN
   RAISE EXCEPTION 'Browser SQL game-clock access was granted';END IF;
 RAISE NOTICE 'PASS planned blocked; 1st and +1 day accepted; replay, overwrite, skip, money and forecast gates';
END $tests$;
ROLLBACK;
