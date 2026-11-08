-- Efficient per-aircraft rotation checks and schedule FK maintenance
-- at scale. Non-destructive; no schedule/flight/booking data changes.
CREATE INDEX IF NOT EXISTS section9_schedule_aircraft_rotation_idx
 ON airlinerra_game.airline_flight_schedule_drafts_v1(
 aircraft_inventory_id,airline_id,status,id);
CREATE INDEX IF NOT EXISTS section9_schedule_configuration_ref_idx
 ON airlinerra_game.airline_flight_schedule_drafts_v1(configuration_id);
