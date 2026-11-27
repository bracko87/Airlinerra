-- Read-only preflight. No schema changes, approvals, or release switches.
-- Run against the current game database as a privileged read-only reviewer.
BEGIN TRANSACTION READ ONLY;
WITH wanted(airport_key,code,runway_id,runway_length,runway_width,landing,departure) AS (
 VALUES ('OURAIRPORTS:26900','ASP','233325',2438.1,45.1,812,129.92),
        ('OURAIRPORTS:4073','LDE','235930',3000.1,45.1,1000,160.00),
        ('OURAIRPORTS:3856','ROW','244235',3050.4,30.5,1875,337.50)
), inspected AS (
 SELECT x.*,u.operationally_authorized,u.dispatch_eligible_by_airport_admission,
 p.latitude_deg,p.longitude_deg,p.timezone_iana,
 w.source_runway_id,w.runway_designator,w.length_m,w.width_m,w.surface_reported,w.verification,w.operational_status,
 t.landing_base_for_reference_aircraft_usd AS live_landing,
 round(t.landing_base_for_reference_aircraft_usd*t.departure_movement_fraction,2) AS live_departure,
 t.evidence_class,cap.remote_stands,cap.remote_per_direction_10m,f.fuel_available,
 o.default_game_open_24_7,o.curfew_identified,o.operating_hours_basis,o.noise_limit_basis
 FROM wanted x
 LEFT JOIN airlinerra_game.airport_unified_operations_v1 u ON u.world_id=1 AND u.airport_key=x.airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles p ON p.world_id=1 AND p.airport_key=x.airport_key
 LEFT JOIN LATERAL (SELECT z.* FROM airlinerra_game.airport_runway_inventory z WHERE z.world_id=1 AND z.airport_key=x.airport_key ORDER BY z.length_m DESC NULLS LAST,z.source_runway_id LIMIT 1) w ON true
 LEFT JOIN airlinerra_game.section8_airport_operating_tariffs_v1 t ON t.world_id=1 AND t.airport_key=x.airport_key
 LEFT JOIN airlinerra_game.section6_airport_slot_capacity_v1 cap ON cap.world_id=1 AND cap.airport_key=x.airport_key
 LEFT JOIN airlinerra_game.airport_facilities f ON f.world_id=1 AND f.airport_key=x.airport_key
 LEFT JOIN airlinerra_game.section5_airport_operating_policy_v1 o ON o.world_id=1 AND o.airport_key=x.airport_key
)
SELECT airport_key,code,runway_designator,length_m,width_m,surface_reported,verification,operational_status,
 timezone_iana,live_landing,live_departure,remote_stands,remote_per_direction_10m,fuel_available,
 default_game_open_24_7,curfew_identified,operating_hours_basis,noise_limit_basis,
 CASE WHEN operationally_authorized IS TRUE AND dispatch_eligible_by_airport_admission IS TRUE
 AND latitude_deg IS NOT NULL AND longitude_deg IS NOT NULL AND timezone_iana IN(SELECT name FROM pg_timezone_names)
 AND source_runway_id=runway_id AND length_m=runway_length AND width_m=runway_width AND upper(surface_reported)='ASP'
 AND live_landing=landing AND live_departure=departure AND evidence_class='GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'
 AND remote_stands>0 AND remote_per_direction_10m>0 AND fuel_available IS TRUE
 AND default_game_open_24_7 IS NOT NULL AND curfew_identified IS NOT NULL AND noise_limit_basis IS NOT NULL
 THEN 'GAME_SOURCE_MATCHED_REVIEW_REQUIRED' ELSE 'BLOCKED_SOURCE_CHANGED_OR_MISSING' END AS preflight,
 CASE code WHEN 'ASP' THEN 'Retain existing game runway and operator access coordination'
 WHEN 'LDE' THEN 'Directional landing distance discrepancy requires review'
 WHEN 'ROW' THEN 'Runway identity discrepancy requires review' END AS outstanding_review,
 false AS approval_granted
 FROM inspected ORDER BY code;
ROLLBACK;
