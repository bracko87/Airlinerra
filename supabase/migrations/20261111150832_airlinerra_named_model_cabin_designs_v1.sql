-- Named cabin configurations are company designs for a model/catalog configuration.
-- They are NOT an installed cabin, an aircraft-level draft, an MRO booking or a charge.
CREATE TABLE IF NOT EXISTS airlinerra_game.airline_cabin_model_designs_v1 (
 design_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE CASCADE,
 configuration_id bigint NOT NULL
   REFERENCES airlinerra_game.cabin_model_standard_v1(configuration_id),
 name text NOT NULL CHECK (
   char_length(name) BETWEEN 2 AND 80 AND name=btrim(name)
   AND name !~ '[[:cntrl:]]'
 ),
 economy_seats integer NOT NULL CHECK (economy_seats BETWEEN 0 AND 850),
 premium_seats integer NOT NULL CHECK (premium_seats BETWEEN 0 AND 850),
 business_seats integer NOT NULL CHECK (business_seats BETWEEN 0 AND 850),
 first_seats integer NOT NULL CHECK (first_seats BETWEEN 0 AND 850),
 economy_type text NOT NULL REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 premium_type text NOT NULL REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 business_type text NOT NULL REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 first_type text NOT NULL REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 extra_legroom_cm numeric(4,1) NOT NULL DEFAULT 0
   CHECK (extra_legroom_cm BETWEEN 0 AND 20),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT airline_model_design_unique_name
  UNIQUE (airline_id,configuration_id,name),
 CONSTRAINT airline_model_design_seat_count
  CHECK (economy_seats+premium_seats+business_seats+first_seats BETWEEN 1 AND 850)
);
CREATE INDEX IF NOT EXISTS cabin_model_designs_airline_lookup_idx
 ON airlinerra_game.airline_cabin_model_designs_v1(airline_id,configuration_id,updated_at DESC);
ALTER TABLE airlinerra_game.airline_cabin_model_designs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.airline_cabin_model_designs_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.airline_cabin_model_designs_v1 IS
 'Private airline-owned named aircraft-model design templates, not installed aircraft cabins or scheduled refits.';
