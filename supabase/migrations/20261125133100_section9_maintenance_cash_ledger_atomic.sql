-- Maintenance payments must change both authoritative cash and ledger exactly once.
-- No historical balances are modified by this migration.
DO $patch$
DECLARE src text; revised text;
 old_decl constant text:='ledger_id bigint; airline_row uuid; balance_usd numeric;';
 new_decl constant text:='ledger_id bigint; airline_row uuid; balance_usd numeric; cash_before numeric; cash_updated integer;';
 old_decl_live constant text:='ledger_id bigint; airline_row uuid; balance_usd numeric; pos jsonb; actual_hours numeric;';
 new_decl_live constant text:='ledger_id bigint; airline_row uuid; balance_usd numeric; cash_before numeric; cash_updated integer; pos jsonb; actual_hours numeric;';
 old_lock constant text:='SELECT id INTO airline_row FROM airlinerra_game.airlines';
 new_lock constant text:='SELECT id,cash_usd INTO airline_row,cash_before FROM airlinerra_game.airlines';
 old_gate constant text:='IF balance_usd<j.quoted_cost_usd THEN';
 new_gate constant text:='IF cash_before IS DISTINCT FROM balance_usd OR balance_usd<j.quoted_cost_usd THEN';
 old_post constant text:=$old$     RETURNING id INTO ledger_id;
     UPDATE airlinerra_game.section9_game_maintenance_jobs_v1$old$;
 new_post constant text:=$new$     RETURNING id INTO ledger_id;
     -- MAINTENANCE_ATOMIC_CASH_LEDGER_V1
     UPDATE airlinerra_game.airlines
     SET cash_usd=cash_usd-j.quoted_cost_usd
     WHERE id=j.airline_id AND world_id=1 AND cash_usd=cash_before
       AND cash_usd>=j.quoted_cost_usd;
     GET DIAGNOSTICS cash_updated=ROW_COUNT;
     IF cash_updated<>1 THEN
      RAISE EXCEPTION 'SECTION9_MAINTENANCE_CASH_UPDATE_FAILED' USING ERRCODE='40001';
     END IF;
     UPDATE airlinerra_game.section9_game_maintenance_jobs_v1$new$;
BEGIN
 SELECT pg_get_functiondef('airlinerra_game.section9_advance_game_maintenance_jobs_v1()'::regprocedure) INTO src;
 IF strpos(src,new_post)>0 AND strpos(src,new_gate)>0 AND strpos(src,new_lock)>0 THEN RETURN; END IF;
 IF (strpos(src,old_decl)=0 AND strpos(src,old_decl_live)=0)
 OR strpos(src,old_lock)=0 OR strpos(src,old_gate)=0 OR strpos(src,old_post)=0
 OR strpos(src,'FOR UPDATE SKIP LOCKED')=0 OR strpos(src,'MAINTENANCE_ATOMIC_CASH_LEDGER_V1')>0
 THEN RAISE EXCEPTION 'SECTION9_MAINTENANCE_CASH_SOURCE_DRIFT'; END IF;
 revised:=replace(replace(replace(replace(replace(src,old_decl_live,new_decl_live),old_decl,new_decl),old_lock,new_lock),old_gate,new_gate),old_post,new_post);
 IF revised=src THEN RAISE EXCEPTION 'SECTION9_MAINTENANCE_CASH_PATCH_EMPTY'; END IF;
 EXECUTE revised;
END $patch$;
