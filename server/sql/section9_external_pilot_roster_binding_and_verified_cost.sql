
ALTER TABLE airlinerra_game.section9_planned_flight_crews_v1 ADD COLUMN external_captain_count integer NOT NULL DEFAULT 0 CHECK(external_captain_count BETWEEN 0 AND 2), ADD COLUMN external_first_officer_count integer NOT NULL DEFAULT 0 CHECK(external_first_officer_count BETWEEN 0 AND 2),
 DROP CONSTRAINT planned_external_cabin_reference_check,
 DROP CONSTRAINT section9_planned_flight_crews_v1_captain_count_check,
 DROP CONSTRAINT section9_planned_flight_crews_v1_first_officer_count_check,
 ADD CONSTRAINT planned_pilot_total_check CHECK(captain_count BETWEEN 0 AND 2 AND first_officer_count BETWEEN 0 AND 2 AND captain_count+external_captain_count BETWEEN 1 AND 2 AND captain_count+external_captain_count=first_officer_count+external_first_officer_count),
 ADD CONSTRAINT planned_external_crew_reference_check CHECK((external_cabin_count+external_captain_count+external_first_officer_count=0 AND external_contract_reference IS NULL) OR (external_cabin_count+external_captain_count+external_first_officer_count>0 AND external_contract_reference IS NOT NULL));
ALTER TABLE airlinerra_game.section9_operated_crew_bindings_v1 ADD COLUMN external_captain_count integer NOT NULL DEFAULT 0 CHECK(external_captain_count BETWEEN 0 AND 2), ADD COLUMN external_first_officer_count integer NOT NULL DEFAULT 0 CHECK(external_first_officer_count BETWEEN 0 AND 2),
 DROP CONSTRAINT bound_external_cabin_reference_check,
 ADD CONSTRAINT bound_external_crew_reference_check CHECK((external_cabin_count+external_captain_count+external_first_officer_count=0 AND external_contract_reference IS NULL) OR (external_cabin_count+external_captain_count+external_first_officer_count>0 AND external_contract_reference IS NOT NULL));
ALTER TABLE airlinerra_game.section9_pilot_departure_manifests_v1 ADD COLUMN external_captain_count integer NOT NULL DEFAULT 0 CHECK(external_captain_count BETWEEN 0 AND 2), ADD COLUMN external_first_officer_count integer NOT NULL DEFAULT 0 CHECK(external_first_officer_count BETWEEN 0 AND 2),
 ADD COLUMN external_cabin_count integer NOT NULL DEFAULT 0 CHECK(external_cabin_count BETWEEN 0 AND 40),
 ADD COLUMN external_contract_reference text,
 DROP CONSTRAINT section9_pilot_departure_manifests_v1_check,
 ADD CONSTRAINT manifest_pilot_total_check CHECK(cardinality(captain_ids)+external_captain_count BETWEEN 1 AND 2 AND cardinality(captain_ids)+external_captain_count=cardinality(first_officer_ids)+external_first_officer_count),
 ADD CONSTRAINT manifest_external_crew_reference_check CHECK((external_cabin_count+external_captain_count+external_first_officer_count=0 AND external_contract_reference IS NULL) OR (external_cabin_count+external_captain_count+external_first_officer_count>0 AND external_contract_reference IS NOT NULL));
CREATE FUNCTION airlinerra_game.section9_pilot_counts_valid_v1(p_required integer,p_internal_captains integer,p_internal_first_officers integer,p_external_captains integer,p_external_first_officers integer) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO pg_catalog AS $f$
 SELECT coalesce(p_required BETWEEN 1 AND 2 AND p_internal_captains BETWEEN 0 AND p_required AND p_internal_first_officers BETWEEN 0 AND p_required AND p_external_captains BETWEEN 0 AND p_required AND p_external_first_officers BETWEEN 0 AND p_required AND p_internal_captains+p_external_captains=p_required AND p_internal_first_officers+p_external_first_officers=p_required,false);
