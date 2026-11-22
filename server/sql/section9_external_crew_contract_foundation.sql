-- External flight-only game crew. These are aggregate contract seats,
-- never persistent employee profiles, payroll recipients or career records.
CREATE TABLE airlinerra_game.section9_external_crew_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),contracting_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_external_crew_release_v1 VALUES(1,false);
CREATE TABLE airlinerra_game.section9_external_crew_rate_v1(
 role text PRIMARY KEY CHECK(role IN('captain','first_officer','cabin')),hourly_usd numeric(10,2) NOT NULL CHECK(hourly_usd>0)
);
INSERT INTO airlinerra_game.section9_external_crew_rate_v1 VALUES('captain',350),('first_officer',250),('cabin',100);
CREATE TABLE airlinerra_game.section9_external_crew_contracts_v1(
 physical_flight_id text PRIMARY KEY,airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 occurrence_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id),
 schedule_version int NOT NULL,qualification_group text NOT NULL REFERENCES airlinerra_game.section9_pilot_qualification_groups_v1(qualification_group),
 captains int NOT NULL CHECK(captains BETWEEN 0 AND 2),first_officers int NOT NULL CHECK(first_officers BETWEEN 0 AND 2),cabin_crew int NOT NULL CHECK(cabin_crew BETWEEN 0 AND 40),
 captain_rate numeric(10,2) NOT NULL CHECK(captain_rate>0),first_officer_rate numeric(10,2) NOT NULL CHECK(first_officer_rate>0),cabin_rate numeric(10,2) NOT NULL CHECK(cabin_rate>0),
 planned_departure_utc timestamptz NOT NULL,planned_arrival_utc timestamptz NOT NULL,authorized_game_utc timestamptz NOT NULL,
 quoted_cost_usd numeric(16,2) NOT NULL CHECK(quoted_cost_usd>0),
 source_reference text NOT NULL CHECK(length(source_reference) BETWEEN 12 AND 180),
 CHECK(captains+first_officers+cabin_crew>0),CHECK(planned_arrival_utc>planned_departure_utc),CHECK(authorized_game_utc<=planned_departure_utc)
);
CREATE INDEX section9_external_crew_airline_idx ON airlinerra_game.section9_external_crew_contracts_v1(airline_id);
ALTER TABLE airlinerra_game.section9_external_crew_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_external_crew_rate_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_external_crew_contracts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_external_crew_release_v1,airlinerra_game.section9_external_crew_rate_v1,airlinerra_game.section9_external_crew_contracts_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_external_crew_cost_v1(p_captains int,p_first_officers int,p_cabin int,p_captain_rate numeric,p_first_officer_rate numeric,p_cabin_rate numeric,p_minutes numeric)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE STRICT SECURITY INVOKER SET search_path TO pg_catalog AS $$
BEGIN
 IF p_captains NOT BETWEEN 0 AND 2 OR p_first_officers NOT BETWEEN 0 AND 2 OR p_cabin NOT BETWEEN 0 AND 40 OR p_captain_rate NOT BETWEEN 0 AND 100000 OR p_first_officer_rate NOT BETWEEN 0 AND 100000 OR p_cabin_rate NOT BETWEEN 0 AND 100000 OR p_minutes<=0 OR p_minutes>4320 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_EXTERNAL_CREW_COST_INPUT';END IF;
 RETURN round((p_captains*p_captain_rate+p_first_officers*p_first_officer_rate+p_cabin*p_cabin_rate)*p_minutes/60,2);
