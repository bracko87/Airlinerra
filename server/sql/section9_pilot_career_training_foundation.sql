-- Provisional game rules, not real-world licence requirements.
CREATE TABLE airlinerra_game.section9_pilot_career_policy_v1(
 from_rank text NOT NULL,to_rank text NOT NULL,
 min_total_minutes bigint NOT NULL CHECK(min_total_minutes>=0),
 min_family_minutes bigint NOT NULL CHECK(min_family_minutes>=0),
 training_days int NOT NULL CHECK(training_days BETWEEN 1 AND 90),
 required_permission text NOT NULL CHECK(required_permission IN('first_officer','captain')),
 target_permission text NOT NULL CHECK(target_permission IN('first_officer','captain')),
 PRIMARY KEY(from_rank,to_rank));
INSERT INTO airlinerra_game.section9_pilot_career_policy_v1 VALUES
 ('second_officer','first_officer',0,0,7,'first_officer','first_officer'),
 ('first_officer','senior_first_officer',90000,30000,5,'first_officer','first_officer'),
 ('senior_first_officer','captain',180000,60000,14,'first_officer','captain'),
 ('captain','training_captain',300000,90000,10,'captain','captain'),
 ('training_captain','flight_instructor',360000,120000,14,'captain','captain'),
 ('flight_instructor','examiner',450000,150000,14,'captain','captain');
CREATE TABLE airlinerra_game.section9_pilot_training_release_v1(world_id smallint PRIMARY KEY CHECK(world_id=1),enrollment_enabled boolean NOT NULL DEFAULT false,assessment_enabled boolean NOT NULL DEFAULT false);
INSERT INTO airlinerra_game.section9_pilot_training_release_v1 VALUES(1,false,false);
CREATE TABLE airlinerra_game.section9_pilot_training_courses_v1(
 course_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),airline_id uuid NOT NULL,crew_id uuid NOT NULL,
 qualification_group text NOT NULL REFERENCES airlinerra_game.section9_pilot_qualification_groups_v1(qualification_group),
 course_kind text NOT NULL CHECK(course_kind IN('promotion','family_qualification','renewal')),
 original_rank text NOT NULL,target_rank text NOT NULL,
 target_permission text NOT NULL CHECK(target_permission IN('captain','first_officer')),
 start_utc timestamptz NOT NULL,end_utc timestamptz NOT NULL,
 absence_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_crew_unavailability_v1(id),
 status text NOT NULL DEFAULT 'scheduled' CHECK(status IN('scheduled','passed','failed','cancelled')),
 assessment_reference text UNIQUE,assessed_at_utc timestamptz,
 FOREIGN KEY(airline_id,crew_id) REFERENCES airlinerra_game.section9_pilot_profiles_v1(airline_id,crew_id),
 CHECK(isfinite(start_utc) AND isfinite(end_utc) AND end_utc>start_utc),
 CHECK((status IN('passed','failed') AND assessment_reference IS NOT NULL AND assessed_at_utc IS NOT NULL AND assessed_at_utc>=end_utc) OR (status IN('scheduled','cancelled') AND assessment_reference IS NULL AND assessed_at_utc IS NULL)));
