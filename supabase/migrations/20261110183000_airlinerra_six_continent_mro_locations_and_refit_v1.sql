-- Source-linked global maintenance directory: six inhabited regions, >=5 per region.
-- A provider-supported LOCATION is not automatically aircraft/type/check APPROVED.
ALTER TABLE airlinerra_game.maintenance_facility_locations_v1
 ADD COLUMN IF NOT EXISTS continent text,
 ADD COLUMN IF NOT EXISTS game_cost_multiplier numeric(5,2) DEFAULT 1.00
  CHECK(game_cost_multiplier BETWEEN 0.60 AND 1.50);
UPDATE airlinerra_game.maintenance_facility_locations_v1 f SET continent=CASE
 WHEN a.airport_code IN('EDDH','LTFM') THEN 'Europe'
 ELSE 'Asia' END
FROM airlinerra_game.approved_game_airports a
WHERE a.world_id=f.world_id AND a.airport_key=f.airport_key AND f.continent IS NULL;
ALTER TABLE airlinerra_game.maintenance_facility_locations_v1
 ADD CONSTRAINT maintenance_facility_continent_v1_check
 CHECK(continent IN ('Europe','Asia','Africa','North America','South America','Oceania'));
WITH source(continent,airport_code,provider_key,provider_name,research_status,source_url,source_note) AS(
 VALUES ('Europe','LBSF','lht-sofia','Lufthansa Technik Sofia','provider_supported','https://www.lufthansa-technik.com/en/lufthansa-technik-sofia','A320 and 737 base checks, painting and cabin modifications; type-specific game approvals are separate'),
('Europe','LHBP','lht-budapest','Lufthansa Technik Budapest','provider_supported','https://www.lufthansa-technik.com/en/exclusive-base-maintenance-support-for-eurowings-airbus-a320-family-fleet-41e0cf9b97f013e7','Published A320-family base maintenance partnership'),
('Europe','LMML','lht-malta','Lufthansa Technik Malta','provider_supported','https://www.lufthansa-technik.com/de/locations','Provider lists Malta base maintenance location; exact model and checks need research'),
('Europe','EINN','aag','Atlantic Aviation Group','provider_supported','https://www.atlanticaviation.ie/our-services/base-maintenance/','Shannon C/D checks and A320 family, 737, 757, 767, cabin modification services'),
('Europe','EDDH','lht-hamburg','Lufthansa Technik Hamburg','provider_supported','https://www.lufthansa-technik.com/de/locations','Hamburg real MRO location; specific A319 heavy checks must not be inferred'),
('Asia','WSSS','siaec','SIA Engineering Company','provider_supported','https://www.siaec.com.sg/our_services/base_maintenance/airframe_maintenance.html','Existing provider and type-specific game capabilities'),
('Asia','VHHH','haeco-hkg','HAECO Hong Kong','provider_supported','https://www.haeco.com/en/services/base-maintenance','Hong Kong base maintenance and cabin reconfiguration'),
('Asia','ZSAM','haeco-xmn','HAECO Xiamen','provider_supported','https://www.haeco.com/en/services/base-maintenance','HAECO Xiamen airframe base and cabin reconfiguration'),
('Asia','ZUUU','haeco-chengdu','HAECO Chengdu','research_pending','https://www.haeco.com/en/services/base-maintenance','HAECO lists Chengdu; airport-location match and available type/check scope require review'),
('Asia','ZHEC','steng','ST Engineering Hubei','provider_supported','https://www.stengg.com/en/aerospace/global-network/','Ezhou airframe MRO reported, per-model scope pending'),
('Africa','HAAB','ethiopian-mro','Ethiopian MRO','provider_supported','https://mro.ethiopianairlines.com/service/base-maintenance','Addis base maintenance and cabin modifications for published types'),
('Africa','HECA','egyptair-me','Egyptair Maintenance & Engineering','provider_supported','https://www.egyptair.com/en/about-egyptair/Pages/egyptair-group.aspx','Cairo MRO base; specific current platform scope pending'),
('Africa','HKJK','kenya-mro','Kenya Airways Engineering & Maintenance','provider_supported','https://www.afraa.org/members-mros/','AFRAA member MRO in Nairobi; aircraft type-specific approval pending'),
('Africa','FAOR','saat','South African Airways Technical','provider_supported','https://www.flysaa.com/about-us/leading-carrier/saa-technical/maintenance','Johannesburg base C/D checks includes A319 and A320 families'),
('Africa','GMMN','ati','Aerotechnic Industries','provider_supported','https://serige.setec.fr/projets/mro-ati-nouasseur/','Casablanca Mohammed V new MRO project with base maintenance hangar; operating status and model scope pending'),
('North America','KOKC','aar-okc','AAR Oklahoma City','provider_supported','https://www.aarcorp.com/en/repair/airframe-mro/','Airframe maintenance provider at Oklahoma City; type scope pending'),
('North America','KIND','aar-ind','AAR Indianapolis','provider_supported','https://www.aarcorp.com/en/repair/airframe-mro/','Airframe MRO at Indianapolis'),
('North America','KMIA','aar-mia','AAR Miami','provider_supported','https://www.aarcorp.com/en/repair/airframe-mro/','Airframe MRO at Miami'),
('North America','KRFD','aar-rfd','AAR Rockford','provider_supported','https://www.aarcorp.com/en/repair/airframe-mro/','Airframe MRO at Rockford'),
('North America','KGSO','aar-gso','AAR Greensboro','provider_supported','https://www.aarcorp.com/en/repair/airframe-mro/','Airframe MRO at Greensboro'),
('North America','KPNS','steng-pensacola','ST Engineering Pensacola','provider_supported','https://www.stengg.com/en/aerospace/global-network/','ST Engineering airframe MRO at Pensacola'),
('South America','SCEL','latam-scl','LATAM MRO Santiago','provider_supported','https://www.sec.gov/Archives/edgar/data/1047716/000104771626000046/ltm-20251231.htm','A320-family heavy maintenance and cabin work supported by 2025 filing'),
('South America','SBGR','latam-gru','LATAM MRO Guarulhos','provider_supported','https://www.sec.gov/Archives/edgar/data/1047716/000104771626000046/ltm-20251231.htm','Mid-term A320-family and 777 C checks reported'),
('South America','SPIM','latam-lim','LATAM MRO Lima','provider_supported','https://www.sec.gov/Archives/edgar/data/1047716/000104771626000046/ltm-20251231.htm','Lima A320-family mid-term checks reported, separate from deep C/D approval'),
('South America','SKRG','avianca-mro','Avianca MRO Rionegro','provider_supported','https://static.avianca.com/media/ikaphyv4/1-iso-14001-agil.pdf','Avianca-certified maintenance repair and overhaul hangar at Rionegro'),
('South America','SEQM','avianca-quito','Avianca Quito Maintenance','provider_supported','https://static.avianca.com/media/yeebkhm4/anexo-a-certificate-sa-cer659886-certificate-code-co-sa-cer659886-agil.pdf','Avianca maintenance at Quito hangar; heavy-check approval pending'),
('South America','SAEZ','aerolineas-eze','Aerolineas Argentinas Technical','research_pending','https://www.aerolineas.com.ar/','Candidate Ezeiza technical base; provider and model scope awaiting primary-source confirmation'),
('Oceania','NZAA','airnz-akl','Air New Zealand Engineering Auckland','provider_supported','https://www.airnewzealand.eu/engineering-and-maintenance-airframe','Auckland MRO all letter checks and cabin refurbishments, A320 range'),
('Oceania','NZCH','airnz-chc','Air New Zealand Engineering Christchurch','provider_supported','https://www.airnewzealand.eu/engineering-and-maintenance-airframe','Christchurch MRO site with all letter checks, A320 range'),
('Oceania','NZNS','airnz-nsn','Air New Zealand Engineering Nelson','provider_supported','https://www.airnewzealand.eu/engineering-and-maintenance-airframe','Nelson maintenance facility; heavy aircraft scope may differ, don''t infer'),
('Oceania','YPAD','nje-adelaide','National Jet Express Aircraft Services Adelaide','provider_supported','https://nje.aero/mro/','Adelaide base maintenance DHC8, E190, BAe146'),
('Oceania','YBBN','execujet-bne','ExecuJet MRO Brisbane','provider_supported','https://www.execujet-mro.com/locations/brisbane/','Brisbane scheduled base maintenance, business jet scope'),
('Oceania','YMML','aviat-mel','Aviat Global Melbourne','provider_supported','https://www.aviat.com.au/facilities/','Melbourne Tullamarine scheduled line maintenance; C/D scope pending')
)
INSERT INTO airlinerra_game.maintenance_facility_locations_v1
(world_id,airport_key,provider_key,provider_name,research_status,source_url,source_note,reviewed_on,continent,game_cost_multiplier)
SELECT a.world_id,a.airport_key,s.provider_key,s.provider_name,s.research_status,s.source_url,s.source_note,
 DATE '2026-11-10',s.continent,
 CASE s.continent WHEN 'Europe' THEN 1.00 WHEN 'Asia' THEN 0.95
  WHEN 'Africa' THEN 0.90 WHEN 'North America' THEN 1.10
  WHEN 'South America' THEN 0.95 ELSE 1.10 END
