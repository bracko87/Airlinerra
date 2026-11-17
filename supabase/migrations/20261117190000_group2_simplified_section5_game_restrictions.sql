-- Complete source-neutral Section 5 simplified GAME restriction input registration.
-- Source unknown stays GAME_DEFAULT_NOT_CHECKED; do not claim real-world approval.
begin;
alter table airlinerra_game.section5_airport_simplified_game_rules_v1
 drop constraint section5_airport_simplified_game_rule_world_id_airport_key_fkey,
 add constraint section5_simplified_rules_unified_airport_fk
 foreign key(world_id,airport_key)
 references airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key);
insert into airlinerra_game.section5_airport_simplified_game_rules_v1
(world_id,airport_key,nighttime_ban,noise_restrictions,permitted_noise_chapters,
 simplified_nighttime_window,source_status,game_model_version,note)
select c.world_id,c.airport_key,c.game_nighttime_ban,c.game_noise_restrictions,
case when c.game_noise_restrictions then array[3,4,14]::smallint[] else array[]::smallint[] end,
case when c.game_nighttime_ban then null else null end,
'GAME_DEFAULT_NOT_CHECKED',
'GROUP2_ESTIMATED_SECTION5_SIMULATION_MODEL_V1',
'Simulation-only estimated rules. True airport noise, curfew, civilian/commercial access and exact hours are not verified; any airport release requires separate authorization.'
from airlinerra_game.airport_unified_operations_v1 c
where c.source_group='GROUP_2'
on conflict(world_id,airport_key) do nothing;
do $$
begin
 if (select count(*) from airlinerra_game.section5_airport_simplified_game_rules_v1 s
 join airlinerra_game.airport_sections1_8_combined_members_v1 m using(world_id,airport_key)
 where m.source_group='GROUP_2')<>1118
 then raise exception 'GROUP2_SIMPLIFIED_RESTRICTION_BRIDGE_INCOMPLETE'; end if;
 if exists(select 1 from airlinerra_game.airport_group2_operational_releases_v1 where release_status='approved')
 then raise exception 'UNEXPECTED_GROUP2_RELEASE'; end if;
end $$;
commit;