-- Flight cabin geometry and 40 seat choices. All dimensions and prices
-- are Airlinerra GAME ESTIMATES even when the product reference is real.
-- Seat/exit certification and aircraft-specific layout approval are not implied.
ALTER TABLE airlinerra_game.cabin_seat_types_v1
 ADD COLUMN IF NOT EXISTS real_product_reference text,
 ADD COLUMN IF NOT EXISTS source_url text,
 ADD COLUMN IF NOT EXISTS geometry_basis text NOT NULL DEFAULT 'game_estimate_not_certified'
  CHECK (geometry_basis='game_estimate_not_certified');
INSERT INTO airlinerra_game.cabin_seat_types_v1
(seat_code,cabin_class,label,seat_pitch_inches,seat_width_inches,
 equivalent_economy_units,indicative_install_usd,real_product_reference,source_url)
VALUES
('eco_recaro_r1','economy','RECARO R1 · slimline',29,17.3,0.97,550,'RECARO R1','https://www.recaro-as.com/en/aircraft-seats/economy-class.html'),
('eco_recaro_r2','economy','RECARO R2 · comfort',30,17.8,1.02,680,'RECARO R2','https://www.recaro-as.com/en/aircraft-seats/economy-class.html'),
('eco_recaro_r3','economy','RECARO R3 · long-range',32,18.5,1.13,900,'RECARO R3','https://www.recaro-as.com/en/aircraft-seats/economy-class/r3.html'),
('eco_safran_z85','economy','Safran Z85 · dense',29,17.2,0.96,540,'Safran Z85','https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats'),
('eco_safran_z200','economy','Safran Z200 · classic',31,17.8,1.06,770,'Safran Z200','https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats'),
('eco_safran_z300','economy','Safran Z300 · long-haul',32,18,1.12,1050,'Safran Z300','https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats'),
('eco_safran_z400','economy','Safran Z400 · comfort',34,18.5,1.2,1250,'Safran Z400','https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats'),
('premium_recaro_pl3530','premium','RECARO PL3530',40,19.5,1.48,2600,'RECARO PL3530','https://www.recaro-as.com/en/aircraft-seats/economy-class/pl3530.html'),
('premium_recaro_r4','premium','RECARO R4',41,20,1.57,3300,'RECARO R4','https://www.recaro-as.com/en/press/press-releases/details/recaro-launches-the-next-generation-of-premium-class-seating-r4.html'),
('premium_safran_z535i','premium','Safran Z535i',40,20,1.52,3100,'Safran Z535i','https://www.safran-group.com/products-services/premium-economy-class-seat-z535i'),
('premium_safran_airgo','premium','Safran AIRGO FX Premium',42,20,1.72,3900,'AIRGO FX PREMIUM','https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats'),
('premium_collins_miq','premium','Collins MiQ · premium',40,20,1.56,3400,'Collins MiQ','https://www.rtx.com/collinsaerospace/what-we-do/industries/commercial-aviation/cabin/seating/business-class/miq'),
('premium_zim_zp610','premium','ZIM ZP610 · shell',41,19,1.61,4100,'ZIM ZP610','https://www.zim.aero/en-us/products/zim-zp600-series'),
('premium_zim_zp450','premium','ZIM ZP450 · premium',38,19,1.44,2800,'ZIM ZP450','https://www.zim.aero/en-us/product-range/premium'),
('premium_geven_comoda','premium','Geven Comoda AQ',44,20.5,1.87,4500,'Geven Comoda AQ','https://www.geven.com/products-hx'),
('business_recaro_r5','business','RECARO R5 · recliner',44,21,1.94,5300,'RECARO R5','https://www.recaro-as.com/en/press/press-releases/details/recaro-aircraft-seating-debuts-new-seat-naming-concept-at-aix-2024.html'),
('business_recaro_r7','business','RECARO R7 · lie-flat',79,21.5,3.56,16000,'RECARO R7','https://www.recaro-as.com/en/press/press-releases/details/recaro-aircraft-seating-debuts-new-seat-naming-concept-at-aix-2024.html'),
('business_safran_z600','business','Safran Z600 · regional',45,20.5,1.99,4900,'Safran Z600','https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats'),
('business_safran_fusio','business','Safran FUSIO · suite',80,22,3.83,19500,'Safran FUSIO','https://www.safran-group.com/products-services/business-class-seat-fusio'),
('business_collins_miq','business','Collins MiQ · business',43,20.5,1.93,5500,'Collins MiQ','https://www.rtx.com/collinsaerospace/what-we-do/industries/commercial-aviation/cabin/seating/business-class/miq'),
('business_zim_luxury','business','ZIMluxury · lie-flat',77,22,3.62,17400,'ZIMluxury','https://www.aeroexpo.online/prod/zim-flugsitz-gmbh-171913.html'),
('business_collins_diamond','business','Collins Diamond · flat',76,21,3.42,15100,'Collins Diamond family','https://www.rtx.com/collinsaerospace/what-we-do/industries/commercial-aviation/cabin/seating/business-class/maya'),
('first_emirates_a380','first','Emirates A380 private suite',84,26,5.65,42000,'Emirates A380 Private Suite','https://www.emirates.com/media-centre/elevating-luxury-emirates-unveils-more-enhancements-to-first-class/'),
('first_emirates_777','first','Emirates 777 Game Changer',94,30,7.2,75000,'Emirates 777 Game Changer Suite','https://www.emirates.com/us/english/experience/our-fleet/gamechanger/'),
('first_singapore_a380','first','Singapore A380 Suite',90,28,6.4,80000,'Singapore Airlines A380 Suites','https://www.singaporeair.com/en_UK/us/flying-withus/cabins/suites/'),
('first_airfrance_premiere','first','Air France La Première',94,30,7.7,100000,'Air France La Première','https://corporate.airfrance.com/en/news/air-france-unveils-its-new-la-premiere-experience-highest-expression-travel'),
('first_ana_suite','first','ANA THE Suite',85,28,6.15,65000,'ANA THE Suite','https://www.ana.co.jp/en/de/travel-information/cabin/b777-300er-first-class/'),
('first_ana_square','first','ANA First Square',83,27,5.9,58000,'ANA First Square','https://www.ana.co.jp/en/jp/guide/flight_service_info/int-service/f/seat/'),
('first_lufthansa_allegris','first','Lufthansa Allegris First',92,30,7.1,92000,'Lufthansa Allegris First Class Suite','https://www.lufthansa.com/de/en/discover-lufthansa/allegris')
ON CONFLICT(seat_code) DO UPDATE SET
 label=EXCLUDED.label,seat_pitch_inches=EXCLUDED.seat_pitch_inches,
 seat_width_inches=EXCLUDED.seat_width_inches,
 equivalent_economy_units=EXCLUDED.equivalent_economy_units,
 indicative_install_usd=EXCLUDED.indicative_install_usd,
 real_product_reference=EXCLUDED.real_product_reference,
 source_url=EXCLUDED.source_url;
