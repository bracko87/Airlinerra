-- Permit exactly one submitted -> approved transition when the trusted reviewed release is enabled
-- and the issued permit, fee ledger entry, and unique review-event receipt all match.
-- Current release remains hard-paused by the existing database constraint.
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_guard_application_changes_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare v_check jsonb;v_game_day date;
begin
 if current_user is distinct from 'postgres' then
  raise exception using errcode='42501',message='LICENCE2_PRIVATE_APPLICATION_WRITER_REQUIRED';
 end if;
 if new.status not in ('draft','submitted','approved','withdrawn') then
  raise exception using errcode='42501',message='LICENCE2_UNSUPPORTED_APPLICATION_TRANSITION';
 end if;
 if new.status='approved' then
   if tg_op='INSERT' or old.status is distinct from 'submitted'
   or not exists(
     select 1 from airlinerra_game.licence2_approval_release_v1 rel
     where rel.world_id=new.world_id and rel.approval_enabled
       and rel.reviewer_integration_verified and rel.fee_ledger_integration_verified)
   then raise exception using errcode='42501',message='LICENCE2_APPROVAL_NOT_RELEASED';end if;
   if not exists(
     select 1 from airlinerra_game.licence2_review_event_receipts_v1 receipt
     join airlinerra_game.airline_ledger ledger
       on ledger.id=receipt.fee_ledger_id and ledger.airline_id=new.airline_id
       and ledger.entry_kind='EXPENSE' and ledger.amount_usd<0
     join airlinerra_game.licence2_airline_market_permits_v1 permit
       on permit.world_id=new.world_id and permit.airline_id=new.airline_id
       and permit.market_code=new.market_code and permit.level=new.requested_level
       and permit.status='approved'
       and permit.approval_reference=new.approved_permit_reference
     where receipt.application_id=new.application_id
       and receipt.airline_id=new.airline_id
       and receipt.market_code=new.market_code
       and receipt.fee_ledger_id=new.fee_posted_ledger_id
       and receipt.review_reference=new.approved_permit_reference)
   then raise exception using errcode='42501',message='LICENCE2_APPROVAL_MISSING_MATCHED_FEE_RECEIPT_AND_PERMIT';end if;
 elsif new.fee_posted_ledger_id is not null or new.approved_permit_reference is not null
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
end $function$
;
do $$
begin
 if exists(select 1 from airlinerra_game.licence2_approval_release_v1 where approval_enabled)
 then raise exception 'LICENCE2_APPROVAL_UNEXPECTEDLY_ACTIVE';end if;
end $$;