$f$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_pilot_counts_valid_v1(integer,integer,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_external_cabin_input_v1(p_airline uuid, p_occurrence uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE c record; o record; required integer; min_cabin integer;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT o1.*,pol.qualification_group INTO o FROM airlinerra_game.section9_dated_flight_occurrences_v1 o1 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o1.schedule_id AND s.version=o1.schedule_version AND s.airline_id=o1.airline_id AND s.aircraft_inventory_id=o1.aircraft_inventory_id AND s.status='active' AND s.operationally_verified JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=s.configuration_id WHERE o1.id=p_occurrence AND o1.airline_id=p_airline AND o1.world_id=1 AND o1.booking_status<>'cancelled';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','external_cabin_occurrence_unverified');END IF;
 SELECT * INTO c FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE occurrence_id=p_occurrence OR physical_flight_id=o.schedule_id||':'||o.flight_local_date||':'||o.weekly_entry;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','external_cabin_input_verified','cabinCount',0,'captainCount',0,'firstOfficerCount',0);END IF;
 required:=CASE WHEN o.arrival_utc-o.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 min_cabin:=CASE WHEN o.verified_passenger_seats<=19 THEN 0 ELSE (o.verified_passenger_seats+49)/50 END;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_release_v1 WHERE world_id=1 AND contracting_enabled) OR c.airline_id<>p_airline OR c.occurrence_id<>p_occurrence OR c.physical_flight_id<>o.schedule_id||':'||o.flight_local_date||':'||o.weekly_entry OR c.schedule_version<>o.schedule_version OR c.qualification_group<>o.qualification_group OR c.planned_departure_utc<>o.departure_utc OR c.planned_arrival_utc<>o.arrival_utc OR c.authorized_game_utc>o.departure_utc OR o.arrival_utc-o.departure_utc>interval '9 hours 30 minutes' OR c.captains+c.first_officers+c.cabin_crew<=0 OR c.captains NOT BETWEEN 0 AND required OR c.first_officers NOT BETWEEN 0 AND required OR c.cabin_crew NOT BETWEEN 0 AND min_cabin THEN RETURN jsonb_build_object('status','external_cabin_contract_unverified');END IF;
 RETURN jsonb_build_object('status','external_cabin_input_verified','cabinCount',c.cabin_crew,'captainCount',c.captains,'firstOfficerCount',c.first_officers,'contractReference',c.source_reference);
END $function$
;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_save_owned_crew_plan_preview_v1(p_player uuid, p_airline uuid, p_plan uuid, p_start timestamp with time zone, p_snapshot jsonb, p_assignments jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE snap jsonb;old record;f record;item jsonb;member jsonb;emp jsonb;legs jsonb;rotation jsonb;prior_history jsonb;fit jsonb;d record;duty uuid;emp_id uuid;role_name text;required int;now_utc timestamptz;report_at timestamptz;count_f int:=0;failure text;ids jsonb;external_cabin jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_plan IS NULL OR p_start IS NULL OR p_snapshot IS NULL OR jsonb_typeof(p_assignments) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 SELECT * INTO old FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE plan_id=p_plan AND airline_id=p_airline;
 IF FOUND THEN
 IF old.source_snapshot<>p_snapshot OR old.proposed_assignments<>p_assignments OR old.window_start_utc<>p_start THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CREW_PLAN_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status',old.status,'planId',p_plan,'replayed',true,'dispatchEnforced',false);
 END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF p_start<now_utc OR p_start>now_utc+interval '7 days' THEN RETURN jsonb_build_object('status','crew_plan_window_invalid');END IF;
 snap:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,p_start);
 IF snap IS DISTINCT FROM p_snapshot THEN RETURN jsonb_build_object('status','crew_plan_snapshot_changed');END IF;
 IF snap->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR snap->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','crew_plan_input_unreconciled');END IF;
 IF jsonb_array_length(p_assignments) NOT BETWEEN 1 AND 2000 OR jsonb_array_length(p_assignments)<>jsonb_array_length(snap->'flights') THEN RETURN jsonb_build_object('status','crew_plan_incomplete');END IF;
 -- Live history is not yet integrated. Never replace a duty that has begun.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id WHERE b.airline_id=p_airline AND b.status='validated_preview' AND pd.duty_start_utc<=now_utc)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_departure_manifests_v1 WHERE airline_id=p_airline)
 THEN RETURN jsonb_build_object('status','live_duty_history_required');END IF;
 BEGIN
 UPDATE airlinerra_game.section9_crew_plan_batches_v1 SET status='superseded' WHERE airline_id=p_airline AND status='validated_preview';
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1(plan_id,airline_id,window_start_utc,window_end_utc,source_snapshot,proposed_assignments,status)
 VALUES(p_plan,p_airline,p_start,p_start+interval '168 hours',snap,p_assignments,'validated_preview');
 -- Store each flight using only current trusted occurrence data.
 FOR item IN SELECT value FROM jsonb_array_elements(p_assignments) LOOP
 SELECT o.*,s.configuration_id,pol.qualification_group,pol.maximum_cabin_crew,pol.seat_basis INTO f
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version AND s.status='active'
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=s.configuration_id
 WHERE o.id=(item->>'flightId')::uuid AND o.airline_id=p_airline AND o.world_id=1 AND o.departure_utc>=p_start AND o.departure_utc<p_start+interval '168 hours' AND o.booking_status<>'cancelled';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_occurrence_invalid';END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(snap->'flights') x WHERE x->>'id'=f.id::text) OR item->>'aircraftId' IS DISTINCT FROM f.aircraft_inventory_id::text OR (item->>'departureUtc')::timestamptz IS DISTINCT FROM f.departure_utc OR (item->>'arrivalUtc')::timestamptz IS DISTINCT FROM f.arrival_utc THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_occurrence_mismatch';END IF;
 required:=CASE WHEN f.arrival_utc-f.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 IF jsonb_typeof(item->'captains') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'firstOfficers') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'cabinCrew') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'duties') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_invalid_manifest';END IF;
 external_cabin:=airlinerra_game.section9_verified_external_cabin_input_v1(p_airline,f.id);
 IF external_cabin->>'status'<>'external_cabin_input_verified' THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_external_contract_unverified';END IF;
 IF NOT airlinerra_game.section9_pilot_counts_valid_v1(required,jsonb_array_length(item->'captains'),jsonb_array_length(item->'firstOfficers'),(external_cabin->>'captainCount')::int,(external_cabin->>'firstOfficerCount')::int) OR NOT airlinerra_game.section9_cabin_composition_valid_v1(f.configuration_id,f.verified_passenger_seats,jsonb_array_length(item->'cabinCrew'),(external_cabin->>'cabinCount')::int) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_wrong_staff_count';END IF;
 ids:=(item->'captains')||(item->'firstOfficers')||(item->'cabinCrew');
 IF jsonb_array_length(ids)<>(SELECT count(DISTINCT value) FROM jsonb_array_elements(ids)) OR jsonb_array_length(ids)<>jsonb_array_length(item->'duties') THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_duplicate_employee';END IF;
 INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count,external_cabin_count,external_contract_reference,external_captain_count,external_first_officer_count)
 VALUES(p_plan,p_airline,f.id,f.schedule_version,f.aircraft_inventory_id,f.schedule_id||':'||f.flight_local_date||':'||f.weekly_entry,f.qualification_group,f.departure_utc,f.arrival_utc,f.origin_airport_key,f.destination_airport_key,jsonb_array_length(item->'captains'),jsonb_array_length(item->'firstOfficers'),jsonb_array_length(item->'cabinCrew'),(external_cabin->>'cabinCount')::int,external_cabin->>'contractReference',(external_cabin->>'captainCount')::int,(external_cabin->>'firstOfficerCount')::int);
 count_f:=count_f+1;
 END LOOP;
 -- Validate each distinct employee and reconstruct entire rotations from legs;
 -- the caller's proposed duty end is not trusted.
 FOR d IN SELECT DISTINCT (x->>'employeeId')::uuid employee FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x LOOP
 emp_id:=d.employee;
 SELECT value INTO emp FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) WHERE value->>'id'=emp_id::text;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_employee_unavailable';END IF;
 prior_history:='[]';
 FOR report_at IN SELECT DISTINCT (x->>'dutyStartUtc')::timestamptz FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x WHERE x->>'employeeId'=emp_id::text ORDER BY 1 LOOP
 SELECT jsonb_agg(jsonb_build_object('departureUtc',to_char(flight.departure_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'arrivalUtc',to_char(flight.arrival_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'originAirportKey',flight.origin_airport_key,'destinationAirportKey',flight.destination_airport_key) ORDER BY flight.departure_utc,flight.occurrence_id) INTO legs
 FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x JOIN airlinerra_game.section9_planned_flight_crews_v1 flight ON flight.plan_id=p_plan AND flight.occurrence_id=(j->>'flightId')::uuid
 WHERE x->>'employeeId'=emp_id::text AND (x->>'dutyStartUtc')::timestamptz=report_at;
 rotation:=airlinerra_game.section9_crew_rotation_window_v2(legs);
 IF rotation->>'status'<>'rotation_preview' OR (rotation->>'dutyStartUtc')::timestamptz<>report_at OR report_at<now_utc OR report_at<(emp->>'locationEffectiveUtc')::timestamptz OR (report_at AT TIME ZONE (emp->>'baseTimezone'))::date<(emp->>'employmentFrom')::date THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_invalid_duty';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(emp->'absences','[]')) a WHERE (a->>'startUtc')::timestamptz<(rotation->>'dutyEndUtc')::timestamptz AND (a->>'endUtc')::timestamptz>report_at) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_employee_absent';END IF;
 fit:=airlinerra_game.section9_crew_duty_fit_v2(rotation,prior_history,emp->>'baseTimezone',emp->>'initialAirport');
 IF fit->>'eligible'<>'true' THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_'||(fit->>'status');END IF;
 prior_history:=prior_history||jsonb_build_array(rotation);
 INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(plan_id,airline_id,pilot_id,cabin_member_id,duty_start_utc,duty_end_utc,report_date,starting_airport,ending_airport)
 VALUES(p_plan,p_airline,CASE WHEN emp?'permissions' THEN emp_id END,CASE WHEN NOT emp?'permissions' THEN emp_id END,report_at,(rotation->>'dutyEndUtc')::timestamptz,(report_at AT TIME ZONE (emp->>'baseTimezone'))::date,rotation->>'startingAirport',rotation->>'endingAirport') RETURNING duty_id INTO duty;
 FOR member IN SELECT jsonb_build_object('flight',j,'assignment',x) FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x WHERE x->>'employeeId'=emp_id::text AND (x->>'dutyStartUtc')::timestamptz=report_at LOOP
 item:=member->'flight'; role_name:=member->'assignment'->>'role';
 SELECT * INTO STRICT f FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=p_plan AND occurrence_id=(item->>'flightId')::uuid;
 IF role_name NOT IN('captain','firstOfficer','cabin') OR role_name IS NULL THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_invalid_role';END IF;
 ids:=CASE role_name WHEN 'captain' THEN item->'captains' WHEN 'firstOfficer' THEN item->'firstOfficers' ELSE item->'cabinCrew' END;
 IF NOT ids?emp_id::text THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_manifest_mismatch';END IF;
 IF role_name='cabin' THEN
 IF emp?'permissions' OR emp->>'role' NOT IN('flight_attendant','cabin_supervisor','purser') THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_wrong_cabin_role';END IF;
 ELSE
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(emp->'permissions','[]')) q WHERE q->>'group'=f.qualification_group AND q->>'active'='true' AND q->>role_name='true' AND (q->>'issued')::date<=(f.departure_utc AT TIME ZONE (emp->>'baseTimezone'))::date AND (q->>'expires')::date>(f.arrival_utc AT TIME ZONE (emp->>'baseTimezone'))::date) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_qualification_failed';END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_planned_crew_seats_v1(plan_id,airline_id,occurrence_id,duty_id,employee_id,seat_role) VALUES(p_plan,p_airline,f.occurrence_id,duty,emp_id,CASE WHEN role_name='firstOfficer' THEN 'first_officer' ELSE role_name END);
 END LOOP;
 END LOOP;
 END LOOP;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_flight_crews_v1 pf WHERE pf.plan_id=p_plan AND (pf.captain_count<>(SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='captain') OR pf.first_officer_count<>(SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='first_officer') OR pf.cabin_count<>(SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='cabin'))) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_incomplete_seats';END IF;
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN GET STACKED DIAGNOSTICS failure=MESSAGE_TEXT;RETURN jsonb_build_object('status',failure,'saved',false);
 WHEN unique_violation OR invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow THEN RETURN jsonb_build_object('status','crew_plan_invalid_or_duplicate_data','saved',false);
 END;
 RETURN jsonb_build_object('status','validated_preview','planId',p_plan,'flightCount',count_f,'dutyCount',(SELECT count(*) FROM airlinerra_game.section9_planned_crew_duties_v1 WHERE plan_id=p_plan),'saved',true,'dispatchEnforced',false,'actualDutyHistoryIntegrated',false,'replayed',false);
