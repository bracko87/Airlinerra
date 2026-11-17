-- Non-destructive player-game exclusion: preserve research records and audit trail.
-- Exactly two documented military air bases are excluded from selectable gameplay.
create or replace view airlinerra_game.airport_player_game_roster_v1
with (security_invoker=true) as
select c.*
from airlinerra_game.airport_unified_operations_v1 c
where c.source_group='GROUP_1'
or (c.source_group='GROUP_2' and c.admission_status <> 'DOCUMENTED_PROHIBITION');
revoke all on airlinerra_game.airport_player_game_roster_v1 from public,anon,authenticated;
do $$
begin
if (select count(*) from airlinerra_game.airport_player_game_roster_v1)<>4257
 then raise exception 'UNEXPECTED_PLAYABLE_AIRPORT_ROSTER_COUNT'; end if;
if (select count(*) from airlinerra_game.airport_player_game_roster_v1 where source_group='GROUP_2')<>1116
 then raise exception 'GROUP2_GAME_ROSTER_NOT_1116'; end if;
if exists (select 1 from airlinerra_game.airport_player_game_roster_v1 where airport_key in('OURAIRPORTS:29484','OURAIRPORTS:4436'))
 then raise exception 'EXCLUDED_MILITARY_AIRPORT_PRESENT'; end if;
end $$;