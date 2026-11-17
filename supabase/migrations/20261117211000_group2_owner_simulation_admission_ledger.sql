-- Explicit GAME-ONLY airport admission; not a civil aviation approval.
-- Restricted owner-managed database ledger, no public or player writes.
begin;
create table if not exists airlinerra_game.airport_group2_simulation_admissions_v1 (
 world_id smallint not null default 1,
 airport_key text not null,
 admission_scope text not null default 'GAME_SIMULATION_ONLY',
 reference text not null,
 admitted_at timestamptz not null default now(),
 primary key(world_id,airport_key),
 foreign key(world_id,airport_key)
 references airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key),
 constraint game_admission_scope_v1_check check(admission_scope='GAME_SIMULATION_ONLY'),
 constraint game_admission_reference_nonempty check(length(btrim(reference))>=12)
);
alter table airlinerra_game.airport_group2_simulation_admissions_v1 enable row level security;
revoke all on airlinerra_game.airport_group2_simulation_admissions_v1 from public,anon,authenticated;
create or replace function airlinerra_game.guard_group2_simulation_admission_v1()
returns trigger language plpgsql
set search_path to 'airlinerra_game','pg_catalog' as $$
begin
 if new.world_id<>1 or not exists(
   select 1 from airlinerra_game.airport_group2_simulation_admission_candidates_v1 x
   where x.world_id=new.world_id and x.airport_key=new.airport_key
     and x.simulation_candidate_only and not x.documented_commercial_prohibition
     and x.game_model_inputs_complete)
 then raise exception 'GROUP2_GAME_ADMISSION_REQUIRES_VALID_NONPROHIBITED_SIMULATION_CANDIDATE'; end if;
 return new;
end $$;
drop trigger if exists guard_group2_simulation_admissions_v1 on airlinerra_game.airport_group2_simulation_admissions_v1;
create trigger guard_group2_simulation_admissions_v1 before insert or update on airlinerra_game.airport_group2_simulation_admissions_v1
for each row execute function airlinerra_game.guard_group2_simulation_admission_v1();
insert into airlinerra_game.airport_group2_simulation_admissions_v1(world_id,airport_key,reference)
select world_id,airport_key,'OWNER_AUTHORIZED_GAME_SIMULATION_GROUP2_2026_11_17'
from airlinerra_game.airport_group2_simulation_admission_candidates_v1
where simulation_candidate_only and not documented_commercial_prohibition
on conflict(world_id,airport_key) do nothing;
do $$
begin
 if (select count(*) from airlinerra_game.airport_group2_simulation_admissions_v1)<>1116
 then raise exception 'GROUP2_GAME_ADMISSION_COUNT_MISMATCH';end if;
 if exists (select 1 from airlinerra_game.airport_group2_simulation_admissions_v1
 where airport_key in ('OURAIRPORTS:29484','OURAIRPORTS:4436'))
 then raise exception 'DOCUMENTED_PROHIBITION_MUST_REMAIN_EXCLUDED';end if;
end $$;
commit;