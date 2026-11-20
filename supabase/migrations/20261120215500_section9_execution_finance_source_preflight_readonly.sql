-- Independent SOURCE PREFLIGHT for the two unreleased flight certificates.
-- It exposes factual blockers only. It is NOT a signing oracle, does not
-- return a verified certification, and cannot substitute for the separate
-- HMAC issuer or the certification sink's same-transaction source recheck.
-- Production flight execution/finance release flags are NOT changed.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_execution_finance_certificate_source_preflight_v1(
 p_airline uuid,p_schedule uuid,p_version integer,p_game_date date,
 p_clearance_type text
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
 s record;f record;m record;activation record;execution record;
 finance record;engine record;verified_hour jsonb;
 blockers text[]:=ARRAY[]::text[];required_count integer:=0;
BEGIN
 -- Never present this preflight as independent permission to issue a
 -- certificate, even if its future prerequisites eventually become true.
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PRIVATE_EXECUTION_FINANCE_SOURCE_PREFLIGHT_ONLY';
 END IF;
 IF p_airline IS NULL OR p_schedule IS NULL OR p_version IS NULL
 OR p_version<1 OR p_game_date IS NULL
 OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_clearance_type NOT IN('trusted_flight_execution','commercial_finance')
 OR p_clearance_type IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_EXECUTION_FINANCE_SOURCE_SCOPE';
 END IF;
 SELECT * INTO activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT * INTO execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO finance
 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1;
 SELECT * INTO engine
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF activation.release_state IS DISTINCT FROM 'enabled'
 OR activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR activation.enabled_at IS NULL OR activation.reviewed_at IS NULL THEN
  blockers:=array_append(blockers,'COMMERCIAL_ACTIVATION_NOT_RELEASED');
 END IF;
 IF execution.release_state IS DISTINCT FROM 'enabled'
 OR execution.enabled_at IS NULL OR execution.reviewed_at IS NULL
 OR length(coalesce(execution.release_reference,''))<16
 OR length(coalesce(execution.approved_by,''))<12 THEN
  blockers:=array_append(blockers,'TRUSTED_EXECUTION_NOT_RELEASED');
 END IF;
 IF engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true THEN
  blockers:=array_append(blockers,'FLIGHT_FUEL_ENGINE_NOT_ACTIVATED');
 END IF;
 IF p_clearance_type='commercial_finance' AND
  (finance.release_state IS DISTINCT FROM 'approved'
  OR finance.approved_at IS NULL
  OR length(coalesce(finance.approval_reference,''))<20) THEN
  blockers:=array_append(blockers,'FINANCE_POSTING_NOT_APPROVED');
 END IF;
 -- Read verified clock, never derive a game day from server UTC time.
 verified_hour:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF verified_hour->>'status' IS DISTINCT FROM 'verified_berlin_realtime_hour'
 OR verified_hour->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR verified_hour->>'gameDate' IS DISTINCT FROM p_game_date::text
 OR verified_hour->>'berlinDate' IS DISTINCT FROM p_game_date::text THEN
  blockers:=array_append(blockers,'AUTHORITATIVE_GAME_DAY_NOT_VERIFIED');
 END IF;
 SELECT * INTO s FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id=p_schedule AND airline_id=p_airline AND world_id=1
 AND version=p_version;
 IF NOT FOUND OR s.status IS DISTINCT FROM 'draft'
 OR s.operationally_verified IS DISTINCT FROM false THEN
  blockers:=array_append(blockers,'CURRENT_DRAFT_VERSION_NOT_VERIFIED');
 ELSE
  SELECT * INTO f FROM airlinerra_game.airline_aircraft_inventory
  WHERE id=s.aircraft_inventory_id AND airline_id=p_airline;
  IF NOT FOUND OR f.fleet_status IS DISTINCT FROM 'in_service'
   OR f.ownership_type NOT IN('owned','leased')
   OR f.configuration_id IS DISTINCT FROM s.configuration_id THEN
   blockers:=array_append(blockers,'OWNED_OR_LEASED_AIRCRAFT_NOT_READY');
  END IF;
  SELECT * INTO m FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
  WHERE configuration_id=s.configuration_id;
  IF NOT FOUND OR m.game_calculation_ready IS DISTINCT FROM true
   OR m.operational_dispatch_release IS DISTINCT FROM 'RELEASED'
   OR (p_clearance_type='commercial_finance'
     AND m.financial_settlement_release IS DISTINCT FROM 'RELEASED') THEN
   blockers:=array_append(blockers,'AIRCRAFT_GAME_FUEL_MODEL_NOT_RELEASED');
  END IF;
  SELECT count(DISTINCT c.clearance_type)::integer INTO required_count
  FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
  JOIN airlinerra_game.section9_operational_certification_events_v1 e
   ON e.event_id=c.last_verified_event_id
   AND e.schedule_id=c.schedule_id
   AND e.schedule_version=c.schedule_version
   AND e.clearance_type=c.clearance_type AND e.action='certify'
   AND e.source_kind=c.source_kind
   AND e.source_reference=c.source_reference
   AND e.reviewer_reference=c.reviewer_reference
  WHERE c.schedule_id=p_schedule AND c.schedule_version=p_version
   AND c.airline_id=p_airline AND c.review_status='certified'
   AND c.clearance_type IN ('operator_licence','route_traffic_rights',
                             'airport_slot_capacity')
   AND c.valid_from_game_date<=p_game_date
   AND c.valid_to_game_date>=p_game_date+28;
  IF required_count<>3 THEN
   blockers:=array_append(blockers,'PRIOR_INDEPENDENT_CERTIFICATIONS_MISSING');
  END IF;
 END IF;

 RETURN jsonb_build_object(
  'status',CASE WHEN cardinality(blockers)=0
   THEN 'source_preflight_complete_not_certifiable'
   ELSE 'blocked_unreleased_execution_finance_source' END,
  'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
  'scheduleVersion',p_version,'gameDate',p_game_date,
  'clearanceType',p_clearance_type,'readOnly',true,'verified',false,
  'certificateIssued',false,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,
  'ledgerPosted',false,'sourceAuthorityReleased',false,
  'priorCertificateTypesPresent',required_count,
  'blockers',to_jsonb(blockers));
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_execution_finance_certificate_source_preflight_v1(
 uuid,uuid,integer,date,text)
 FROM PUBLIC,anon,authenticated,service_role;
