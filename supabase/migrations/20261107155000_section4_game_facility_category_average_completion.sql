-- SECTION 4: World 1 GAME-DATA closure by user-approved category averages.
-- This is NOT primary-source facility verification or legal/operational dispatch permission.
-- Retain original airport-specific values, source URLs and owner cargo-category decisions.
BEGIN;

ALTER TABLE airlinerra_game.airport_facilities
 DROP CONSTRAINT airport_facilities_facility_status_check;
ALTER TABLE airlinerra_game.airport_facilities
 ADD CONSTRAINT airport_facilities_facility_status_check
 CHECK (facility_status IN ('pending','research','partially_verified','verified','game_complete_estimated'));
ALTER TABLE airlinerra_game.airport_data_master_categories
 DROP CONSTRAINT airport_data_master_categories_status_check;
ALTER TABLE airlinerra_game.airport_data_master_categories
 ADD CONSTRAINT airport_data_master_categories_status_check
 CHECK (status IN ('research_pending','partially_populated','awaiting_verification','verified_complete','game_complete_estimated'));
ALTER TABLE airlinerra_game.airport_data_work_queue
 DROP CONSTRAINT airport_data_work_queue_research_status_check;
ALTER TABLE airlinerra_game.airport_data_work_queue
 ADD CONSTRAINT airport_data_work_queue_research_status_check
 CHECK (research_status IN ('pending','researching','review_required','complete','not_applicable','game_complete_estimated'));

CREATE TABLE IF NOT EXISTS airlinerra_game.section4_tier_facility_game_defaults_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK (world_id=1),
 airport_category text NOT NULL,
 donor_airports integer NOT NULL CHECK (donor_airports>0),
 category_airports integer NOT NULL CHECK (category_airports>=donor_airports),
 avg_passenger_gates integer NOT NULL CHECK (avg_passenger_gates>=0),
 avg_contact_stands integer NOT NULL CHECK (avg_contact_stands>=0),
 avg_remote_stands integer NOT NULL CHECK (avg_remote_stands>=0),
 avg_cargo_stands integer NOT NULL CHECK (avg_cargo_stands>=0),
 avg_total_stands integer NOT NULL CHECK (avg_total_stands>=0),
 model_version text NOT NULL DEFAULT 'section4_category_average_game_fallback_20261107_v1',
 approved_for_game_on date NOT NULL DEFAULT DATE '2026-11-07',
 notes text NOT NULL DEFAULT 'Mean of existing same-category GAME stand/gate figures, rounded to whole positions; not certified physical airport facilities.',
 PRIMARY KEY(world_id,airport_category),
 CHECK (avg_total_stands=avg_contact_stands+avg_remote_stands+avg_cargo_stands)
);
ALTER TABLE airlinerra_game.section4_tier_facility_game_defaults_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section4_tier_facility_game_defaults_v1 FROM PUBLIC,anon,authenticated;

INSERT INTO airlinerra_game.section4_tier_facility_game_defaults_v1 (
 world_id,airport_category,donor_airports,category_airports,
 avg_passenger_gates,avg_contact_stands,avg_remote_stands,avg_cargo_stands,avg_total_stands
)
SELECT f.world_id,p.provisional_category,
 count(f.passenger_gate_count)::integer,count(*)::integer,
 round(avg(f.passenger_gate_count))::integer,
 round(avg(f.contact_stand_count))::integer,
 round(avg(f.remote_stand_count))::integer,
 round(avg(f.cargo_stand_count))::integer,
 (round(avg(f.contact_stand_count))+
  round(avg(f.remote_stand_count))+
  round(avg(f.cargo_stand_count)))::integer
FROM airlinerra_game.airport_facilities f
JOIN airlinerra_game.airport_reference_profiles p USING(world_id,airport_key)
WHERE f.world_id=1 AND p.provisional_category IS NOT NULL
GROUP BY f.world_id,p.provisional_category
ON CONFLICT (world_id,airport_category) DO NOTHING;