CREATE UNIQUE INDEX section9_one_scheduled_pilot_course_idx ON airlinerra_game.section9_pilot_training_courses_v1(crew_id) WHERE status='scheduled';
ALTER TABLE airlinerra_game.section9_pilot_career_policy_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_pilot_training_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_pilot_training_courses_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_pilot_career_policy_v1,airlinerra_game.section9_pilot_training_release_v1,airlinerra_game.section9_pilot_training_courses_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_owned_pilot_training_preview_v1(p_player uuid,p_airline uuid,p_crew uuid,p_group text,p_kind text,p_target text,p_date date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pr record;q record;pol record;days int;permission text;target_rank text;total_need bigint:=0;family_need bigint:=0;reason text;q_active boolean;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_date IS NULL OR p_kind IS NULL OR p_kind NOT IN('promotion','family_qualification','renewal') OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_qualification_groups_v1 WHERE qualification_group=p_group) THEN RETURN jsonb_build_object('status','invalid_training_request','eligible',false);END IF;
 SELECT r.employment_status,r.game_effective_date,p.career_rank,p.total_flight_minutes INTO pr FROM airlinerra_game.section9_pilot_profiles_v1 p JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=p.airline_id AND r.crew_id=p.crew_id WHERE p.airline_id=p_airline AND p.crew_id=p_crew;
 IF NOT FOUND OR pr.employment_status<>'verified_employed' OR pr.game_effective_date IS NULL OR pr.game_effective_date>p_date THEN RETURN jsonb_build_object('status','pilot_not_employed','eligible',false);END IF;
 SELECT * INTO q FROM airlinerra_game.section9_pilot_family_permissions_v1 WHERE airline_id=p_airline AND crew_id=p_crew AND qualification_group=p_group;
 q_active:=coalesce(q.qualification_status='active' AND q.issued_game_date<=p_date AND q.expires_game_date>p_date,false);
 IF p_kind='promotion' THEN
  SELECT * INTO pol FROM airlinerra_game.section9_pilot_career_policy_v1 WHERE from_rank=pr.career_rank AND to_rank=p_target;
  IF NOT FOUND THEN RETURN jsonb_build_object('status','promotion_path_not_supported','eligible',false);END IF;
  days:=pol.training_days;target_rank:=pol.to_rank;total_need:=pol.min_total_minutes;family_need:=pol.min_family_minutes;permission:=pol.target_permission;
  IF NOT q_active OR NOT coalesce(CASE WHEN pol.required_permission='captain' THEN q.captain_permission ELSE q.first_officer_permission END,false) THEN reason:='current_family_permission_required';END IF;
  IF reason IS NULL AND (pr.total_flight_minutes<total_need OR coalesce(q.family_flight_minutes,0)<family_need) THEN reason:='insufficient_experience';END IF;
 ELSE
  target_rank:=pr.career_rank;permission:=p_target;
  IF permission IS NULL OR permission NOT IN('captain','first_officer') OR NOT airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,true,true,permission) THEN RETURN jsonb_build_object('status','rank_not_eligible_for_permission','eligible',false);END IF;
  IF p_kind='family_qualification' THEN
   days:=21;
   IF q_active AND coalesce(CASE WHEN permission='captain' THEN q.captain_permission ELSE q.first_officer_permission END,false) THEN reason:='already_qualified';END IF;
  ELSE
   days:=3;
   IF NOT coalesce(CASE WHEN permission='captain' THEN q.captain_permission ELSE q.first_officer_permission END,false) THEN reason:='existing_permission_required';END IF;
  END IF;
  IF q.qualification_status='suspended' THEN reason:='qualification_suspension_requires_review';END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_training_courses_v1 WHERE crew_id=p_crew AND status='scheduled') THEN reason:='training_already_scheduled';END IF;
 RETURN jsonb_build_object('status',coalesce(reason,'eligible_for_training_preview'),'eligible',reason IS NULL,'crewId',p_crew,'currentRank',pr.career_rank,'targetRank',target_rank,'targetPermission',permission,'qualificationGroup',p_group,'courseKind',p_kind,'trainingDays',days,'minimumTotalMinutes',total_need,'minimumFamilyMinutes',family_need,'currentTotalMinutes',pr.total_flight_minutes,'currentFamilyMinutes',coalesce(q.family_flight_minutes,0),'assessmentRequired',true,'policyProvisional',true,'enrollmentEnabled',false,'salaryChangeApplied',false);
END $$;
CREATE FUNCTION airlinerra_game.section9_schedule_pilot_training_v1(p_player uuid,p_airline uuid,p_crew uuid,p_group text,p_kind text,p_target text,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE r jsonb;now_utc timestamptz;finish timestamptz;absence uuid;course uuid;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_training_release_v1 WHERE world_id=1 AND enrollment_enabled) THEN RETURN jsonb_build_object('status','training_enrollment_disabled');END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF p_start IS NULL OR NOT isfinite(p_start) OR p_start<now_utc OR p_start>now_utc+interval '90 days' THEN RETURN jsonb_build_object('status','invalid_training_start');END IF;
 r:=airlinerra_game.section9_owned_pilot_training_preview_v1(p_player,p_airline,p_crew,p_group,p_kind,p_target,(p_start AT TIME ZONE 'Europe/Berlin')::date);
 IF r->>'eligible'<>'true' THEN RETURN r;END IF;
 finish:=p_start+make_interval(hours=>24*(r->>'trainingDays')::int);
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 WHERE airline_id=p_airline AND pilot_id=p_crew AND status='active' AND start_utc<finish AND end_utc>p_start) THEN RETURN jsonb_build_object('status','training_absence_conflict');END IF;
 INSERT INTO airlinerra_game.section9_crew_unavailability_v1(airline_id,pilot_id,reason,start_utc,end_utc) VALUES(p_airline,p_crew,'training',p_start,finish) RETURNING id INTO absence;
 INSERT INTO airlinerra_game.section9_pilot_training_courses_v1(airline_id,crew_id,qualification_group,course_kind,original_rank,target_rank,target_permission,start_utc,end_utc,absence_id) VALUES(p_airline,p_crew,p_group,p_kind,r->>'currentRank',r->>'targetRank',r->>'targetPermission',p_start,finish,absence) RETURNING course_id INTO course;
 RETURN jsonb_build_object('status','training_scheduled','courseId',course,'startUtc',p_start,'endUtc',finish,'absenceId',absence,'rankChanged',false);
