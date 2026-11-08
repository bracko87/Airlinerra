BEGIN;
DO $tests$
DECLARE denied boolean; before_ledger bigint;before_cash numeric; a_id uuid;
BEGIN
 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;
 SELECT id,cash_usd INTO a_id,before_cash FROM airlinerra_game.airlines
 WHERE world_id=1 ORDER BY id LIMIT 1;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_initialize_verified_occurrence_v1(
   '11111111-1111-4111-8111-111111111111'::uuid,
   '2026-11-09'::date,1);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Unverified occurrence was initialized';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_hold_verified_itinerary_v1(
   'alloc-unknown-leg-1',ARRAY['11111111-1111-4111-8111-111111111111:2026-11-09:1'],
   10,0::numeric);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Missing verified inventory accepted';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_hold_verified_itinerary_v1(
   'alloc-invalid',ARRAY['someflight','someflight'],10,0::numeric);
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Duplicate leg accepted';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_hold_verified_itinerary_v1(
   'alloc-too-many',ARRAY['a','b','c'],10,0::numeric);
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Three-leg itinerary accepted';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_hold_verified_itinerary_v1(
   'alloc-negative',ARRAY['a'],-1,0::numeric);
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Negative passenger demand accepted';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_occurrence_capacity_inventory_v1)>0 OR
    (SELECT count(*) FROM airlinerra_game.section9_atomic_itinerary_holds_v1)>0 OR
    (SELECT count(*) FROM airlinerra_game.section9_atomic_itinerary_hold_legs_v1)>0
 THEN RAISE EXCEPTION 'Unsafe capacity hold persisted';END IF;
 IF has_table_privilege('anon','airlinerra_game.section9_occurrence_capacity_inventory_v1','SELECT')
 OR has_table_privilege('authenticated','airlinerra_game.section9_atomic_itinerary_holds_v1','INSERT')
 OR has_function_privilege('authenticated',
  'airlinerra_game.section9_hold_verified_itinerary_v1(text,text[],integer,numeric)',
  'EXECUTE') OR has_function_privilege('anon',
  'airlinerra_game.section9_initialize_verified_occurrence_v1(uuid,date,integer)',
  'EXECUTE')
 THEN RAISE EXCEPTION 'Player access to capacity holds was granted';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_ledger
 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=a_id)<>before_cash
 THEN RAISE EXCEPTION 'Real airline economy changed';END IF;
 RAISE NOTICE 'PASS: draft/unknown flights denied, 1-2 leg input strict, private access, no balances touched';
END $tests$;
ROLLBACK;