FROM source s JOIN airlinerra_game.approved_game_airports a ON a.airport_code=s.airport_code AND a.world_id=1
ON CONFLICT(world_id,airport_key,provider_key) DO UPDATE SET
 provider_name=EXCLUDED.provider_name,research_status=EXCLUDED.research_status,
 source_url=EXCLUDED.source_url,source_note=EXCLUDED.source_note,
 reviewed_on=EXCLUDED.reviewed_on,continent=EXCLUDED.continent,
 game_cost_multiplier=EXCLUDED.game_cost_multiplier;
-- Existing providers remain. Data shows source-backed providers, never silently
-- deems all continent entries capable of C/D for every model.
-- Game-approved check matches below require provider published specific A320 family.
WITH approval(airport_code,provider_key,check_code,source_url,scope_basis) AS(
 VALUES
 ('LBSF','lht-sofia','a','https://www.lufthansa-technik.com/en/lufthansa-technik-sofia','published_a320_family_base'),
 ('LBSF','lht-sofia','b','https://www.lufthansa-technik.com/en/lufthansa-technik-sofia','published_a320_family_base'),
 ('LBSF','lht-sofia','c','https://www.lufthansa-technik.com/en/lufthansa-technik-sofia','published_a320_family_base'),
 ('LBSF','lht-sofia','d','https://www.lufthansa-technik.com/en/lufthansa-technik-sofia','published_a320_family_base'),
 ('LHBP','lht-budapest','c','https://www.lufthansa-technik.com/en/exclusive-base-maintenance-support-for-eurowings-airbus-a320-family-fleet-41e0cf9b97f013e7','published_a320_family_base_checks'),
 ('EINN','aag','a','https://www.atlanticaviation.ie/our-services/base-maintenance/','published_a320_family_maintenance'),
 ('EINN','aag','c','https://www.atlanticaviation.ie/our-services/base-maintenance/','published_a320_family_c_check'),
 ('EINN','aag','d','https://www.atlanticaviation.ie/our-services/base-maintenance/','published_a320_family_d_check'),
 ('FAOR','saat','c','https://www.flysaa.com/about-us/leading-carrier/saa-technical/maintenance','published_a319_family_c_check'),
 ('FAOR','saat','d','https://www.flysaa.com/about-us/leading-carrier/saa-technical/maintenance','published_a319_family_d_check'),
 ('SCEL','latam-scl','c','https://www.sec.gov/Archives/edgar/data/1047716/000104771626000046/ltm-20251231.htm','published_a320_family_c_check'),
 ('NZAA','airnz-akl','a','https://www.airnewzealand.eu/engineering-and-maintenance-airframe','published_a320_family_letter_checks'),
 ('NZAA','airnz-akl','c','https://www.airnewzealand.eu/engineering-and-maintenance-airframe','published_a320_family_letter_checks'),
 ('NZCH','airnz-chc','c','https://www.airnewzealand.eu/engineering-and-maintenance-airframe','published_a320_family_letter_checks')
)
INSERT INTO airlinerra_game.maintenance_airport_capabilities_v1
(world_id,airport_key,provider_key,configuration_id,check_code,approval_status,scope_basis,source_url,reviewed_on)
SELECT a.world_id,a.airport_key,b.provider_key,c.configuration_id,b.check_code,'game_approved',
 b.scope_basis,b.source_url,DATE '2026-11-10'
