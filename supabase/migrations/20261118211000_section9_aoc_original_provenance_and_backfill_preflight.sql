-- Tighten AOC provenance and provide read-only original-airline backfill preflight; issuance remains gated.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_issue_original_v1(p_airline uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE now_day date; a record;kind record;issued record;release record;
 audit_id text;proof text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_ORIGINAL_ISSUER_TRUSTED_ONLY';END IF;
 SELECT * INTO release FROM airlinerra_game.section9_aoc_release_policy_v1
 WHERE world_id=1;
 IF release.issuance_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','aoc_not_released',
  'issued',false,'charged',false);END IF;
 now_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF now_day IS NULL
 THEN RETURN jsonb_build_object('status','aoc_clock_not_verified',
  'issued',false,'charged',false);END IF;

 SELECT * INTO a FROM airlinerra_game.airlines
 WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aoc_airline_unknown',
  'issued',false,'charged',false);END IF;
 SELECT * INTO kind FROM airlinerra_game.section9_aoc_operating_companies_v1
 WHERE airline_id=p_airline AND world_id=1 FOR SHARE;
 IF NOT FOUND OR kind.company_source IS DISTINCT FROM 'original' OR
  kind.identity_evidence_reference IS DISTINCT FROM
   'verified-original-airline-registration-v1-'||p_airline::text OR
  kind.holding_id IS NOT NULL OR kind.subsidiary_id IS NOT NULL OR
  NOT EXISTS(
   SELECT 1 FROM airlinerra_game.world_memberships wm
   WHERE wm.world_id=1 AND wm.player_id=a.owner_player_id AND wm.state='active'
  ) OR
  (SELECT count(*) FROM airlinerra_game.airlines other
   WHERE other.world_id=1 AND other.owner_player_id=a.owner_player_id)<>1 OR
  EXISTS(
   SELECT 1 FROM airlinerra_game.holding_groups_v1 h
   WHERE h.world_id=1 AND h.owner_player_id=a.owner_player_id
    AND h.original_airline_id IS DISTINCT FROM p_airline
  )
 THEN RETURN jsonb_build_object('status','aoc_original_identity_not_verified',
  'issued',false,'charged',false);END IF;

 SELECT * INTO issued FROM airlinerra_game.section9_aoc_certificates_v1
 WHERE airline_id=p_airline FOR UPDATE;
 IF FOUND THEN RETURN jsonb_build_object('status','aoc_already_recorded',
  'issued',false,'charged',false,
  'certificateId',issued.certificate_id);END IF;

 proof:='aoc-original-registration-v1-'||p_airline::text||'-'||now_day::text;
 INSERT INTO airlinerra_game.section9_aoc_certificates_v1(
   airline_id,world_id,initial_issue_source,initial_issue_verified_reference,
   status,issued_game_day,expires_game_day,last_decision_game_day)
 VALUES(p_airline,1,'original_free_registration',proof,
   'active',now_day,now_day+365,now_day)
 RETURNING * INTO issued;

 audit_id:='aoc-original-v1-'||p_airline::text||'-'||now_day::text;
 INSERT INTO airlinerra_game.section9_aoc_review_audit_v1(
   event_id,airline_id,game_day,action,effective_safety_rating,
   expiry_game_day,verified_event_reference)
 VALUES(audit_id,p_airline,now_day,'original_issue',100,
   issued.expires_game_day,proof);

 RETURN jsonb_build_object('status','aoc_original_issued',
  'issued',true,'charged',false,'feeUsd',0,'airlineId',p_airline,
  'issuedGameDay',now_day,'expiresGameDay',issued.expires_game_day,
  'flightActivated',false);
END $function$
;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_original_backfill_readiness_v1(p_airline uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare a record; k record; rel record; d date; issues text[]:=array[]::text[];
begin
 select * into a from airlinerra_game.airlines where id=p_airline and world_id=1;
 if not found then return jsonb_build_object('status','AIRLINE_NOT_FOUND','canIssue',false,
 'issues',jsonb_build_array('AIRLINE_NOT_VERIFIED'),'feeUsd',0,'certificateIssued',false);end if;
 select * into rel from airlinerra_game.section9_aoc_release_policy_v1 where world_id=1;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 if rel.issuance_enabled IS DISTINCT FROM true
 then issues:=array_append(issues,'AOC_ISSUANCE_NOT_RELEASED');end if;
 if d is null then issues:=array_append(issues,'VERIFIED_GAME_DAY_MISSING');end if;
 if not exists(select 1 from airlinerra_game.world_memberships wm where wm.world_id=1
   and wm.player_id=a.owner_player_id and wm.state='active')
 then issues:=array_append(issues,'ACTIVE_OWNER_MEMBERSHIP_MISSING');end if;
 if (select count(*) from airlinerra_game.airlines other
   where other.world_id=1 and other.owner_player_id=a.owner_player_id)<>1
 then issues:=array_append(issues,'ORIGINAL_AIRLINE_UNIQUENESS_NOT_VERIFIED');end if;
 if exists(select 1 from airlinerra_game.holding_groups_v1 h
  where h.world_id=1 and h.owner_player_id=a.owner_player_id
   and h.original_airline_id IS DISTINCT FROM p_airline)
 then issues:=array_append(issues,'HOLDING_ORIGINAL_AIRLINE_CONFLICT');end if;
 select * into k from airlinerra_game.section9_aoc_operating_companies_v1
 where airline_id=p_airline and world_id=1;
 if not found or k.company_source is distinct from 'original'
 or k.identity_evidence_reference is distinct from
  'verified-original-airline-registration-v1-'||p_airline::text
 or k.holding_id is not null or k.subsidiary_id is not null
 then issues:=array_append(issues,'VERIFIED_ORIGINAL_COMPANY_IDENTITY_MISSING');end if;
 if exists(select 1 from airlinerra_game.section9_aoc_certificates_v1
  where airline_id=p_airline and world_id=1)
 then issues:=array_append(issues,'CERTIFICATE_ALREADY_RECORDED');end if;
 return jsonb_build_object('status','READ_ONLY_AOC_ORIGINAL_BACKFILL_CHECK',
  'airlineId',p_airline,'gameDay',d,'canIssue',cardinality(issues)=0,
  'issues',to_jsonb(issues),'feeUsd',0,'certificateIssued',false,
  'charged',false,'flightsActivated',false);
end $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_aoc_original_backfill_readiness_v1(uuid) FROM public,anon,authenticated;
