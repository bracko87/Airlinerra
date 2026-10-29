-- Airlinerra airport-office persistence foundation (NOT activated or deployed).
-- Private schema: verified owner/backend only. No public Data API access.
-- HQ stays on airlines.home_airport_key. This table stores ADDITIONAL offices only.
CREATE UNIQUE INDEX IF NOT EXISTS airlines_world_id_id_office_fk
 ON airlinerra_game.airlines (world_id,id);

CREATE TABLE IF NOT EXISTS airlinerra_game.airport_offices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL,
 airline_id uuid NOT NULL,
 airport_key text NOT NULL,
 office_type text NOT NULL CHECK (office_type IN ('hub','station')),
 office_status text NOT NULL DEFAULT 'draft' CHECK (office_status = 'draft'),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT airport_offices_airline_world_fk FOREIGN KEY (world_id,airline_id)
   REFERENCES airlinerra_game.airlines(world_id,id) ON DELETE CASCADE,
 CONSTRAINT airport_offices_approved_world_fk FOREIGN KEY (world_id,airport_key)
   REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key),
 CONSTRAINT airport_offices_unique_airline_airport UNIQUE (airline_id,airport_key)
);
CREATE INDEX IF NOT EXISTS airport_offices_airport_world_idx
 ON airlinerra_game.airport_offices(world_id,airport_key);

-- Defense in depth for privileged server writes: never record an extra office at HQ.
CREATE OR REPLACE FUNCTION airlinerra_game.validate_additional_airport_office()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
 IF EXISTS (
   SELECT 1 FROM airlinerra_game.airlines a
   WHERE a.id=NEW.airline_id AND a.world_id=NEW.world_id
     AND a.home_airport_key=NEW.airport_key
 ) THEN
   RAISE EXCEPTION 'Registered headquarters is not an additional office'
     USING ERRCODE='23514';
 END IF;
 IF TG_OP='UPDATE' THEN NEW.updated_at=now(); END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.validate_additional_airport_office() FROM PUBLIC;
DROP TRIGGER IF EXISTS airport_offices_validate_hq ON airlinerra_game.airport_offices;
CREATE TRIGGER airport_offices_validate_hq
 BEFORE INSERT OR UPDATE ON airlinerra_game.airport_offices
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.validate_additional_airport_office();

-- Untrusted browser roles cannot inspect or modify private airline office records.
ALTER TABLE airlinerra_game.airport_offices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.airport_offices FROM PUBLIC, anon, authenticated;
-- Deliberately no RLS policy and no REST/RPC exposure.
-- Future activation will require a separate guarded migration, real assigned staff,
-- a server-verified pricing quote and an idempotent ledger transaction.
