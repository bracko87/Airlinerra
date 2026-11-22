-- Phase 14K: provisional replacement authorization receipt, intentionally not
-- consumed by live dispatch or original crew-plan capture. All mutations are
-- private and gated. The old roster and contractor row remain immutable.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_delayed_crew_approval_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 approval_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_delayed_crew_approval_release_v1(world_id,approval_enabled) VALUES(1,false) ON CONFLICT(world_id) DO NOTHING;
ALTER TABLE airlinerra_game.section9_delayed_crew_approval_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_delayed_crew_approval_release_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_delayed_crew_approvals_v1(
 approval_id uuid PRIMARY KEY,
 world_id smallint NOT NULL CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 occurrence_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id),
 physical_flight_id text NOT NULL UNIQUE,
 source_plan_id uuid NOT NULL REFERENCES airlinerra_game.section9_crew_plan_batches_v1(plan_id),
 original_departure_utc timestamptz NOT NULL,
 revised_departure_utc timestamptz NOT NULL,
 revised_arrival_utc timestamptz NOT NULL,
 authorized_game_utc timestamptz NOT NULL,
 internal_captains uuid[] NOT NULL,
 internal_first_officers uuid[] NOT NULL,
 internal_cabin uuid[] NOT NULL,
 released_employee_ids uuid[] NOT NULL,
 external_captains integer NOT NULL CHECK(external_captains BETWEEN 0 AND 2),
 external_first_officers integer NOT NULL CHECK(external_first_officers BETWEEN 0 AND 2),
 external_cabin integer NOT NULL CHECK(external_cabin BETWEEN 0 AND 40),
 captain_rate numeric(12,2) NOT NULL CHECK(captain_rate>=0),
 first_officer_rate numeric(12,2) NOT NULL CHECK(first_officer_rate>=0),
 cabin_rate numeric(12,2) NOT NULL CHECK(cabin_rate>=0),
 quoted_cost_usd numeric(14,2) NOT NULL CHECK(quoted_cost_usd>=0),
 additional_reserved_usd numeric(14,2) NOT NULL CHECK(additional_reserved_usd>=0),
 original_contract_reference text,
 request_payload jsonb NOT NULL,
 validation_receipt jsonb NOT NULL,
 CHECK(revised_arrival_utc>revised_departure_utc AND revised_departure_utc>original_departure_utc AND authorized_game_utc<revised_departure_utc)
);
ALTER TABLE airlinerra_game.section9_delayed_crew_approvals_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_delayed_crew_approvals_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX IF NOT EXISTS section9_delayed_crew_approval_airline_idx ON airlinerra_game.section9_delayed_crew_approvals_v1(airline_id);

