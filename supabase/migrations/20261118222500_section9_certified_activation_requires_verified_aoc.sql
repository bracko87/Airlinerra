-- Critical activation transaction AOC safety gate; all rollout switches remain off.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_flight_release_readiness_v1(p_airline uuid, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare a record; registry record; cert record; issues text[]:=ARRAY[]::text[]; live_day date;
begin
 if p_airline is null or p_game_day is null
 then return jsonb_build_object('status','AOC_INVALID_FLIGHT_SCOPE','authorized',false,
   'issues',jsonb_build_array('AOC_INVALID_FLIGHT_SCOPE'));end if;
 select * into a from airlinerra_game.airlines
 where id=p_airline and world_id=1;
 if not found then return jsonb_build_object('status','AOC_AIRLINE_NOT_FOUND','authorized',false,
   'issues',jsonb_build_array('AOC_AIRLINE_NOT_FOUND'));end if;
 if not exists(select 1 from airlinerra_game.section9_aoc_release_policy_v1 rp
 where rp.world_id=1 and rp.issuance_enabled and rp.safety_events_enabled
 and rp.renewal_enabled and rp.flight_enforcement_enabled)
 then issues:=array_append(issues,'AOC_FLIGHT_ENFORCEMENT_NOT_RELEASED');end if;
 live_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 if live_day is null or live_day is distinct from p_game_day
 then issues:=array_append(issues,'AOC_VERIFIED_GAME_DAY_MISMATCH');end if;
 select * into registry from airlinerra_game.section9_aoc_operating_companies_v1
 where airline_id=p_airline and world_id=1;
 if not found or registry.business_kind not in('passenger','regional','low_cost','cargo','charter','vip')
 then issues:=array_append(issues,'AOC_OPERATING_COMPANY_NOT_VERIFIED');end if;
 select * into cert from airlinerra_game.section9_aoc_certificates_v1
 where airline_id=p_airline and world_id=1;
 if not found or cert.status<>'active' or cert.issued_game_day>p_game_day
 or cert.expires_game_day<=p_game_day
 or cert.expires_game_day is distinct from cert.issued_game_day+365
 then issues:=array_append(issues,'AOC_ACTIVE_CERTIFICATE_NOT_VERIFIED');
 else
  if registry.company_source='original' then
   if cert.initial_issue_source is distinct from 'original_free_registration'
    or cert.initial_issue_application_id is not null
    or cert.initial_issue_ledger_id is not null
    or registry.identity_evidence_reference is distinct from
     'verified-original-airline-registration-v1-'||p_airline::text
   then issues:=array_append(issues,'AOC_ORIGINAL_ISSUE_PROVENANCE_INVALID');end if;
  elsif registry.company_source='subsidiary' then
   if cert.initial_issue_source is distinct from 'subsidiary_paid_application'
    or not exists(
     select 1 from airlinerra_game.section9_game_permission_applications_v1 app
     join airlinerra_game.airline_ledger ledger on ledger.id=app.ledger_entry_id
      and ledger.airline_id=p_airline and ledger.entry_kind='EXPENSE'
      and ledger.amount_usd=-10000
     join airlinerra_game.section9_operator_licence_evidence_v1 ev
      on ev.issued_application_id=app.id and ev.airline_id=p_airline
      and ev.evidence_status='verified'
     where app.id=cert.initial_issue_application_id
      and app.airline_id=p_airline and app.world_id=1
      and app.permission_code='AIR_OPERATOR_CERTIFICATE'
      and app.status='issued' and app.fee_usd=10000
      and app.ledger_entry_id=cert.initial_issue_ledger_id)
   then issues:=array_append(issues,'AOC_SUBSIDIARY_PAID_PROVENANCE_INVALID');end if;
  else issues:=array_append(issues,'AOC_COMPANY_ORIGIN_NOT_VERIFIED');end if;
 end if;
 return jsonb_build_object(
  'status',case when cardinality(issues)=0 then 'AOC_FLIGHT_READY' else 'AOC_FLIGHT_BLOCKED' end,
  'authorized',cardinality(issues)=0,'issues',to_jsonb(issues),
  'airlineId',p_airline,'gameDay',p_game_day,
  'flightActivated',false,'ledgerPosted',false);
end $function$
;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_commit_certified_schedule_activation_v1(p_player uuid, p_airline uuid, p_schedule uuid, p_expected_version integer, p_game_date date, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE target record; approval jsonb; proof record; changed integer; aoc_gate jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL
    OR p_expected_version IS NULL OR p_expected_version<1
    OR p_game_date IS NULL
    OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
    OR p_days IS NULL OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_SCHEDULE_ACTIVATION_REQUEST'; END IF;
 SELECT s.id,s.world_id,s.version,s.status,s.operationally_verified,
        s.airline_id,s.aircraft_inventory_id
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a
   ON a.id=s.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1
 FOR UPDATE OF s;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_SCHEDULE_ACTIVATION_NOT_OWNED';
 END IF;
 aoc_gate:=airlinerra_game.section9_aoc_flight_release_readiness_v1(p_airline,p_game_date);
 IF aoc_gate->>'authorized' IS DISTINCT FROM 'true' THEN
  RETURN jsonb_build_object('status','blocked_activation_not_fully_certified',
   'scheduleId',p_schedule,'blockers',coalesce(aoc_gate->'issues','[]'::jsonb),
   'scheduleActivated',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 IF target.version IS DISTINCT FROM p_expected_version
 THEN RETURN jsonb_build_object(
   'status','blocked_stale_schedule_version','scheduleId',p_schedule,
   'scheduleActivated',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 IF target.status IS DISTINCT FROM 'draft'
    OR target.operationally_verified IS DISTINCT FROM false
 THEN RETURN jsonb_build_object(
   'status','blocked_schedule_not_draft','scheduleId',p_schedule,
   'scheduleActivated',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;

 -- Re-check full real-world and game certification, current clock, slots,
 -- crew, aircraft, route rights and source evidence inside the same lock.
 approval:=airlinerra_game.section9_prepare_certified_schedule_activation_v1(
   p_player,p_airline,p_schedule,p_expected_version,p_game_date,p_days);
 IF approval->>'status' IS DISTINCT FROM 'prepared_for_future_activation_commit'
    OR approval->>'prepared' IS DISTINCT FROM 'true'
    OR approval->>'flightActivated' IS DISTINCT FROM 'false'
    OR approval->>'movementRecorded' IS DISTINCT FROM 'false'
    OR approval->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object(
    'status','blocked_activation_not_fully_certified',
    'scheduleId',p_schedule,
    'blockers',coalesce(approval->'blockers','[]'::jsonb),
    'scheduleActivated',false,'flightActivated',false,
    'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 SELECT * INTO proof
 FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE schedule_id=p_schedule AND schedule_version=p_expected_version
 AND airline_id=p_airline AND aircraft_inventory_id=target.aircraft_inventory_id
 FOR SHARE;
 IF NOT FOUND
  OR proof.verified_game_date IS DISTINCT FROM p_game_date
  OR proof.certified_horizon_days IS DISTINCT FROM p_days
  OR proof.fingerprint_md5 IS DISTINCT FROM approval->>'fingerprint'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ACTIVATION_PREPARATION_CHANGED';END IF;

 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET status='active',operationally_verified=true,updated_at=clock_timestamp()
 WHERE id=p_schedule AND version=p_expected_version AND world_id=1
   AND airline_id=p_airline AND status='draft' AND operationally_verified=false;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ACTIVATION_ATOMIC_UPDATE_NOT_CONFIRMED';END IF;
 RETURN jsonb_build_object(
  'status','certified_schedule_activated','worldId',1,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'certifiedThroughGameDate',p_game_date+p_days,
  'scheduleActivated',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_aoc_flight_release_readiness_v1(uuid,date) FROM public,anon,authenticated;
