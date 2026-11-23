-- Evidence labels must match the source, not overstate manufacturer verification.
-- Model and airframe-specific diagrams still need manual checking.
UPDATE airlinerra_game.cabin_model_row_geometry_v1 g
 SET review_status='operator_supported_pattern',
  source_url='https://www.lufthansa.com/de/en/319',
  updated_at=now()
 FROM airlinerra.aircraft_catalog_configuration_inventory c
 WHERE c.configuration_id=g.configuration_id AND c.family_name='A320'
 AND c.use_type IN ('passenger','combi')
 AND g.manually_verified=false;

UPDATE airlinerra_game.cabin_model_row_geometry_v1 g
 SET review_status='game_estimate_needs_review',
  source_url=NULL,updated_at=now()
 FROM airlinerra.aircraft_catalog_configuration_inventory c
 WHERE c.configuration_id=g.configuration_id AND c.family_name='E-Jets'
 AND c.use_type IN ('passenger','combi')
 AND g.manually_verified=false;
