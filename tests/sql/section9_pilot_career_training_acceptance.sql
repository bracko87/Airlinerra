-- Isolated lifecycle tests. All changes, including gates, roll back.
DO $test$
DECLARE a record; pilot uuid; absence uuid; course uuid; r jsonb; dt date; now_utc timestamptz; family text; other_family text;
BEGIN
 BEGIN
 SELECT id,owner_player_id,home_airport_key INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();dt:=(now_utc AT TIME ZONE 'Europe/Berlin')::date;
 SELECT qualification_group INTO STRICT family FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=16;
 SELECT qualification_group INTO STRICT other_family FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=54;
 INSERT INTO airlinerra_game.section9_airline_crew_roster_v1(world_id,airline_id,crew_reference,role,qualified_configuration_id,employment_status,employment_proof_ref,employment_reviewed_at,monthly_salary_usd,contract_source,game_effective_date,contract_signed_at)
 VALUES(1,a.id,'TEST-CAREER-'||gen_random_uuid(),'flight_deck',16,'verified_employed','rollback-career',clock_timestamp(),5500,'game_npc_offer_v1',dt-365,clock_timestamp()) RETURNING crew_id INTO pilot;
 INSERT INTO airlinerra_game.section9_pilot_profiles_v1(crew_id,airline_id,career_rank,total_flight_minutes) VALUES(pilot,a.id,'senior_first_officer',179999);
 INSERT INTO airlinerra_game.section9_pilot_family_permissions_v1(airline_id,crew_id,qualification_group,captain_permission,first_officer_permission,qualification_status,family_flight_minutes,issued_game_date,expires_game_date)
 VALUES(a.id,pilot,family,false,true,'active',60000,dt-365,dt+90);
 r:=airlinerra_game.section9_owned_pilot_training_preview_v1(a.owner_player_id,a.id,pilot,family,'promotion','captain',dt);
 IF r->>'status'<>'insufficient_experience' THEN RAISE EXCEPTION 'experience %',r;END IF;
 UPDATE airlinerra_game.section9_pilot_profiles_v1 SET total_flight_minutes=180000 WHERE crew_id=pilot;
 r:=airlinerra_game.section9_owned_pilot_training_preview_v1(a.owner_player_id,a.id,pilot,family,'promotion','captain',dt);
 IF r->>'eligible'<>'true' OR r->>'trainingDays'<>'14' THEN RAISE EXCEPTION 'eligible %',r;END IF;
 IF airlinerra_game.section9_owned_pilot_training_preview_v1(a.owner_player_id,a.id,pilot,other_family,'family_qualification','captain',dt)->>'status'<>'rank_not_eligible_for_permission' THEN RAISE EXCEPTION 'wrong rank';END IF;
 IF airlinerra_game.section9_owned_pilot_training_preview_v1(a.owner_player_id,a.id,pilot,other_family,'family_qualification','first_officer',dt)->>'eligible'<>'true' THEN RAISE EXCEPTION 'new type training';END IF;
 IF airlinerra_game.section9_schedule_pilot_training_v1(a.owner_player_id,a.id,pilot,family,'promotion','captain',now_utc+interval '1 day')->>'status'<>'training_enrollment_disabled' THEN RAISE EXCEPTION 'gate';END IF;
 UPDATE airlinerra_game.section9_pilot_training_release_v1 SET enrollment_enabled=true,assessment_enabled=true WHERE world_id=1;
 r:=airlinerra_game.section9_schedule_pilot_training_v1(a.owner_player_id,a.id,pilot,family,'promotion','captain',now_utc+interval '1 day');
 IF r->>'status'<>'training_scheduled' THEN RAISE EXCEPTION 'schedule %',r;END IF;
 course:=(r->>'courseId')::uuid;absence:=(r->>'absenceId')::uuid;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 WHERE id=absence AND reason='training' AND end_utc-start_utc=interval '14 days') THEN RAISE EXCEPTION 'absence';END IF;
 IF airlinerra_game.section9_assess_pilot_training_v1(a.id,course,true,'test-early-assessment')->>'status'<>'training_not_finished' THEN RAISE EXCEPTION 'premature';END IF;
 -- Fixture completed course: advance the course's test-only timestamps, not the game clock.
 UPDATE airlinerra_game.section9_crew_unavailability_v1 SET start_utc=now_utc-interval '15 days',end_utc=now_utc-interval '1 day' WHERE id=absence;
 UPDATE airlinerra_game.section9_pilot_training_courses_v1 SET start_utc=now_utc-interval '15 days',end_utc=now_utc-interval '1 day' WHERE course_id=course;
 r:=airlinerra_game.section9_assess_pilot_training_v1(a.id,course,false,'test-failed-assessment');
 IF r->>'status'<>'training_failed' OR (SELECT career_rank FROM airlinerra_game.section9_pilot_profiles_v1 WHERE crew_id=pilot)<>'senior_first_officer' THEN RAISE EXCEPTION 'failed course %',r;END IF;
 r:=airlinerra_game.section9_schedule_pilot_training_v1(a.owner_player_id,a.id,pilot,family,'promotion','captain',now_utc+interval '2 days');
 IF r->>'status'<>'training_scheduled' THEN RAISE EXCEPTION 'retry %',r;END IF;
 course:=(r->>'courseId')::uuid;absence:=(r->>'absenceId')::uuid;
 UPDATE airlinerra_game.section9_crew_unavailability_v1 SET start_utc=now_utc-interval '15 days',end_utc=now_utc-interval '1 day' WHERE id=absence;
 UPDATE airlinerra_game.section9_pilot_training_courses_v1 SET start_utc=now_utc-interval '15 days',end_utc=now_utc-interval '1 day' WHERE course_id=course;
 r:=airlinerra_game.section9_assess_pilot_training_v1(a.id,course,true,'test-passed-assessment');
 IF r->>'status'<>'training_passed' OR (SELECT career_rank FROM airlinerra_game.section9_pilot_profiles_v1 WHERE crew_id=pilot)<>'captain' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_family_permissions_v1 WHERE crew_id=pilot AND qualification_group=family AND captain_permission AND family_flight_minutes=60000) THEN RAISE EXCEPTION 'promotion %',r;END IF;
 IF airlinerra_game.section9_assess_pilot_training_v1(a.id,course,true,'test-passed-assessment')->>'status'<>'training_assessment_already_recorded' THEN RAISE EXCEPTION 'replay';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_family_permissions_v1 WHERE crew_id=pilot AND qualification_group=other_family) THEN RAISE EXCEPTION 'untrained family';END IF;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;END;
END $test$;
SELECT 'passed' test,(SELECT count(*) FROM airlinerra_game.section9_pilot_training_courses_v1) persisted_courses,(SELECT to_jsonb(r) FROM airlinerra_game.section9_pilot_training_release_v1 r) release,has_function_privilege('authenticated','airlinerra_game.section9_assess_pilot_training_v1(uuid,uuid,boolean,text)','execute') client_access;