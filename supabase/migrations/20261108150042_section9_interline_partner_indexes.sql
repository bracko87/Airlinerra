-- Section 9 partnership-lookup indexes: supports directional agreement checks
-- and foreign-key maintenance without scanning the future agreement catalog.
CREATE INDEX IF NOT EXISTS section9_interline_left_active_idx
 ON airlinerra_game.section9_interline_agreements_v1
 (left_airline_id,world_id,agreement_status,valid_from);
CREATE INDEX IF NOT EXISTS section9_interline_right_active_idx
 ON airlinerra_game.section9_interline_agreements_v1
 (right_airline_id,world_id,agreement_status,valid_from);
