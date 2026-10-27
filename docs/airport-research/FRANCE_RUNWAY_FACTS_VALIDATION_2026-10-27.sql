-- Airlinerra private runway facts: reproducible regression assertions.
-- Run in project hwllkabgzaynalahvkpz using a privileged SQL editor.
-- Every column must be TRUE; no test modifies data.
WITH v AS (SELECT * FROM airlinerra.runway_research_facts),
d AS (
 SELECT r.source_gps_code icao,s.runway_pair,x.*
 FROM airlinerra.runway_direction_facts x
 JOIN airlinerra.runway_source_versions s ON s.id=x.source_version_id
 JOIN airlinerra.airport_registry r ON r.airport_key=s.airport_key
),
p AS (
 SELECT r.source_gps_code icao,s.runway_pair,x.*
 FROM airlinerra.runway_permission_facts x
 JOIN airlinerra.runway_source_versions s ON s.id=x.source_version_id
 JOIN airlinerra.airport_registry r ON r.airport_key=s.airport_key
)
SELECT
 (SELECT count(distinct airport_key)=14 FROM v) covers_14_airports,
 (SELECT count(*)=18 FROM v) has_18_runway_physical_versions,
 (SELECT physical_length_m=1721 FROM v WHERE icao='LFQE') lfqe_length,
 (SELECT max(physical_length_m)=2991 FROM v WHERE icao='LFPB') le_bourget_longest,
 (SELECT count(*)=3 FROM v WHERE icao='LFPB') le_bourget_three_pairs,
 (SELECT count(*)=6 FROM p WHERE icao='LFPB'
   AND operation_type IN ('SCHEDULED_PASSENGER','CHARTER_PASSENGER')
   AND permission_state='PROHIBITED') le_bourget_passenger_ban,
 (SELECT count(*)=1 FROM d WHERE icao='LFPB' AND direction_code='09'
   AND landing_status='PROHIBITED') le_bourget_rw09_landing_ban,
 (SELECT count(*)=1 FROM d WHERE icao='LFPB' AND direction_code='27'
   AND takeoff_status='PROHIBITED') le_bourget_rw27_takeoff_ban,
 (SELECT count(*)=2 FROM d WHERE icao='LFRO'
   AND lda_m IN (1376,1463) AND tora_m IS NULL) lannion_lda_only,
 (SELECT count(*)=1 FROM d WHERE icao='LFPM' AND direction_code='28'
   AND toda_m=2650 AND clearway_m=678 AND lda_m=1890) melun_clearway,
 (SELECT count(*)=1 FROM v WHERE icao='LFMO'
   AND normalized_surface='MACADAM_UNRESOLVED'
   AND material_verification='UNVERIFIED') orange_surface_hold,
 (SELECT count(*)=0 FROM v WHERE icao='LFPC') creil_excluded,
 (SELECT count(*)=0 FROM v WHERE game_admission_status<>'NOT_APPROVED') no_game_admission,
 NOT has_schema_privilege('anon','airlinerra','USAGE')
 AND NOT has_schema_privilege('authenticated','airlinerra','USAGE') private_schema,
 NOT has_table_privilege('anon','airlinerra.runway_research_facts','SELECT')
 AND NOT has_table_privilege('authenticated','airlinerra.runway_research_facts','SELECT') private_view,
 (SELECT count(*)=3140 FROM airlinerra_game.approved_game_airports WHERE world_id=1) approved_world1_unchanged;

-- Extra consistency checks: each must produce zero.
SELECT count(*) AS mismatched_evidence_airport
FROM airlinerra.runway_source_versions sv
JOIN airlinerra.airport_evidence e ON e.id=sv.evidence_id
WHERE e.airport_key<>sv.airport_key;
SELECT count(*) AS illegal_exact_material
FROM airlinerra.runway_physical_facts
WHERE material_verification='VERIFIED'
 AND normalized_surface NOT IN ('ASPHALT','CONCRETE','MIXED_VERIFIED');
SELECT count(*) AS lda_greater_than_runway
FROM airlinerra.runway_direction_facts d
JOIN airlinerra.runway_physical_facts p USING(source_version_id)
WHERE d.lda_m>p.physical_length_m;