END $function$
;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_record_pilot_departure_manifest_v1(p_airline uuid, p_physical text, p_captains uuid[], p_officers uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE f record; manifest record; required int; member record; eligible int; occ uuid; ext jsonb; ec int; ef int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_physical IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO manifest FROM airlinerra_game.section9_pilot_departure_manifests_v1 WHERE physical_flight_id=p_physical;
 IF FOUND THEN
  IF manifest.airline_id=p_airline AND manifest.captain_ids=p_captains AND manifest.first_officer_ids=p_officers THEN RETURN jsonb_build_object('status','manifest_already_recorded','created',false);END IF;
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='PILOT_MANIFEST_CONFLICT';
 END IF;
 SELECT d.*,r.configuration_id,p.qualification_group INTO f
 FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 r
 JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=r.departure_engine_event_id AND d.flight_occurrence_id=r.physical_flight_id AND d.airline_id=r.airline_id AND d.aircraft_inventory_id=r.aircraft_inventory_id
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=r.configuration_id
 WHERE r.physical_flight_id=p_physical AND r.airline_id=p_airline AND d.world_id=1 AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1' AND d.schedule_id IS NOT NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','departure_not_verified');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=p_physical AND phase='arrived') THEN RETURN jsonb_build_object('status','manifest_too_late');END IF;
 required:=CASE WHEN f.scheduled_arrival_utc-f.scheduled_departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 SELECT id INTO occ FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.airline_id=p_airline AND o.world_id=1 AND o.schedule_id=f.schedule_id AND o.schedule_version=f.schedule_version AND o.flight_local_date=f.flight_local_date AND o.weekly_entry=f.weekly_entry AND o.aircraft_inventory_id=f.aircraft_inventory_id;
 IF occ IS NULL THEN RETURN jsonb_build_object('status','manifest_occurrence_unverified');END IF;
 ext:=airlinerra_game.section9_verified_external_cabin_input_v1(p_airline,occ);
 IF ext->>'status'<>'external_cabin_input_verified' THEN RETURN jsonb_build_object('status','manifest_external_contract_unverified');END IF;
 ec:=(ext->>'captainCount')::int;ef:=(ext->>'firstOfficerCount')::int;
 IF p_captains IS NULL OR p_officers IS NULL OR coalesce(array_ndims(p_captains),1)<>1 OR coalesce(array_ndims(p_officers),1)<>1 OR NOT airlinerra_game.section9_pilot_counts_valid_v1(required,cardinality(p_captains),cardinality(p_officers),ec,ef) OR (SELECT count(DISTINCT id) FROM unnest(p_captains||p_officers) id)<>cardinality(p_captains)+cardinality(p_officers) THEN RETURN jsonb_build_object('status','invalid_pilot_manifest');END IF;
 FOR member IN SELECT id,'captain' AS seat_role FROM unnest(p_captains) id UNION ALL SELECT id,'first_officer' FROM unnest(p_officers) id LOOP
 SELECT count(*) INTO eligible FROM airlinerra_game.section9_pilot_profiles_v1 pr
 JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=pr.airline_id AND r.crew_id=pr.crew_id
 JOIN airlinerra_game.section9_pilot_family_permissions_v1 q ON q.airline_id=pr.airline_id AND q.crew_id=pr.crew_id AND q.qualification_group=f.qualification_group
 WHERE pr.airline_id=p_airline AND pr.crew_id=member.id AND r.employment_status='verified_employed' AND r.game_effective_date<=f.flight_local_date
 AND q.qualification_status='active' AND q.issued_game_date<=f.flight_local_date AND q.expires_game_date>f.flight_local_date
 AND airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,member.seat_role);
 IF eligible<>1 THEN RETURN jsonb_build_object('status','pilot_manifest_qualification_failed');END IF;
 END LOOP;
 INSERT INTO airlinerra_game.section9_pilot_departure_manifests_v1(physical_flight_id,airline_id,departure_event_id,configuration_id,qualification_group,captain_ids,first_officer_ids,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(p_physical,p_airline,f.engine_event_id,f.configuration_id,f.qualification_group,p_captains,p_officers,ec,ef,(ext->>'cabinCount')::int,ext->>'contractReference');
 RETURN jsonb_build_object('status','pilot_manifest_recorded','created',true,'pilotCount',required*2,'internalPilotCount',cardinality(p_captains)+cardinality(p_officers),'externalPilotCount',ec+ef,'dispatchEnforced',false);
END $function$
;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_capture_dispatched_crew_v1(p_airline uuid, p_physical text, p_event text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE m record;pl record;existing record;seat record;prior record;location record;cps uuid[];fos uuid[];cabin uuid[];outcome jsonb;issue text;external_cabin jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','crew_capture_disabled');END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT d.*,r.configuration_id INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 d JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 r ON r.departure_engine_event_id=d.engine_event_id AND r.physical_flight_id=d.flight_occurrence_id AND r.airline_id=d.airline_id AND r.aircraft_inventory_id=d.aircraft_inventory_id
 WHERE d.engine_event_id=p_event AND d.flight_occurrence_id=p_physical AND d.airline_id=p_airline AND d.world_id=1 AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1' AND d.schedule_id IS NOT NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','crew_departure_evidence_missing');END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_operated_crew_bindings_v1 WHERE physical_flight_id=p_physical;
 IF FOUND THEN
 IF existing.airline_id<>p_airline OR existing.departure_event_id<>p_event THEN RAISE EXCEPTION 'CREW_BINDING_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','crew_departure_already_bound','replayed',true);
 END IF;
 SELECT pf.* INTO pl FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview'
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=pf.occurrence_id AND o.airline_id=pf.airline_id AND o.schedule_id=m.schedule_id AND o.schedule_version=pf.schedule_version AND o.flight_local_date=m.flight_local_date AND o.weekly_entry=m.weekly_entry AND o.booking_status<>'cancelled' AND o.departure_utc=pf.departure_utc AND o.arrival_utc=pf.arrival_utc
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=m.configuration_id AND pol.qualification_group=pf.qualification_group
 WHERE pf.airline_id=p_airline AND pf.physical_flight_id=p_physical AND pf.schedule_version=m.schedule_version AND pf.aircraft_inventory_id=m.aircraft_inventory_id AND pf.origin_airport_key=m.origin_airport_key AND pf.destination_airport_key=m.destination_airport_key AND pf.departure_utc=m.scheduled_departure_utc AND pf.arrival_utc=m.scheduled_arrival_utc;
 IF NOT FOUND THEN issue:='crew_current_plan_missing';
 ELSIF m.actual_event_utc<>pl.departure_utc THEN issue:='crew_delayed_rotation_requires_replan';
 END IF;
 IF issue IS NULL THEN
 SELECT coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='captain'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='first_officer'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='cabin'),'{}') INTO cps,fos,cabin FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=pl.plan_id AND occurrence_id=pl.occurrence_id;
 IF cardinality(cps)<>pl.captain_count OR cardinality(fos)<>pl.first_officer_count OR cardinality(cabin)<>pl.cabin_count THEN issue:='crew_seat_count_changed';END IF;
 END IF;
 IF issue IS NULL THEN
 external_cabin:=airlinerra_game.section9_verified_external_cabin_input_v1(p_airline,pl.occurrence_id);
 IF external_cabin->>'status'<>'external_cabin_input_verified' OR (external_cabin->>'cabinCount')::int IS DISTINCT FROM pl.external_cabin_count OR (external_cabin->>'captainCount')::int IS DISTINCT FROM pl.external_captain_count OR (external_cabin->>'firstOfficerCount')::int IS DISTINCT FROM pl.external_first_officer_count OR external_cabin->>'contractReference' IS DISTINCT FROM pl.external_contract_reference
 OR NOT airlinerra_game.section9_pilot_counts_valid_v1(CASE WHEN m.scheduled_arrival_utc-m.scheduled_departure_utc>interval '6 hours' THEN 2 ELSE 1 END,cardinality(cps),cardinality(fos),pl.external_captain_count,pl.external_first_officer_count)
 OR NOT airlinerra_game.section9_cabin_composition_valid_v1(m.configuration_id,(SELECT verified_passenger_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=pl.occurrence_id AND airline_id=p_airline),cardinality(cabin),pl.external_cabin_count) THEN issue:='crew_external_cabin_or_staffing_changed';END IF;
 END IF;
 IF issue IS NULL THEN
 FOR seat IN SELECT s.employee_id,s.seat_role,d.pilot_id,d.cabin_member_id,d.duty_id,d.duty_start_utc,d.duty_end_utc
 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id WHERE s.plan_id=pl.plan_id AND s.occurrence_id=pl.occurrence_id LOOP
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 a WHERE a.airline_id=p_airline AND a.status='active' AND (a.pilot_id=seat.pilot_id OR a.cabin_member_id=seat.cabin_member_id) AND a.start_utc<seat.duty_end_utc AND a.end_utc>seat.duty_start_utc) THEN issue:='crew_employee_unavailable';EXIT;END IF;
 IF seat.seat_role='cabin' THEN
 SELECT c.initial_airport_key,c.location_effective_utc,ap.timezone_iana INTO location FROM airlinerra_game.section9_cabin_crew_members_v1 c JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=c.world_id AND ap.airport_key=c.base_airport_key WHERE c.airline_id=p_airline AND c.member_id=seat.cabin_member_id AND c.employment_status='employed' AND c.role IN('flight_attendant','cabin_supervisor','purser') AND c.effective_game_date<=(seat.duty_start_utc AT TIME ZONE ap.timezone_iana)::date;
 ELSE
 SELECT b.initial_airport_key,b.location_effective_utc,ap.timezone_iana INTO location FROM airlinerra_game.section9_pilot_profiles_v1 pr JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=pr.airline_id AND r.crew_id=pr.crew_id
 JOIN airlinerra_game.section9_pilot_base_assignments_v1 b ON b.airline_id=pr.airline_id AND b.crew_id=pr.crew_id
 JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.base_airport_key
 JOIN airlinerra_game.section9_pilot_family_permissions_v1 q ON q.airline_id=pr.airline_id AND q.crew_id=pr.crew_id AND q.qualification_group=pl.qualification_group
 WHERE pr.airline_id=p_airline AND pr.crew_id=seat.pilot_id AND r.employment_status='verified_employed' AND r.game_effective_date<=(seat.duty_start_utc AT TIME ZONE ap.timezone_iana)::date AND q.qualification_status='active'
 AND q.issued_game_date<=(pl.departure_utc AT TIME ZONE ap.timezone_iana)::date AND q.expires_game_date>(pl.arrival_utc AT TIME ZONE ap.timezone_iana)::date
 AND airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,seat.seat_role);
 END IF;
 IF NOT FOUND OR location.location_effective_utc>seat.duty_start_utc THEN issue:='crew_employment_or_qualification_changed';EXIT;END IF;
 -- Every prior planned leg must have genuinely operated with this roster.
 -- Full actual duty history and disruption reallocation are phase 14G.
 SELECT pf.*,ps.duty_id AS prior_duty_id,pd.duty_end_utc AS prior_duty_end INTO prior FROM airlinerra_game.section9_planned_crew_seats_v1 ps JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=ps.plan_id AND pf.occurrence_id=ps.occurrence_id JOIN airlinerra_game.section9_planned_crew_duties_v1 pd ON pd.duty_id=ps.duty_id
 WHERE ps.plan_id=pl.plan_id AND ps.employee_id=seat.employee_id AND pf.departure_utc<pl.departure_utc ORDER BY pf.departure_utc DESC LIMIT 1;
 IF FOUND THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.flight_occurrence_id=b.physical_flight_id AND a.airline_id=b.airline_id AND a.phase='arrived' AND a.destination_airport_key=pl.origin_airport_key
 WHERE b.plan_id=prior.plan_id AND b.occurrence_id=prior.occurrence_id AND a.actual_event_utc<=pl.departure_utc
 AND (CASE WHEN prior.prior_duty_id=seat.duty_id THEN a.actual_event_utc+interval '30 minutes'<=pl.departure_utc ELSE greatest(prior.prior_duty_end,a.actual_event_utc+interval '30 minutes')+interval '12 hours'<=seat.duty_start_utc END))
 THEN issue:='crew_prior_arrival_or_rest_unverified';EXIT;END IF;
 ELSIF location.initial_airport_key<>pl.origin_airport_key THEN issue:='crew_initial_airport_mismatch';EXIT;
 END IF;
 END LOOP;
 END IF;
 IF issue IS NULL THEN
 outcome:=airlinerra_game.section9_record_pilot_departure_manifest_v1(p_airline,p_physical,cps,fos);
 IF outcome->>'status' NOT IN('pilot_manifest_recorded','manifest_already_recorded') THEN issue:=coalesce(outcome->>'status','crew_manifest_unverified');
 ELSIF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_departure_manifests_v1 pm WHERE pm.physical_flight_id=p_physical AND pm.airline_id=p_airline AND pm.departure_event_id=p_event AND pm.external_captain_count=pl.external_captain_count AND pm.external_first_officer_count=pl.external_first_officer_count AND pm.external_cabin_count=pl.external_cabin_count AND pm.external_contract_reference IS NOT DISTINCT FROM pl.external_contract_reference) THEN issue:='crew_manifest_contract_mismatch';
 ELSE
 INSERT INTO airlinerra_game.section9_operated_crew_bindings_v1(physical_flight_id,airline_id,plan_id,occurrence_id,departure_event_id,cabin_member_ids,external_cabin_count,external_contract_reference,external_captain_count,external_first_officer_count) VALUES(p_physical,p_airline,pl.plan_id,pl.occurrence_id,p_event,cabin,pl.external_cabin_count,pl.external_contract_reference,pl.external_captain_count,pl.external_first_officer_count);
 RETURN jsonb_build_object('status','crew_departure_bound','pilotCount',cardinality(cps)+cardinality(fos)+pl.external_captain_count+pl.external_first_officer_count,'internalPilotCount',cardinality(cps)+cardinality(fos),'externalPilotCount',pl.external_captain_count+pl.external_first_officer_count,'cabinCount',cardinality(cabin)+pl.external_cabin_count,'internalCabinCount',cardinality(cabin),'externalCabinCount',pl.external_cabin_count,'replayed',false);
 END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_operated_crew_capture_issues_v1(engine_event_id,airline_id,physical_flight_id,issue_code) VALUES(p_event,p_airline,p_physical,issue) ON CONFLICT(engine_event_id) DO NOTHING;
 RETURN jsonb_build_object('status',issue,'crewCancellationTriggered',false);
