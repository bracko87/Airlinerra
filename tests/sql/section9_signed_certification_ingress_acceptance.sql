-- Phase 14AA regression: legacy fabricated certified events are NO LONGER accepted.
-- Rollback-only against the connected game schema. Real signed happy-path
-- and revoked-event acceptance are in section9_actual_signed_certification_activation_gate_acceptance.sql
-- and section9_complete_five_source_signed_schedule_activation_acceptance.sql.
BEGIN;
DO $negative$
DECLARE a record;plane record;draft uuid;day_now date;denied boolean;kind text;reviewer text;
 before_events bigint;before_certs bigint;before_moves bigint;before_ledger bigint;
BEGIN
 IF has_function_privilege('anon','airlinerra_game.section9_record_verified_certification_event_v1(uuid,uuid,integer,text,text,text,text,text,date,date,text)','EXECUTE')
 OR has_function_privilege('authenticated','airlinerra_game.section9_record_verified_certification_event_v1(uuid,uuid,integer,text,text,text,text,text,date,date,text)','EXECUTE')
 OR has_function_privilege('service_role','airlinerra_game.section9_record_verified_certification_event_v1(uuid,uuid,integer,text,text,text,text,text,date,date,text)','EXECUTE')
 THEN RAISE EXCEPTION 'certification sink exposed to browser or service account';END IF;
 SELECT * INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT * INTO STRICT plane FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=a.id LIMIT 1;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN RAISE EXCEPTION 'game day unavailable';END IF;
 SELECT count(*) INTO before_events FROM airlinerra_game.section9_operational_certification_events_v1;
 SELECT count(*) INTO before_certs FROM airlinerra_game.section9_schedule_operational_certifications_v1;
 SELECT count(*) INTO before_moves FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
 airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,
 reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified)
 VALUES(a.id,plane.id,plane.configuration_id,a.iata_code||'975',a.home_airport_key,'OURAIRPORTS:4612',
 (day_now::timestamp+interval '11 hours') AT TIME ZONE 'Europe/Belgrade',
 (day_now::timestamp+interval '13 hours') AT TIME ZONE 'Europe/Belgrade',
 '[{"day":0,"time":"11:00"}]'::jsonb,'{}'::jsonb,a.owner_player_id,'draft',false)
 RETURNING id INTO draft;
 FOR kind,reviewer IN SELECT * FROM (VALUES
 ('operator_licence','independent-game-licence-authority-v1'),
 ('route_traffic_rights','independent-game-traffic-rights-v1'),
 ('airport_slot_capacity','independent-game-slot-authority-v1'),
 ('trusted_flight_execution','independent-trusted-flight-execution-authority-v1'),
 ('commercial_finance','independent-commercial-finance-authority-v1')) src(kind,reviewer)
 LOOP
  denied:=false;
  BEGIN
   PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
    a.id,draft,1,kind,'certify','synthetic-rejected-14aa-'||replace(draft::text,'-','')||'-'||kind,
    CASE WHEN kind IN('trusted_flight_execution','commercial_finance')
     THEN 'candidate-execution-finance-v1-' ELSE 'synthetic-forged-source-v1-' END||repeat('d',32),
    reviewer,day_now,day_now+28,repeat('f',64));
  EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
  IF NOT denied THEN RAISE EXCEPTION 'legacy synthetic source certificate was accepted: %',kind;END IF;
 END LOOP;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
   a.id,draft,1,'operator_licence','revoke','synthetic-revoke-without-approval-14aa',
   'synthetic-unissued-certificate-14aa','independent-game-licence-authority-v1',
   day_now,day_now+28,repeat('f',64));
 EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'revocation without issued approval was accepted';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1)<>before_events
 OR (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1)<>before_certs
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>before_moves
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_ledger
 THEN RAISE EXCEPTION 'forged certificate test wrote irreversible live records';END IF;
END $negative$;
ROLLBACK;
SELECT jsonb_build_object('status','passed','syntheticFiveSourcesRejected',true,
 'revocationWithoutCertificateRejected',true,'privateSinkProtected',true,
 'allTestDraftWritesRolledBack',true) result;