END $$;
CREATE FUNCTION airlinerra_game.section9_assess_pilot_training_v1(p_airline uuid,p_course uuid,p_passed boolean,p_reference text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE c record;rank_now text;now_utc timestamptz;game_day date;roster_status text;outcome text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_training_release_v1 WHERE world_id=1 AND assessment_enabled) THEN RETURN jsonb_build_object('status','training_assessment_disabled');END IF;
 IF p_passed IS NULL OR p_reference IS NULL OR length(p_reference) NOT BETWEEN 12 AND 128 THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 outcome:=CASE WHEN p_passed THEN 'passed' ELSE 'failed' END;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO c FROM airlinerra_game.section9_pilot_training_courses_v1 WHERE airline_id=p_airline AND course_id=p_course FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','training_course_not_found');END IF;
 IF c.status<>'scheduled' THEN
  IF c.assessment_reference=p_reference AND c.status=outcome THEN RETURN jsonb_build_object('status','training_assessment_already_recorded');END IF;
  RETURN jsonb_build_object('status','training_assessment_conflict');
 END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc<c.end_utc THEN RETURN jsonb_build_object('status','training_not_finished');END IF;
 SELECT p.career_rank,r.employment_status INTO rank_now,roster_status FROM airlinerra_game.section9_pilot_profiles_v1 p JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=p.airline_id AND r.crew_id=p.crew_id WHERE p.airline_id=p_airline AND p.crew_id=c.crew_id;
 IF NOT FOUND OR rank_now<>c.original_rank OR roster_status<>'verified_employed' THEN RETURN jsonb_build_object('status','training_employment_or_rank_changed');END IF;
 IF p_passed AND EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_family_permissions_v1 WHERE airline_id=p_airline AND crew_id=c.crew_id AND qualification_group=c.qualification_group AND qualification_status='suspended') THEN RETURN jsonb_build_object('status','qualification_suspension_requires_review');END IF;
 game_day:=(now_utc AT TIME ZONE 'Europe/Berlin')::date;
 IF p_passed THEN
  UPDATE airlinerra_game.section9_pilot_profiles_v1 SET career_rank=c.target_rank WHERE airline_id=p_airline AND crew_id=c.crew_id;
  INSERT INTO airlinerra_game.section9_pilot_family_permissions_v1 AS q(airline_id,crew_id,qualification_group,captain_permission,first_officer_permission,qualification_status,issued_game_date,expires_game_date)
  VALUES(p_airline,c.crew_id,c.qualification_group,c.target_permission='captain',c.target_permission='first_officer','active',game_day,game_day+365)
  ON CONFLICT(crew_id,qualification_group) DO UPDATE SET
   captain_permission=(q.qualification_status='active' AND q.expires_game_date>game_day AND q.captain_permission) OR excluded.captain_permission,
   first_officer_permission=(q.qualification_status='active' AND q.expires_game_date>game_day AND q.first_officer_permission) OR excluded.first_officer_permission,
   qualification_status='active',issued_game_date=game_day,expires_game_date=game_day+365;
 END IF;
 UPDATE airlinerra_game.section9_pilot_training_courses_v1 SET status=outcome,assessment_reference=p_reference,assessed_at_utc=now_utc WHERE course_id=p_course;
 RETURN jsonb_build_object('status','training_'||outcome,'rankChanged',p_passed AND c.original_rank<>c.target_rank,'salaryChangeApplied',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_pilot_training_preview_v1(uuid,uuid,uuid,text,text,text,date),airlinerra_game.section9_schedule_pilot_training_v1(uuid,uuid,uuid,text,text,text,timestamptz),airlinerra_game.section9_assess_pilot_training_v1(uuid,uuid,boolean,text) FROM PUBLIC,anon,authenticated,service_role;