END $function$
;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_capture_actual_turnaround_v1(p_airline uuid, p_physical text, p_event text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE f record;old record;key text;digest bytea;roll numeric;minutes int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO old FROM airlinerra_game.section9_actual_turnaround_receipts_v1 WHERE physical_flight_id=p_physical;
 IF FOUND THEN
 IF old.airline_id<>p_airline OR old.arrival_event_id<>p_event THEN RAISE EXCEPTION 'TURNAROUND_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','turnaround_already_recorded','actualMinutes',old.actual_minutes,'availableUtc',old.available_utc);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dynamic_turnaround_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','dynamic_turnaround_disabled');END IF;
 SELECT a.actual_event_utc,a.aircraft_inventory_id,o.id occurrence_id,o.turnaround_minutes,o.verified_passenger_seats,d.configuration_id,cardinality(b.cabin_member_ids)+b.external_cabin_count cabin_count,b.external_cabin_count,b.external_contract_reference,b.external_captain_count,b.external_first_officer_count INTO f
 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=b.occurrence_id AND o.airline_id=b.airline_id
 JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 d ON d.physical_flight_id=b.physical_flight_id AND d.airline_id=b.airline_id AND d.departure_engine_event_id=b.departure_event_id
 JOIN airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 r ON r.physical_flight_id=d.physical_flight_id AND r.airline_id=d.airline_id AND r.aircraft_inventory_id=d.aircraft_inventory_id
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.engine_event_id=r.arrival_engine_event_id AND a.flight_occurrence_id=r.physical_flight_id AND a.airline_id=r.airline_id AND a.aircraft_inventory_id=r.aircraft_inventory_id AND a.phase='arrived' AND a.schedule_id=o.schedule_id AND a.schedule_version=o.schedule_version
 WHERE b.airline_id=p_airline AND b.physical_flight_id=p_physical AND a.engine_event_id=p_event;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','turnaround_crew_or_arrival_evidence_missing');END IF;
 -- External cabin crew must have been bound at the verified departure; an offer or contract alone is insufficient.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 c WHERE c.physical_flight_id=p_physical)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 c WHERE c.physical_flight_id=p_physical AND c.airline_id=p_airline AND c.occurrence_id=f.occurrence_id AND c.captains=f.external_captain_count AND c.first_officers=f.external_first_officer_count AND c.cabin_crew=f.external_cabin_count AND c.source_reference=f.external_contract_reference) THEN RETURN jsonb_build_object('status','mixed_crew_turnaround_pending');END IF;
 IF f.external_cabin_count+f.external_captain_count+f.external_first_officer_count>0 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 c WHERE c.physical_flight_id=p_physical AND c.airline_id=p_airline AND c.occurrence_id=f.occurrence_id AND c.captains=f.external_captain_count AND c.first_officers=f.external_first_officer_count AND c.cabin_crew=f.external_cabin_count AND c.source_reference=f.external_contract_reference) THEN RETURN jsonb_build_object('status','external_cabin_binding_missing');END IF;
 SELECT decrypted_secret INTO key FROM vault.decrypted_secrets WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF key IS NULL OR length(key)<64 THEN RETURN jsonb_build_object('status','turnaround_seed_unavailable');END IF;
 digest:=extensions.hmac(convert_to('airlinerra-turnaround-v1:'||p_physical,'UTF8'),convert_to(key,'UTF8'),'sha256');
 roll:=(get_byte(digest,0)*65536+get_byte(digest,1)*256+get_byte(digest,2))::numeric/16777216;
 minutes:=airlinerra_game.section9_sample_turnaround_minutes_v1(f.configuration_id,f.verified_passenger_seats,f.cabin_count,f.turnaround_minutes,roll);
 IF minutes IS NULL THEN RETURN jsonb_build_object('status','turnaround_staffing_unverified');END IF;
 INSERT INTO airlinerra_game.section9_actual_turnaround_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,arrival_event_id,occurrence_id,configuration_id,installed_seats,assigned_cabin_crew,scheduled_minutes,actual_minutes,arrival_utc,available_utc)
 VALUES(p_physical,p_airline,f.aircraft_inventory_id,p_event,f.occurrence_id,f.configuration_id,f.verified_passenger_seats,f.cabin_count,f.turnaround_minutes,minutes,f.actual_event_utc,f.actual_event_utc+make_interval(mins=>minutes)) ON CONFLICT(physical_flight_id) DO NOTHING;
 SELECT * INTO STRICT old FROM airlinerra_game.section9_actual_turnaround_receipts_v1 WHERE physical_flight_id=p_physical;
 RETURN jsonb_build_object('status','turnaround_recorded','actualMinutes',old.actual_minutes,'scheduledMinutes',old.scheduled_minutes,'availableUtc',old.available_utc,'excessMinutes',greatest(0,old.actual_minutes-old.scheduled_minutes));
