-- Licence 2 approval pricing and preflight, intentionally NON-ISSUING and NON-CHARGING.
-- EU level caps are approved, but market-specific fees, processing and activation are not.
begin;
create table if not exists airlinerra_game.licence2_reviewed_fee_policy_v1 (
 market_code text not null,
 level smallint not null,
 application_kind text not null check(application_kind in ('INITIAL','UPGRADE')),
 fee_usd numeric(18,2) check(fee_usd>0),
 processing_game_days integer check(processing_game_days>=0),
 review_state text not null default 'DRAFT' check(review_state in ('DRAFT','APPROVED')),
 approved_by text,
 approval_reference text,
 approved_at timestamptz,
 primary key(market_code,level,application_kind),
 foreign key(market_code,level) references airlinerra_game.licence2_market_levels_v1(market_code,level),
 constraint licence2_fee_policy_needs_real_approval check (
  review_state='DRAFT' or (
  fee_usd is not null and processing_game_days is not null
  and length(coalesce(approved_by,''))>=12
  and length(coalesce(approval_reference,''))>=20
  and approved_at is not null and approved_at<=now()))
);
alter table airlinerra_game.licence2_reviewed_fee_policy_v1 enable row level security;
revoke all on airlinerra_game.licence2_reviewed_fee_policy_v1 from public,anon,authenticated;
insert into airlinerra_game.licence2_reviewed_fee_policy_v1(market_code,level,application_kind)
select market_code,level,k.application_kind
from airlinerra_game.licence2_market_levels_v1
cross join (values ('INITIAL'),('UPGRADE')) k(application_kind)
on conflict do nothing;
create or replace function airlinerra_game.licence2_approval_preflight_v1(p_application uuid)
returns jsonb language plpgsql stable
set search_path to 'airlinerra_game','pg_catalog' as $$
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
 if kind='UPGRADE' then
   if existing_permit.last_upgrade_game_date is null then
    issues:=array_append(issues,'UPGRADE_HISTORY_NOT_VERIFIED');
   elsif game_day is not null and (game_day-existing_permit.last_upgrade_game_date)<365 then
    issues:=array_append(issues,'YEARLY_UPGRADE_WINDOW_NOT_REACHED');end if;
 end if;
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
end $$;
revoke all on function airlinerra_game.licence2_approval_preflight_v1(uuid) from public,anon,authenticated;
comment on function airlinerra_game.licence2_approval_preflight_v1(uuid) is
 'Private read-only approval evidence check. Never charges, approves, issues or activates.';
commit;