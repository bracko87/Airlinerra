-- Group 2 Section 5 GAME MODEL operating-policy inputs only.
-- Unknown real-world restrictions remain unresolved; no airport is granted approval.
begin;
insert into airlinerra_game.section5_airport_operating_policy_v1
 (world_id,airport_key,airport_code,timezone_iana,default_game_open_24_7,
 operating_hours_basis,curfew_identified,max_day_game_noise_class,
 max_night_game_noise_class,noise_limit_basis,operational_policy_note,last_checked)
select c.world_id,c.airport_key,c.game_lookup_code,c.timezone_iana,
 false,'GROUP2_GAME_MODEL_ESTIMATE_NOT_REAL_WORLD_VERIFIED',
 c.game_nighttime_ban,
 case when c.game_noise_restrictions then 3 else 5 end::smallint,
 case when c.game_noise_restrictions then 3 else 5 end::smallint,
 'GROUP2_GAME_MODEL_ESTIMATE_NOT_VERIFIED',
 'Prepared estimated game rules. Civilian/commercial access, current AIP/NOTAM, exact operating hours and actual noise constraints are NOT verified. Flight operations require separate airport admission and explicit release.',
 current_date
from airlinerra_game.airport_unified_operations_v1 c
where c.source_group='GROUP_2'
on conflict(world_id,airport_key) do nothing;
do $$
begin
 if (select count(*) from airlinerra_game.section5_airport_operating_policy_v1 p
 join airlinerra_game.airport_sections1_8_combined_members_v1 m using(world_id,airport_key)
 where m.source_group='GROUP_2')<>1118 then
 raise exception 'GROUP2_SECTION5_GAME_POLICY_INTEGRATION_INCOMPLETE';end if;
 if exists(select 1 from airlinerra_game.airport_group2_operational_releases_v1 where release_status='approved')
 then raise exception 'UNEXPECTED_COMMERCIAL_RELEASE';end if;
end $$;
commit;