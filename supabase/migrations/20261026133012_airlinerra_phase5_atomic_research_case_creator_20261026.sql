-- Administrative research case intake only. SEC INVOKER, no public EXECUTE.
-- Both the case and all 11 evidence gates initialize atomically.
CREATE OR REPLACE FUNCTION airlinerra.create_faa_operation_research_case(
 p_case_id text,p_cycle date,p_airport_key text,p_runway_pair text,p_runway_end text,
 p_service_class text DEFAULT 'UNSPECIFIED')
RETURNS text
LANGUAGE plpgsql SECURITY INVOKER
SET search_path=airlinerra,pg_temp
AS $body$
DECLARE v_faa text;
DECLARE v_case airlinerra.airport_faa_operation_verification_cases%ROWTYPE;
BEGIN
 SELECT e.faa_identifier INTO v_faa
 FROM airlinerra.airport_faa_nasr_backfill_runway_ends e
 WHERE e.cycle_date=p_cycle AND e.airport_key=p_airport_key
 AND e.runway_pair=p_runway_pair AND e.runway_end=p_runway_end;
 IF NOT FOUND THEN
 RAISE EXCEPTION 'Cannot create case: unrecognized FAA source runway direction';
 END IF;
 IF p_service_class IS NULL OR p_service_class NOT IN
 ('UNSPECIFIED','SCHEDULED_PASSENGER','CHARTER_PASSENGER','CARGO','OTHER_PAID_SERVICE')
 THEN RAISE EXCEPTION 'Invalid service class'; END IF;
 INSERT INTO airlinerra.airport_faa_operation_verification_cases
 (case_id,evidence_cycle,airport_key,faa_identifier,runway_pair,runway_end,service_class)
 VALUES(p_case_id,p_cycle,p_airport_key,v_faa,p_runway_pair,p_runway_end,p_service_class)
 ON CONFLICT(case_id) DO NOTHING;
 SELECT * INTO v_case
 FROM airlinerra.airport_faa_operation_verification_cases WHERE case_id=p_case_id;
 IF v_case.evidence_cycle IS DISTINCT FROM p_cycle
 OR v_case.airport_key IS DISTINCT FROM p_airport_key
 OR v_case.runway_pair IS DISTINCT FROM p_runway_pair
 OR v_case.runway_end IS DISTINCT FROM p_runway_end
 OR v_case.service_class IS DISTINCT FROM p_service_class
 THEN RAISE EXCEPTION 'Case ID reused with different airport, runway, cycle or service';
 END IF;
 INSERT INTO airlinerra.airport_faa_operation_gate_evidence(case_id,gate_code)
 SELECT p_case_id,gate_code FROM (VALUES
 ('RUNWAY_DIRECTION_SOURCE'),('FAA_NASR_PROVENANCE'),
 ('AIRCRAFT_AIRWORTHINESS'),('AIRCRAFT_AF_MANUAL_PERFORMANCE'),
 ('RUNWAY_WIDTH_SURFACE_PAVEMENT_LOAD'),('FAA_OPERATOR_CERTIFICATE_OPSPECS'),
 ('DOT_ECONOMIC_AUTHORITY'),('AIRPORT_OWNER_PAID_USE_PERMISSION'),
 ('FUEL_HANDLING_RESCUE_ACCESS'),('FLIGHT_DAY_NOTAM_FICON_WEATHER'),
 ('SERVICE_CLASS_SECURITY_CUSTOMS')) all_gates(gate_code)
 ON CONFLICT(case_id,gate_code) DO NOTHING;
 RETURN p_case_id;
END $body$;
REVOKE ALL ON FUNCTION airlinerra.create_faa_operation_research_case(text,date,text,text,text,text) FROM PUBLIC,anon,authenticated;
