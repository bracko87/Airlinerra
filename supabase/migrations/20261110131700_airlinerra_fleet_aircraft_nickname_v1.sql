-- Aircraft names are optional owner-controlled presentation metadata.
ALTER TABLE airlinerra_game.airline_aircraft_inventory
 ADD COLUMN IF NOT EXISTS nickname text;
ALTER TABLE airlinerra_game.airline_aircraft_inventory
 ADD CONSTRAINT airline_aircraft_inventory_nickname_v1_check
 CHECK (nickname IS NULL OR (
  char_length(nickname) BETWEEN 1 AND 40
  AND nickname=btrim(nickname)
  AND nickname !~ '[[:cntrl:]]'
 ));
COMMENT ON COLUMN airlinerra_game.airline_aircraft_inventory.nickname
 IS 'Airline owner editable aircraft nickname; immutable model, registration and configuration are unaffected.';