END $function$
;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_completed_external_crew_cost_v1(p_airline uuid, p_physical text, p_arrival_event text)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE c record;d record;a record;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO c FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE physical_flight_id=p_physical;
 IF NOT FOUND THEN RETURN 0;END IF;
 IF c.airline_id<>p_airline THEN RAISE EXCEPTION 'EXTERNAL_CREW_AIRLINE_MISMATCH';END IF;
 SELECT * INTO STRICT d FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=p_physical AND airline_id=p_airline AND phase='departed' AND schedule_version=c.schedule_version AND scheduled_departure_utc=c.planned_departure_utc AND scheduled_arrival_utc=c.planned_arrival_utc AND actual_event_utc>=c.authorized_game_utc;
 SELECT * INTO STRICT a FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=p_arrival_event AND flight_occurrence_id=p_physical AND airline_id=p_airline AND phase='arrived' AND aircraft_inventory_id=d.aircraft_inventory_id AND schedule_id=d.schedule_id AND schedule_version=d.schedule_version AND weekly_entry=d.weekly_entry AND flight_local_date=d.flight_local_date AND origin_airport_key=d.origin_airport_key AND destination_airport_key=d.destination_airport_key;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b JOIN airlinerra_game.section9_pilot_departure_manifests_v1 m ON m.physical_flight_id=b.physical_flight_id AND m.airline_id=b.airline_id AND m.departure_event_id=b.departure_event_id WHERE b.physical_flight_id=p_physical AND b.airline_id=p_airline AND b.occurrence_id=c.occurrence_id AND b.departure_event_id=d.engine_event_id AND b.external_contract_reference=c.source_reference AND b.external_captain_count=c.captains AND b.external_first_officer_count=c.first_officers AND b.external_cabin_count=c.cabin_crew AND m.external_contract_reference=c.source_reference AND m.external_captain_count=c.captains AND m.external_first_officer_count=c.first_officers AND m.external_cabin_count=c.cabin_crew AND m.qualification_group=c.qualification_group) THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='EXTERNAL_CREW_NOT_BOUND_TO_VERIFIED_DEPARTURE';END IF;
 RETURN airlinerra_game.section9_external_crew_cost_v1(c.captains,c.first_officers,c.cabin_crew,c.captain_rate,c.first_officer_rate,c.cabin_rate,extract(epoch FROM a.actual_event_utc-d.actual_event_utc)/60);
