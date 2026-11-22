-- Transaction-isolated fixtures; no live movements or employees survive.
DO $test$
DECLARE ar record; ac uuid; sc uuid; ph text; cp uuid; fo uuid; pid uuid; n int; r jsonb; de text; ae text; grp text;
BEGIN
 BEGIN
 SELECT x.id,x.owner_player_id,x.home_airport_key,x.iata_code INTO STRICT ar FROM airlinerra_game.airlines x WHERE world_id=1 LIMIT 1;
 SELECT qualification_group INTO STRICT grp FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=16;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(airline_id,configuration_id,registration,ownership_type,fleet_status) VALUES(ar.id,16,'TEST-PILOT-HOURS','owned','in_service') RETURNING id INTO ac;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(ar.id,ac,16,ar.iata_code||'987',ar.home_airport_key,'OURAIRPORTS:2212','2026-11-23T06:00:00Z','2026-11-23T09:00:00Z','[{"day":0,"time":"07:00"}]','{}',ar.owner_player_id) RETURNING id INTO sc;
 ph:=sc::text||':2026-11-23:1';de:='test-crew-depart-'||sc;ae:='test-crew-arrive-'||sc;
 FOR n IN 1..2 LOOP
 INSERT INTO airlinerra_game.section9_airline_crew_roster_v1(world_id,airline_id,crew_reference,role,qualified_configuration_id,employment_status,employment_proof_ref,employment_reviewed_at,monthly_salary_usd,contract_source,game_effective_date,contract_signed_at)
 VALUES(1,ar.id,'TEST-PILOT-HOURS-'||n,'flight_deck',16,'verified_employed','rollback-fixture',clock_timestamp(),5000,'game_npc_offer_v1','2026-01-01',clock_timestamp()) RETURNING crew_id INTO pid;
 INSERT INTO airlinerra_game.section9_pilot_profiles_v1(crew_id,airline_id,career_rank) VALUES(pid,ar.id,CASE WHEN n=1 THEN 'captain' ELSE 'first_officer' END);
 INSERT INTO airlinerra_game.section9_pilot_family_permissions_v1(airline_id,crew_id,qualification_group,captain_permission,first_officer_permission,qualification_status,issued_game_date,expires_game_date) VALUES(ar.id,pid,grp,n=1,n=2,'active','2026-01-01','2027-01-01');
 IF n=1 THEN cp:=pid;ELSE fo:=pid;END IF;
 END LOOP;
 r:=airlinerra_game.section9_record_pilot_departure_manifest_v1(ar.id,ph,ARRAY[cp],ARRAY[fo]);
 IF r->>'status'<>'departure_not_verified' THEN RAISE EXCEPTION 'unverified departure %',r;END IF;
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,de,repeat('a',64),ar.id,ac,sc,1,1,'2026-11-23',ph,'departed',ar.home_airport_key,'OURAIRPORTS:2212','2026-11-23T06:00:00Z','2026-11-23T09:00:00Z','2026-11-23T06:10:00Z','signed_operated_game_flight_v1');
 INSERT INTO airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,departure_engine_event_id,departure_airport_key,destination_airport_key,configuration_id,fuel_custody_source_event_id,fuel_custody_revision,onboard_at_departure_kg,planned_trip_burn_kg,planned_contingency_kg,planned_holding_reserve_kg,minimum_planned_onboard_kg,model_version,verified_game_hour_utc)
 VALUES(ph,ar.id,ac,de,ar.home_airport_key,'OURAIRPORTS:2212',16,'test-fuel-custody',1,6000,4000,400,600,5000,'rollback-fixture','2026-11-23T06:00:00Z');
 IF airlinerra_game.section9_record_pilot_departure_manifest_v1(ar.id,ph,ARRAY[cp],ARRAY[cp])->>'status'<>'invalid_pilot_manifest' THEN RAISE EXCEPTION 'duplicate seat';END IF;
 IF airlinerra_game.section9_record_pilot_departure_manifest_v1(ar.id,ph,ARRAY[fo],ARRAY[cp])->>'status'<>'pilot_manifest_qualification_failed' THEN RAISE EXCEPTION 'wrong rank';END IF;
 r:=airlinerra_game.section9_record_pilot_departure_manifest_v1(ar.id,ph,ARRAY[cp],ARRAY[fo]);
 IF r->>'status'<>'pilot_manifest_recorded' THEN RAISE EXCEPTION 'manifest %',r;END IF;
 IF airlinerra_game.section9_credit_completed_pilot_flight_v1(ar.id,ph)->>'status'<>'completed_flight_not_verified' THEN RAISE EXCEPTION 'premature credit';END IF;
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,ae,repeat('b',64),ar.id,ac,sc,1,1,'2026-11-23',ph,'arrived',ar.home_airport_key,'OURAIRPORTS:2212','2026-11-23T06:00:00Z','2026-11-23T09:00:00Z','2026-11-23T09:25:00Z','signed_operated_game_flight_v1');
 r:=airlinerra_game.section9_credit_completed_pilot_flight_v1(ar.id,ph);
 IF r->>'pilotsCredited'<>'2' OR r->>'flightMinutes'<>'195' THEN RAISE EXCEPTION 'credit %',r;END IF;
 IF airlinerra_game.section9_credit_completed_pilot_flight_v1(ar.id,ph)->>'pilotsCredited'<>'0' THEN RAISE EXCEPTION 'replay';END IF;
 r:=airlinerra_game.section9_owned_pilot_career_v1(ar.owner_player_id,ar.id,cp);
 IF r->>'totalFlightMinutes'<>'195' OR r->>'recordedCompletedFlights'<>'1' OR r->'families'->0->>'familyFlightMinutes'<>'195' THEN RAISE EXCEPTION 'career %',r;END IF;
 BEGIN PERFORM airlinerra_game.section9_owned_pilot_career_v1(gen_random_uuid(),ar.id,cp);RAISE EXCEPTION 'owner bypass';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;END;
END $test$;
SELECT 'passed' test,(SELECT count(*) FROM airlinerra_game.section9_pilot_flight_experience_v1) persisted_flights,has_function_privilege('authenticated','airlinerra_game.section9_credit_completed_pilot_flight_v1(uuid,text)','execute') client_access;