END $$;
-- Trusted worker quote; actual seat deficits must originate from the validated
-- mixed-roster planner, not from the browser. No operational activation here.
CREATE FUNCTION airlinerra_game.section9_external_crew_quote_v1(p_airline uuid,p_occurrence uuid,p_captains int,p_first_officers int,p_cabin int)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE f record;captain_rate numeric;fo_rate numeric;cabin_rate numeric;required_pilots int;required_cabin int;fee numeric;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT o.*,p.qualification_group,p.seat_basis,p.maximum_cabin_crew INTO f FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version AND s.status='active' AND s.operationally_verified JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=s.configuration_id
 WHERE o.id=p_occurrence AND o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','external_crew_occurrence_unverified');END IF;
 required_pilots:=CASE WHEN f.arrival_utc-f.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 required_cabin:=CASE WHEN f.seat_basis='cargo_zero' OR f.verified_passenger_seats<=19 THEN 0 ELSE (f.verified_passenger_seats+49)/50 END;
 IF f.arrival_utc-f.departure_utc>interval '9 hours 30 minutes' OR required_cabin>f.maximum_cabin_crew OR p_captains IS NULL OR p_first_officers IS NULL OR p_cabin IS NULL OR p_captains NOT BETWEEN 0 AND required_pilots OR p_first_officers NOT BETWEEN 0 AND required_pilots OR p_cabin NOT BETWEEN 0 AND required_cabin OR p_captains+p_first_officers+p_cabin=0 THEN RETURN jsonb_build_object('status','external_crew_counts_invalid');END IF;
 SELECT hourly_usd INTO STRICT captain_rate FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='captain';
 SELECT hourly_usd INTO STRICT fo_rate FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='first_officer';
 SELECT hourly_usd INTO STRICT cabin_rate FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='cabin';
 fee:=airlinerra_game.section9_external_crew_cost_v1(p_captains,p_first_officers,p_cabin,captain_rate,fo_rate,cabin_rate,extract(epoch FROM f.arrival_utc-f.departure_utc)/60);
 RETURN jsonb_build_object('status','external_crew_quote','physicalFlightId',f.schedule_id||':'||f.flight_local_date||':'||f.weekly_entry,'occurrenceId',f.id,'scheduleVersion',f.schedule_version,'qualificationGroup',f.qualification_group,'captains',p_captains,'firstOfficers',p_first_officers,'cabinCrew',p_cabin,'captainRateUsd',captain_rate,'firstOfficerRateUsd',fo_rate,'cabinRateUsd',cabin_rate,'plannedDepartureUtc',f.departure_utc,'plannedArrivalUtc',f.arrival_utc,'estimatedCostUsd',fee,'permanentEmployeesCreated',false,'ledgerPosted',false,'contractingEnabled',(SELECT contracting_enabled FROM airlinerra_game.section9_external_crew_release_v1 WHERE world_id=1));
