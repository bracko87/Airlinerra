-- Airlinerra holding & finance Phase 1, 2026-11-08.
-- Production has been updated with this reference schema and 3 disabled policies.
-- No real company formation, treasury credit, transfer or licence grant is enabled.
-- Database-funded transfers require a future locked double-entry posting engine.
begin;
create table if not exists airlinerra_game.holding_world_policy_v1 (
 world_id smallint primary key references public.airlinerra_game_worlds(id),
 minimum_operating_age_days integer not null default 60 check(minimum_operating_age_days=60),
 formation_enabled boolean not null default false check(formation_enabled=false),
 subsidiary_creation_enabled boolean not null default false check(subsidiary_creation_enabled=false),
 treasury_transfers_enabled boolean not null default false check(treasury_transfers_enabled=false),
 holding_registration_fee_usd numeric(14,2) check(holding_registration_fee_usd is null or holding_registration_fee_usd>=0),
 subsidiary_registration_fee_usd numeric(14,2) check(subsidiary_registration_fee_usd is null or subsidiary_registration_fee_usd>=0),
 transfer_fixed_fee_usd numeric(14,2) check(transfer_fixed_fee_usd is null or transfer_fixed_fee_usd>=0),
 transfer_fee_basis_points integer check(transfer_fee_basis_points is null or transfer_fee_basis_points between 0 and 500),
 transfer_fee_cap_usd numeric(14,2) check(transfer_fee_cap_usd is null or transfer_fee_cap_usd>=0),
 updated_at timestamptz not null default now()
);
create table if not exists airlinerra_game.holding_world_clock_v1 (
 world_id smallint primary key references public.airlinerra_game_worlds(id),
 confirmed_game_date date,
 clock_source text not null default 'not_connected'
   check(clock_source in ('not_connected','authoritative_game_engine')),
 engine_proof_ref text,
 last_verified_at timestamptz,
 constraint holding_verified_clock_source check (
  (clock_source='not_connected' and confirmed_game_date is null
   and engine_proof_ref is null and last_verified_at is null)
  or (clock_source='authoritative_game_engine' and confirmed_game_date is not null
   and length(engine_proof_ref)>=12 and last_verified_at is not null)
 )
);
create table if not exists airlinerra_game.airline_first_operating_day_v1 (
 airline_id uuid primary key references airlinerra_game.airlines(id) on delete restrict,
 first_operating_game_date date not null,
 completed_flight_proof_id text not null check(length(completed_flight_proof_id) between 12 and 200),
 evidence_status text not null check(evidence_status='settled_commercial_flight'),
 verified_at timestamptz not null default now()
);
-- This index validates that a holding founder truly owns the selected airline.
-- Keep the existing UNIQUE(world_id,owner_player_id) restriction; it will need
-- deliberate ownership refactoring before multiple real airlines are activated.
create unique index if not exists airlines_world_owner_airline_identity_v1
 on airlinerra_game.airlines(world_id,owner_player_id,id);
create table if not exists airlinerra_game.holding_groups_v1 (
 id uuid primary key default gen_random_uuid(),
 world_id smallint not null references public.airlinerra_game_worlds(id),
 owner_player_id uuid not null,
 original_airline_id uuid not null,
 holding_name text not null check(length(trim(holding_name)) between 3 and 100),
 state text not null default 'planning' check(state='planning'),
 registered_country_iso2 text check(registered_country_iso2 ~ '^[A-Z]{2}$'),
 created_at timestamptz not null default now(),
 unique(world_id,owner_player_id),unique(original_airline_id),unique(id,world_id),
 foreign key(world_id,owner_player_id)
   references airlinerra_game.world_memberships(world_id,player_id),
 foreign key(world_id,owner_player_id,original_airline_id)
   references airlinerra_game.airlines(world_id,owner_player_id,id)
);
create table if not exists airlinerra_game.holding_subsidiaries_v1 (
 id uuid primary key default gen_random_uuid(),
 holding_id uuid not null,world_id smallint not null,
 company_name text not null check(length(trim(company_name)) between 3 and 100),
 company_kind text not null check(company_kind in
  ('regional_airline','passenger_airline','cargo_airline','charter_airline','maintenance_mro')),
 country_iso2 text not null check(country_iso2 ~ '^[A-Z]{2}$'),
 formation_state text not null default 'planned' check(formation_state='planned'),
 planned_capital_usd numeric(16,2) check(planned_capital_usd is null or planned_capital_usd>=0),
 created_at timestamptz not null default now(),
 foreign key(holding_id,world_id)
   references airlinerra_game.holding_groups_v1(id,world_id),
 unique(holding_id,company_name),unique(id,holding_id,world_id)
);
create table if not exists airlinerra_game.holding_treasury_accounts_v1 (
 id uuid primary key default gen_random_uuid(),
 holding_id uuid not null,world_id smallint not null,
 account_scope text not null check(account_scope in ('holding','subsidiary')),
 subsidiary_id uuid,
 available_usd numeric(16,2) not null default 0 check(available_usd=0),
 reserved_usd numeric(16,2) not null default 0 check(reserved_usd=0),
 created_at timestamptz not null default now(),
 unique(id,holding_id,world_id),
 constraint holding_treasury_account_scope check (
  (account_scope='holding' and subsidiary_id is null)
  or (account_scope='subsidiary' and subsidiary_id is not null)
 ),
 foreign key(holding_id,world_id)
   references airlinerra_game.holding_groups_v1(id,world_id),
 foreign key(subsidiary_id,holding_id,world_id)
   references airlinerra_game.holding_subsidiaries_v1(id,holding_id,world_id)
);
create unique index if not exists holding_one_parent_treasury_v1
 on airlinerra_game.holding_treasury_accounts_v1(holding_id)
 where account_scope='holding';
