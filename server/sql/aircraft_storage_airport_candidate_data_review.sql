-- REVIEW ONLY. Proposed nine-facility game data, not dispatch authorization.
-- Separate observed physical characteristics from balance proposals.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_airport_candidate_data_v1(
 world_id smallint NOT NULL CHECK(world_id=1),airport_key text NOT NULL,
 icao_observed text NOT NULL,airport_name text NOT NULL,country_iso text NOT NULL,
 scope text NOT NULL CHECK(scope IN('existing_commercial','relocation_only')),
 latitude_deg numeric NOT NULL CHECK(latitude_deg BETWEEN -90 AND 90),
 longitude_deg numeric NOT NULL CHECK(longitude_deg BETWEEN -180 AND 180),timezone_iana text NOT NULL,
 physical_runway_m numeric NOT NULL CHECK(physical_runway_m>0),
 physical_width_m numeric CHECK(physical_width_m>0),
 conservative_game_runway_m numeric CHECK(conservative_game_runway_m>0 AND conservative_game_runway_m<=physical_runway_m),
 runway_source text NOT NULL,operator_source text NOT NULL,
 proposed_landing_usd numeric(14,2),proposed_departure_fraction numeric,proposed_handling_fraction numeric,proposed_parking_daily_usd numeric(14,2),proposed_navigation_usd numeric(14,2),
 proposed_monthly_regional_usd numeric(14,2) NOT NULL CHECK(proposed_monthly_regional_usd>0),
 proposed_monthly_narrowbody_usd numeric(14,2) NOT NULL CHECK(proposed_monthly_narrowbody_usd>=proposed_monthly_regional_usd),
 proposed_monthly_widebody_usd numeric(14,2) NOT NULL CHECK(proposed_monthly_widebody_usd>=proposed_monthly_narrowbody_usd),
 restriction_review_note text NOT NULL,
 PRIMARY KEY(world_id,airport_key),UNIQUE(world_id,icao_observed),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key),
 CHECK((scope='existing_commercial' AND num_nonnulls(proposed_landing_usd,proposed_departure_fraction,proposed_handling_fraction,proposed_parking_daily_usd,proposed_navigation_usd)=0)
 OR (scope='relocation_only' AND num_nonnulls(proposed_landing_usd,proposed_departure_fraction,proposed_handling_fraction,proposed_parking_daily_usd,proposed_navigation_usd)=5
 AND proposed_landing_usd>=0 AND proposed_departure_fraction BETWEEN 0 AND 1 AND proposed_handling_fraction BETWEEN 0 AND 1 AND proposed_parking_daily_usd>=0 AND proposed_navigation_usd>=0))
);
ALTER TABLE airlinerra_game.aircraft_storage_airport_candidate_data_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_airport_candidate_data_v1 FROM PUBLIC,anon,authenticated,service_role;
-- Monthly prices are uniform game-balance proposals (not real contracts);
-- existing commercial airports keep their existing movement tariffs.
INSERT INTO airlinerra_game.aircraft_storage_airport_candidate_data_v1 VALUES
(1,'OURAIRPORTS:26900','YBAS','Alice Springs','AU','existing_commercial',-23.806588,133.903427,'Australia/Darwin',2438,45,NULL,'https://www.casa.gov.au/alice-springs-manoeuvring-area-map','https://www.apas.com.au/facility/',NULL,NULL,NULL,NULL,NULL,4000,8000,15000,'Reuse existing commercial runway, noise, curfew, and fee screens.'),
(1,'OURAIRPORTS:4073','LFBT','Tarbes-Lourdes','FR','existing_commercial',43.178699,-0.006439,'Europe/Paris',3000.1,45.1,NULL,'registry runway inventory reviewed 2026-11-26','https://tarmacaerosave.aero/our-sites/',NULL,NULL,NULL,NULL,NULL,4000,8000,15000,'Reuse existing commercial runway, noise, curfew, and fee screens.'),
(1,'OURAIRPORTS:3856','KROW','Roswell','US','existing_commercial',33.301601,-104.530998,'America/Denver',3050.4,30.5,NULL,'registry runway inventory reviewed 2026-11-26','https://www.aersale.com/products-services/airframe-mro/storage',NULL,NULL,NULL,NULL,NULL,4000,8000,15000,'Reuse existing commercial runway, noise, curfew, and fee screens.'),
(1,'OURAIRPORTS:316427','LETL','Teruel','ES','relocation_only',40.410269,-1.217366,'Europe/Madrid',2825,45,2539,'https://www.boe.es/diario_boe/txt.php?id=BOE-A-2019-6524 ; https://aerocartas.com/espana/aeropuertos/letl/aip/','https://tarmacaerosave.aero/our-sites/',1000,0.16,0.20,100,50,4000,8000,15000,'Directional lengths differ; conservative 2539 m proposal. Elevation factor and restrictions need review.'),
(1,'OURAIRPORTS:20594','KMZJ','Pinal Airpark','US','relocation_only',32.510601,-111.328003,'America/Phoenix',2087.6,45.7,NULL,'https://www.globalair.com/airport/apt.runway.aspx?aptcode=mzj','https://www.pinal.gov/1831/Pinal-Airpark',800,0.16,0.20,80,40,4000,8000,15000,'Private access/permission, declared distances and fuel-family evidence pending. Not KAVQ.'),
(1,'OURAIRPORTS:20507','KMHV','Mojave','US','relocation_only',35.056391,-118.145342,'America/Los_Angeles',3810,60.96,NULL,'https://www.faa.gov/space/spaceports_by_state ; registry width reviewed 2026-11-26','https://tour.mojaveairport.com/index.php/point4',1000,0.16,0.20,100,50,4000,8000,15000,'Long runway differs from registry 2148.5 m; verify selected runway and width before profile release.'),
(1,'OURAIRPORTS:21315','KVCV','Victorville','US','relocation_only',34.597500,-117.383003,'America/Los_Angeles',3978,45.72,3978,'https://www.victorvilleca.gov/Government/City-Departments/Airport/For-Pilots','https://www.comav.com/facilities/',1200,0.16,0.20,120,60,4000,8000,15000,'Runway 17/35 declared distances confirmed by city. Review elevation factor, permissions and fuel family.'),
(1,'OURAIRPORTS:2395','EGBP','Cotswold','GB','relocation_only',51.668528,-2.056599,'Europe/London',2009,45,NULL,'https://airportguide.com/airport/info/GBA','https://airsalvage.co.uk/location/',800,0.16,0.20,80,40,4000,8000,15000,'Operator confirms storage/disassembly; directional distances and operating hours pending.'),
(1,'OURAIRPORTS:2409','EGSY','St Athan','GB','relocation_only',51.405229,-3.433254,'Europe/London',1828,45,NULL,'https://airfieldfinder.app/airfield/EGSY?from=EGFE','https://www.ecube.aero/about-us/locations/united-kingdom/',800,0.16,0.20,80,40,4000,8000,15000,'Identity mismatch with registry EGDX; PPR only. Confirm code and conflicting width sources; do not release.');
-- No writes to approval, tariffs, operating profiles, fuel supplier or slot tables.
-- Missing curfew/noise data follows the user's game default only once reviewed;
-- known access restrictions must not be treated as unknown.
DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1)<>9
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 WHERE scope='existing_commercial')<>3
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 WHERE proposed_monthly_regional_usd<>4000 OR proposed_monthly_narrowbody_usd<>8000 OR proposed_monthly_widebody_usd<>15000)
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 WHERE airport_key='OURAIRPORTS:19330')
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 c JOIN airlinerra_game.aircraft_storage_facilities_v1 f USING(world_id,airport_key) WHERE c.scope<>f.admission_scope)
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 c WHERE NOT EXISTS(SELECT 1 FROM pg_timezone_names t WHERE t.name=c.timezone_iana))
 THEN RAISE EXCEPTION 'STORAGE_AIRPORT_CANDIDATE_DATA_INVALID';END IF;
 RAISE NOTICE 'Nine storage airport candidate records validated; no commercial or storage admission changed';
END $verify$;
ROLLBACK;
