-- Shared slot capacity inputs for Group 2; not dispatch approval.
begin;
alter table airlinerra_game.section6_airport_slot_capacity_v1
 drop constraint section6_airport_slot_capacity_v1_world_id_airport_key_fkey;
alter table airlinerra_game.section6_airport_slot_capacity_v1
 add constraint section6_airport_slot_capacity_unified_airport_fk
 foreign key(world_id,airport_key)
 references airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key);
insert into airlinerra_game.section6_airport_slot_capacity_v1
 (world_id,airport_key,terminal_stands,remote_stands,cargo_stands,
 terminal_per_direction_10m,remote_per_direction_10m,cargo_per_direction_10m,model_version)
select world_id,airport_key,game_terminal_stands,game_remote_stands,game_cargo_stands,
game_terminal_slot_per_10m,game_remote_slot_per_10m,game_cargo_slot_per_10m,'group2_estimated_stand_capacity_v1'
from airlinerra_game.airport_unified_operations_v1 where source_group='GROUP_2'
on conflict(world_id,airport_key) do nothing;
do $$
begin
if (select count(*) from airlinerra_game.section6_airport_slot_capacity_v1 s
join airlinerra_game.airport_sections1_8_combined_members_v1 m using(world_id,airport_key)
where m.source_group='GROUP_2')<>1118 then raise exception 'UNIFIED_GROUP2_SLOT_DATA_INCOMPLETE';end if;
if exists(select 1 from airlinerra_game.airport_group2_operational_releases_v1 where release_status='approved')
then raise exception 'UNEXPECTED_GROUP2_OPERATIONAL_RELEASE';end if;
end $$;
commit;