create unique index if not exists holding_one_subsidiary_treasury_v1
 on airlinerra_game.holding_treasury_accounts_v1(subsidiary_id)
 where account_scope='subsidiary';
create table if not exists airlinerra_game.holding_transfer_intents_v1 (
 id uuid primary key default gen_random_uuid(),
 holding_id uuid not null,world_id smallint not null,
 sender_account_id uuid not null,recipient_account_id uuid not null,
 idempotency_key uuid not null,
 transfer_kind text not null check(transfer_kind in (
  'equity_contribution','intercompany_loan','loan_repayment','dividend','service_payment'
 )),
 gross_amount_usd numeric(16,2) not null check(gross_amount_usd>0),
 estimated_fee_usd numeric(14,2) check(estimated_fee_usd is null or estimated_fee_usd>=0),
 intent_state text not null default 'draft' check(intent_state='draft'),
 created_at timestamptz not null default now(),
 unique(holding_id,idempotency_key),check(sender_account_id<>recipient_account_id),
 foreign key(holding_id,world_id)
   references airlinerra_game.holding_groups_v1(id,world_id),
 foreign key(sender_account_id,holding_id,world_id)
   references airlinerra_game.holding_treasury_accounts_v1(id,holding_id,world_id),
 foreign key(recipient_account_id,holding_id,world_id)
   references airlinerra_game.holding_treasury_accounts_v1(id,holding_id,world_id)
);

-- Never infer genuine operating age from airline registration or route drafts.
create or replace view airlinerra_game.holding_eligibility_preview_v1
with (security_invoker=true) as
select
 a.id as airline_id,a.owner_player_id,a.world_id,w.state as world_state,
 p.minimum_operating_age_days,
 f.first_operating_game_date,
 c.confirmed_game_date as current_verified_game_date,
 case when w.state='active' and c.clock_source='authoritative_game_engine'
    and f.evidence_status='settled_commercial_flight'
    and c.confirmed_game_date>=f.first_operating_game_date
   then c.confirmed_game_date-f.first_operating_game_date else null end
    as completed_world_days_since_first_operation,
 case when f.first_operating_game_date is not null
   then f.first_operating_game_date+p.minimum_operating_age_days else null end
   as earliest_eligibility_game_date,
 case when w.state='active' and c.clock_source='authoritative_game_engine'
    and f.evidence_status='settled_commercial_flight'
    and c.confirmed_game_date>=f.first_operating_game_date
   then greatest(0,p.minimum_operating_age_days-
     (c.confirmed_game_date-f.first_operating_game_date)) else null end
   as remaining_world_days,
 coalesce((w.state='active' and c.clock_source='authoritative_game_engine'
  and f.evidence_status='settled_commercial_flight'
  and c.confirmed_game_date>=f.first_operating_game_date+p.minimum_operating_age_days),false)
   as minimum_age_met,
 p.formation_enabled as holding_registration_open,
 case when w.state<>'active' then 'world_not_active'
      when c.clock_source<>'authoritative_game_engine' then 'game_clock_unverified'
      when f.airline_id is null then 'first_operating_flight_unverified'
      when c.confirmed_game_date<f.first_operating_game_date then 'clock_before_first_operation'
      when c.confirmed_game_date<f.first_operating_game_date+p.minimum_operating_age_days
        then 'waiting_for_60_game_days'
      when not p.formation_enabled then 'holding_registration_not_released'
      else 'eligible_for_application' end as eligibility_status
from airlinerra_game.airlines a
join public.airlinerra_game_worlds w on w.id=a.world_id
join airlinerra_game.holding_world_policy_v1 p on p.world_id=a.world_id
join airlinerra_game.holding_world_clock_v1 c on c.world_id=a.world_id
left join airlinerra_game.airline_first_operating_day_v1 f on f.airline_id=a.id;

-- Explicit denial at browser Data API; only the authenticated private server
-- connection may read holding status and eventually handle financial postings.
do $$
declare t text;
begin
 foreach t in array array[
  'holding_world_policy_v1','holding_world_clock_v1','airline_first_operating_day_v1',
  'holding_groups_v1','holding_subsidiaries_v1','holding_treasury_accounts_v1',
  'holding_transfer_intents_v1'
 ] loop
   execute format('alter table airlinerra_game.%I enable row level security',t);
   execute format('revoke all on airlinerra_game.%I from public,anon,authenticated',t);
 end loop;
end $$;
revoke all on airlinerra_game.holding_eligibility_preview_v1 from public,anon,authenticated;

insert into airlinerra_game.holding_world_policy_v1(world_id)
 select id from public.airlinerra_game_worlds on conflict(world_id) do nothing;
insert into airlinerra_game.holding_world_clock_v1(world_id)
 select id from public.airlinerra_game_worlds on conflict(world_id) do nothing;
commit;