DO $validate_tiers$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.section4_tier_facility_game_defaults_v1 WHERE world_id=1)<>6
 THEN RAISE EXCEPTION 'Section4: expected six airport categories with same-tier donor averages'; END IF;
 IF (SELECT sum(category_airports) FROM airlinerra_game.section4_tier_facility_game_defaults_v1 WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'Section4: category coverage mismatch'; END IF;
END $validate_tiers$;

-- Snapshot each original airport row before estimated defaults; retain for traceability.
CREATE TABLE IF NOT EXISTS airlinerra_game.section4_facility_game_completion_audit_v1 (
 world_id smallint NOT NULL,
 airport_key text NOT NULL,
 airport_category text NOT NULL,
 model_version text NOT NULL,
 baseline_before jsonb NOT NULL,
 missing_before jsonb NOT NULL,
 modeled_game_only boolean NOT NULL DEFAULT true CHECK (modeled_game_only=true),
 primary_source_verified boolean NOT NULL DEFAULT false CHECK (primary_source_verified=false),
 note text NOT NULL DEFAULT 'Owner-approved same-tier facility estimates; source evidence remains unverified. Operational aviation dispatch and slots are excluded.',
 completed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.airport_facilities(world_id,airport_key)
);
ALTER TABLE airlinerra_game.section4_facility_game_completion_audit_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section4_facility_game_completion_audit_v1 FROM PUBLIC,anon,authenticated;

INSERT INTO airlinerra_game.section4_facility_game_completion_audit_v1(
 world_id,airport_key,airport_category,model_version,baseline_before,missing_before
)
SELECT f.world_id,f.airport_key,p.provisional_category,
 'section4_category_average_game_fallback_20261107_v1',to_jsonb(f),
 jsonb_build_object(
  'passenger_gate_count', f.passenger_gate_count IS NULL,
  'aircraft_stand_count', f.aircraft_stand_count IS NULL,
  'contact_stand_count',f.contact_stand_count IS NULL,
  'remote_stand_count',f.remote_stand_count IS NULL,
  'cargo_stand_count',f.cargo_stand_count IS NULL,
  'jet_bridge_count',f.jet_bridge_count IS NULL,
  'apron_area_m2',f.apron_area_m2 IS NULL,
  'parking_position_count',f.parking_position_count IS NULL,
  'hangar_capacity_count',f.hangar_capacity_count IS NULL,
  'customs_available',f.customs_available IS NULL,
  'international_operations_allowed',f.international_operations_allowed IS NULL,
  'scheduled_passenger_service',f.scheduled_passenger_service IS NULL,
  'cargo_handling_available',f.cargo_handling_available IS NULL,
  'ground_handling_available',f.ground_handling_available IS NULL,
  'fuel_available',f.fuel_available IS NULL,
  'arff_category',f.arff_category IS NULL,
  'cargo_priority',f.cargo_priority IS NULL
 )
FROM airlinerra_game.airport_facilities f
JOIN airlinerra_game.airport_reference_profiles p USING(world_id,airport_key)
WHERE f.world_id=1 AND f.facility_status IN ('pending','research')
ON CONFLICT(world_id,airport_key) DO NOTHING;

-- Populate NULLS ONLY: preserve owner-approved and individually sourced airport values.
-- Entirely missing real-world data gets labelled GAME estimates, not regulatory certification.
UPDATE airlinerra_game.airport_facilities f
SET passenger_gate_count=coalesce(f.passenger_gate_count,d.avg_passenger_gates),
 contact_stand_count=coalesce(f.contact_stand_count,d.avg_contact_stands),
 remote_stand_count=coalesce(f.remote_stand_count,d.avg_remote_stands),
 cargo_stand_count=coalesce(f.cargo_stand_count,d.avg_cargo_stands),
 aircraft_stand_count=coalesce(f.aircraft_stand_count,
  coalesce(f.contact_stand_count,d.avg_contact_stands)+
  coalesce(f.remote_stand_count,d.avg_remote_stands)+
  coalesce(f.cargo_stand_count,d.avg_cargo_stands)),
 jet_bridge_count=coalesce(f.jet_bridge_count,
  least(coalesce(f.contact_stand_count,d.avg_contact_stands),
    round(coalesce(f.contact_stand_count,d.avg_contact_stands)*
      CASE p.provisional_category WHEN 'Local' THEN 0.00 WHEN 'Regional' THEN 0.15
       WHEN 'Medium' THEN 0.35 WHEN 'Large' THEN 0.60
       WHEN 'Major Hub' THEN 0.75 WHEN 'Mega Hub' THEN 0.85 ELSE 0.0 END)::integer)),
 apron_area_m2=coalesce(f.apron_area_m2,
  coalesce(f.aircraft_stand_count,d.avg_total_stands)*
  CASE p.provisional_category WHEN 'Local' THEN 5000 WHEN 'Regional' THEN 6000
   WHEN 'Medium' THEN 7000 WHEN 'Large' THEN 8000
   WHEN 'Major Hub' THEN 10000 WHEN 'Mega Hub' THEN 12000 ELSE 5000 END),
 parking_position_count=coalesce(f.parking_position_count,
  coalesce(f.aircraft_stand_count,d.avg_total_stands)),
 hangar_capacity_count=coalesce(f.hangar_capacity_count,
  CASE p.provisional_category WHEN 'Local' THEN 0 WHEN 'Regional' THEN 1
   WHEN 'Medium' THEN greatest(1,round(coalesce(f.aircraft_stand_count,d.avg_total_stands)/20.0)::integer)
   WHEN 'Large' THEN greatest(1,round(coalesce(f.aircraft_stand_count,d.avg_total_stands)/25.0)::integer)
   WHEN 'Major Hub' THEN greatest(2,round(coalesce(f.aircraft_stand_count,d.avg_total_stands)/25.0)::integer)
   WHEN 'Mega Hub' THEN greatest(4,round(coalesce(f.aircraft_stand_count,d.avg_total_stands)/20.0)::integer)
   ELSE 0 END),
 customs_available=coalesce(f.customs_available,p.provisional_category IN ('Medium','Large','Major Hub','Mega Hub')),
 international_operations_allowed=coalesce(f.international_operations_allowed,
  p.provisional_category IN ('Medium','Large','Major Hub','Mega Hub')),
 scheduled_passenger_service=coalesce(f.scheduled_passenger_service,true),
 cargo_handling_available=coalesce(f.cargo_handling_available,
  coalesce(f.cargo_stand_count,d.avg_cargo_stands)>0 OR coalesce(f.cargo_priority,false)),
 ground_handling_available=coalesce(f.ground_handling_available,true),
 fuel_available=coalesce(f.fuel_available,true),
 arff_category=coalesce(f.arff_category,
  'GAME_ESTIMATE_'||CASE p.provisional_category
   WHEN 'Local' THEN '3' WHEN 'Regional' THEN '4' WHEN 'Medium' THEN '6'
   WHEN 'Large' THEN '7' WHEN 'Major Hub' THEN '9' WHEN 'Mega Hub' THEN '10'
   ELSE 'UNVERIFIED' END),
 cargo_priority=coalesce(f.cargo_priority,
  coalesce(f.cargo_dominance_status,'')='owner_selected_game_cargo_majority'),
 facility_status='game_complete_estimated'
FROM airlinerra_game.airport_reference_profiles p,
 airlinerra_game.section4_tier_facility_game_defaults_v1 d
WHERE f.world_id=1 AND f.facility_status IN ('pending','research')
 AND p.world_id=f.world_id AND p.airport_key=f.airport_key
 AND d.world_id=f.world_id AND d.airport_category=p.provisional_category;

-- Section 4 GAME release can be marked complete while source validation is tracked in Section 10.
UPDATE airlinerra_game.airport_data_master_categories
SET status='game_complete_estimated',
 updated_on=DATE '2026-11-07',
 scope_summary=scope_summary||
 ' | GAME DATA COMPLETE 2026-11-07: all 3,141 airports have facility model values. Missing gates/stands use averages from same-tier peers; other blank facility fields use explicit category-based game defaults. Estimated values are NOT real-airport facts or verified aviation permissions. Independent field evidence and live slots/operations remain separate Sections 10/6.'
WHERE world_id=1 AND category_number=4 AND status<>'game_complete_estimated';

UPDATE airlinerra_game.airport_data_work_queue
SET research_status='game_complete_estimated',
 research_notes=concat_ws(E'\n',nullif(research_notes,''),
 '2026-11-07 GAME COMPLETION: tier-average facilities / labeled game defaults recorded; physical source verification is still outstanding and belongs to Section 10. Do not treat estimates as certified permissions.'),
 last_updated=now()
WHERE world_id=1 AND data_area='facilities_gates' AND research_status IN ('pending','researching','review_required');

CREATE OR REPLACE VIEW airlinerra_game.section4_game_facilities_completion_v1
WITH (security_invoker=true) AS
SELECT p.provisional_category AS airport_category,count(*)::integer airports,
 count(*) FILTER(WHERE f.facility_status='game_complete_estimated')::integer game_complete,
 count(*) FILTER(WHERE f.passenger_gate_count IS NULL OR f.contact_stand_count IS NULL
  OR f.remote_stand_count IS NULL OR f.cargo_stand_count IS NULL
  OR f.aircraft_stand_count IS NULL OR f.jet_bridge_count IS NULL
  OR f.apron_area_m2 IS NULL OR f.parking_position_count IS NULL
  OR f.hangar_capacity_count IS NULL OR f.customs_available IS NULL
  OR f.international_operations_allowed IS NULL OR f.scheduled_passenger_service IS NULL
  OR f.cargo_handling_available IS NULL OR f.ground_handling_available IS NULL
  OR f.fuel_available IS NULL OR f.arff_category IS NULL OR f.cargo_priority IS NULL)::integer missing_required_game_fields,
 count(*) FILTER(WHERE f.aircraft_stand_count<>
   f.contact_stand_count+f.remote_stand_count+f.cargo_stand_count)::integer stand_split_errors,
 count(*) FILTER(WHERE f.source_url IS NOT NULL)::integer existing_facility_source_urls,
 count(*) FILTER(WHERE f.facility_status='verified')::integer independently_verified
FROM airlinerra_game.airport_reference_profiles p
JOIN airlinerra_game.airport_facilities f USING(world_id,airport_key)
WHERE p.world_id=1
GROUP BY p.provisional_category;
REVOKE ALL ON airlinerra_game.section4_game_facilities_completion_v1 FROM PUBLIC,anon,authenticated;

DO $verify$
DECLARE n integer; missing integer; inconsistencies integer; rows_done integer;
BEGIN
 SELECT coalesce(sum(airports),0),coalesce(sum(missing_required_game_fields),0),
  coalesce(sum(stand_split_errors),0),coalesce(sum(game_complete),0)
 INTO n,missing,inconsistencies,rows_done
 FROM airlinerra_game.section4_game_facilities_completion_v1;
 IF n<>3141 OR missing<>0 OR inconsistencies<>0 OR rows_done<>3141 THEN
  RAISE EXCEPTION 'Section4 game facility closure FAILED airports %,missing %,split errors %,complete %',
   n,missing,inconsistencies,rows_done; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section4_facility_game_completion_audit_v1 WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'Section4 audit archive incomplete'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_data_work_queue
      WHERE world_id=1 AND data_area='facilities_gates' AND research_status='game_complete_estimated')<>3141
 THEN RAISE EXCEPTION 'Section4 game completion research queue mismatch'; END IF;
 IF (SELECT status FROM airlinerra_game.airport_data_master_categories WHERE category_number=4)<>'game_complete_estimated'
 THEN RAISE EXCEPTION 'Section4 master status not closed'; END IF;
END $verify$;
COMMIT;