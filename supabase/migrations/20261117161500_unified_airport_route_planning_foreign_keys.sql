-- Planning-only integration. Retain the operational approval firewall.
-- Both groups have shared catalogue membership; no slots, bookings or flights are authorized here.
begin;
alter table airlinerra_game.airline_route_planning_drafts_v1
 drop constraint route_planning_origin_fk,
 drop constraint route_planning_destination_fk;
alter table airlinerra_game.airline_route_planning_drafts_v1
 add constraint route_planning_origin_fk
 foreign key (world_id,origin_airport_key)
 references airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key),
 add constraint route_planning_destination_fk
 foreign key (world_id,destination_airport_key)
 references airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key);
comment on table airlinerra_game.airline_route_planning_drafts_v1 is
 'Owner-scoped planning ONLY using unified airport catalogue for both groups. Flight activation, real slot reservations, aircraft movements and finance require separate verified operational authorization.';
commit;