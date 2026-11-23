-- Allow a transferred aircraft to retain explicit last-installed cabin provenance.
-- Previously only catalog default and verified refit were permitted.
ALTER TABLE airlinerra_game.aircraft_installed_cabins_v1
 DROP CONSTRAINT aircraft_installed_cabins_v1_installed_source_check;
ALTER TABLE airlinerra_game.aircraft_installed_cabins_v1
 ADD CONSTRAINT aircraft_installed_cabins_v1_installed_source_check
 CHECK (installed_source IN (
  'catalog_standard_game_layout',
  'verified_game_refit',
  'used_aircraft_previous_owner_layout'
 ));
COMMENT ON COLUMN airlinerra_game.aircraft_installed_cabins_v1.installed_source IS
 'Origin of the currently installed cabin. An awarded used aircraft inherits its previous installed layout; not reset by acquisition.';
