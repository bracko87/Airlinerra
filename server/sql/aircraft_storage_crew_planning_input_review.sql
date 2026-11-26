-- ROLLBACK-ONLY REVIEW. Produce a storage-aware commercial crew allocation input.
-- This is deliberately a preview, not a replacement for the current plan writer.
BEGIN;
CREATE FUNCTION airlinerra_game.owned_storage_aware_crew_input_preview_v1(p_player uuid,p_airline uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE base jsonb;member jsonb;h jsonb;pilots jsonb:='[]';cabin jsonb:='[]';excluded jsonb:='[]';v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR p_start IS NULL OR NOT isfinite(p_start) OR p_start<v_now OR p_start>v_now+interval '7 days' THEN RETURN jsonb_build_object('status','storage_aware_crew_window_invalid','dispatchEnforced',false);END IF;
 base:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,p_start);
 IF base->>'status' IS DISTINCT FROM 'weekly_crew_bootstrap_input_preview' OR base->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR base->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR jsonb_typeof(base->'pilots') IS DISTINCT FROM 'array' OR jsonb_typeof(base->'cabinMembers') IS DISTINCT FROM 'array' OR jsonb_typeof(base->'flights') IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('status','storage_aware_crew_input_unverified','dispatchEnforced',false);END IF;
 -- No projected future arrival or rest is used as historical fact.
 FOR member IN SELECT value FROM jsonb_array_elements((base->'pilots')||(base->'cabinMembers')) LOOP
  h:=airlinerra_game.storage_crew_combined_history_preview_v1(p_airline,(member->>'id')::uuid,v_now,member->>'initialAirport',(member->>'locationEffectiveUtc')::timestamptz);
  IF h->>'status' IS DISTINCT FROM 'combined_crew_history_preview' OR h->>'eligibleByHistory' IS DISTINCT FROM 'true' THEN
   excluded:=excluded||jsonb_build_array(jsonb_build_object('employeeId',member->>'id','status',h->>'status'));CONTINUE;
  END IF;
  -- Preserve the initial checkpoint; the engine walks completed duties to
  -- derive physical location and last duty end.
  member:=jsonb_set(member,'{history}',h->'history');
  IF member?'permissions' THEN pilots:=pilots||jsonb_build_array(member);ELSE cabin:=cabin||jsonb_build_array(member);END IF;
 END LOOP;
 RETURN base||jsonb_build_object('status','storage_aware_crew_input_preview','airlineId',p_airline,'pilots',pilots,'cabinMembers',cabin,'excludedEmployees',excluded,'planNotBeforeUtc',v_now,'planningCutoffUtc',v_now,'storageHistoryIncluded',true,'enforceRollingWeeklyDutyHours',true,'scheduleCompletenessVerified',false,'dispatchEnforced',false,'saveAllowed',false,'crewReleased',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_storage_aware_crew_input_preview_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
