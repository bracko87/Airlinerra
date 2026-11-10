-- Airlinerra cabin planning foundation, owner-scoped through protected fleet API.
-- Dimensions/costs are deliberately labelled GAME ESTIMATES, NOT aircraft design approval.
CREATE TABLE airlinerra_game.cabin_seat_types_v1 (
 seat_code text PRIMARY KEY CHECK(seat_code~'^[a-z][a-z0-9_]{2,39}$'),
 cabin_class text NOT NULL CHECK(cabin_class IN ('economy','premium','business','first')),
 label text NOT NULL,
 seat_pitch_inches numeric(5,1) NOT NULL CHECK(seat_pitch_inches BETWEEN 25 AND 100),
 seat_width_inches numeric(5,1) NOT NULL CHECK(seat_width_inches BETWEEN 15 AND 40),
 equivalent_economy_units numeric(6,2) NOT NULL CHECK(equivalent_economy_units BETWEEN 0.9 AND 8),
 indicative_install_usd integer NOT NULL CHECK(indicative_install_usd>=0),
 evidence_status text NOT NULL DEFAULT 'game_balance_estimate'
 CHECK(evidence_status='game_balance_estimate')
);
INSERT INTO airlinerra_game.cabin_seat_types_v1
(seat_code,cabin_class,label,seat_pitch_inches,seat_width_inches,equivalent_economy_units,indicative_install_usd)
VALUES
 ('eco_standard','economy','Standard economy',30,17.5,1,450),
 ('eco_extra','economy','Extra legroom economy',34,18,1.15,700),
 ('eco_comfort','economy','Comfort economy',36,18.5,1.25,950),
 ('premium_standard','premium','Premium economy',38,19.5,1.4,1700),
 ('premium_recliner','premium','Premium recliner',42,20,1.6,2600),
 ('business_standard','business','Business recliner',44,20.5,1.9,4400),
 ('business_flat','business','Lie-flat business',74,21,3.3,10000),
 ('business_suite','business','Business suite',79,22,3.9,15000),
 ('first_standard','first','First-class recliner',60,23,3,9000),
 ('first_suite','first','First-class suite',82,25,5.2,26000),
 ('first_private','first','Private first-class suite',88,28,6.3,38000);

-- Each catalog configuration gets a standard customer-ready layout:
-- all economy standard for passenger/combi, none for cargo.
-- The combi's existing passenger reference is respected, NOT the full-passenger max.
CREATE TABLE airlinerra_game.cabin_model_standard_v1 (
 configuration_id bigint PRIMARY KEY REFERENCES airlinerra.aircraft_configurations(id),
 use_type text NOT NULL CHECK(use_type IN ('passenger','cargo','combi')),
 reference_seat_units numeric(9,2) NOT NULL CHECK(reference_seat_units>=0),
 standard_economy_seats integer NOT NULL CHECK(standard_economy_seats>=0),
 layout_evidence text NOT NULL DEFAULT 'airlinerra_game_reference_capacity'
);
INSERT INTO airlinerra_game.cabin_model_standard_v1
 (configuration_id,use_type,reference_seat_units,standard_economy_seats)
SELECT configuration_id,use_type,
 CASE WHEN use_type='cargo' THEN 0 ELSE reference_passenger_capacity END,
 CASE WHEN use_type='cargo' THEN 0 ELSE reference_passenger_capacity END
FROM airlinerra.aircraft_catalog_configuration_inventory
ON CONFLICT(configuration_id) DO NOTHING;