END $$;
-- A private authorization primitive for the future trusted mixed-roster
-- transaction. Until that integration is complete the gate stays FALSE.
CREATE FUNCTION airlinerra_game.section9_authorize_external_crew_v1(p_airline uuid,p_occurrence uuid,p_captains int,p_first_officers int,p_cabin int,p_reference text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE q jsonb;c record;now_utc timestamptz;cash numeric;committed numeric;physical text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_reference IS NULL OR length(p_reference) NOT BETWEEN 12 AND 180 THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 SELECT cash_usd INTO cash FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO c FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE occurrence_id=p_occurrence;
 IF FOUND THEN
 IF c.airline_id<>p_airline OR c.captains IS DISTINCT FROM p_captains OR c.first_officers IS DISTINCT FROM p_first_officers OR c.cabin_crew IS DISTINCT FROM p_cabin OR c.source_reference<>p_reference THEN RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='EXTERNAL_CREW_CONTRACT_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','external_crew_contract_already_authorized','physicalFlightId',c.physical_flight_id,'replayed',true,'ledgerPosted',false);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_release_v1 WHERE world_id=1 AND contracting_enabled) THEN RETURN jsonb_build_object('status','external_crew_contracting_disabled');END IF;
 q:=airlinerra_game.section9_external_crew_quote_v1(p_airline,p_occurrence,p_captains,p_first_officers,p_cabin);
 IF q->>'status'<>'external_crew_quote' THEN RETURN q;END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 physical:=q->>'physicalFlightId';
 IF now_utc>(q->>'plannedDepartureUtc')::timestamptz OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=physical) THEN RETURN jsonb_build_object('status','external_crew_authorization_too_late');END IF;
 -- Conservative affordability check includes existing unposted contracts.
 SELECT coalesce(sum(ec.quoted_cost_usd),0) INTO committed FROM airlinerra_game.section9_external_crew_contracts_v1 ec WHERE ec.airline_id=p_airline AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 f WHERE f.physical_flight_id=ec.physical_flight_id) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=ec.occurrence_id AND o.booking_status='cancelled');
 IF cash<committed+(q->>'estimatedCostUsd')::numeric THEN RETURN jsonb_build_object('status','external_crew_insufficient_funds','quotedCostUsd',q->'estimatedCostUsd','ledgerPosted',false);END IF;
 INSERT INTO airlinerra_game.section9_external_crew_contracts_v1(physical_flight_id,airline_id,occurrence_id,schedule_version,qualification_group,captains,first_officers,cabin_crew,captain_rate,first_officer_rate,cabin_rate,planned_departure_utc,planned_arrival_utc,authorized_game_utc,quoted_cost_usd,source_reference)
 VALUES(physical,p_airline,p_occurrence,(q->>'scheduleVersion')::int,q->>'qualificationGroup',p_captains,p_first_officers,p_cabin,(q->>'captainRateUsd')::numeric,(q->>'firstOfficerRateUsd')::numeric,(q->>'cabinRateUsd')::numeric,(q->>'plannedDepartureUtc')::timestamptz,(q->>'plannedArrivalUtc')::timestamptz,now_utc,(q->>'estimatedCostUsd')::numeric,p_reference);
 RETURN jsonb_build_object('status','external_crew_contract_authorized','physicalFlightId',physical,'quotedCostUsd',q->'estimatedCostUsd','replayed',false,'ledgerPosted',false,'permanentEmployeesCreated',false);
END $$;
-- Called ONLY after independent signed-event HMAC verification by the
-- normal final flight-cost approval/posting path. Rate/counts are frozen.
CREATE FUNCTION airlinerra_game.section9_completed_external_crew_cost_v1(p_airline uuid,p_physical text,p_arrival_event text)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE c record;d record;a record;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO c FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE physical_flight_id=p_physical;
 IF NOT FOUND THEN RETURN 0;END IF;
 IF c.airline_id<>p_airline THEN RAISE EXCEPTION 'EXTERNAL_CREW_AIRLINE_MISMATCH';END IF;
 SELECT * INTO STRICT d FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=p_physical AND airline_id=p_airline AND phase='departed' AND schedule_version=c.schedule_version AND scheduled_departure_utc=c.planned_departure_utc AND scheduled_arrival_utc=c.planned_arrival_utc AND actual_event_utc>=c.authorized_game_utc;
 SELECT * INTO STRICT a FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=p_arrival_event AND flight_occurrence_id=p_physical AND airline_id=p_airline AND phase='arrived' AND aircraft_inventory_id=d.aircraft_inventory_id AND schedule_id=d.schedule_id AND schedule_version=d.schedule_version AND weekly_entry=d.weekly_entry AND flight_local_date=d.flight_local_date AND origin_airport_key=d.origin_airport_key AND destination_airport_key=d.destination_airport_key;
 RETURN airlinerra_game.section9_external_crew_cost_v1(c.captains,c.first_officers,c.cabin_crew,c.captain_rate,c.first_officer_rate,c.cabin_rate,extract(epoch FROM a.actual_event_utc-d.actual_event_utc)/60);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_external_crew_cost_v1(int,int,int,numeric,numeric,numeric,numeric),airlinerra_game.section9_external_crew_quote_v1(uuid,uuid,int,int,int),airlinerra_game.section9_authorize_external_crew_v1(uuid,uuid,int,int,int,text),airlinerra_game.section9_completed_external_crew_cost_v1(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;
