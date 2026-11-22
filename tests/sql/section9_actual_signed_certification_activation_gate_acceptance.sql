-- Section 5+6 actual verifier isolation: no real slot, certification or airline modified.
DO $slot_fixture$
DECLARE t text; cols text; fn record; a record; aircraft record; sc uuid; rr record; hmac_payload text; evsign text; revoked_event text; certificate_count integer; blocker jsonb; proof record; game_key text:=repeat('S',70); game_day date; orig text:='OURAIRPORTS:4610'; dest text:='OURAIRPORTS:4612'; dep timestamptz:='2026-11-23T10:00:00Z'; arr timestamptz:='2026-11-23T12:00:00Z'; weekly jsonb:='[{"day":0,"time":"11:00"}]'::jsonb; verdict jsonb; restriction jsonb; result jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA cert_signed_fixture_14aa;
 CREATE TABLE cert_signed_fixture_14aa.fixture_worlds(id smallint primary key,state text,opens_at timestamptz);
 CREATE TABLE cert_signed_fixture_14aa.test_signer(name text primary key,decrypted_secret text not null);
 INSERT INTO cert_signed_fixture_14aa.test_signer(name,decrypted_secret) VALUES
 ('cert_signed_fixture_14aa_clearance_operator_licence_v1',repeat('S',70)),
 ('cert_signed_fixture_14aa_clearance_route_traffic_rights_v1',repeat('T',70)),
 ('cert_signed_fixture_14aa_clearance_airport_slot_capacity_v1',repeat('U',70));
 INSERT INTO cert_signed_fixture_14aa.fixture_worlds VALUES(1,'active',now()-interval '3 days');
 FOREACH t IN ARRAY ARRAY['airlines','airline_aircraft_inventory','airline_flight_schedule_drafts_v1','airport_reference_profiles','section9_maintenance_relocation_trips_v1',
 'holding_world_clock_v1','section9_verified_game_tick_receipts_v1',
 'section6_airport_slot_capacity_v1','section6_weekly_airport_slot_reservations_v1',
 'section9_verified_schedule_capacity_v1','section9_aoc_operating_companies_v1','section9_aoc_release_policy_v1','section9_aoc_certificates_v1','section9_aoc_safety_incidents_v1','section9_aoc_corrective_tasks_v1','section9_aoc_independent_correction_release_v1','section9_aoc_compliance_receipts_v1','section9_aoc_verified_correction_proofs_v1','section9_game_maintenance_service_receipts_v1','section9_game_permission_applications_v1','section9_operator_licence_evidence_v1','airline_ledger','aviation_countries_v1','airport_offices','licence2_directed_route_allocations_v1','licence2_market_policy_v1','licence2_market_levels_v1','licence2_airline_market_permits_v1','section9_operational_certification_events_v1','section9_schedule_operational_certifications_v1','section9_schedule_activation_preparations_v1','section9_activation_release_policy_v1','section9_weekly_crew_duty_proposals_v1','section9_airline_crew_roster_v1','section9_route_operating_permission_evidence_v1'] LOOP
  EXECUTE format('CREATE TABLE cert_signed_fixture_14aa.%I (LIKE airlinerra_game.%I INCLUDING ALL)',t,t);
 END LOOP;
 SELECT * INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT * INTO STRICT aircraft FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=a.id LIMIT 1;
 game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF game_day IS DISTINCT FROM date '2026-11-22' THEN RAISE EXCEPTION 'fixture date must match verification day';END IF;
 FOREACH t IN ARRAY ARRAY['airport_unified_operations_v1','section5_airport_operating_policy_v1','section5_airport_simplified_game_rules_v1',
 'airport_runway_inventory','airport_runway_source_status_evidence','airport_sections1_8_combined_members_v1','section5_airport_batch50_screen_v1',
 'section5_airport_icao_chapter_policy_v2','section5_airport_official_noise_rules_v2','section5_airport_time_restrictions_v1',
 'section5_full_weight_airport_aircraft_screen_v2','section5_runway_specific_restrictions_v1'] LOOP
  EXECUTE format('CREATE TABLE cert_signed_fixture_14aa.%I AS SELECT * FROM airlinerra_game.%I WHERE world_id=1 AND airport_key=ANY($1)',t,t) USING ARRAY[orig,dest];
 END LOOP;
 CREATE TABLE cert_signed_fixture_14aa.section5_icao_aircraft_certification_v2 AS SELECT * FROM airlinerra_game.section5_icao_aircraft_certification_v2 WHERE configuration_id=aircraft.configuration_id;
 FOR fn IN SELECT pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='airlinerra_game'::regnamespace AND proname IN (
 'section5_local_restriction_window_match_v1','section5_universal_airport_leg_restriction_v1','section5_simplified_airport_leg_screen_v1',
 'section5_universal_route_restriction_gate_v1','section5_batch_route_restriction_screen_v1','section5_weekly_route_restriction_gate_v1',
 'section9_game_route_restrictions_valid_v1','section6_weekly_slot_proposals_v1','section6_weekly_slot_preflight_v1','section9_verify_slot_clearance_source_v1',
 'section9_verified_permission_game_day_v1','section9_aoc_safety_score_v1','section9_aoc_flight_release_readiness_v1','section9_canonical_aoc_covers_v1',
 'section9_verify_game_operator_licence_v1','section9_verify_game_route_traffic_rights_v1','section9_game_route_licence_scope_v1',
 'licence2_foreign_route_preview_v1','licence2_country_market_v1',
 'section9_issue_queued_game_clearance_v1','section9_record_verified_certification_event_v1',
 'section9_prepare_certified_schedule_activation_v1','section9_commit_certified_schedule_activation_v1',
 'section9_activation_evidence_fingerprint_v1','section9_guard_schedule_activation_update_v1','section9_reject_certificate_audit_mutation_v1'
 ) LOOP
  EXECUTE replace(replace(replace(fn.def,'airlinerra_game','cert_signed_fixture_14aa'),'public.cert_signed_fixture_14aa_worlds','cert_signed_fixture_14aa.fixture_worlds'),'vault.decrypted_secrets','cert_signed_fixture_14aa.test_signer');
 END LOOP;
 EXECUTE $stubs$CREATE FUNCTION cert_signed_fixture_14aa.section9_owned_crew_licence_preflight_v1(uuid,uuid,uuid,date,integer) RETURNS jsonb LANGUAGE sql STABLE AS $body$
 SELECT jsonb_build_object('readOnly',true,'permissions',jsonb_build_object('gameOperatorLicenceEvidenceRecorded',true,'requiredServiceTypes',1,'gameRoutePermissionEvidenceRecorded',1)) $body$; $stubs$;
 EXECUTE $stubs$CREATE FUNCTION cert_signed_fixture_14aa.section9_owned_commercial_activation_preflight_v1(uuid,uuid,uuid,date,integer) RETURNS jsonb LANGUAGE sql STABLE AS $body$
 SELECT jsonb_build_object('readOnly',true,'canActivateNormalFlight',false,'activationChecklist',jsonb_build_object('airportRestrictionPreviewPassed',true,'aircraftRotationPreviewConflictFree',true,'departureArrivalSlotRecordsPresent',true,'aircraftDeliveryAnchorVerified',true,'aircraftInFlight',false,'lastVerifiedGroundAirport','OURAIRPORTS:4610','operatorLicenceEvidenceRecorded',true,'routePermissionEvidenceComplete',true,'worldClockConnected',true),
 'turnaround',jsonb_build_object('shortTurnaroundOccurrences',0,'minimumMinutes',45)) $body$; $stubs$;
 EXECUTE $stubs$CREATE TRIGGER fixture_signed_event_immutable BEFORE DELETE OR UPDATE ON cert_signed_fixture_14aa.section9_operational_certification_events_v1 FOR EACH ROW EXECUTE FUNCTION cert_signed_fixture_14aa.section9_reject_certificate_audit_mutation_v1() $stubs$;
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO cols FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO cert_signed_fixture_14aa.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',cols,cols) USING ARRAY[orig,dest];
 INSERT INTO cert_signed_fixture_14aa.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO cert_signed_fixture_14aa.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=aircraft.id;
 INSERT INTO cert_signed_fixture_14aa.holding_world_clock_v1 SELECT * FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 INSERT INTO cert_signed_fixture_14aa.section9_verified_game_tick_receipts_v1 SELECT * FROM airlinerra_game.section9_verified_game_tick_receipts_v1 WHERE world_id=1 AND game_date=game_day;
 INSERT INTO cert_signed_fixture_14aa.section6_airport_slot_capacity_v1 SELECT * FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=1 AND airport_key IN(orig,dest);
 INSERT INTO cert_signed_fixture_14aa.section9_aoc_operating_companies_v1 SELECT * FROM airlinerra_game.section9_aoc_operating_companies_v1 WHERE airline_id=a.id;
 INSERT INTO cert_signed_fixture_14aa.section9_aoc_release_policy_v1 SELECT * FROM airlinerra_game.section9_aoc_release_policy_v1 WHERE world_id=1;
 INSERT INTO cert_signed_fixture_14aa.section9_aoc_certificates_v1 SELECT * FROM airlinerra_game.section9_aoc_certificates_v1 WHERE airline_id=a.id;
 INSERT INTO cert_signed_fixture_14aa.aviation_countries_v1 SELECT * FROM airlinerra_game.aviation_countries_v1;
 INSERT INTO cert_signed_fixture_14aa.licence2_market_policy_v1 SELECT * FROM airlinerra_game.licence2_market_policy_v1;
 INSERT INTO cert_signed_fixture_14aa.licence2_market_levels_v1 SELECT * FROM airlinerra_game.licence2_market_levels_v1;
 INSERT INTO cert_signed_fixture_14aa.licence2_airline_market_permits_v1 SELECT * FROM airlinerra_game.licence2_airline_market_permits_v1 WHERE airline_id=a.id;
 INSERT INTO cert_signed_fixture_14aa.licence2_directed_route_allocations_v1 SELECT * FROM airlinerra_game.licence2_directed_route_allocations_v1 WHERE airline_id=a.id;
 INSERT INTO cert_signed_fixture_14aa.airport_offices SELECT * FROM airlinerra_game.airport_offices WHERE airline_id=a.id;
 INSERT INTO cert_signed_fixture_14aa.section9_activation_release_policy_v1 SELECT * FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 INSERT INTO cert_signed_fixture_14aa.airline_flight_schedule_drafts_v1(world_id,airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified,departure_stand_type,arrival_stand_type)
 VALUES(1,a.id,aircraft.id,aircraft.configuration_id,a.iata_code||'973',orig,dest,dep,arr,weekly,'{}'::jsonb,a.owner_player_id,'draft',false,'terminal','terminal') RETURNING id INTO sc;
 INSERT INTO cert_signed_fixture_14aa.section9_verified_schedule_capacity_v1(schedule_id,airline_id,schedule_version,passenger_seats,cargo_capacity_tonnes,verification_source)
 VALUES(sc,a.id,1,156,0,'verified_test_capacity_14z');
 restriction:=cert_signed_fixture_14aa.section5_weekly_route_restriction_gate_v1(1::smallint,orig,dest,aircraft.configuration_id,dep,arr,weekly);
 IF NOT cert_signed_fixture_14aa.section9_game_route_restrictions_valid_v1(orig,dest,restriction)
 THEN RAISE EXCEPTION 'eligible domestic game airport restrictions rejected %',restriction;END IF;
 INSERT INTO cert_signed_fixture_14aa.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT sc,1,airport_key,stand_type,direction,weekday,minute_of_day FROM cert_signed_fixture_14aa.section6_weekly_slot_proposals_v1(1::smallint,orig,dest,dep,arr,weekly,'terminal','terminal');
 verdict:=cert_signed_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'verified_game_airport_slots' OR verdict->>'verified'<>'true' OR (verdict->>'reservedSlots')::int<>2
 THEN RAISE EXCEPTION 'actual reserved airport slots rejected %',verdict;END IF;
 UPDATE cert_signed_fixture_14aa.section6_weekly_airport_slot_reservations_v1 SET minute_of_day=minute_of_day+10 WHERE schedule_id=sc AND airport_key=orig AND direction='departure';
 verdict:=cert_signed_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'blocked_slot_clearance_evidence' OR NOT verdict->'blockers' ? 'RECURRING_SLOT_RESERVATIONS_MISMATCH'
 THEN RAISE EXCEPTION 'mismatched slot accepted %',verdict;END IF;
 DELETE FROM cert_signed_fixture_14aa.section6_weekly_airport_slot_reservations_v1 WHERE schedule_id=sc;
 INSERT INTO cert_signed_fixture_14aa.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT sc,1,airport_key,stand_type,direction,weekday,minute_of_day FROM cert_signed_fixture_14aa.section6_weekly_slot_proposals_v1(1::smallint,orig,dest,dep,arr,weekly,'terminal','terminal');
 UPDATE cert_signed_fixture_14aa.section6_airport_slot_capacity_v1 SET terminal_stands=1,terminal_per_direction_10m=1 WHERE airport_key=orig;
 INSERT INTO cert_signed_fixture_14aa.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT gen_random_uuid(),world_id,airport_key,stand_type,direction,weekday,minute_of_day FROM cert_signed_fixture_14aa.section6_weekly_airport_slot_reservations_v1
 WHERE schedule_id=sc AND airport_key=orig AND direction='departure';
 verdict:=cert_signed_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'blocked_slot_clearance_evidence' OR NOT verdict->'blockers' ? 'AIRPORT_CAPACITY_RECHECK_FAILED'
 THEN RAISE EXCEPTION 'oversubscribed hour or 10-minute stand accepted %',verdict;END IF;
 DELETE FROM cert_signed_fixture_14aa.section6_weekly_airport_slot_reservations_v1 WHERE schedule_id<>sc;
 UPDATE cert_signed_fixture_14aa.section6_airport_slot_capacity_v1 SET terminal_stands=0,terminal_per_direction_10m=0 WHERE airport_key=orig;
 verdict:=cert_signed_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'blocked_slot_clearance_evidence' OR NOT verdict->'blockers' ? 'AIRPORT_CAPACITY_RECHECK_FAILED'
 THEN RAISE EXCEPTION 'airport without capacity approved %',verdict;END IF;
 IF cert_signed_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day+1)->>'status'<>'blocked_unverified_world_or_game_day'
 THEN RAISE EXCEPTION 'unverified game day approved';END IF;

 -- Restore the actual game capacity values after the negative cases.
 UPDATE cert_signed_fixture_14aa.section6_airport_slot_capacity_v1 c SET
 terminal_stands=real.terminal_stands,terminal_per_direction_10m=real.terminal_per_direction_10m
 FROM airlinerra_game.section6_airport_slot_capacity_v1 real
 WHERE real.world_id=c.world_id AND real.airport_key=c.airport_key;
 -- Three different independent game source verifiers go through the real
 -- production certificate issuer and the real certification-event sink.
 FOR rr IN SELECT * FROM (VALUES
  ('operator_licence','cert_signed_fixture_14aa_clearance_operator_licence_v1'),
  ('route_traffic_rights','cert_signed_fixture_14aa_clearance_route_traffic_rights_v1'),
  ('airport_slot_capacity','cert_signed_fixture_14aa_clearance_airport_slot_capacity_v1')
 ) types(clearance_type,key_name) LOOP
  verdict:=cert_signed_fixture_14aa.section9_issue_queued_game_clearance_v1(a.id,sc,1,game_day,rr.clearance_type);
  IF verdict->>'status'<>'certification_event_recorded' OR verdict->>'certificateChanged'<>'true'
  THEN RAISE EXCEPTION 'real signed clearance failed % %',rr.clearance_type,verdict;END IF;
  -- HMAC is recomputed locally from the game-only test secret, without touching
  -- production Vault or representing this as real issued flight authority.
  SELECT e.* INTO STRICT proof FROM cert_signed_fixture_14aa.section9_operational_certification_events_v1 e WHERE e.event_id=verdict->>'eventId';
  hmac_payload:=concat_ws(E'\n','airlinerra-verified-operations-certification-v1','1','1',
   a.id::text,sc::text,'1',rr.clearance_type,proof.source_kind,'certify',proof.event_id,
   proof.source_reference,proof.reviewer_reference,game_day::text,(game_day+28)::text);
  SELECT decrypted_secret INTO game_key FROM cert_signed_fixture_14aa.test_signer WHERE name=rr.key_name;
  evsign:=encode(extensions.hmac(convert_to(hmac_payload,'UTF8'),convert_to(game_key,'UTF8'),'sha256'),'hex');
  IF proof.verified_hmac_sha256<>evsign THEN RAISE EXCEPTION 'event signer digest inconsistent';END IF;
  verdict:=cert_signed_fixture_14aa.section9_issue_queued_game_clearance_v1(a.id,sc,1,game_day,rr.clearance_type);
  IF verdict->>'status'<>'certification_event_replayed' OR verdict->>'certificateChanged'<>'false'
  THEN RAISE EXCEPTION 'event signer replay mutated certification %',verdict;END IF;
 END LOOP;
 SELECT count(*) INTO certificate_count FROM cert_signed_fixture_14aa.section9_schedule_operational_certifications_v1 WHERE schedule_id=sc AND review_status='certified';
 IF certificate_count<>3 THEN RAISE EXCEPTION 'must have 3 certified source types not %',certificate_count;END IF;
 -- Execution/finance approvals are absent. An otherwise 3-source-verified
 -- flight must never be activated or have a booking created.
 verdict:=cert_signed_fixture_14aa.section9_commit_certified_schedule_activation_v1(a.owner_player_id,a.id,sc,1,game_day,28);
 IF verdict->>'scheduleActivated'<>'false' OR verdict->>'status'<>'blocked_activation_not_fully_certified'
 THEN RAISE EXCEPTION 'flight activated without execution/finance %',verdict;END IF;
 INSERT INTO cert_signed_fixture_14aa.section9_schedule_activation_preparations_v1(schedule_id,schedule_version,airline_id,aircraft_inventory_id,verified_game_date,certified_horizon_days,fingerprint_md5,release_reference)
 VALUES(sc,1,a.id,aircraft.id,game_day,28,repeat('c',32),'test-only-signed-cache-14aa');
 -- Revocation must delete the saved approval, even if a certificate was
 -- previously signed and had matching source evidence.
 SELECT * INTO STRICT proof FROM cert_signed_fixture_14aa.section9_schedule_operational_certifications_v1
 WHERE schedule_id=sc AND clearance_type='route_traffic_rights';
 revoked_event:='game-route-rights-revoke-14aa-'||replace(sc::text,'-','');
 hmac_payload:=concat_ws(E'\n','airlinerra-verified-operations-certification-v1','1','1',
 a.id::text,sc::text,'1','route_traffic_rights','verified_game_traffic_rights_engine','revoke',
 revoked_event,'game-route-rights-revoked-14aa','independent-game-traffic-rights-v1',game_day::text,(game_day+28)::text);
 evsign:=encode(extensions.hmac(convert_to(hmac_payload,'UTF8'),convert_to(repeat('T',70),'UTF8'),'sha256'),'hex');
 verdict:=cert_signed_fixture_14aa.section9_record_verified_certification_event_v1(a.id,sc,1,'route_traffic_rights','revoke',revoked_event,
  'game-route-rights-revoked-14aa','independent-game-traffic-rights-v1',game_day,game_day+28,evsign);
 IF verdict->>'status'<>'certification_revoked' OR EXISTS(SELECT 1 FROM cert_signed_fixture_14aa.section9_schedule_activation_preparations_v1 WHERE schedule_id=sc)
 THEN RAISE EXCEPTION 'signed revocation failed to clear cached approval %',verdict;END IF;
 verdict:=cert_signed_fixture_14aa.section9_issue_queued_game_clearance_v1(a.id,sc,1,game_day,'route_traffic_rights');
 IF verdict->>'status'<>'certification_event_replayed' OR
 (SELECT review_status FROM cert_signed_fixture_14aa.section9_schedule_operational_certifications_v1 WHERE schedule_id=sc AND clearance_type='route_traffic_rights')<>'revoked'
 THEN RAISE EXCEPTION 'replayed older certificate resurrected revoked authority %',verdict;END IF;
 IF (SELECT count(*) FROM cert_signed_fixture_14aa.section9_operational_certification_events_v1)<>4 THEN RAISE EXCEPTION 'expected 4 immutable signed events';END IF;
 BEGIN
  UPDATE cert_signed_fixture_14aa.section9_operational_certification_events_v1 SET source_reference='tampered' WHERE event_id=revoked_event;
  RAISE EXCEPTION 'immutable signed audit allowed mutation';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF (SELECT count(*) FROM cert_signed_fixture_14aa.section9_schedule_operational_certifications_v1 WHERE schedule_id=sc AND review_status='certified')<>2
 THEN RAISE EXCEPTION 'revoked state invalid';END IF;
 IF (SELECT status FROM cert_signed_fixture_14aa.airline_flight_schedule_drafts_v1 WHERE id=sc)<>'draft' THEN RAISE EXCEPTION 'certification activated draft';END IF;
 result:=jsonb_build_object('status','passed','actualGameNightAndRunwayRestrictions',true,'actualWeeklySlotProposals',true,'actualHourAndTenMinuteCapacity',true,'matchedReservationsCertified',true,'mismatchedReservationBlocked',true,'zeroStandCapacityBlocked',true,'overbookedStandBlocked',true,'wrongGameDateBlocked',true,'noGameDataMutated',true,'realIndependentCertifierHmac',true,'threeSignedIndependentSources',true,'sourceApprovalIdempotent',true,'revocationInvalidatedPreparation',true,'replayCannotResurrectRevoked',true,'missingFinanceExecutionBlocksActivation',true);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.cert_signed_fixture_14aa',SQLERRM,true);END;
END $slot_fixture$;
SELECT current_setting('airlinerra.cert_signed_fixture_14aa',true)::jsonb result,to_regnamespace('cert_signed_fixture_14aa') IS NULL fixture_removed,(SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1) live_reservations;