FROM approval b
JOIN airlinerra_game.approved_game_airports a ON a.world_id=1 AND a.airport_code=b.airport_code
JOIN airlinerra.aircraft_catalog_configuration_inventory c
 ON c.family_name='A320' AND c.manufacturer_name='Airbus'
 AND c.use_type IN ('passenger','combi')
ON CONFLICT(world_id,airport_key,configuration_id,check_code) DO NOTHING;

-- Refit facilities are separately matched against type, NEVER assumed from generic hangars.
CREATE TABLE airlinerra_game.cabin_refit_facility_types_v1 (
 world_id smallint NOT NULL CHECK(world_id=1),airport_key text NOT NULL,
 provider_key text NOT NULL,configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 approval_basis text NOT NULL,source_url text NOT NULL CHECK(source_url LIKE 'https://%'),
 planning_status text NOT NULL DEFAULT 'game_planning_approved' CHECK(planning_status='game_planning_approved'),
 PRIMARY KEY(world_id,airport_key,provider_key,configuration_id),
 FOREIGN KEY(world_id,airport_key,provider_key)
 REFERENCES airlinerra_game.maintenance_facility_locations_v1(world_id,airport_key,provider_key)
);
WITH refit(airport_code,provider_key,source_url) AS(VALUES
 ('LBSF','lht-sofia','https://www.lufthansa-technik.com/en/lufthansa-technik-sofia'),
 ('EINN','aag','https://www.atlanticaviation.ie/our-services/base-maintenance/'),
 ('VHHH','haeco-hkg','https://www.haeco.com/en/services/base-maintenance'),
 ('NZAA','airnz-akl','https://www.airnewzealand.eu/engineering-and-maintenance-airframe'),
 ('NZCH','airnz-chc','https://www.airnewzealand.eu/engineering-and-maintenance-airframe')
)
INSERT INTO airlinerra_game.cabin_refit_facility_types_v1
(world_id,airport_key,provider_key,configuration_id,approval_basis,source_url)
SELECT a.world_id,a.airport_key,r.provider_key,c.configuration_id,
 'publisher_type_family_and_interior_modifications_game_scope',r.source_url
FROM refit r
JOIN airlinerra_game.approved_game_airports a ON a.world_id=1 AND a.airport_code=r.airport_code
JOIN airlinerra.aircraft_catalog_configuration_inventory c ON
 c.manufacturer_name='Airbus' AND c.family_name='A320'
ON CONFLICT DO NOTHING;
ALTER TABLE airlinerra_game.cabin_refit_facility_types_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.cabin_refit_facility_types_v1 FROM PUBLIC,anon,authenticated;
