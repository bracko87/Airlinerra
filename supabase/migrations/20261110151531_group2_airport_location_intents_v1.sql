-- Group 2 location CHOICES for existing airlines. Not operational HQ, hub or station.
-- Existing airline home-airport FK, approved roster and flight engines remain untouched.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_sections1_8_combined_catalog_v1)<>4259
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'GROUP2_PLANNED_LOCATIONS_PREFLIGHT_FAILED';END IF;
END $$;

CREATE TABLE airlinerra_game.airport_group2_location_intents_v1 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 intent_type text NOT NULL CHECK(intent_type IN ('future_hq','hub','station')),
 intent_status text NOT NULL DEFAULT 'planned_only' CHECK(intent_status='planned_only'),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(airline_id,airport_key),
 FOREIGN KEY(world_id,airline_id) REFERENCES airlinerra_game.airlines(world_id,id) ON DELETE CASCADE,
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key)
);
CREATE UNIQUE INDEX airport_group2_one_future_hq_per_airline_v1
 ON airlinerra_game.airport_group2_location_intents_v1(airline_id)
 WHERE intent_type='future_hq';
CREATE INDEX airport_group2_location_intents_airline_v1
 ON airlinerra_game.airport_group2_location_intents_v1(world_id,airline_id);
ALTER TABLE airlinerra_game.airport_group2_location_intents_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_location_intents_v1 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.validate_group2_location_intent_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_sections1_8_combined_members_v1 m
 WHERE m.world_id=NEW.world_id AND m.airport_key=NEW.airport_key
 AND m.source_group='GROUP_2' AND m.commercial_access_scope='GROUP2_PREPARED_NOT_ADMITTED')
 THEN RAISE EXCEPTION 'Only prepared Group 2 airports can be planned here' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airlines a WHERE a.id=NEW.airline_id
   AND a.world_id=NEW.world_id AND a.home_airport_key=NEW.airport_key)
 THEN RAISE EXCEPTION 'Current headquarters is not a planned additional location' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_offices o WHERE o.airline_id=NEW.airline_id
   AND o.world_id=NEW.world_id AND o.airport_key=NEW.airport_key)
 THEN RAISE EXCEPTION 'Existing office is not a Group 2 planned location' USING ERRCODE='23514';END IF;
 NEW.updated_at=now();RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.validate_group2_location_intent_v1() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER validate_group2_location_intent_v1
 BEFORE INSERT OR UPDATE ON airlinerra_game.airport_group2_location_intents_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.validate_group2_location_intent_v1();

CREATE VIEW airlinerra_game.airport_group2_location_choice_status_v1
 WITH (security_invoker=true) AS
SELECT (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)::integer AS eligible_prepared_airports,
 (SELECT count(*) FROM airlinerra_game.airport_group2_location_intents_v1)::integer AS saved_intents,
 (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)::integer AS original_approved_airports,
 (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)::integer AS group2_flights_enabled,
 false AS activates_headquarters,
 false AS activates_offices,
 false AS authorizes_flights;
REVOKE ALL ON airlinerra_game.airport_group2_location_choice_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT eligible_prepared_airports FROM airlinerra_game.airport_group2_location_choice_status_v1)<>1118
 OR (SELECT original_approved_airports FROM airlinerra_game.airport_group2_location_choice_status_v1)<>3141
 OR (SELECT group2_flights_enabled FROM airlinerra_game.airport_group2_location_choice_status_v1)<>0
 THEN RAISE EXCEPTION 'GROUP2_PLANNED_LOCATIONS_POSTCHECK_FAILED';END IF;
END $$;