-- Existing game-style seats are retained to avoid invalidating saved drafts.
-- Ten options/class = current 3/2/3/3 + new 7/8/7/7.
CREATE TABLE airlinerra_game.cabin_model_row_geometry_v1(
 configuration_id bigint PRIMARY KEY REFERENCES airlinerra.aircraft_configurations(id),
 economy_columns smallint[] NOT NULL,
 premium_columns smallint[] NOT NULL,
 business_columns smallint[] NOT NULL,
 first_columns smallint[] NOT NULL,
 review_status text NOT NULL CHECK(review_status IN
  ('manufacturer_supported_pattern','operator_supported_pattern','game_estimate_needs_review','cargo_not_applicable')),
 source_url text,
 layout_note text NOT NULL,
 manually_verified boolean NOT NULL DEFAULT false,
 reviewed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK (coalesce(array_length(economy_columns,1),0)<=3),
 CHECK (coalesce(array_length(premium_columns,1),0)<=3),
 CHECK (coalesce(array_length(business_columns,1),0)<=3),
 CHECK (coalesce(array_length(first_columns,1),0)<=3)
);
WITH base AS(
 SELECT c.configuration_id,c.manufacturer_name,c.family_name,c.model_name,c.use_type,c.reference_passenger_capacity,
 CASE
 WHEN c.use_type='cargo' THEN ARRAY[]::smallint[]
 WHEN c.family_name IN ('A380','747','777') THEN ARRAY[3,4,3]::smallint[]
 WHEN c.family_name IN ('787','A350','Il-96') THEN ARRAY[3,3,3]::smallint[]
 WHEN c.family_name IN ('A300','A310','A330','A340') THEN ARRAY[2,4,2]::smallint[]
 WHEN c.family_name='767' THEN ARRAY[2,3,2]::smallint[]
 WHEN c.family_name IN ('L-1011 TriStar','DC-10','MD-11') THEN ARRAY[2,5,2]::smallint[]
 WHEN c.family_name IN ('A220','717','C909','Superjet 100','SSJ100','Fokker 100','Fokker 70','F28 Fellowship','MD-80','MD-90','DC-9','C919') AND c.family_name<>'C919' THEN ARRAY[2,3]::smallint[]
 WHEN c.family_name IN ('ERJ 135/140/145','Jetstream 31/32','EMB 110','EMB 120','Dornier 228') THEN ARRAY[1,2]::smallint[]
 WHEN c.family_name IN ('DHC-6 Twin Otter','1900','Y-12') THEN ARRAY[1,1]::smallint[]
 WHEN c.family_name IN ('A320','737','757','727','BAe 146','Avro RJ','C919','Il-62','Tu-154','Yak-42') THEN ARRAY[3,3]::smallint[]
 WHEN c.family_name IN ('ATR 42','ATR 72','CRJ','E-Jets','E-Jets E2','Dash 7','Dash 8','Dornier 328','D328eco','Fokker 50','F27','An-24','An-26','An-72/74','Jetstream 41') THEN ARRAY[2,2]::smallint[]
 WHEN c.reference_passenger_capacity<=24 THEN ARRAY[1,1]::smallint[]
 WHEN c.reference_passenger_capacity<=85 THEN ARRAY[2,2]::smallint[]
 WHEN c.reference_passenger_capacity<=155 THEN ARRAY[2,3]::smallint[]
 ELSE ARRAY[3,3]::smallint[]
 END eco
 FROM airlinerra.aircraft_catalog_configuration_inventory c
), plans AS (
 SELECT b.*,
 CASE
 WHEN b.use_type='cargo' THEN ARRAY[]::smallint[]
 WHEN b.eco IN (ARRAY[3,4,3]::smallint[],ARRAY[3,3,3]::smallint[],ARRAY[2,5,2]::smallint[]) THEN ARRAY[2,3,2]::smallint[]
 WHEN b.eco IN (ARRAY[2,4,2]::smallint[],ARRAY[2,3,2]::smallint[]) THEN ARRAY[2,2,2]::smallint[]
 WHEN b.eco=ARRAY[3,3]::smallint[] OR b.eco=ARRAY[2,3]::smallint[] THEN ARRAY[2,2]::smallint[]
 ELSE ARRAY[1,1]::smallint[] END prem,
 CASE
 WHEN b.use_type='cargo' THEN ARRAY[]::smallint[]
 WHEN cardinality(b.eco)=3 THEN ARRAY[1,2,1]::smallint[]
 WHEN b.eco=ARRAY[3,3]::smallint[] THEN ARRAY[2,2]::smallint[]
 ELSE ARRAY[1,1]::smallint[] END bus,
 CASE
 WHEN b.use_type='cargo' THEN ARRAY[]::smallint[]
 WHEN cardinality(b.eco)=3 THEN ARRAY[1,2,1]::smallint[]
 ELSE ARRAY[1,1]::smallint[] END fst,
 CASE WHEN b.use_type='cargo' THEN 'cargo_not_applicable'
 WHEN b.family_name='A220' THEN 'manufacturer_supported_pattern'
 WHEN b.family_name IN ('E-Jets','E-Jets E2') THEN 'manufacturer_supported_pattern'
 WHEN b.family_name='A320' THEN 'manufacturer_supported_pattern'
 WHEN b.family_name IN ('ATR 42','ATR 72') THEN 'operator_supported_pattern'
 WHEN b.family_name IN ('A330','A350','777','787') THEN 'operator_supported_pattern'
 ELSE 'game_estimate_needs_review' END status,
 CASE WHEN b.family_name='A220' THEN 'https://www.airbus.com/en/products-services/commercial-aircraft/passenger-aircraft/a220-family'
 WHEN b.family_name IN ('E-Jets','E-Jets E2') THEN 'https://www.embraer.com/e-jets-e2/en/'
 WHEN b.family_name='A320' THEN 'https://www.lufthansa.com/de/en/319'
 WHEN b.family_name IN ('ATR 42','ATR 72') THEN 'https://www.atr-aircraft.com/'
 WHEN b.family_name='A330' THEN 'https://seatinside.com/aircraft/airbus-a330-300'
 WHEN b.family_name='A350' THEN 'https://www.seatsfrog.com/aircraft/a350-900'
 WHEN b.family_name='777' THEN 'https://seatinside.com/aircraft/boeing-777-300er'
 WHEN b.family_name='787' THEN 'https://www.boeing.com/commercial/787'
 ELSE null END source_url
 FROM base b
)
INSERT INTO airlinerra_game.cabin_model_row_geometry_v1
 (configuration_id,economy_columns,premium_columns,business_columns,first_columns,
  review_status,source_url,layout_note)
SELECT configuration_id,eco,prem,bus,fst,status,source_url,
 CASE WHEN use_type='cargo' THEN 'No passenger seating in cargo variant'
 ELSE 'Typical FAMILY seat-abreast pattern; optional class patterns estimated for game, not certified floorplan. Manually review model/variant, exits and facilities before operating.' END
FROM plans
ON CONFLICT(configuration_id) DO NOTHING;
ALTER TABLE airlinerra_game.cabin_model_row_geometry_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.cabin_model_row_geometry_v1
 FROM PUBLIC,anon,authenticated;
