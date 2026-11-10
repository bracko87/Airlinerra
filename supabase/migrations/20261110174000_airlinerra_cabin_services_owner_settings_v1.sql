-- Airline-owned cabin service design state. Planning only, no flight or money effects.
BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.airline_cabin_service_settings_v1 (
 airline_id uuid PRIMARY KEY REFERENCES airlinerra_game.airlines(id) ON DELETE CASCADE,
 world_id smallint NOT NULL DEFAULT 1 CHECK (world_id=1),
 state jsonb NOT NULL CHECK (jsonb_typeof(state)='object' AND pg_column_size(state)<=16384),
 version integer NOT NULL DEFAULT 1 CHECK (version>0),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE airlinerra_game.airline_cabin_service_settings_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airline_cabin_service_settings_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.airline_cabin_service_settings_v1 IS
 'Owner-scoped cabin service planning settings; only private verified owner API may read or write. No flight activation or ledger effects.';
COMMIT;
