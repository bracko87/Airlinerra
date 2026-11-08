DO $checks$
DECLARE r jsonb; denied bool:=false;
BEGIN
 r:=airlinerra_game.section9_completed_flight_chunk_page_v1(
 1::smallint,'2090-03-12'::date,-1,5);
 IF r->>'status'<>'missing' OR r->>'readOnly'<>'true'
    OR jsonb_array_length(r->'chunks')<>0 THEN
  RAISE EXCEPTION 'Incomplete forecast data was exposed as completed: %',r;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_completed_flight_chunk_page_v1(
   1::smallint,'2090-03-12'::date,-2,5);
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Invalid pagination was not rejected';END IF;
 IF has_function_privilege('anon',
  'airlinerra_game.section9_completed_flight_chunk_page_v1(smallint,date,integer,integer)',
  'EXECUTE') OR has_function_privilege('authenticated',
  'airlinerra_game.section9_completed_flight_chunk_page_v1(smallint,date,integer,integer)',
  'EXECUTE') THEN
  RAISE EXCEPTION 'Browser can access private forecast results';END IF;
 RAISE NOTICE 'SECTION9 PASSED: incomplete hidden, paging validated, private API';
END $checks$;