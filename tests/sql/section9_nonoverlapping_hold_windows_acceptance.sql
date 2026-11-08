BEGIN;
DO $test$
DECLARE original jsonb; same jsonb; denied boolean:=false;
BEGIN
 original:=airlinerra_game.section9_create_hold_plan_v1(
   DATE '2090-12-01',3,repeat('1',64),5);
 same:=airlinerra_game.section9_create_hold_plan_v1(
   DATE '2090-12-01',3,repeat('1',64),5);
 IF same->>'planId'<>original->>'planId'
 THEN RAISE EXCEPTION 'Exact replay changed job identity';END IF;
 BEGIN
  PERFORM airlinerra_game.section9_create_hold_plan_v1(
   DATE '2090-12-02',3,repeat('2',64),5);
 EXCEPTION WHEN unique_violation THEN denied:=true;END;
 IF NOT denied THEN
  RAISE EXCEPTION 'Overlapping alternate demand window was allowed';END IF;
 PERFORM airlinerra_game.section9_create_hold_plan_v1(
  DATE '2090-12-04',3,repeat('3',64),1);
 RAISE NOTICE 'PASS exact replay, overlap denied and adjacent partition allowed';
END $test$;
ROLLBACK;