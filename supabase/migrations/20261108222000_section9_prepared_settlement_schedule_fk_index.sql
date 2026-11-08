-- Cover settlement-preflight's schedule FK for future safe schedule lookups
-- and protect airline schedule deletes/updates from full settlement scans.
CREATE INDEX IF NOT EXISTS section9_prepared_occurrence_schedule_idx
 ON airlinerra_game.section9_prepared_occurrence_settlements_v1
 (schedule_id,local_departure_date);
