-- Group2 independent admission evidence and source queue -- ROLLBACK ONLY.
-- Synthetic evidence URL in this test is deliberately fake; no review is saved.
BEGIN;
DO $test$
DECLARE airport text; blocked text; dual text; q jsonb;v integer;
 rejected boolean; before_ledger integer;
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_admission_readiness_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_required_reviews_v1)<>6830
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_research_batches_v1)<>23
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_source_research_queue_v1
    WHERE documented_commercial_prohibition)<>2
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_source_research_queue_v1
    WHERE historical_access_review IS NULL)<>192
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_source_research_queue_v1
    WHERE faa_source_url IS NOT NULL)<>510
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_admission_readiness_v1
    WHERE readiness_status='EVIDENCE_INCOMPLETE_NOT_PLAYABLE')<>1116
 THEN RAISE EXCEPTION 'GROUP2_SOURCE_BACKLOG_COUNTS_BAD';END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_research_batches_v1
  WHERE airports<1 OR airports>50 OR operationally_approved>0)
 THEN RAISE EXCEPTION 'GROUP2_REVIEW_BATCH_SIZE_OR_RELEASE_BAD';END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_admission_readiness_v1
    WHERE can_activate_flights OR admitted_to_world1
      OR operationally_authorized OR ready_for_owner_release_review)
 THEN RAISE EXCEPTION 'GROUP2_UNREVIEWED_CANDIDATE_RELEASED';END IF;

 IF has_function_privilege('anon',
 'airlinerra_game.group2_verify_candidate_admission_v1(text)','EXECUTE')
 OR has_function_privilege('authenticated',
 'airlinerra_game.group2_verify_candidate_admission_v1(text)','EXECUTE')
 OR has_table_privilege('authenticated',
 'airlinerra_game.airport_group2_review_evidence_events_v1','INSERT')
 OR has_table_privilege('anon',
 'airlinerra_game.airport_group2_admission_readiness_v1','SELECT')
 THEN RAISE EXCEPTION 'GROUP2_REVIEW_PRIVACY_FAILED';END IF;

 SELECT airport_key INTO airport
 FROM airlinerra_game.airport_group2_admission_readiness_v1
 WHERE NOT documented_commercial_prohibition AND game_traffic_type='Passenger'
 ORDER BY review_sequence LIMIT 1;
 SELECT airport_key INTO dual
 FROM airlinerra_game.airport_group2_admission_readiness_v1
 WHERE NOT documented_commercial_prohibition AND game_traffic_type='Both'
 ORDER BY review_sequence LIMIT 1;
 SELECT airport_key INTO blocked
 FROM airlinerra_game.airport_group2_admission_readiness_v1
 WHERE documented_commercial_prohibition
 ORDER BY review_sequence LIMIT 1;
 IF airport IS NULL OR dual IS NULL OR blocked IS NULL
 THEN RAISE EXCEPTION 'EXPECTED_GROUP2_REVIEW_CANDIDATES_MISSING';END IF;
 q:=airlinerra_game.group2_verify_candidate_admission_v1(airport);
 IF q->>'status'<>'EVIDENCE_INCOMPLETE_NOT_PLAYABLE'
 OR (q->>'canActivateFlights')::boolean
 OR (q->>'canJoinWorld1')::boolean
 OR (q->>'requiredEvidenceGates')::integer<>6
 THEN RAISE EXCEPTION 'GROUP2_UNCHECKED_CANDIDATE_NOT_DENIED: %',q;END IF;
 q:=airlinerra_game.group2_verify_candidate_admission_v1(dual);
 IF (q->>'requiredEvidenceGates')::integer<>7
 THEN RAISE EXCEPTION 'GROUP2_BOTH_SERVICE_MUST_HAVE_SEPARATE_CARGO_AND_PAX_RIGHTS';END IF;
 q:=airlinerra_game.group2_verify_candidate_admission_v1('OURAIRPORTS:999999999999999');
 IF q->>'status'<>'not_in_group2' OR (q->>'canActivateFlights')::boolean
 THEN RAISE EXCEPTION 'GROUP2_UNKNOWN_ID_ALLOWED';END IF;
 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;

 -- Explicitly FAKE events for regression only (whole transaction rolls back).
 INSERT INTO airlinerra_game.airport_group2_review_evidence_events_v1(
 airport_key,gate_code,service_type,decision,source_url,source_effective_on,
 reviewed_on,reviewer_reference,evidence_note)
 SELECT r.airport_key,r.gate_code,r.service_type,'verified',
  'https://example.invalid/rollback-synthetic-evidence-DO-NOT-REUSE',
  DATE '2026-11-09',DATE '2026-11-10','synthetic-sql-test-reviewer',
  'ROLLBACK TEST ONLY: not real airport evidence or actual commercial authorization.'
 FROM airlinerra_game.airport_group2_required_reviews_v1 r
 WHERE r.airport_key IN(airport,blocked);

 q:=airlinerra_game.group2_verify_candidate_admission_v1(airport);
 IF q->>'status'<>'READY_FOR_SEPARATE_OWNER_RELEASE_REVIEW'
 OR (q->>'verifiedEvidenceGates')::integer<>6
 OR (q->>'canJoinWorld1')::boolean
 OR (q->>'canActivateFlights')::boolean
 THEN RAISE EXCEPTION 'FULL_FAKE_REVIEW_IMPROPERLY_RELEASED_WORLD1: %',q;END IF;
 q:=airlinerra_game.group2_verify_candidate_admission_v1(blocked);
 IF q->>'status'<>'HARD_HOLD_DOCUMENTED_PROHIBITION'
 OR (q->>'readyForSeparateOwnerReleaseReview')::boolean
 OR (q->>'canJoinWorld1')::boolean
 OR (q->>'canActivateFlights')::boolean
 THEN RAISE EXCEPTION 'DOCUMENTED_COMMERCIAL_PROHIBITION_BYPASSED: %',q;END IF;

 rejected:=false;
 BEGIN
  INSERT INTO airlinerra_game.airport_group2_review_evidence_events_v1(
  airport_key,gate_code,service_type,decision,source_url,source_effective_on,
  reviewed_on,reviewer_reference,evidence_note)
  VALUES (airport,'identity_and_location','cargo','verified',
  'https://example.invalid/rollback-synthetic-evidence-DO-NOT-REUSE',
  DATE '2026-11-09',DATE '2026-11-10','synthetic-sql-test-reviewer',
  'ROLLBACK TEST ONLY: this service does not apply to the gate or airport.');
 EXCEPTION WHEN SQLSTATE '22023' THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'INVALID_SERVICE_GATE_NOT_REJECTED';END IF;

 rejected:=false;
 BEGIN
  UPDATE airlinerra_game.airport_group2_review_evidence_events_v1
  SET decision='rejected' WHERE airport_key=airport;
 EXCEPTION WHEN SQLSTATE '42501' THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'APPEND_ONLY_EVIDENCE_WAS_EDITABLE';END IF;

 INSERT INTO airlinerra_game.airport_group2_review_evidence_events_v1(
 airport_key,gate_code,service_type,decision,source_url,source_effective_on,
 reviewed_on,reviewer_reference,evidence_note)
 VALUES(airport,'current_paved_runway','general','withdrawn',
  'https://example.invalid/rollback-synthetic-evidence-DO-NOT-REUSE',
  DATE '2026-11-09',DATE '2026-11-10','synthetic-sql-test-reviewer',
  'ROLLBACK TEST ONLY: newer withdrawal supersedes the previous fake positive record.');
 q:=airlinerra_game.group2_verify_candidate_admission_v1(airport);
 IF q->>'status'<>'EVIDENCE_INCOMPLETE_NOT_PLAYABLE'
 OR (q->>'verifiedEvidenceGates')::integer<>5
 OR (q->>'canActivateFlights')::boolean
 THEN RAISE EXCEPTION 'WITHDRAWN_EVIDENCE_NOT_REVOKED: %',q;END IF;

 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_ledger
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable)
 THEN RAISE EXCEPTION 'GROUP1_OR_GAME_FINANCE_CHANGED_BY_GROUP2_RESEARCH';END IF;
 RAISE NOTICE 'PASS Group2: 1118 source cases, 6830 service-specific evidence gates, 23 review batches, two AIP prohibitions; even synthetic full verification cannot launch flights; immutable revocation and owner-release boundary verified';
END $test$;
ROLLBACK;
