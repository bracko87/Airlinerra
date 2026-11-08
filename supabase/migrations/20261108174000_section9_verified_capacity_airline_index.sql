-- Section 9: index the secondary airline FK used by trusted capacity proofs.
CREATE INDEX IF NOT EXISTS section9_verified_schedule_capacity_airline_idx
 ON airlinerra_game.section9_verified_schedule_capacity_v1 (airline_id,schedule_id);
