-- Owner-requested game-only airport for World 1 testing. Fictional by design.
-- No airport research evidence or public gameplay gate is changed.
insert into airlinerra_game.approved_game_airports
 (world_id,airport_key,approval_reference,airport_name,airport_code,country_iso,municipality)
select 1,r.airport_key,
 'OWNER_REQUESTED_WORLD1_TEST_FICTIONAL_ALEKSANDROVO_20261028',
 r.airport_name,'LYAL',r.country_iso,r.municipality
from airlinerra.airport_registry r
where r.airport_key='FICTIONAL:fictional:RS:LYAL'
 and r.source_type='FICTIONAL'
 and r.runway_screen_status='RUNWAY_QUALIFIED'
 and r.longest_qualifying_runway_m>=1200
 and lower(r.longest_qualifying_surface)='asphalt'
on conflict(world_id,airport_key) do nothing;