CREATE OR REPLACE FUNCTION airlinerra_game.section9_stage_delayed_crew_approval_v1(
 p_player uuid,p_airline uuid,p_occurrence uuid,p_approval uuid,
 p_expected_departure timestamptz,p_expected_arrival timestamptz,p_max_cost numeric,
 p_captains uuid[],p_first_officers uuid[],p_cabin uuid[],
 p_external_captains int,p_external_first_officers int,p_external_cabin int
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $body$
DECLARE existing record;co record;v jsonb;q jsonb;req jsonb;cash numeric;now_utc timestamptz;
 cp uuid[];fo uuid[];fa uuid[];removed uuid[];ids uuid[];old_plan uuid;original_dep timestamptz;
 old_contract record;cr numeric;fr numeric;ar numeric;fee numeric;add_reserve numeric;pending numeric;baseline_commit numeric;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT cash_usd INTO cash FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_approval IS NULL OR p_occurrence IS NULL OR p_expected_departure IS NULL OR p_expected_arrival IS NULL OR NOT isfinite(p_expected_departure) OR NOT isfinite(p_expected_arrival) OR p_expected_arrival<=p_expected_departure
 OR p_max_cost IS NULL OR p_max_cost<0 OR p_max_cost>1000000000 OR p_max_cost<>round(p_max_cost,2)
 OR p_captains IS NULL OR p_first_officers IS NULL OR p_cabin IS NULL OR cardinality(p_captains)>2 OR cardinality(p_first_officers)>2 OR cardinality(p_cabin)>40
 OR p_external_captains IS NULL OR p_external_first_officers IS NULL OR p_external_cabin IS NULL THEN RETURN jsonb_build_object('status','delayed_approval_invalid_request');END IF;
 SELECT coalesce(array_agg(x ORDER BY x),'{}') INTO cp FROM unnest(p_captains)x;
 SELECT coalesce(array_agg(x ORDER BY x),'{}') INTO fo FROM unnest(p_first_officers)x;
 SELECT coalesce(array_agg(x ORDER BY x),'{}') INTO fa FROM unnest(p_cabin)x;
 ids:=cp||fo||fa;
 req:=jsonb_build_object('occurrenceId',p_occurrence,'departureUtc',p_expected_departure,'arrivalUtc',p_expected_arrival,'maxCostUsd',p_max_cost,
 'captains',cp,'firstOfficers',fo,'cabinCrew',fa,'externalCaptains',p_external_captains,'externalFirstOfficers',p_external_first_officers,'externalCabin',p_external_cabin);
 SELECT * INTO existing FROM airlinerra_game.section9_delayed_crew_approvals_v1 WHERE approval_id=p_approval OR occurrence_id=p_occurrence;
 IF FOUND THEN
  IF existing.airline_id<>p_airline OR existing.approval_id<>p_approval OR existing.request_payload IS DISTINCT FROM req THEN RETURN jsonb_build_object('status','delayed_approval_replay_conflict','saved',false);END IF;
  -- Replays report the historical receipt, never a new dispatch permission.
  RETURN jsonb_build_object('status','delayed_crew_approval_staged','approvalId',p_approval,'occurrenceId',p_occurrence,'quotedCostUsd',existing.quoted_cost_usd,'saved',true,'replayed',true,'dispatchAuthorizationIssued',false,'ledgerPosted',false,'activeRosterChanged',false);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approval_release_v1 WHERE world_id=1 AND approval_enabled) THEN RETURN jsonb_build_object('status','delayed_crew_approval_disabled','saved',false);END IF;
 -- Protect canonical occurrence and revised slot rows for the entire receipt.
 PERFORM 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=p_occurrence AND airline_id=p_airline AND world_id=1 AND booking_status<>'cancelled' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_approval_occurrence_unavailable','saved',false);END IF;
 PERFORM 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 WHERE occurrence_id=p_occurrence AND revised_departure_utc=p_expected_departure AND revised_arrival_utc=p_expected_arrival FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_approval_slot_changed','saved',false);END IF;
 PERFORM 1 FROM airlinerra_game.section9_dated_replacement_slots_v1 WHERE occurrence_id=p_occurrence FOR SHARE;
 v:=airlinerra_game.section9_validate_delayed_crew_roster_v1(p_player,p_airline,p_occurrence,cp,fo,fa,p_external_captains,p_external_first_officers,p_external_cabin);
 IF v->>'status' IS DISTINCT FROM 'delayed_roster_validation_passed' THEN RETURN jsonb_build_object('status',coalesce(v->>'status','delayed_approval_validation_failed'),'saved',false);END IF;
 q:=v->'quote';old_plan:=(v->>'sourcePlanId')::uuid;original_dep:=(q->>'originalDepartureUtc')::timestamptz;now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 fee:=(q->>'estimatedCostUsd')::numeric;
 IF (q->>'revisedDepartureUtc')::timestamptz IS DISTINCT FROM p_expected_departure OR (q->>'revisedArrivalUtc')::timestamptz IS DISTINCT FROM p_expected_arrival OR now_utc>=p_expected_departure THEN RETURN jsonb_build_object('status','delayed_approval_slot_changed','saved',false);END IF;
 IF fee>p_max_cost THEN RETURN jsonb_build_object('status','delayed_approval_budget_exceeded','quotedCostUsd',fee,'saved',false);END IF;
 IF (p_external_captains+p_external_first_officers+p_external_cabin>0 OR q->>'existingContract'='true') AND q->>'contractingEnabled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','external_crew_contracting_disabled','saved',false);END IF;
 PERFORM 1 FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE plan_id=old_plan AND airline_id=p_airline AND status='validated_preview' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_approval_source_plan_changed','saved',false);END IF;
 SELECT coalesce(array_agg(s.employee_id ORDER BY s.employee_id),'{}') INTO removed FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=old_plan AND s.occurrence_id=p_occurrence AND NOT(s.employee_id=ANY(ids));
 -- The receipt can release only an unstarted isolated assignment. Later legs
 -- cannot inherit a false airport or reset rest. Other scenarios remain held.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=old_plan AND s.occurrence_id=p_occurrence AND s.employee_id=ANY(removed) AND d.duty_start_utc<=now_utc) THEN RETURN jsonb_build_object('status','active_duty_release_required','saved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 f ON f.plan_id=s.plan_id AND f.occurrence_id=s.occurrence_id WHERE s.plan_id=old_plan AND s.employee_id=ANY(removed) AND s.occurrence_id<>p_occurrence AND f.departure_utc>=now_utc) THEN RETURN jsonb_build_object('status','replacement_rotation_release_required','saved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND x.occurrence_id<>p_occurrence AND (x.internal_captains||x.internal_first_officers||x.internal_cabin||x.released_employee_ids)&&(ids||removed)) THEN RETURN jsonb_build_object('status','delayed_approval_employee_already_reserved','saved',false);END IF;
 SELECT * INTO old_contract FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE occurrence_id=p_occurrence FOR UPDATE;
 IF FOUND THEN cr:=old_contract.captain_rate;fr:=old_contract.first_officer_rate;ar:=old_contract.cabin_rate;
 ELSE
 SELECT hourly_usd INTO STRICT cr FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='captain' FOR SHARE;
 SELECT hourly_usd INTO STRICT fr FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='first_officer' FOR SHARE;
 SELECT hourly_usd INTO STRICT ar FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='cabin' FOR SHARE;
 END IF;
 IF airlinerra_game.section9_external_crew_cost_v1(p_external_captains,p_external_first_officers,p_external_cabin,cr,fr,ar,extract(epoch FROM p_expected_arrival-p_expected_departure)/60) IS DISTINCT FROM fee THEN RETURN jsonb_build_object('status','delayed_approval_quote_changed','saved',false);END IF;
 -- Count all ordinary outstanding commitments, plus only positive incremental
 -- reservations for staged amendments. Do not release an old contract's funds.
 SELECT coalesce(sum(x.quoted_cost_usd),0) INTO baseline_commit FROM airlinerra_game.section9_external_crew_contracts_v1 x WHERE x.airline_id=p_airline AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 z WHERE z.physical_flight_id=x.physical_flight_id) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=x.occurrence_id AND o.booking_status='cancelled');
 SELECT coalesce(sum(x.additional_reserved_usd),0) INTO pending FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline;
 add_reserve:=greatest(0,fee-coalesce(old_contract.quoted_cost_usd,0));
 IF cash<baseline_commit+pending+add_reserve THEN RETURN jsonb_build_object('status','delayed_approval_combined_budget_exceeded','saved',false);END IF;
 INSERT INTO airlinerra_game.section9_delayed_crew_approvals_v1(approval_id,world_id,airline_id,occurrence_id,physical_flight_id,source_plan_id,original_departure_utc,revised_departure_utc,revised_arrival_utc,authorized_game_utc,internal_captains,internal_first_officers,internal_cabin,released_employee_ids,external_captains,external_first_officers,external_cabin,captain_rate,first_officer_rate,cabin_rate,quoted_cost_usd,additional_reserved_usd,original_contract_reference,request_payload,validation_receipt)
 VALUES(p_approval,1,p_airline,p_occurrence,q->>'physicalFlightId',old_plan,original_dep,p_expected_departure,p_expected_arrival,now_utc,cp,fo,fa,removed,p_external_captains,p_external_first_officers,p_external_cabin,cr,fr,ar,fee,add_reserve,old_contract.source_reference,req,v);
 RETURN jsonb_build_object('status','delayed_crew_approval_staged','approvalId',p_approval,'occurrenceId',p_occurrence,'quotedCostUsd',fee,'additionalReservedUsd',add_reserve,'releasedAssignmentCount',cardinality(removed),'saved',true,'replayed',false,'dispatchAuthorizationIssued',false,'ledgerPosted',false,'activeRosterChanged',false,'requiresBindingAdapter',true);
END $body$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_stage_delayed_crew_approval_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,numeric,uuid[],uuid[],uuid[],int,int,int) FROM PUBLIC,anon,authenticated,service_role;