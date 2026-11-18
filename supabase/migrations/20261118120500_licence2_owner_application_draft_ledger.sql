-- Owner-scoped Licence 2 draft workflow. Production application/approval is NOT enabled.
begin;
create table if not exists airlinerra_game.licence2_market_applications_v1 (
 application_id uuid primary key default gen_random_uuid(),
 world_id smallint not null default 1,
 airline_id uuid not null,
 owner_player_id uuid not null,
 market_code text not null,
 requested_level smallint not null,
 status text not null default 'draft'
  check(status in ('draft','submitted','under_review','approved','rejected','withdrawn')),
 requested_at timestamptz not null default now(),
 submitted_game_date date,
 latest_readiness jsonb,
 approved_permit_reference text,
 fee_posted_ledger_id bigint,
 reviewed_at timestamptz,
 foreign key(world_id,airline_id) references airlinerra_game.airlines(world_id,id),
 foreign key(market_code,requested_level) references airlinerra_game.licence2_market_levels_v1(market_code,level),
 constraint licence2_no_fake_approval check(
 status<>'approved' or
 (reviewed_at is not null and length(coalesce(approved_permit_reference,''))>=20
 and fee_posted_ledger_id is not null))
);
create unique index if not exists licence2_one_open_application_per_market_v1
 on airlinerra_game.licence2_market_applications_v1(world_id,airline_id,market_code)
 where status in ('draft','submitted','under_review');
alter table airlinerra_game.licence2_market_applications_v1 enable row level security;
revoke all on airlinerra_game.licence2_market_applications_v1 from public,anon,authenticated;
create or replace function airlinerra_game.licence2_stage_owner_application_v1(
 p_player uuid,p_airline uuid,p_market text,p_level smallint
) returns jsonb language plpgsql
set search_path to 'airlinerra_game','pg_catalog'
as $$
declare a record; v_check jsonb; v_id uuid;
begin
 if current_user is distinct from 'postgres'
 then raise exception using errcode='42501',message='LICENCE2_PRIVATE_OWNER_SERVICE_ONLY';end if;
 if p_player is null or p_airline is null or p_market is null or p_level is null
 then return jsonb_build_object('status','INVALID_APPLICATION','created',false);end if;
 select a.id into a from airlinerra_game.airlines a
 join airlinerra_game.world_memberships wm on wm.world_id=a.world_id
  and wm.player_id=p_player and wm.state='active'
 where a.id=p_airline and a.owner_player_id=p_player and a.world_id=1;
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
end $$;
revoke all on function airlinerra_game.licence2_stage_owner_application_v1(uuid,uuid,text,smallint)
 from public,anon,authenticated;
create or replace function airlinerra_game.licence2_guard_application_changes_v1()
returns trigger language plpgsql
set search_path to 'airlinerra_game','pg_catalog' as $$
begin
 if current_user is distinct from 'postgres' then
 raise exception using errcode='42501',message='LICENCE2_PRIVATE_APPLICATION_WRITER_REQUIRED';end if;
 if new.status not in ('draft','withdrawn') then
 raise exception using errcode='42501',message='LICENCE2_SUBMISSION_REVIEW_APPROVAL_NOT_RELEASED';end if;
 if new.status='draft' and (
 new.submitted_game_date is not null or new.fee_posted_ledger_id is not null
 or new.approved_permit_reference is not null)
 then raise exception 'LICENCE2_DRAFT_CANNOT_CLAIM_SUBMISSION_PAYMENT_OR_APPROVAL';end if;
 return new;
end $$;
drop trigger if exists licence2_guard_application_changes_v1
 on airlinerra_game.licence2_market_applications_v1;
create trigger licence2_guard_application_changes_v1
 before insert or update on airlinerra_game.licence2_market_applications_v1
 for each row execute function airlinerra_game.licence2_guard_application_changes_v1();
commit;