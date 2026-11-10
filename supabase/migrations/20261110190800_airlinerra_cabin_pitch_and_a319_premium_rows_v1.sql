-- Cabin design-only extra row pitch in centimetres. Never change installed layout.
-- Additional legroom is a proposed uniform increment to each selected seat's
-- nominal row pitch; 0 cm preserves existing saved designs.
ALTER TABLE airlinerra_game.aircraft_cabin_drafts_v1
 ADD COLUMN IF NOT EXISTS extra_legroom_cm numeric(4,1) NOT NULL DEFAULT 0
 CHECK (extra_legroom_cm >= 0 AND extra_legroom_cm <= 20);
-- Game's A319-100 premium class should be 3+3 at the same column count
-- as Economy, while seat choice/pitch uses additional length.
-- Operator cabin evidence is illustrative, not a certification assertion.
UPDATE airlinerra_game.cabin_model_row_geometry_v1 g
 SET premium_columns=ARRAY[3,3]::smallint[],
     source_url='https://seatinside.com/aircraft/airbus-a319-100',
     updated_at=now()
 FROM airlinerra.aircraft_catalog_configuration_inventory c
 WHERE c.configuration_id=g.configuration_id
   AND c.model_name='A319-100' AND c.manufacturer_name='Airbus'
   AND c.use_type IN ('passenger','combi')
   AND g.manually_verified=false;
