-- Airlinerra Holding eligibility v2 — 2026-11-09
-- Supersedes the v1 game-day/first-flight holding waiting-period rule.
-- A holding requires 60 *elapsed calendar days* since original airline
-- registration, measured by the Postgres server clock and created_at.
-- This does NOT enable holding registration, subsidiaries or any charges.
-- This is the exact production-installed read-only age calculation.
begin;
alter table airlinerra_game.holding_world_policy_v1
 add column if not exists minimum_registration_age_days integer not null default 60
 check (minimum_registration_age_days=60);
comment on column airlinerra_game.holding_world_policy_v1.minimum_registration_age_days is
 'Holding age rule: 60 elapsed 24-hour calendar days after airline created_at, independent of flights/game world clock/login activity. Registration remains locked.';

create or replace view airlinerra_game.holding_registration_eligibility_v2
with (security_invoker=true) as
select
 a.id as airline_id,
 a.owner_player_id,
 a.world_id,
 w.state as world_state,
 a.created_at as airline_registered_at,
 (a.created_at + p.minimum_registration_age_days*interval '1 day') as eligibility_at,
 p.minimum_registration_age_days,
 greatest(0,floor(extract(epoch from (now()-a.created_at))/86400))::integer as completed_registration_days,
 greatest(0,ceil(extract(epoch from ((a.created_at+p.minimum_registration_age_days*interval '1 day')-now()))/86400))::integer as remaining_registration_days,
 (now() >= a.created_at + p.minimum_registration_age_days*interval '1 day') as minimum_age_met,
 p.formation_enabled as holding_registration_open,
 case
  when now()<a.created_at+p.minimum_registration_age_days*interval '1 day'
    then 'waiting_for_60_registration_days'
  when not p.formation_enabled then 'holding_registration_not_released'
  when w.state<>'active' then 'world_not_active'
  else 'eligible_for_application'
 end as eligibility_status
from airlinerra_game.airlines a
join public.airlinerra_game_worlds w on w.id=a.world_id
join airlinerra_game.holding_world_policy_v1 p on p.world_id=a.world_id;
comment on view airlinerra_game.holding_registration_eligibility_v2 is
 'Server-owned, read-only 60-day holding waiting period from authoritative airlines.created_at and now(). No first flight, game clock, permission or holding creation.';
revoke all on airlinerra_game.holding_registration_eligibility_v2
 from public,anon,authenticated;
commit;

-- Verification (read-only):
-- select airline_registered_at,eligibility_at,
--        remaining_registration_days,eligibility_status
-- from airlinerra_game.holding_registration_eligibility_v2;
-- Existing v1 eligibility view is historical and should not be used
-- for new holding registration eligibility decisions.
