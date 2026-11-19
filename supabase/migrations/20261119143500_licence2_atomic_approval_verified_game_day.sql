-- Never debit airline funds for Licence 2 using a clock row without verified tick proof.
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_approve_application_atomic_v1(p_application uuid, p_review_event text, p_review_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare
 v_release record; v_airline record; v_app record; v_preflight jsonb;
 v_fee numeric; v_entry_id bigint; v_game_day date;
 v_prev record;
begin
 if current_user is distinct from 'postgres' then
  raise exception using errcode='42501',message='LICENCE2_APPROVAL_PRIVATE_REVIEW_SERVICE_ONLY';end if;
 select * into v_release from airlinerra_game.licence2_approval_release_v1
 where world_id=1 for share;
 if v_release.approval_enabled is distinct from true
 or v_release.reviewer_integration_verified is distinct from true
 or v_release.fee_ledger_integration_verified is distinct from true
 then return jsonb_build_object('status','LICENCE2_APPROVAL_NOT_RELEASED',
  'chargedNow',false,'permitIssuedNow',false,'flightActivated',false);end if;
 if p_application is null or p_review_event is null
 or p_review_event !~ '^[A-Za-z0-9._:-]{16,128}$'
 or length(coalesce(p_review_reference,''))<20 then
 raise exception using errcode='22023',message='LICENCE2_REVIEW_EVENT_INVALID';end if;
 -- Lock airline first, matching existing game finance writers' lock ordering.
 select a.* into v_airline from airlinerra_game.airlines a
 join airlinerra_game.licence2_market_applications_v1 ap on ap.airline_id=a.id and ap.world_id=a.world_id
 where ap.application_id=p_application and a.world_id=1 for update of a;
 if not found then
  return jsonb_build_object('status','LICENCE2_AIRLINE_NOT_FOUND',
  'chargedNow',false,'permitIssuedNow',false);end if;
 select * into v_app from airlinerra_game.licence2_market_applications_v1
 where application_id=p_application and world_id=1 and airline_id=v_airline.id for update;
 if v_app.status='approved' then
   return jsonb_build_object('status','ALREADY_APPROVED','applicationId',p_application,
    'chargedNow',false,'permitIssuedNow',false,'ledgerEntryId',v_app.fee_posted_ledger_id);
 end if;
 if v_app.status is distinct from 'submitted' or v_airline.owner_player_id is distinct from v_app.owner_player_id
 then return jsonb_build_object('status','SUBMITTED_OWNED_APPLICATION_REQUIRED',
  'chargedNow',false,'permitIssuedNow',false);end if;
 v_preflight:=airlinerra_game.licence2_approval_preflight_v1(p_application);
 if v_preflight->>'approvalReady' is distinct from 'true' then
  return jsonb_build_object('status','APPROVAL_PREFLIGHT_BLOCKED',
   'preflight',v_preflight,'chargedNow',false,'permitIssuedNow',false);end if;
 -- Never accept a client-provided fee. Take the reviewed approved policy amount.
 v_fee:=(v_preflight->>'quotedFeeUsd')::numeric;
 if v_fee is null or v_fee<=0 then
  raise exception 'LICENCE2_APPROVAL_FEE_UNAVAILABLE';end if;
 -- Authoritative day must be backed by the current, independently verified
 -- engine tick receipt, active world, and exact current game date.
 -- A syntactically valid/stale clock row is not permission to debit cash.
 v_game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 if v_game_day is null then
  return jsonb_build_object('status','APPROVAL_GAME_DAY_UNVERIFIED','chargedNow',false,'permitIssuedNow',false);end if;
 select * into v_prev from airlinerra_game.licence2_airline_market_permits_v1
 where world_id=1 and airline_id=v_app.airline_id and market_code=v_app.market_code for update;
 if v_prev.status='approved' and v_prev.level>=v_app.requested_level then
  return jsonb_build_object('status','ALREADY_HOLDS_LEVEL','chargedNow',false,'permitIssuedNow',false);end if;
 -- Must not consume cash without a reconciled ledger and adequate locked balance.
 if v_airline.cash_usd<v_fee
 or (select coalesce(sum(amount_usd),0) from airlinerra_game.airline_ledger
    where airline_id=v_airline.id) is distinct from v_airline.cash_usd
 then return jsonb_build_object('status','APPROVAL_CASH_LEDGER_BLOCKED',
  'chargedNow',false,'permitIssuedNow',false);end if;
 update airlinerra_game.airlines set cash_usd=cash_usd-v_fee
 where id=v_airline.id and world_id=1 and cash_usd>=v_fee;
 if not found then raise exception 'LICENCE2_CASH_CHANGED_CONCURRENTLY';end if;
 insert into airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
 values(v_airline.id,'EXPENSE',-v_fee) returning id into v_entry_id;
 -- Review-event uniqueness is enforced in the SAME transaction as cash and permit.
 -- A conflicting event rolls back the ledger debit and airline balance update.
 insert into airlinerra_game.licence2_review_event_receipts_v1
 (review_event_id,application_id,airline_id,market_code,review_reference,fee_ledger_id,approved_game_date)
 values(p_review_event,p_application,v_airline.id,v_app.market_code,p_review_reference,v_entry_id,v_game_day);
 insert into airlinerra_game.licence2_airline_market_permits_v1
 (world_id,airline_id,market_code,level,status,approved_at,approval_reference,last_upgrade_game_date)
 values(1,v_airline.id,v_app.market_code,v_app.requested_level,'approved',now(),p_review_reference,v_game_day)
 on conflict(world_id,airline_id,market_code)
 do update set level=excluded.level,status='approved',approved_at=excluded.approved_at,
 approval_reference=excluded.approval_reference,last_upgrade_game_date=excluded.last_upgrade_game_date;
 update airlinerra_game.licence2_market_applications_v1
 set status='approved',approved_permit_reference=p_review_reference,
 fee_posted_ledger_id=v_entry_id,reviewed_at=now()
 where application_id=p_application and status='submitted';
 if not found then raise exception 'LICENCE2_APPLICATION_STATUS_CHANGED';end if;
 return jsonb_build_object('status','APPROVED_AND_CHARGED_ONCE',
  'applicationId',p_application,'reviewEventId',p_review_event,
  'ledgerEntryId',v_entry_id,'chargedNow',true,'chargedUsd',v_fee,
  'permitIssuedNow',true,'flightActivated',false);
end $function$
;
