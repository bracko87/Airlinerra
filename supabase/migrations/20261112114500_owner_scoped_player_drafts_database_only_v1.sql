-- Separate inert player workspace drafts and account display settings.
-- Neither table data nor API responses grant slots, licences, routes, jobs,
-- flight movements, purchases, staff employment or ledger transactions.
BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.airline_player_drafts_v1(
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE CASCADE,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 kind text NOT NULL CHECK(kind IN ('preferences','workplan')),
 state jsonb NOT NULL CHECK(jsonb_typeof(state)='object' AND pg_column_size(state)<=32768),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(airline_id,kind)
);
ALTER TABLE airlinerra_game.airline_player_drafts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airline_player_drafts_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.airline_player_drafts_v1 IS
 'Non-operational, owner-scoped game planning documents and UI preferences. Written only by a verified-owner API. This is not an aircraft, crew, flight, airport-office or finance record.';
COMMIT;
