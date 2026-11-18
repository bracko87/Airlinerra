-- Licence 2 game-only foreign network policy foundation (18 Nov 2026).
-- Does not issue licences, debit funds, or authorize commercial flight operations.
begin;
create table if not exists airlinerra_game.licence2_market_policy_v1(
 market_code text primary key check(market_code in ('L2-EU','L2-US','L2-UK','L2-JP')),
 market_name text not null,
 maximum_level smallint not null check(maximum_level between 1 and 4),
 rules_status text not null default 'DRAFT'
   check(rules_status in ('APPROVED_EU_ROUTE_CAPS','DRAFT')),
 issuance_enabled boolean not null default false,
 enforcement_enabled boolean not null default false,
 constraint licence2_policy_no_unreviewed_release check(
  issuance_enabled=false and enforcement_enabled=false)
);
create table if not exists airlinerra_game.licence2_market_levels_v1(
 market_code text not null references airlinerra_game.licence2_market_policy_v1(market_code),
 level smallint not null check(level between 1 and 4),
 max_active_directed_routes integer check(max_active_directed_routes>0),
 max_category text check(max_category in ('Local','Regional','Medium','Large','Major Hub','Mega Hub')),
 quota_approved boolean not null default false,
 primary key(market_code,level),
 constraint licence2_unapproved_limits_not_released check(
   quota_approved=false or (max_category is not null
    and (max_active_directed_routes is not null or level=4)))
);
create table if not exists airlinerra_game.licence2_airline_market_permits_v1(
 world_id smallint not null default 1,
 airline_id uuid not null references airlinerra_game.airlines(id),
 market_code text not null references airlinerra_game.licence2_market_policy_v1(market_code),
 level smallint not null,
 status text not null default 'draft'
   check(status in ('draft','pending_review','approved','suspended','revoked')),
 approved_at timestamptz,
 approval_reference text,
 last_upgrade_game_date date,
 created_at timestamptz not null default now(),
 primary key(world_id,airline_id,market_code),
 foreign key(market_code,level) references airlinerra_game.licence2_market_levels_v1(market_code,level),
 constraint licence2_approved_requires_evidence check(
 status<>'approved' or (approved_at is not null and length(coalesce(approval_reference,''))>=20))
);
alter table airlinerra_game.licence2_market_policy_v1 enable row level security;
alter table airlinerra_game.licence2_market_levels_v1 enable row level security;
alter table airlinerra_game.licence2_airline_market_permits_v1 enable row level security;
revoke all on airlinerra_game.licence2_market_policy_v1 from public,anon,authenticated;
revoke all on airlinerra_game.licence2_market_levels_v1 from public,anon,authenticated;
revoke all on airlinerra_game.licence2_airline_market_permits_v1 from public,anon,authenticated;
insert into airlinerra_game.licence2_market_policy_v1(market_code,market_name,maximum_level,rules_status)
values
('L2-EU','European Union and EEA',4,'APPROVED_EU_ROUTE_CAPS'),
('L2-US','United States',4,'DRAFT'),
('L2-UK','United Kingdom',2,'DRAFT'),
('L2-JP','Japan',2,'DRAFT')
on conflict(market_code) do nothing;
insert into airlinerra_game.licence2_market_levels_v1(market_code,level,max_active_directed_routes,max_category,quota_approved)
values
('L2-EU',1,20,'Medium',true),
('L2-EU',2,50,'Large',true),
('L2-EU',3,150,'Major Hub',true),
('L2-EU',4,null,'Mega Hub',true),
('L2-US',1,null,null,false),('L2-US',2,null,null,false),
('L2-US',3,null,null,false),('L2-US',4,null,null,false),
('L2-UK',1,null,null,false),('L2-UK',2,null,null,false),
('L2-JP',1,null,null,false),('L2-JP',2,null,null,false)
on conflict(market_code,level) do nothing;
do $$
begin
 if (select max_active_directed_routes from airlinerra_game.licence2_market_levels_v1
   where market_code='L2-EU' and level=1)<>20
 then raise exception 'LICENCE2_EU_LEVEL1_MUST_BE_20'; end if;
 if exists(select 1 from airlinerra_game.licence2_market_policy_v1 where issuance_enabled or enforcement_enabled)
 then raise exception 'LICENCE2_MUST_NOT_ACTIVATE_WITHOUT_APPLICATION_AND_ROUTE_CHECKS';end if;
end $$;
commit;