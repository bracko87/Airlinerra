-- Cover aircraft qualification FK in crew roster for mass aircraft
-- configuration maintenance and high-volume per-airline staffing lookups.
CREATE INDEX IF NOT EXISTS section9_crew_qualification_fk_idx
 ON airlinerra_game.section9_airline_crew_roster_v1
 (qualified_configuration_id,airline_id);
