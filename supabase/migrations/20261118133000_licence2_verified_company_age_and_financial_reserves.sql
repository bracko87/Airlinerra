-- Licence 2 independently reviewed company age and reserve-evidence inputs.
-- This migration does not issue licences, create financial postings, or alter game clock.
begin;
create table if not exists airlinerra_game.licence2_company_game_registration_evidence_v1(
 world_id smallint not null default 1,
 airline_id uuid not null,
 registered_game_date date not null,
 evidence_reference text not null check(length(btrim(evidence_reference))>=20),
 verified_by text not null check(length(btrim(verified_by))>=12),
 verified_at timestamptz not null default now(),
 primary key(world_id,airline_id),
 foreign key(world_id,airline_id) references airlinerra_game.airlines(world_id,id),
 check(world_id=1)
);
create table if not exists airlinerra_game.licence2_airline_operating_reserve_evidence_v1(
 world_id smallint not null default 1,
 airline_id uuid not null,
 evidence_game_date date not null,
 projected_daily_operating_cost_usd numeric(18,2) not null check(projected_daily_operating_cost_usd>0),
 reserve_days integer not null default 90 check(reserve_days>=90),
 projected_cost_evidence_reference text not null check(length(btrim(projected_cost_evidence_reference))>=20),
 verified_by text not null check(length(btrim(verified_by))>=12),
 verified_at timestamptz not null default now(),
 primary key(world_id,airline_id),
 foreign key(world_id,airline_id) references airlinerra_game.airlines(world_id,id),
 check(world_id=1)
);
alter table airlinerra_game.licence2_company_game_registration_evidence_v1 enable row level security;
alter table airlinerra_game.licence2_airline_operating_reserve_evidence_v1 enable row level security;
revoke all on airlinerra_game.licence2_company_game_registration_evidence_v1 from public,anon,authenticated;
revoke all on airlinerra_game.licence2_airline_operating_reserve_evidence_v1 from public,anon,authenticated;
create or replace view airlinerra_game.licence2_airline_verified_evidence_readiness_v1
with (security_invoker=true) as
select a.world_id,a.id airline_id,
 c.confirmed_game_date game_date,
 registration.registered_game_date,
 case when c.clock_source='authoritative_game_engine'
 and c.last_verified_at is not null
 and registration.registered_game_date<=c.confirmed_game_date
 and registration.verified_at<=now()
 then (c.confirmed_game_date-registration.registered_game_date)::integer
 else null::integer end as verified_company_game_days,
 reserve.projected_daily_operating_cost_usd,
 reserve.reserve_days,
 case when reserve.evidence_game_date=c.confirmed_game_date
 and reserve.verified_at<=now()
 and c.clock_source='authoritative_game_engine'
 and reserve.projected_daily_operating_cost_usd>0
 and reserve.reserve_days>=90
 then reserve.projected_daily_operating_cost_usd*90 else null::numeric end as verified_90_day_reserve_required_usd,
 a.cash_usd,
 case when reserve.evidence_game_date=c.confirmed_game_date
 and reserve.verified_at<=now()
 and c.clock_source='authoritative_game_engine'
 and reserve.reserve_days>=90
 and reserve.projected_daily_operating_cost_usd>0
 then a.cash_usd>=reserve.projected_daily_operating_cost_usd*90
 else null::boolean end as ninety_day_cash_reserve_passes
from airlinerra_game.airlines a
left join airlinerra_game.holding_world_clock_v1 c on c.world_id=a.world_id
left join airlinerra_game.licence2_company_game_registration_evidence_v1 registration
 on registration.world_id=a.world_id and registration.airline_id=a.id
left join airlinerra_game.licence2_airline_operating_reserve_evidence_v1 reserve
 on reserve.world_id=a.world_id and reserve.airline_id=a.id;
revoke all on airlinerra_game.licence2_airline_verified_evidence_readiness_v1 from public,anon,authenticated;
do $$ begin
 if exists(select 1 from airlinerra_game.licence2_airline_verified_evidence_readiness_v1
 where verified_company_game_days<0 or verified_90_day_reserve_required_usd<=0)
 then raise exception 'LICENCE2_EVIDENCE_READINESS_INVALID';end if;
end $$;
commit;