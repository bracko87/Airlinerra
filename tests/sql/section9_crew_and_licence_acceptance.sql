-- All examples are rollback-only synthetic inputs. No game staff or
-- legal permissions are fabricated in persistent production data.
BEGIN;
DO $test$
DECLARE a uuid;u uuid;code text;plane uuid;schedule uuid;
 verified_crew uuid;pending_crew uuid;invalid_crew uuid;
 out jsonb;combined jsonb;roster jsonb; denied boolean:=false;
 conf bigint:=3;carrier_country text;valid_country text;
 required_count integer;
BEGIN
 SELECT a.id,a.owner_player_id,a.iata_code,home.country_iso
 INTO a,u,code,carrier_country
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=a.home_airport_key
 WHERE a.world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'No test airline';END IF;
 SELECT crew_required INTO required_count
 FROM airlinerra.aircraft_configurations WHERE id=conf;
 IF required_count IS NOT NULL THEN
  RAISE EXCEPTION 'Expected unknown crew requirement for released fixture';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
 airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,conf,'S9-CREW-ROLLBACK','owned','in_service')
 RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
 airline_id,aircraft_inventory_id,configuration_id,flight_number,
 origin_airport_key,destination_airport_key,
 reference_departure_utc,reference_arrival_utc,
 weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,plane,conf,code||'978',
  'OURAIRPORTS:2214','OURAIRPORTS:2212',
  '2026-11-09T09:00:00Z','2026-11-09T11:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,u)
 RETURNING id INTO schedule;
 INSERT INTO airlinerra_game.section9_airline_crew_roster_v1(
  airline_id,crew_reference,qualified_configuration_id,employment_status,
  employment_proof_ref,employment_reviewed_at)
 VALUES(a,'S9-TEST-PILOT-1',conf,'verified_employed',
  'rollback-verification-source',now()) RETURNING crew_id INTO verified_crew;
 INSERT INTO airlinerra_game.section9_airline_crew_roster_v1(
  airline_id,crew_reference,qualified_configuration_id)
 VALUES(a,'S9-TEST-PILOT-2',conf) RETURNING crew_id INTO pending_crew;

 out:=airlinerra_game.section9_plan_owned_crew_duty_v1(
  u,a,schedule,verified_crew,1,'plan');
 IF out->>'status'<>'planned_not_verified' OR
    out->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION 'Crew draft approval bypassed';END IF;
 out:=airlinerra_game.section9_plan_owned_crew_duty_v1(
  u,a,schedule,pending_crew,1,'plan');
 out:=airlinerra_game.section9_owned_crew_licence_preflight_v1(
  u,a,schedule,'2026-11-09',14);
 IF (out->'crew'->'weeklyEntries'->0->>'proposed')::int<>2
 OR (out->'crew'->'weeklyEntries'->0->>'registeredVerifiedEmployment')::int<>1
 OR out->'crew'->>'catalogCrewRequirementKnown'<>'false'
 OR (out->'crew'->'weeklyEntries'->0->>'missingRegisteredCrew') IS NOT NULL
 OR out->'permissions'->>'trafficRightsOperationallyGranted'<>'false'
 OR out->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION 'Unverified employee counted as ready: %',out;END IF;

 -- Even manually inserted admin-like proof remains evidence-only.
 INSERT INTO airlinerra_game.section9_operator_licence_evidence_v1(
  airline_id,jurisdiction_iso2,evidence_status,evidence_reference,
  reviewed_at,valid_from)
 VALUES(a,carrier_country,'verified','rollback-test-license-review',
  now(),'2026-01-01');
 INSERT INTO airlinerra_game.section9_route_operating_permission_evidence_v1(
 airline_id,origin_airport_key,destination_airport_key,service_type,
 evidence_status,evidence_reference,reviewed_at,valid_from)
 VALUES(a,'OURAIRPORTS:2214','OURAIRPORTS:2212','passenger',
 'verified','rollback-test-route-review',now(),'2026-01-01');
 out:=airlinerra_game.section9_owned_crew_licence_preflight_v1(
 u,a,schedule,'2026-11-09',14);
 IF out->'permissions'->>'gameOperatorLicenceEvidenceRecorded'<>'true'
 OR (out->'permissions'->>'gameRoutePermissionEvidenceRecorded')::integer<>1
 OR out->'permissions'->>'trafficRightsOperationallyGranted'<>'false'
 THEN RAISE EXCEPTION 'Recorded game evidence claimed legal authority: %',out;END IF;

 roster:=airlinerra_game.section9_owned_crew_roster_preview_v1(u,a,schedule);
 IF jsonb_array_length(roster->'crewAvailableForPlanning')<>2 OR
 jsonb_array_length(roster->'proposals')<>2
 THEN RAISE EXCEPTION 'Owner roster list wrong';END IF;
 combined:=airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 u,a,schedule,'2026-11-09',14);
 IF combined->'crewStaffing' IS NULL OR
    combined->'operatingPermissionEvidence' IS NULL OR
    combined->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION 'Composed operations evidence unsafe';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_plan_owned_crew_duty_v1(
   gen_random_uuid(),a,schedule,verified_crew,1,'remove');
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Other owner mutated crew';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_plan_owned_crew_duty_v1(
   u,a,schedule,gen_random_uuid(),1,'plan');
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Unknown crew assigned';END IF;
 IF has_table_privilege('authenticated',
 'airlinerra_game.section9_airline_crew_roster_v1','INSERT')
 OR has_table_privilege('anon',
 'airlinerra_game.section9_operator_licence_evidence_v1','SELECT')
 OR has_function_privilege('authenticated',
 'airlinerra_game.section9_plan_owned_crew_duty_v1(uuid,uuid,uuid,uuid,integer,text)',
 'EXECUTE')
 THEN RAISE EXCEPTION 'Public employment or legal authority leakage';END IF;
 RAISE NOTICE 'PASS owner crew planning; pending employee excluded; legal evidence advisory; no activation';
END $test$;
ROLLBACK;