END $function$
;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_complete_bound_crew_arrival_v1(p_airline uuid, p_physical text, p_event text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE b record;outcome jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO b FROM airlinerra_game.section9_operated_crew_bindings_v1 WHERE airline_id=p_airline AND physical_flight_id=p_physical;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','crew_arrival_no_bound_roster');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=p_event AND phase='arrived' AND airline_id=p_airline AND flight_occurrence_id=p_physical) THEN RETURN jsonb_build_object('status','crew_arrival_evidence_missing');END IF;
 outcome:=airlinerra_game.section9_credit_completed_pilot_flight_v1(p_airline,p_physical);
 RETURN outcome||jsonb_build_object('crewRosterBound',true,'cabinCrewCount',cardinality(b.cabin_member_ids)+b.external_cabin_count,'externalCabinCount',b.external_cabin_count,'externalPilotCount',b.external_captain_count+b.external_first_officer_count);
END $function$
;
DO $test$
BEGIN
IF NOT airlinerra_game.section9_pilot_counts_valid_v1(1,1,1,0,0) OR NOT airlinerra_game.section9_pilot_counts_valid_v1(1,0,1,1,0) OR NOT airlinerra_game.section9_pilot_counts_valid_v1(1,1,0,0,1) OR NOT airlinerra_game.section9_pilot_counts_valid_v1(1,0,0,1,1) OR NOT airlinerra_game.section9_pilot_counts_valid_v1(2,1,1,1,1) OR airlinerra_game.section9_pilot_counts_valid_v1(1,1,1,1,0) OR airlinerra_game.section9_pilot_counts_valid_v1(2,1,1,0,1) OR airlinerra_game.section9_pilot_counts_valid_v1(1,0,1,-1,0) THEN RAISE EXCEPTION 'PILOT_COMPOSITION_TEST_FAILED';END IF;
END $test$;