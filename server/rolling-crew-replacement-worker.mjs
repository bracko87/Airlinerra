import {planWeeklyCrew} from './weekly-crew-allocation-engine.mjs';
import {crewCapacityStatus} from './fleet-crew-capacity-engine.mjs';
import {prepareExternalCrewPlan} from './external-crew-planning-worker.mjs';
// No live plan writes. Preserve prior roster preferences; all current
// employment, absence, family, location, rest and duty checks still apply.
export function previewRollingCrewReplacement(snapshot,{capacityByFamily={}}={}){
 const stop=(status,details={})=>({status,...details,changesPersisted:false,dispatchEnforced:false,crewCancellationTriggered:false});
 if(snapshot?.status!=='rolling_crew_input_preview')return stop('rolling_crew_input_unverified');
 if(snapshot.invalidOccurrenceCount!==0||snapshot.cabinHeadcountReconciled!==true)return stop('rolling_crew_input_unreconciled');
 if(snapshot.unboundDeparturesLast7Days!==0||snapshot.unresolvedCaptureIssues!==0)return stop('crew_history_incomplete');
 if(snapshot.alreadyReportedFutureFlights!==0)return stop('active_duty_continuation_required');
 let plan;
 try{plan=planWeeklyCrew({...snapshot,planNotBeforeUtc:snapshot.planningCutoffUtc});}
 catch{return stop('crew_history_or_rotation_requires_review');}
 const prior=new Map((snapshot.preferredAssignments||[]).map(a=>[a.flightId,a]));
 const changes=[];
 for(const a of plan.assignments){
  const before=prior.get(a.flightId);if(!before)continue;
  const roles={};
  for(const key of ['captains','firstOfficers','cabinCrew']){
   const removed=before[key].filter(id=>!a[key].includes(id));
   const added=a[key].filter(id=>!before[key].includes(id));
   if(removed.length||added.length)roles[key]={removed,added};
  }
  if(Object.keys(roles).length)changes.push({flightId:a.flightId,roles});
 }
 const flights=new Map(snapshot.flights.map(f=>[f.id,f]));
 const shortages=plan.shortages.map(s=>{
  const group=flights.get(s.flightId)?.group;
  const percent=capacityByFamily[group]??null;
  const c=crewCapacityStatus(percent);
  // Capacity is display/decision policy; never treat an estimated percentage
  // as proof that an actual crew can operate the flight.
  return {...s,qualificationGroup:group,capacityPct:percent,
   capacityStatus:c.status,crewShortageCancellationEligible:c.crewShortageCancellationEligible,
   action:c.crewShortageCancellationEligible===true?'shortage_risk_review':c.crewShortageCancellationEligible===false?'protected_replacement_required':'capacity_verification_required'};
 });
 return stop('rolling_crew_replacement_preview',{plan:{...plan,shortages},changes,excludedEmployees:snapshot.excludedEmployees||[],completedDutyHistoryIncluded:true,scheduleCompletenessVerified:false,liveReplacementReady:false});
}
export async function prepareRollingCrewReplacement({client,playerId,airlineId,windowStartUtc}){
 if(typeof client?.query!=='function')throw Error('INVALID_ROLLING_CREW_WORKER');
 const response=await client.query('SELECT airlinerra_game.section9_owned_rolling_crew_input_v1($1::uuid,$2::uuid,$3::timestamptz) AS result',[playerId,airlineId,windowStartUtc]);
 return previewRollingCrewReplacement(response.rows?.[0]?.result);
}

// Private cycle entry. A scheduler can invoke it per owned airline, but there
// is deliberately no cron registration or dispatch activation here.
// The explicit authorization/budget checks in prepareExternalCrewPlan and
// the independent SQL validation are mandatory for every saved cycle.
export async function runRollingCrewReplanning({client,playerId,airlineId,planId,windowStartUtc,execute=false,authorizeExternal=false,maxExternalCostUsd=0}){
 if(typeof execute!=='boolean'||typeof authorizeExternal!=='boolean')throw Error('INVALID_ROLLING_CREW_CYCLE');
 return prepareExternalCrewPlan({client,playerId,airlineId,planId,windowStartUtc,save:execute,authorizeExternal,maxExternalCostUsd,rolling:true});
}

// Read-only disruption-cycle preflight. Do not treat a duty-fit result as
// dispatch authorization: revised roster persistence and contractor retiming
// must be validated separately. Review only verified, unflown delayed legs.
export async function reviewDelayedCrewRotations({client,playerId,airlineId,limit=50}){
 if(typeof client?.query!=='function'||!Number.isInteger(limit)||limit<1||limit>100)throw Error('INVALID_DELAYED_CREW_REVIEW');
 const response=await client.query(`
 SELECT o.id AS "occurrenceId",
 airlinerra_game.section9_assess_delayed_crew_rotation_v1($1::uuid,$2::uuid,o.id) AS result
 FROM airlinerra_game.section9_replacement_slot_pairs_v1 p
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=p.occurrence_id AND o.aircraft_inventory_id=p.aircraft_inventory_id
 JOIN airlinerra_game.airlines a ON a.id=o.airline_id AND a.owner_player_id=$1::uuid AND a.world_id=1
 WHERE o.airline_id=$2::uuid AND o.world_id=1 AND o.booking_status<>'cancelled'
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.airline_id=o.airline_id AND m.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text AND m.phase='departed')
 ORDER BY p.revised_departure_utc,o.id LIMIT $3::integer
 `,[playerId,airlineId,limit]);
 const results=(response.rows||[]).map(row=>{
  if(typeof row.result?.status!=='string'||row.result.dispatchEnforced!==false)throw Error('DELAYED_CREW_ASSESSMENT_UNVERIFIED');
  return {occurrenceId:row.occurrenceId,...row.result};
 });
 const counts={};
 for(const r of results)counts[r.status]=(counts[r.status]||0)+1;
 return {status:'delayed_crew_review_preview',assessedFlights:results.length,counts,results,changesPersisted:false,dispatchEnforced:false,crewCancellationTriggered:false};
}
