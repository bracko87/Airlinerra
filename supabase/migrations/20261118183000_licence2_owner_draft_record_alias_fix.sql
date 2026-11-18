-- Fix PL/pgSQL airline record naming collision in guarded owner draft staging.
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_stage_owner_application_v1(p_player uuid, p_airline uuid, p_market text, p_level smallint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare v_airline record; v_check jsonb; v_id uuid;
begin
 if current_user is distinct from 'postgres'
 then raise exception using errcode='42501',message='LICENCE2_PRIVATE_OWNER_SERVICE_ONLY';end if;
 if p_player is null or p_airline is null or p_market is null or p_level is null
 then return jsonb_build_object('status','INVALID_APPLICATION','created',false);end if;
 select airline.id into v_airline from airlinerra_game.airlines airline
 join airlinerra_game.world_memberships wm on wm.world_id=airline.world_id
  and wm.player_id=p_player and wm.state='active'
 where airline.id=p_airline and airline.owner_player_id=p_player and airline.world_id=1;
 if not found then raise exception using errcode='42501',message='LICENCE2_APPLICATION_AIRLINE_NOT_OWNED';end if;
 v_check:=airlinerra_game.licence2_application_readiness_v1(p_airline,p_market,p_level);
 if v_check->>'status' is distinct from 'READ_ONLY_PREAPPLICATION_ASSESSMENT'
 then return jsonb_build_object('status','INVALID_OR_UNSUPPORTED_MARKET_LEVEL','created',false);end if;
 if exists(select 1 from airlinerra_game.licence2_airline_market_permits_v1
  where world_id=1 and airline_id=p_airline and market_code=p_market
   and status='approved' and level>=p_level)
 then return jsonb_build_object('status','ALREADY_HOLDS_SUFFICIENT_LEVEL',
  'created',false,'feeCharged',false);end if;
 insert into airlinerra_game.licence2_market_applications_v1
 (world_id,airline_id,owner_player_id,market_code,requested_level,status,latest_readiness)
 values(1,p_airline,p_player,p_market,p_level,'draft',v_check)
 on conflict (world_id,airline_id,market_code)
 where status in ('draft','submitted','under_review')
 do nothing returning application_id into v_id;
 return jsonb_build_object(
 'status',case when v_id is null then 'EXISTING_APPLICATION_ALREADY_OPEN'
 else 'APPLICATION_DRAFT_STAGED_NOT_SUBMITTED' end,
 'created',v_id is not null,'applicationId',v_id,
 'readiness',v_check,'submitted',false,'rightsGranted',false,
 'feeCharged',false,'flightsActivated',false);
end $function$
;
