-- Licence 2 guarded submission workflow. No fee or permit issued.
begin;
create or replace function airlinerra_game.licence2_guard_application_changes_v1()
returns trigger language plpgsql
set search_path to 'airlinerra_game','pg_catalog' as $$
declare v_check jsonb;v_game_day date;
begin
 if current_user is distinct from 'postgres' then
  raise exception using errcode='42501',message='LICENCE2_PRIVATE_APPLICATION_WRITER_REQUIRED';end if;
 if new.status not in ('draft','submitted','withdrawn') then
  raise exception using errcode='42501',message='LICENCE2_REVIEW_APPROVAL_NOT_RELEASED';end if;
 if new.fee_posted_ledger_id is not null or new.approved_permit_reference is not null
 then raise exception 'LICENCE2_UNAPPROVED_APPLICATION_CANNOT_CLAIM_PAYMENT_OR_PERMIT';end if;
 if new.status='draft' and new.submitted_game_date is not null
 then raise exception 'LICENCE2_DRAFT_CANNOT_CLAIM_SUBMISSION';end if;
 if new.status='submitted' then
  if tg_op='INSERT' or old.status is distinct from 'draft' then
   raise exception using errcode='42501',message='LICENCE2_ONLY_VERIFIED_DRAFT_CAN_BE_SUBMITTED';end if;
  select confirmed_game_date into v_game_day
  from airlinerra_game.holding_world_clock_v1
  where world_id=new.world_id and clock_source='authoritative_game_engine'
   and last_verified_at is not null;
  v_check:=airlinerra_game.licence2_application_readiness_v1(
   new.airline_id,new.market_code,new.requested_level);
  if v_game_day is null or new.submitted_game_date is distinct from v_game_day
   or v_check->>'eligible' is distinct from 'true'
   or new.latest_readiness is distinct from v_check then
    raise exception using errcode='42501',message='LICENCE2_SUBMISSION_REQUIRES_LIVE_VERIFIED_READINESS';end if;
 end if;
 return new;
end $$;
create or replace function airlinerra_game.licence2_submit_owner_application_v1(
 p_player uuid,p_application uuid)
returns jsonb language plpgsql
set search_path to 'airlinerra_game','pg_catalog' as $$
declare v_app record;v_readiness jsonb;v_day date;
begin
 if current_user is distinct from 'postgres' then
  raise exception using errcode='42501',message='LICENCE2_PRIVATE_OWNER_SERVICE_ONLY';end if;
 if p_player is null or p_application is null
 then return jsonb_build_object('status','INVALID_SUBMISSION','submitted',false);end if;
 select app.* into v_app
 from airlinerra_game.licence2_market_applications_v1 app
 join airlinerra_game.airlines a
  on a.id=app.airline_id and a.world_id=app.world_id
 join airlinerra_game.world_memberships wm
  on wm.world_id=app.world_id and wm.player_id=p_player and wm.state='active'
 where app.application_id=p_application and app.world_id=1
  and app.owner_player_id=p_player and a.owner_player_id=p_player
 for update of app;
 if not found then raise exception using errcode='42501',message='LICENCE2_APPLICATION_NOT_OWNED';end if;
 if v_app.status='submitted' then
  return jsonb_build_object('status','ALREADY_SUBMITTED','submitted',true,
  'applicationId',p_application,'feeCharged',false,'rightsGranted',false);end if;
 if v_app.status<>'draft' then
  return jsonb_build_object('status','APPLICATION_NOT_SUBMITTABLE','submitted',false,
  'applicationId',p_application,'feeCharged',false,'rightsGranted',false);end if;
 v_readiness:=airlinerra_game.licence2_application_readiness_v1(
 v_app.airline_id,v_app.market_code,v_app.requested_level);
 if v_readiness->>'eligible' is distinct from 'true'
 then return jsonb_build_object('status','APPLICATION_NOT_ELIGIBLE','submitted',false,
  'readiness',v_readiness,'applicationId',p_application,
  'feeCharged',false,'rightsGranted',false);end if;
 select c.confirmed_game_date into v_day
 from airlinerra_game.holding_world_clock_v1 c
 where c.world_id=1 and c.clock_source='authoritative_game_engine'
  and c.last_verified_at is not null;
 if v_day is null then return jsonb_build_object('status','GAME_DATE_UNVERIFIED','submitted',false,
  'feeCharged',false,'rightsGranted',false);end if;
 update airlinerra_game.licence2_market_applications_v1
 set status='submitted',submitted_game_date=v_day,latest_readiness=v_readiness
 where application_id=p_application and status='draft';
 if not found then raise exception 'LICENCE2_SUBMISSION_CONCURRENTLY_CHANGED';end if;
 return jsonb_build_object('status','APPLICATION_SUBMITTED_FOR_REVIEW','submitted',true,
 'applicationId',p_application,'submittedGameDate',v_day,
 'feeCharged',false,'rightsGranted',false,'flightsActivated',false);
end $$;
revoke all on function airlinerra_game.licence2_submit_owner_application_v1(uuid,uuid) from public,anon,authenticated;
commit;