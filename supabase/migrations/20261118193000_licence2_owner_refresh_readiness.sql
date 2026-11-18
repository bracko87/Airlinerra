-- Allow owner to refresh the current pre-application assessment for an existing unsent draft.
-- No submission, reviewer state, fee or permit transitions.
create or replace function airlinerra_game.licence2_refresh_owner_draft_v1(
 p_player uuid,p_airline uuid,p_application uuid
) returns jsonb language plpgsql
set search_path to 'airlinerra_game','pg_catalog' as $$
declare v_app record; v_check jsonb; v_issues jsonb;
begin
 if current_user is distinct from 'postgres' then
  raise exception using errcode='42501',message='LICENCE2_REFRESH_PRIVATE_SERVICE_ONLY';
 end if;
 if p_player is null or p_airline is null or p_application is null then
  return jsonb_build_object('status','INVALID_DRAFT_REFRESH','refreshed',false,
    'feeCharged',false,'rightsGranted',false,'flightsActivated',false);
 end if;
 if not exists(
  select 1 from airlinerra_game.airlines airline
  join airlinerra_game.world_memberships wm on wm.world_id=airline.world_id
   and wm.player_id=p_player and wm.state='active'
  where airline.id=p_airline and airline.world_id=1
   and airline.owner_player_id=p_player
 ) then raise exception using errcode='42501',message='LICENCE2_REFRESH_AIRLINE_NOT_OWNED';end if;
 select app.* into v_app
 from airlinerra_game.licence2_market_applications_v1 app
 where app.world_id=1 and app.airline_id=p_airline
  and app.owner_player_id=p_player and app.application_id=p_application
 for update;
 if not found then return jsonb_build_object('status','DRAFT_NOT_FOUND',
  'refreshed',false,'feeCharged',false,'rightsGranted',false,'flightsActivated',false);
 end if;
 if v_app.status<>'draft' then return jsonb_build_object(
  'status','DRAFT_REFRESH_NOT_ALLOWED','refreshed',false,
  'feeCharged',false,'rightsGranted',false,'flightsActivated',false);
 end if;
 v_check:=airlinerra_game.licence2_application_readiness_v1(
  v_app.airline_id,v_app.market_code,v_app.requested_level);
 if v_check->>'status' is distinct from 'READ_ONLY_PREAPPLICATION_ASSESSMENT' then
  return jsonb_build_object('status','DRAFT_READINESS_UNAVAILABLE',
   'refreshed',false,'feeCharged',false,'rightsGranted',false,'flightsActivated',false);
 end if;
 update airlinerra_game.licence2_market_applications_v1
 set latest_readiness=v_check
 where application_id=p_application and status='draft';
 if not found then raise exception 'LICENCE2_DRAFT_CHANGED_DURING_REFRESH';end if;
 v_issues:=v_check->'issues';
 return jsonb_build_object('status','DRAFT_READINESS_REFRESHED',
  'refreshed',true,'applicationId',p_application,
  'marketCode',v_app.market_code,'level',v_app.requested_level,
  'eligible',v_check->'eligible','issues',coalesce(v_issues,'[]'::jsonb),
  'feeCharged',false,'rightsGranted',false,'flightsActivated',false);
end $$;
revoke all on function airlinerra_game.licence2_refresh_owner_draft_v1(uuid,uuid,uuid)
 from public,anon,authenticated;