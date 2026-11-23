-- Index private delivery anchors by World1 approved airport, covering the
-- composite airport foreign key and avoiding large reverse scans.
CREATE INDEX IF NOT EXISTS section9_delivery_position_world_airport_fk_idx
 ON airlinerra_game.section9_aircraft_delivery_position_v1(
  world_id,airport_key);
