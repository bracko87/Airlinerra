-- Rollback-only World 1 licence + route-rights verifier acceptance.
-- No game licence rules are enabled and no real licence is granted.
BEGIN;
DO $test$
DECLARE
 a uuid;owner_id uuid;home text;code text;home_iso text;
 plane uuid;draft uuid;destination_key text;service_role text;
 verdict jsonb;before_licenses bigint;before_routes bigint;
 before_certs bigint;before_events bigint;before_movements bigint;
 before_positions bigint;before_ledger bigint;
BEGIN
 IF has_function_privilege('anon',
  'airlinerra_game.section9_verify_game_operator_licence_v1(uuid,uuid,integer,date)',
  'EXECUTE') OR
  has_function_privilege('authenticated',
  'airlinerra_game.section9_verify_game_route_traffic_rights_v1(uuid,uuid,integer,date)',
  'EXECUTE')
 THEN RAISE EXCEPTION 'Browser can access private game licence source';END IF;
 SELECT count(*) INTO before_licenses
  FROM airlinerra_game.section9_operator_licence_evidence_v1;
 SELECT count(*) INTO before_routes
  FROM airlinerra_game.section9_route_operating_permission_evidence_v1;
 SELECT count(*) INTO before_certs
  FROM airlinerra_game.section9_schedule_operational_certifications_v1;
 SELECT count(*) INTO before_events
  FROM airlinerra_game.section9_operational_certification_events_v1;
 SELECT count(*) INTO before_movements
  FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO before_positions
  FROM airlinerra_game.section9_aircraft_current_position_v1;
 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;

 SELECT airline.id,airline.owner_player_id,airline.home_airport_key,
  airline.iata_code,profile.country_iso
 INTO a,owner_id,home,code,home_iso
 FROM airlinerra_game.airlines airline
 JOIN airlinerra_game.airport_reference_profiles profile
  ON profile.world_id=airline.world_id
  AND profile.airport_key=airline.home_airport_key
 WHERE airline.world_id=1 AND profile.country_iso IS NOT NULL LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'Fixture needs one World 1 airline';END IF;
 destination_key:=CASE WHEN home='OURAIRPORTS:2212'
 THEN 'OURAIRPORTS:4610' ELSE 'OURAIRPORTS:2212' END;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'S9-LIC-ROLLBACK','owned','in_service') RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,
  reference_departure_utc,reference_arrival_utc,
  weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,plane,3,code||'960',home,destination_key,
  '2000-01-03T09:00:00Z','2000-01-03T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,
  '{}'::jsonb,owner_id) RETURNING id INTO draft;

 verdict:=airlinerra_game.section9_verify_game_operator_licence_v1(
  a,draft,1,DATE '2000-01-03');
 IF verdict->>'status'<>'blocked_unverified_world_or_game_day'
  OR verdict->>'verified'<>'false'
 THEN RAISE EXCEPTION 'Unopened world issued licence: %',verdict;END IF;
 verdict:=airlinerra_game.section9_verify_game_operator_licence_v1(
  a,draft,2,DATE '2000-01-03');
 IF verdict->>'status'<>'blocked_stale_or_non_draft_schedule'
 THEN RAISE EXCEPTION 'Stale schedule was verified: %',verdict;END IF;

 -- Signed clock state simulated only inside this rollback transaction.
 UPDATE public.airlinerra_game_worlds SET state='active',
  opens_at=clock_timestamp()-interval '7 days' WHERE id=1;
 UPDATE airlinerra_game.holding_world_clock_v1
 SET clock_source='authoritative_game_engine',
  confirmed_game_date=DATE '2000-01-03',
  engine_proof_ref='ROLLBACK_SIGNED_LICENCE_RIGHTS_20000103',
  last_verified_at=clock_timestamp() WHERE world_id=1;
 INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1(
  world_id,game_date,engine_event_id,event_hmac_sha256,dispatch_kind)
 VALUES(1,DATE '2000-01-03','rollback-game-licence-20000103',
 repeat('e',64),'no_verified_flights');

 INSERT INTO airlinerra_game.section9_operator_licence_evidence_v1(
  world_id,airline_id,jurisdiction_iso2,evidence_status,
  evidence_reference,reviewed_at,valid_from,valid_until)
 VALUES(1,a,home_iso,'verified','ROLLBACK_DUMMY_GAME_OPERATOR_EVIDENCE',
  clock_timestamp()-interval '1 day',
  DATE '2000-01-01',DATE '2000-03-31');
 INSERT INTO airlinerra_game.section9_route_operating_permission_evidence_v1(
  world_id,airline_id,origin_airport_key,destination_airport_key,
  service_type,evidence_status,evidence_reference,reviewed_at,
  valid_from,valid_until)
 VALUES(1,a,home,destination_key,'passenger','verified',
  'ROLLBACK_DUMMY_ROUTE_RIGHTS_EVIDENCE',
  clock_timestamp()-interval '1 day',
  DATE '2000-01-01',DATE '2000-03-31');

 verdict:=airlinerra_game.section9_verify_game_operator_licence_v1(
  a,draft,1,DATE '2000-01-03');
 IF verdict->>'status'<>'blocked_game_operator_licence'
  OR verdict->>'verified'<>'false'
  OR NOT verdict->'blockers' ? 'GAME_OPERATOR_LICENCE_ISSUANCE_DISABLED'
 THEN RAISE EXCEPTION 'Reference-only operator record bypassed game policy: %',verdict;END IF;
 verdict:=airlinerra_game.section9_verify_game_route_traffic_rights_v1(
  a,draft,1,DATE '2000-01-03');
 IF verdict->>'status'<>'blocked_game_route_operator_not_licensed'
  OR verdict->>'verified'<>'false'
 THEN RAISE EXCEPTION 'Unlicensed airline got route traffic grant: %',verdict;END IF;

 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
   a,draft,1,'operator_licence','certify',
   'rollback-fake-operator-game-certification',
   'game-operator-licence-v1-'||repeat('f',32),
   'independent-game-licence-authority-v1',
   DATE '2000-01-03',DATE '2000-01-31',repeat('a',64));
  RAISE EXCEPTION 'Operator certificate accepted without issuance';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
   a,draft,1,'route_traffic_rights','certify',
   'rollback-fake-route-game-certification',
   'game-route-rights-v1-'||repeat('f',32),
   'independent-game-traffic-rights-v1',
   DATE '2000-01-03',DATE '2000-01-31',repeat('b',64));
  RAISE EXCEPTION 'Route certificate accepted without operator';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 verdict:=airlinerra_game.section9_prepare_certified_schedule_activation_v1(
  owner_id,a,draft,1,DATE '2000-01-03',28);
 IF verdict->>'status'<>'blocked_activation_preparation'
  OR NOT verdict->'blockers' ? 'OPERATOR_GAME_LICENCE_SIGNED_PROOF_STALE'
  OR NOT verdict->'blockers' ? 'ROUTE_GAME_RIGHTS_SIGNED_PROOF_STALE'
 THEN RAISE EXCEPTION 'Unverified game permissions bypassed activation: %',verdict;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1)
 <>before_certs OR
 (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1)
 <>before_events OR
 (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)
 <>before_movements OR
 (SELECT count(*) FROM airlinerra_game.section9_aircraft_current_position_v1)
 <>before_positions OR
 (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_ledger
 THEN RAISE EXCEPTION 'Verifier wrote certificate, movement or money';END IF;
 RAISE NOTICE 'PASS: game issuance disabled, verified evidence insufficient, rights dependent on licence, activation protected';
END $test$;
ROLLBACK;