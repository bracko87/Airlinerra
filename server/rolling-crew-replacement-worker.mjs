import {planWeeklyCrew} from './weekly-crew-allocation-engine.mjs';
import {crewCapacityStatus} from './fleet-crew-capacity-engine.mjs';
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
