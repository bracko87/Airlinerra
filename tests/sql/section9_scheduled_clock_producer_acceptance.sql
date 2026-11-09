-- All configuration and game-day ticks here are TEST FIXTURES enclosed in a
-- full rollback transaction. Never open or configure the real world.
BEGIN;
DO $proof$
DECLARE state jsonb; result jsonb; ref text:='ROLLBACK-ONLY-ADMIN-RELEASE-001';
 deny boolean:=false; prior_cash numeric; ledger_count bigint;
 world_count bigint; tick_count bigint; clock_before record;
 day1 date:=DATE '2000-01-01'; day2 date:=DATE '2000-01-02';
 day3 date:=DATE '2000-01-03'; day4 date:=DATE '2000-01-04';
BEGIN
 SELECT count(*) INTO ledger_count FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO world_count FROM airlinerra_game.section9_clock_producer_schedule_v1;
 SELECT count(*) INTO tick_count FROM airlinerra_game.section9_verified_game_tick_receipts_v1;
 SELECT * INTO clock_before FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1;
 IF clock_before.clock_source<>'not_connected' THEN
  RAISE EXCEPTION 'Real clock already running: abort fixture';END IF;
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'status'<>'blocked_world_not_open' THEN
  RAISE EXCEPTION 'Planned world reported due: %',state;END IF;
 result:=airlinerra_game.section9_configure_clock_producer_v1(
  1::smallint,day1,ref);
 IF result->>'status'<>'blocked_world_not_open' THEN
  RAISE EXCEPTION 'Planned world configured: %',result;END IF;

 -- Official world opens_at and active state exist ONLY inside ROLLBACK.
 UPDATE public.airlinerra_game_worlds
 SET state='active',opens_at=clock_timestamp()-interval '2 days 1 hour'
 WHERE id=1;
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'status'<>'not_configured' THEN
  RAISE EXCEPTION 'World without approved schedule could tick';END IF;
 result:=airlinerra_game.section9_configure_clock_producer_v1(
  1::smallint,day1,ref);
 IF result->>'status'<>'paused' THEN
  RAISE EXCEPTION 'New configuration is not paused';END IF;
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'status'<>'paused' THEN
  RAISE EXCEPTION 'Paused producer considered due';END IF;

 deny:=false;
 BEGIN
  PERFORM airlinerra_game.section9_enable_clock_producer_v1(
    1::smallint,'WRONG-ADMIN-RELEASE-001');
 EXCEPTION WHEN SQLSTATE '42501' THEN deny:=true;END;
 IF NOT deny THEN RAISE EXCEPTION 'Wrong release reference enabled producer';END IF;
 result:=airlinerra_game.section9_enable_clock_producer_v1(
   1::smallint,ref);
 IF result->>'status'<>'enabled' THEN
  RAISE EXCEPTION 'Valid admin release did not enable';END IF;
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'status'<>'due' OR state->>'gameDate'<>day1::text OR
  (state->>'daysBehind')::int<>2 THEN
  RAISE EXCEPTION 'First 24-hour due is wrong: %',state;END IF;

 deny:=false;
 BEGIN
  PERFORM airlinerra_game.section9_accept_scheduled_game_tick_v1(
   1::smallint,day2,'horizon-world1-day-2000-01-02',repeat('b',64));
 EXCEPTION WHEN SQLSTATE '42501' THEN deny:=true;END;
 IF NOT deny THEN RAISE EXCEPTION 'Future game day skipped clock';END IF;

 result:=airlinerra_game.section9_accept_scheduled_game_tick_v1(
   1::smallint,day1,'horizon-world1-day-2000-01-01',repeat('a',64));
 IF result->>'status'<>'verified_tick_accepted' OR
  result->>'forecastEnqueued'<>'false' THEN
  RAISE EXCEPTION 'First signed day invalid: %',result;END IF;
 result:=airlinerra_game.section9_accept_scheduled_game_tick_v1(
   1::smallint,day1,'horizon-world1-day-2000-01-01',repeat('a',64));
 IF result->>'status'<>'already_applied' OR
  result->>'clockAdvanced'<>'false' THEN
  RAISE EXCEPTION 'Same signed event was not idempotent';END IF;
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'gameDate'<>day2::text THEN
  RAISE EXCEPTION 'Second consecutive game day not due: %',state;END IF;
 PERFORM airlinerra_game.section9_accept_scheduled_game_tick_v1(
  1::smallint,day2,'horizon-world1-day-2000-01-02',repeat('b',64));
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'gameDate'<>day3::text THEN
  RAISE EXCEPTION 'Third game date not due';END IF;
 PERFORM airlinerra_game.section9_accept_scheduled_game_tick_v1(
  1::smallint,day3,'horizon-world1-day-2000-01-03',repeat('c',64));
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'status'<>'caught_up' THEN
  RAISE EXCEPTION 'Producer tried to advance before next real 24-hour deadline: %',state;END IF;

 deny:=false;
 BEGIN
  PERFORM airlinerra_game.section9_accept_scheduled_game_tick_v1(
   1::smallint,day4,'horizon-world1-day-2000-01-04',repeat('d',64));
 EXCEPTION WHEN SQLSTATE '42501' THEN deny:=true;END;
 IF NOT deny THEN RAISE EXCEPTION 'Future 24-hour game day was accepted early';END IF;

 IF (SELECT count(*) FROM airlinerra_game.section9_verified_game_tick_receipts_v1)<>tick_count+3 OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>ledger_count OR
  (SELECT count(*) FROM airlinerra_game.section9_demand_jobs_v1)>0
 THEN RAISE EXCEPTION 'Clock unexpectedly affected forecast/money';END IF;

 -- Modifying a world's anchor after admin release invalidates producer.
 UPDATE public.airlinerra_game_worlds
 SET opens_at=opens_at-interval '1 hour' WHERE id=1;
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'status'<>'opening_anchor_changed' THEN
  RAISE EXCEPTION 'Changed world opening anchor not detected';END IF;
 IF has_table_privilege('authenticated',
  'airlinerra_game.section9_clock_producer_schedule_v1','SELECT') OR
  has_function_privilege('anon',
   'airlinerra_game.section9_enable_clock_producer_v1(smallint,text)','EXECUTE') OR
  has_function_privilege('authenticated',
   'airlinerra_game.section9_accept_scheduled_game_tick_v1(smallint,date,text,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Public clock producer access was granted';END IF;
 RAISE NOTICE 'PASS 24-hour release gate, 3 sequential ticks, no early 4th tick, replay, world anchor, no ledger';
END $proof$;
ROLLBACK;
