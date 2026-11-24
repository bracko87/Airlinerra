-- Preserve existing owner checks, job overlap checks, ACLs and return contract.
-- Use paid service timestamps for Daily/Weekly instead of calendar-day blocking.
DO $patch$
DECLARE src text; revised text;
 old_decl constant text := 'overlapping_jobs integer:=0; due_codes text[];';
 new_decl constant text := 'overlapping_jobs integer:=0; due_codes text[]; item jsonb; interval_hours integer; completed_at timestamptz;';
 old_gate constant text := $old$  IF (result->>'dueCheckCount')::integer>0 THEN
   reasons:=array_append(reasons,'GAME_MAINTENANCE_CHECK_DUE');
  END IF;$old$;
 new_gate constant text := $new$  -- EXACT_PAID_MAINTENANCE_DEADLINE_V1
  IF jsonb_typeof(result->'checks') IS DISTINCT FROM 'array'
     OR jsonb_array_length(result->'checks')<>6 THEN
   reasons:=array_append(reasons,'GAME_MAINTENANCE_DAILY_EVIDENCE_MISSING');
   CONTINUE;
  END IF;
  IF (SELECT count(DISTINCT x->>'checkCode') FROM jsonb_array_elements(result->'checks') x
      WHERE x->>'checkCode' IN ('daily','weekly','a','b','c','d'))<>6
     OR (SELECT count(*) FROM jsonb_array_elements(result->'checks') x
         WHERE x->>'currentlyDue'='true')<>(result->>'dueCheckCount')::integer
     OR EXISTS(SELECT 1 FROM jsonb_array_elements(result->'checks') x
               WHERE x->>'currentlyDue' IS NULL OR x->>'currentlyDue' NOT IN ('true','false')) THEN
   reasons:=array_append(reasons,'GAME_MAINTENANCE_DAILY_EVIDENCE_MISSING');
   CONTINUE;
  END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(result->'checks') LOOP
   IF item->>'checkCode' IN ('daily','weekly')
      AND item->>'lastCompletedGameCheck' IS NOT NULL THEN
    SELECT calendar_interval_hours INTO interval_hours
      FROM airlinerra_game.maintenance_check_policy_v1
      WHERE check_code=item->>'checkCode';
    completed_at:=(item->>'lastCompletedGameCheck')::timestamptz;
    -- Never grant credit for an uncompleted service or a missing deadline.
    IF interval_hours IS NULL OR interval_hours<=0 OR completed_at>v_now
       OR completed_at>p_departure_utc THEN
     reasons:=array_append(reasons,'GAME_MAINTENANCE_DAILY_EVIDENCE_MISSING');
    ELSIF p_arrival_utc>=completed_at+make_interval(hours=>interval_hours) THEN
     reasons:=array_append(reasons,'GAME_MAINTENANCE_CHECK_DUE');
    END IF;
   ELSIF item->>'currentlyDue'='true' THEN
    -- Keep conservative date/hour checks for unknown exact deadlines and heavy checks.
    reasons:=array_append(reasons,'GAME_MAINTENANCE_CHECK_DUE');
   END IF;
  END LOOP;$new$;
BEGIN
 SELECT pg_get_functiondef('airlinerra_game.section9_owned_game_maintenance_flight_window_v1(uuid,uuid,uuid,timestamptz,timestamptz)'::regprocedure) INTO src;
 IF strpos(src,new_gate)>0 AND strpos(src,new_decl)>0 THEN RETURN; END IF;
 IF strpos(src,old_decl)=0 OR strpos(src,old_gate)=0
 OR strpos(src,'GAME_MAINTENANCE_JOB_TIME_OVERLAP')=0
 OR strpos(src,'SECTION9_GAME_MAINTENANCE_FLIGHT_NOT_OWNED')=0
 OR strpos(src,'EXACT_PAID_MAINTENANCE_DEADLINE_V1')>0
 THEN RAISE EXCEPTION 'SECTION9_MAINTENANCE_WINDOW_SOURCE_DRIFT'; END IF;
 revised:=replace(replace(src,old_decl,new_decl),old_gate,new_gate);
 IF revised=src THEN RAISE EXCEPTION 'SECTION9_MAINTENANCE_WINDOW_PATCH_EMPTY'; END IF;
 EXECUTE revised;
END $patch$;
