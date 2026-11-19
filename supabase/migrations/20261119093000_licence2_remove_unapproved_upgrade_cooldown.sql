-- Owner-approved full new-level fee and 3-game-day processing; no 365-day upgrade cooldown.
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_approval_preflight_v1(p_application uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare
 app record; airline record; market_policy record; fee_policy record;existing_permit record;
 readiness jsonb;issues text[]:=array[]::text[];
 game_day date; ledger_balance numeric;kind text;
begin
 if p_application is null then
 return jsonb_build_object('decision','INVALID_APPLICATION','approvalReady',false,'cashChanged',false,'permitIssued',false);end if;
 select * into app from airlinerra_game.licence2_market_applications_v1
 where application_id=p_application and world_id=1;
 if not found then return jsonb_build_object('decision','APPLICATION_NOT_FOUND','approvalReady',false,'cashChanged',false,'permitIssued',false);end if;
 select * into airline from airlinerra_game.airlines
 where id=app.airline_id and world_id=app.world_id;
 if not found or airline.owner_player_id is distinct from app.owner_player_id then
 issues:=array_append(issues,'AIRLINE_OWNERSHIP_CHANGED');end if;
 select * into market_policy from airlinerra_game.licence2_market_policy_v1
 where market_code=app.market_code;
 if market_policy.issuance_enabled is distinct from true then
 issues:=array_append(issues,'LICENCE2_ISSUANCE_PAUSED');end if;
 select * into existing_permit from airlinerra_game.licence2_airline_market_permits_v1
 where world_id=app.world_id and airline_id=app.airline_id and market_code=app.market_code;
 kind:=case when existing_permit.status='approved' then 'UPGRADE' else 'INITIAL' end;
 if existing_permit.status='approved' and existing_permit.level>=app.requested_level then
 issues:=array_append(issues,'ALREADY_HAS_THIS_OR_HIGHER_LEVEL');end if;
 select * into fee_policy from airlinerra_game.licence2_reviewed_fee_policy_v1
 where market_code=app.market_code and level=app.requested_level and application_kind=kind;
 if fee_policy.review_state is distinct from 'APPROVED'
 or fee_policy.fee_usd is null or fee_policy.processing_game_days is null then
 issues:=array_append(issues,'FEE_AND_PROCESSING_POLICY_NOT_APPROVED');end if;
 select confirmed_game_date into game_day
 from airlinerra_game.holding_world_clock_v1
 where world_id=1 and clock_source='authoritative_game_engine'
 and last_verified_at is not null;
 if game_day is null then issues:=array_append(issues,'AUTHORITATIVE_GAME_DATE_MISSING');end if;
 if app.status is distinct from 'submitted' or app.submitted_game_date is null then
 issues:=array_append(issues,'APPLICATION_NOT_SUBMITTED');end if;
 if app.submitted_game_date>game_day then issues:=array_append(issues,'APPLICATION_DATE_IN_FUTURE');end if;
 if fee_policy.review_state='APPROVED' and app.submitted_game_date is not null
 and game_day is not null
 and (game_day-app.submitted_game_date)<fee_policy.processing_game_days then
 issues:=array_append(issues,'PROCESSING_PERIOD_NOT_FINISHED');end if;
 -- Owner-approved rule: upgrades pay the full NEW level fee.
 -- No 365-game-day upgrade cooldown was authorized.
 -- The verified 3-game-day review period still applies to each submission.
 readiness:=airlinerra_game.licence2_application_readiness_v1(
 app.airline_id,app.market_code,app.requested_level);
 if readiness->>'eligible' is distinct from 'true' then
 issues:=array_append(issues,'CURRENT_ELIGIBILITY_NOT_PASSED');end if;
 select coalesce(sum(amount_usd),0) into ledger_balance
 from airlinerra_game.airline_ledger where airline_id=app.airline_id;
 if airline.id is null or fee_policy.review_state is distinct from 'APPROVED'
 or airline.cash_usd is null or ledger_balance is distinct from airline.cash_usd
 then issues:=array_append(issues,'CASH_LEDGER_NOT_RECONCILED_OR_FEE_UNSET');
 elsif airline.cash_usd<fee_policy.fee_usd then
 issues:=array_append(issues,'INSUFFICIENT_COMPANY_FUNDS_FOR_FEE');end if;
 if app.fee_posted_ledger_id is not null then
 issues:=array_append(issues,'FEE_ALREADY_LINKED_TO_APPLICATION');end if;
 return jsonb_build_object(
 'decision',case when cardinality(issues)=0 then 'REVIEW_READY_NOT_APPROVAL' else 'APPROVAL_BLOCKED' end,
 'approvalReady',cardinality(issues)=0,'issues',to_jsonb(issues),
 'applicationId',p_application,'market',app.market_code,'level',app.requested_level,
 'kind',kind,'quotedFeeUsd',fee_policy.fee_usd,
 'processingGameDays',fee_policy.processing_game_days,
 'ledgerReconciled',airline.cash_usd is not null and ledger_balance=airline.cash_usd,
 'cashChanged',false,'feeCharged',false,'permitIssued',false,'flightsActivated',false);
end $function$
;