CREATE TABLE airlinerra_game.aircraft_installed_cabins_v1(
 aircraft_inventory_id uuid PRIMARY KEY
  REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE CASCADE,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 installed_economy integer NOT NULL DEFAULT 0 CHECK(installed_economy>=0),
 installed_premium integer NOT NULL DEFAULT 0 CHECK(installed_premium>=0),
 installed_business integer NOT NULL DEFAULT 0 CHECK(installed_business>=0),
 installed_first integer NOT NULL DEFAULT 0 CHECK(installed_first>=0),
 installed_source text NOT NULL DEFAULT 'catalog_standard_game_layout'
 CHECK(installed_source IN ('catalog_standard_game_layout','verified_game_refit')),
 updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO airlinerra_game.aircraft_installed_cabins_v1
 (aircraft_inventory_id,airline_id,configuration_id,installed_economy)
SELECT i.id,i.airline_id,i.configuration_id,m.standard_economy_seats
FROM airlinerra_game.airline_aircraft_inventory i
JOIN airlinerra_game.cabin_model_standard_v1 m ON m.configuration_id=i.configuration_id
ON CONFLICT (aircraft_inventory_id) DO NOTHING;

CREATE OR REPLACE FUNCTION airlinerra_game.initial_installed_cabin_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'pg_catalog' AS $f$
DECLARE reference_count int;
BEGIN
 SELECT standard_economy_seats INTO reference_count
 FROM airlinerra_game.cabin_model_standard_v1 WHERE configuration_id=NEW.configuration_id;
 IF reference_count IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='CABIN_STANDARD_CONFIGURATION_MISSING';
 END IF;
 INSERT INTO airlinerra_game.aircraft_installed_cabins_v1
  (aircraft_inventory_id,airline_id,configuration_id,installed_economy)
 VALUES(NEW.id,NEW.airline_id,NEW.configuration_id,reference_count);
 RETURN NEW;
END;$f$;
DROP TRIGGER IF EXISTS create_initial_cabin_on_airframe_v1
 ON airlinerra_game.airline_aircraft_inventory;
CREATE TRIGGER create_initial_cabin_on_airframe_v1
 AFTER INSERT ON airlinerra_game.airline_aircraft_inventory
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.initial_installed_cabin_v1();

-- Pure owner-protected drafts. They are NEVER installed directly on saving.
CREATE TABLE airlinerra_game.aircraft_cabin_drafts_v1(
 aircraft_inventory_id uuid PRIMARY KEY
  REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE CASCADE,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 economy_seats integer NOT NULL CHECK(economy_seats BETWEEN 0 AND 850),
 premium_seats integer NOT NULL CHECK(premium_seats BETWEEN 0 AND 850),
 business_seats integer NOT NULL CHECK(business_seats BETWEEN 0 AND 850),
 first_seats integer NOT NULL CHECK(first_seats BETWEEN 0 AND 850),
 economy_type text NOT NULL REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 premium_type text NOT NULL REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 business_type text NOT NULL REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 first_type text NOT NULL REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 planning_status text NOT NULL DEFAULT 'draft' CHECK(planning_status='draft'),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(economy_seats+premium_seats+business_seats+first_seats BETWEEN 1 AND 850)
);
-- Future refit request: accepted draft, selected MRO, 24/48 h projected downtime;
-- NO aircraft position, live seat plan, flight availability or funds changed.
CREATE TABLE airlinerra_game.aircraft_cabin_refit_plans_v1(
 plan_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL,
 provider_key text NOT NULL,
 indicative_downtime_hours smallint NOT NULL CHECK(indicative_downtime_hours IN(24,48)),
 planning_status text NOT NULL DEFAULT 'draft' CHECK(planning_status='draft'),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(world_id,airport_key,provider_key)
  REFERENCES airlinerra_game.maintenance_facility_locations_v1(world_id,airport_key,provider_key)
);
CREATE INDEX aircraft_cabin_refits_airline_idx ON
 airlinerra_game.aircraft_cabin_refit_plans_v1(airline_id,aircraft_inventory_id);

ALTER TABLE airlinerra_game.cabin_seat_types_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.cabin_model_standard_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_installed_cabins_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_cabin_drafts_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_cabin_refit_plans_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON
 airlinerra_game.cabin_seat_types_v1,airlinerra_game.cabin_model_standard_v1,
 airlinerra_game.aircraft_installed_cabins_v1,airlinerra_game.aircraft_cabin_drafts_v1,
 airlinerra_game.aircraft_cabin_refit_plans_v1
 FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION airlinerra_game.initial_installed_cabin_v1()
 FROM PUBLIC,anon,authenticated;
