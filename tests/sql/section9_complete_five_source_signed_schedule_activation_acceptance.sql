-- Section 5+6 actual verifier isolation: no real slot, certification or airline modified.
DO $slot_fixture$
DECLARE t text; cols text; fn record; a record; aircraft record; sc uuid; rr record; hmac_payload text; evsign text; revoked_event text; certificate_count integer; blocker jsonb; proof record; denied boolean:=false; game_key text:=repeat('S',70); game_day date; orig text:='OURAIRPORTS:4610'; dest text:='OURAIRPORTS:4612'; dep timestamptz; arr timestamptz; weekly jsonb:='[{"day":0,"time":"11:00"}]'::jsonb; verdict jsonb; restriction jsonb; result jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA cert_full_fixture_14aa;
 CREATE TABLE cert_full_fixture_14aa.fixture_worlds(id smallint primary key,state text,opens_at timestamptz);
 CREATE TABLE cert_full_fixture_14aa.test_signer(name text primary key,decrypted_secret text not null);
 INSERT INTO cert_full_fixture_14aa.test_signer(name,decrypted_secret) VALUES
 ('cert_full_fixture_14aa_clearance_operator_licence_v1',repeat('S',70)),
 ('cert_full_fixture_14aa_clearance_route_traffic_rights_v1',repeat('T',70)),
 ('cert_full_fixture_14aa_clearance_airport_slot_capacity_v1',repeat('U',70)),('cert_full_fixture_14aa_clearance_trusted_flight_execution_v1',repeat('V',70)),('cert_full_fixture_14aa_clearance_commercial_finance_v1',repeat('W',70));
 INSERT INTO cert_full_fixture_14aa.fixture_worlds VALUES(1,'active',now()-interval '3 days');
 FOREACH t IN ARRAY ARRAY['airlines','airline_aircraft_inventory','airline_flight_schedule_drafts_v1','airport_reference_profiles','section9_maintenance_relocation_trips_v1','section9_dated_flight_occurrences_v1','section9_operated_flight_movements_v1',
 'holding_world_clock_v1','section9_verified_game_tick_receipts_v1',
 'section6_airport_slot_capacity_v1','section6_weekly_airport_slot_reservations_v1',
 'section9_verified_schedule_capacity_v1','section9_aoc_operating_companies_v1','section9_aoc_release_policy_v1','section9_aoc_certificates_v1','section9_aoc_safety_incidents_v1','section9_aoc_corrective_tasks_v1','section9_aoc_independent_correction_release_v1','section9_aoc_compliance_receipts_v1','section9_aoc_verified_correction_proofs_v1','section9_game_maintenance_service_receipts_v1','section9_game_permission_applications_v1','section9_operator_licence_evidence_v1','airline_ledger','aviation_countries_v1','airport_offices','licence2_directed_route_allocations_v1','licence2_market_policy_v1','licence2_market_levels_v1','licence2_airline_market_permits_v1','section9_operational_certification_events_v1','section9_schedule_operational_certifications_v1','section9_schedule_activation_preparations_v1','section9_activation_release_policy_v1','section9_weekly_crew_duty_proposals_v1','section9_airline_crew_roster_v1','section9_route_operating_permission_evidence_v1','section9_trusted_execution_release_policy_v1','section9_flight_finance_posting_release_v1','section9_fuel_and_settlement_release_policy_v1','section9_clock_producer_schedule_v1'] LOOP
  EXECUTE format('CREATE TABLE cert_full_fixture_14aa.%I (LIKE airlinerra_game.%I INCLUDING ALL)',t,t);
 END LOOP;
 SELECT * INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT * INTO STRICT aircraft FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=a.id LIMIT 1;
 game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF game_day IS NULL THEN RAISE EXCEPTION 'verified game-day fixture unavailable';END IF;
 dep:=((game_day+((8-extract(isodow FROM game_day)::integer)%7))::timestamp+interval '11 hours') AT TIME ZONE 'Europe/Belgrade';
 arr:=dep+interval '2 hours';
 FOREACH t IN ARRAY ARRAY['airport_unified_operations_v1','section5_airport_operating_policy_v1','section5_airport_simplified_game_rules_v1',
 'airport_runway_inventory','airport_runway_source_status_evidence','airport_sections1_8_combined_members_v1','section5_airport_batch50_screen_v1',
 'section5_airport_icao_chapter_policy_v2','section5_airport_official_noise_rules_v2','section5_airport_time_restrictions_v1',
 'section5_full_weight_airport_aircraft_screen_v2','section5_runway_specific_restrictions_v1'] LOOP
  EXECUTE format('CREATE TABLE cert_full_fixture_14aa.%I AS SELECT * FROM airlinerra_game.%I WHERE world_id=1 AND airport_key=ANY($1)',t,t) USING ARRAY[orig,dest];
 END LOOP;
 CREATE TABLE cert_full_fixture_14aa.section9_flight_engine_readiness_audit_v1 AS SELECT * FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 CREATE TABLE cert_full_fixture_14aa.section5_icao_aircraft_certification_v2 AS SELECT * FROM airlinerra_game.section5_icao_aircraft_certification_v2 WHERE configuration_id=aircraft.configuration_id;
 FOR fn IN SELECT pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='airlinerra_game'::regnamespace AND proname IN (
 'section5_local_restriction_window_match_v1','section5_universal_airport_leg_restriction_v1','section5_simplified_airport_leg_screen_v1',
 'section5_universal_route_restriction_gate_v1','section5_batch_route_restriction_screen_v1','section5_weekly_route_restriction_gate_v1',
 'section9_game_route_restrictions_valid_v1','section6_weekly_slot_proposals_v1','section6_weekly_slot_preflight_v1','section9_verify_slot_clearance_source_v1',
 'section9_verified_permission_game_day_v1','section9_aoc_safety_score_v1','section9_aoc_flight_release_readiness_v1','section9_canonical_aoc_covers_v1',
 'section9_verify_game_operator_licence_v1','section9_verify_game_route_traffic_rights_v1','section9_game_route_licence_scope_v1',
 'licence2_foreign_route_preview_v1','licence2_country_market_v1',
 'section9_issue_queued_game_clearance_v1','section9_record_verified_certification_event_v1',
 'section9_prepare_certified_schedule_activation_v1','section9_commit_certified_schedule_activation_v1',
 'section9_activation_evidence_fingerprint_v1','section9_guard_schedule_activation_update_v1','section9_reject_certificate_audit_mutation_v1','section9_cancel_certified_draft_and_release_slots_v1','section9_verified_berlin_game_hour_v1','section9_execution_finance_certificate_source_preflight_v1','section9_execution_finance_source_snapshot_v1','section9_recheck_execution_finance_source_reference_v1'
 ) LOOP
  EXECUTE replace(replace(replace(fn.def,'airlinerra_game','cert_full_fixture_14aa'),'public.cert_full_fixture_14aa_worlds','cert_full_fixture_14aa.fixture_worlds'),'vault.decrypted_secrets','cert_full_fixture_14aa.test_signer');
 END LOOP;
 EXECUTE $stubs$CREATE FUNCTION cert_full_fixture_14aa.section9_owned_crew_licence_preflight_v1(uuid,uuid,uuid,date,integer) RETURNS jsonb LANGUAGE sql STABLE AS $body$
 SELECT jsonb_build_object('readOnly',true,'permissions',jsonb_build_object('gameOperatorLicenceEvidenceRecorded',true,'requiredServiceTypes',1,'gameRoutePermissionEvidenceRecorded',1)) $body$; $stubs$;
 EXECUTE $stubs$CREATE FUNCTION cert_full_fixture_14aa.section9_owned_commercial_activation_preflight_v1(uuid,uuid,uuid,date,integer) RETURNS jsonb LANGUAGE sql STABLE AS $body$
 SELECT jsonb_build_object('readOnly',true,'canActivateNormalFlight',false,'activationChecklist',jsonb_build_object('airportRestrictionPreviewPassed',true,'aircraftRotationPreviewConflictFree',true,'departureArrivalSlotRecordsPresent',true,'aircraftDeliveryAnchorVerified',true,'aircraftInFlight',false,'lastVerifiedGroundAirport','OURAIRPORTS:4610','operatorLicenceEvidenceRecorded',true,'routePermissionEvidenceComplete',true,'worldClockConnected',true),
 'turnaround',jsonb_build_object('shortTurnaroundOccurrences',0,'minimumMinutes',45)) $body$; $stubs$;
 EXECUTE $stubs$CREATE TRIGGER fixture_signed_event_immutable BEFORE DELETE OR UPDATE ON cert_full_fixture_14aa.section9_operational_certification_events_v1 FOR EACH ROW EXECUTE FUNCTION cert_full_fixture_14aa.section9_reject_certificate_audit_mutation_v1() $stubs$;
 EXECUTE $stubs$CREATE TRIGGER fixture_schedule_activation_guard BEFORE INSERT OR UPDATE ON cert_full_fixture_14aa.airline_flight_schedule_drafts_v1 FOR EACH ROW EXECUTE FUNCTION cert_full_fixture_14aa.section9_guard_schedule_activation_update_v1() $stubs$;
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO cols FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO cert_full_fixture_14aa.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',cols,cols) USING ARRAY[orig,dest];
 INSERT INTO cert_full_fixture_14aa.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO cert_full_fixture_14aa.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=aircraft.id;
 INSERT INTO cert_full_fixture_14aa.holding_world_clock_v1 SELECT * FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 INSERT INTO cert_full_fixture_14aa.section9_verified_game_tick_receipts_v1 SELECT * FROM airlinerra_game.section9_verified_game_tick_receipts_v1 WHERE world_id=1 AND game_date=game_day;
 INSERT INTO cert_full_fixture_14aa.section6_airport_slot_capacity_v1 SELECT * FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=1 AND airport_key IN(orig,dest);
 INSERT INTO cert_full_fixture_14aa.section9_aoc_operating_companies_v1 SELECT * FROM airlinerra_game.section9_aoc_operating_companies_v1 WHERE airline_id=a.id;
 INSERT INTO cert_full_fixture_14aa.section9_aoc_release_policy_v1 SELECT * FROM airlinerra_game.section9_aoc_release_policy_v1 WHERE world_id=1;
 INSERT INTO cert_full_fixture_14aa.section9_aoc_certificates_v1 SELECT * FROM airlinerra_game.section9_aoc_certificates_v1 WHERE airline_id=a.id;
 INSERT INTO cert_full_fixture_14aa.aviation_countries_v1 SELECT * FROM airlinerra_game.aviation_countries_v1;
 INSERT INTO cert_full_fixture_14aa.licence2_market_policy_v1 SELECT * FROM airlinerra_game.licence2_market_policy_v1;
 INSERT INTO cert_full_fixture_14aa.licence2_market_levels_v1 SELECT * FROM airlinerra_game.licence2_market_levels_v1;
 INSERT INTO cert_full_fixture_14aa.licence2_airline_market_permits_v1 SELECT * FROM airlinerra_game.licence2_airline_market_permits_v1 WHERE airline_id=a.id;
 INSERT INTO cert_full_fixture_14aa.licence2_directed_route_allocations_v1 SELECT * FROM airlinerra_game.licence2_directed_route_allocations_v1 WHERE airline_id=a.id;
 INSERT INTO cert_full_fixture_14aa.airport_offices SELECT * FROM airlinerra_game.airport_offices WHERE airline_id=a.id;
 CREATE TABLE cert_full_fixture_14aa.section9_game_fuel_model_snapshot_v1 AS SELECT * FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 WHERE configuration_id=aircraft.configuration_id;
 INSERT INTO cert_full_fixture_14aa.section9_activation_release_policy_v1 SELECT * FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 INSERT INTO cert_full_fixture_14aa.section9_trusted_execution_release_policy_v1 SELECT * FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 INSERT INTO cert_full_fixture_14aa.section9_flight_finance_posting_release_v1 SELECT * FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1;
 INSERT INTO cert_full_fixture_14aa.section9_fuel_and_settlement_release_policy_v1 SELECT * FROM airlinerra_game.section9_fuel_and_settlement_release_policy_v1 WHERE world_id=1;
 INSERT INTO cert_full_fixture_14aa.section9_clock_producer_schedule_v1 SELECT * FROM airlinerra_game.section9_clock_producer_schedule_v1 WHERE world_id=1;
 INSERT INTO cert_full_fixture_14aa.airline_flight_schedule_drafts_v1(world_id,airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified,departure_stand_type,arrival_stand_type)
 VALUES(1,a.id,aircraft.id,aircraft.configuration_id,a.iata_code||'973',orig,dest,dep,arr,weekly,'{}'::jsonb,a.owner_player_id,'draft',false,'terminal','terminal') RETURNING id INTO sc;
 INSERT INTO cert_full_fixture_14aa.section9_verified_schedule_capacity_v1(schedule_id,airline_id,schedule_version,passenger_seats,cargo_capacity_tonnes,verification_source)
 VALUES(sc,a.id,1,156,0,'verified_test_capacity_14z');
 restriction:=cert_full_fixture_14aa.section5_weekly_route_restriction_gate_v1(1::smallint,orig,dest,aircraft.configuration_id,dep,arr,weekly);
 IF NOT cert_full_fixture_14aa.section9_game_route_restrictions_valid_v1(orig,dest,restriction)
 THEN RAISE EXCEPTION 'eligible domestic game airport restrictions rejected %',restriction;END IF;
 INSERT INTO cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT sc,1,airport_key,stand_type,direction,weekday,minute_of_day FROM cert_full_fixture_14aa.section6_weekly_slot_proposals_v1(1::smallint,orig,dest,dep,arr,weekly,'terminal','terminal');
 verdict:=cert_full_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'verified_game_airport_slots' OR verdict->>'verified'<>'true' OR (verdict->>'reservedSlots')::int<>2
 THEN RAISE EXCEPTION 'actual reserved airport slots rejected %',verdict;END IF;
 UPDATE cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1 SET minute_of_day=minute_of_day+10 WHERE schedule_id=sc AND airport_key=orig AND direction='departure';
 verdict:=cert_full_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'blocked_slot_clearance_evidence' OR NOT verdict->'blockers' ? 'RECURRING_SLOT_RESERVATIONS_MISMATCH'
 THEN RAISE EXCEPTION 'mismatched slot accepted %',verdict;END IF;
 DELETE FROM cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1 WHERE schedule_id=sc;
 INSERT INTO cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT sc,1,airport_key,stand_type,direction,weekday,minute_of_day FROM cert_full_fixture_14aa.section6_weekly_slot_proposals_v1(1::smallint,orig,dest,dep,arr,weekly,'terminal','terminal');
 UPDATE cert_full_fixture_14aa.section6_airport_slot_capacity_v1 SET terminal_stands=1,terminal_per_direction_10m=1 WHERE airport_key=orig;
 INSERT INTO cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1(schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT gen_random_uuid(),world_id,airport_key,stand_type,direction,weekday,minute_of_day FROM cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1
 WHERE schedule_id=sc AND airport_key=orig AND direction='departure';
 verdict:=cert_full_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'blocked_slot_clearance_evidence' OR NOT verdict->'blockers' ? 'AIRPORT_CAPACITY_RECHECK_FAILED'
 THEN RAISE EXCEPTION 'oversubscribed hour or 10-minute stand accepted %',verdict;END IF;
 DELETE FROM cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1 WHERE schedule_id<>sc;
 UPDATE cert_full_fixture_14aa.section6_airport_slot_capacity_v1 SET terminal_stands=0,terminal_per_direction_10m=0 WHERE airport_key=orig;
 verdict:=cert_full_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day);
 IF verdict->>'status'<>'blocked_slot_clearance_evidence' OR NOT verdict->'blockers' ? 'AIRPORT_CAPACITY_RECHECK_FAILED'
 THEN RAISE EXCEPTION 'airport without capacity approved %',verdict;END IF;
 IF cert_full_fixture_14aa.section9_verify_slot_clearance_source_v1(a.id,sc,1,game_day+1)->>'status'<>'blocked_unverified_world_or_game_day'
 THEN RAISE EXCEPTION 'unverified game day approved';END IF;

 -- Restore the actual game capacity values after the negative cases.
 UPDATE cert_full_fixture_14aa.section6_airport_slot_capacity_v1 c SET
 terminal_stands=real.terminal_stands,terminal_per_direction_10m=real.terminal_per_direction_10m
 FROM airlinerra_game.section6_airport_slot_capacity_v1 real
 WHERE real.world_id=c.world_id AND real.airport_key=c.airport_key;
 -- Three different independent game source verifiers go through the real
 -- production certificate issuer and the real certification-event sink.
 FOR rr IN SELECT * FROM (VALUES
  ('operator_licence','cert_full_fixture_14aa_clearance_operator_licence_v1'),
  ('route_traffic_rights','cert_full_fixture_14aa_clearance_route_traffic_rights_v1'),
  ('airport_slot_capacity','cert_full_fixture_14aa_clearance_airport_slot_capacity_v1')
 ) types(clearance_type,key_name) LOOP
  verdict:=cert_full_fixture_14aa.section9_issue_queued_game_clearance_v1(a.id,sc,1,game_day,rr.clearance_type);
  IF verdict->>'status'<>'certification_event_recorded' OR verdict->>'certificateChanged'<>'true'
  THEN RAISE EXCEPTION 'real signed clearance failed % %',rr.clearance_type,verdict;END IF;
  -- HMAC is recomputed locally from the game-only test secret, without touching
  -- production Vault or representing this as real issued flight authority.
  SELECT e.* INTO STRICT proof FROM cert_full_fixture_14aa.section9_operational_certification_events_v1 e WHERE e.event_id=verdict->>'eventId';
  hmac_payload:=concat_ws(E'\n','airlinerra-verified-operations-certification-v1','1','1',
   a.id::text,sc::text,'1',rr.clearance_type,proof.source_kind,'certify',proof.event_id,
   proof.source_reference,proof.reviewer_reference,game_day::text,(game_day+28)::text);
  SELECT decrypted_secret INTO game_key FROM cert_full_fixture_14aa.test_signer WHERE name=rr.key_name;
  evsign:=encode(extensions.hmac(convert_to(hmac_payload,'UTF8'),convert_to(game_key,'UTF8'),'sha256'),'hex');
  IF proof.verified_hmac_sha256<>evsign THEN RAISE EXCEPTION 'event signer digest inconsistent';END IF;
  verdict:=cert_full_fixture_14aa.section9_issue_queued_game_clearance_v1(a.id,sc,1,game_day,rr.clearance_type);
  IF verdict->>'status'<>'certification_event_replayed' OR verdict->>'certificateChanged'<>'false'
  THEN RAISE EXCEPTION 'event signer replay mutated certification %',verdict;END IF;
 END LOOP;
 SELECT count(*) INTO certificate_count FROM cert_full_fixture_14aa.section9_schedule_operational_certifications_v1 WHERE schedule_id=sc AND review_status='certified';
 IF certificate_count<>3 THEN RAISE EXCEPTION 'must have 3 certified source types not %',certificate_count;END IF;
 -- Sources 4 and 5 may be certified only after the independent
 -- real AOC, traffic-rights and airport-slot signed event reconciliation.
 FOR rr IN SELECT * FROM (VALUES
 ('trusted_flight_execution'),('commercial_finance')) keys(clearance_type) LOOP
  verdict:=cert_full_fixture_14aa.section9_issue_queued_game_clearance_v1(a.id,sc,1,game_day,rr.clearance_type);
  IF verdict->>'status'<>'certification_event_recorded' THEN RAISE EXCEPTION 'final real signed clearance failed % %',rr.clearance_type,verdict;END IF;
 END LOOP;
 SELECT count(*) INTO certificate_count FROM cert_full_fixture_14aa.section9_schedule_operational_certifications_v1 WHERE schedule_id=sc AND review_status='certified';
 IF certificate_count<>5 THEN RAISE EXCEPTION 'five signatures missing %',certificate_count;END IF;
 verdict:=cert_full_fixture_14aa.section9_prepare_certified_schedule_activation_v1(a.owner_player_id,a.id,sc,1,game_day,28);
 IF verdict->>'status'<>'prepared_for_future_activation_commit' OR verdict->>'prepared'<>'true'
 THEN RAISE EXCEPTION 'real five-source preparation rejected %',verdict;END IF;
 UPDATE cert_full_fixture_14aa.section9_schedule_operational_certifications_v1 SET valid_to_game_date=game_day+7
 WHERE schedule_id=sc AND clearance_type='operator_licence';
 verdict:=cert_full_fixture_14aa.section9_prepare_certified_schedule_activation_v1(a.owner_player_id,a.id,sc,1,game_day,28);
 IF verdict->>'status'<>'blocked_activation_preparation'
 OR (verdict->>'acceptedCertifications')::int<>4
 OR NOT verdict->'blockers' ? 'FIVE_NON_CREW_OPERATIONAL_CERTIFICATIONS_MISSING'
 THEN RAISE EXCEPTION 'shortened certificate accepted %',verdict;END IF;
 UPDATE cert_full_fixture_14aa.section9_schedule_operational_certifications_v1 SET valid_to_game_date=game_day+28
 WHERE schedule_id=sc AND clearance_type='operator_licence';
 UPDATE cert_full_fixture_14aa.section9_aoc_certificates_v1 SET status='expired' WHERE airline_id=a.id;
 verdict:=cert_full_fixture_14aa.section9_commit_certified_schedule_activation_v1(a.owner_player_id,a.id,sc,1,game_day,28);
 IF verdict->>'status'<>'blocked_activation_not_fully_certified' THEN RAISE EXCEPTION 'expired operator still activated %',verdict;END IF;
 UPDATE cert_full_fixture_14aa.section9_aoc_certificates_v1 SET status='active' WHERE airline_id=a.id;
 UPDATE cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1 SET minute_of_day=minute_of_day+10 WHERE schedule_id=sc AND direction='departure';
 verdict:=cert_full_fixture_14aa.section9_commit_certified_schedule_activation_v1(a.owner_player_id,a.id,sc,1,game_day,28);
 IF verdict->>'status'<>'blocked_activation_not_fully_certified' THEN RAISE EXCEPTION 'altered slot cert still activated %',verdict;END IF;
 UPDATE cert_full_fixture_14aa.section6_weekly_airport_slot_reservations_v1 SET minute_of_day=minute_of_day-10 WHERE schedule_id=sc AND direction='departure';
 verdict:=cert_full_fixture_14aa.section9_commit_certified_schedule_activation_v1(a.owner_player_id,a.id,sc,1,game_day,28);
 IF verdict->>'status'<>'certified_schedule_activated' OR verdict->>'scheduleActivated'<>'true'
 OR verdict->>'flightActivated'<>'false' OR verdict->>'bookingsCreated'<>'false'
 OR (SELECT status FROM cert_full_fixture_14aa.airline_flight_schedule_drafts_v1 WHERE id=sc)<>'active'
 THEN RAISE EXCEPTION 'five sources complete but schedule did not activate %',verdict;END IF;
 verdict:=cert_full_fixture_14aa.section9_cancel_certified_draft_and_release_slots_v1(a.owner_player_id,a.id,sc,1);
 IF verdict->>'status'<>'blocked_only_unactivated_draft_cancellable' THEN RAISE EXCEPTION 'active schedule cancelled as draft %',verdict;END IF;
 result:=jsonb_build_object('status','passed','fiveRealSourceSignedCertifications',true,'schedulePreparedAndActivated',true,
 'shortenedCertificationHorizonBlocks',true,'expiredAocAfterSigningBlocks',true,'staleAirportReservationsBlock',true,
 'activeScheduleCannotUseDraftCancellation',true,'actualPassengerFlightsExecuted',false,'actualTicketBookingsCreated',false,'realPlayerDataTouched',false);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.cert_full_fixture_14aa',SQLERRM,true);END;
END $slot_fixture$;
SELECT current_setting('airlinerra.cert_full_fixture_14aa',true)::jsonb result,to_regnamespace('cert_full_fixture_14aa') IS NULL fixture_removed,(SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1) live_reservations;