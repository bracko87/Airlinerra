/**
 * Trusted, READ-ONLY delayed-flight crew recovery. A validated replacement slot
 * does not update the canonical flight schedule, contract price, or movement.
 * This worker intentionally has no method to write a roster or dispatch.
 */
import {planWeeklyCrew} from './weekly-crew-allocation-engine.mjs';
import {previewCrewSubstitutions} from './crew-substitution-engine.mjs';

const SQL={
 clock:'SELECT airlinerra_game.section9_verified_world_instant_v1() AS now',
 rolling:'SELECT airlinerra_game.section9_owned_rolling_crew_input_v1($1::uuid,$2::uuid,$3::timestamptz) AS result',
 delays:`SELECT o.id::text AS "flightId",o.departure_utc AS "originalDepartureUtc",
 o.arrival_utc AS "originalArrivalUtc", t.effective_departure_utc AS "effectiveDepartureUtc",
 t.effective_arrival_utc AS "effectiveArrivalUtc",t.is_delayed AS "isDelayed",
 t.dispatch_allowed AS "dispatchAllowed",
 airlinerra_game.section9_assess_delayed_crew_rotation_v1($1::uuid,$2::uuid,o.id) AS assessment
 FROM airlinerra_game.section9_replacement_slot_pairs_v1 p
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o
 ON o.id=p.occurrence_id AND o.aircraft_inventory_id=p.aircraft_inventory_id
 JOIN airlinerra_game.airlines a
 ON a.id=o.airline_id AND a.owner_player_id=$1::uuid AND a.world_id=1
 CROSS JOIN LATERAL airlinerra_game.section9_effective_dispatch_window_v1(o.id) t
 WHERE o.airline_id=$2::uuid AND o.world_id=1 AND o.booking_status<>'cancelled'
 AND o.departure_utc >= $3::timestamptz
 AND o.departure_utc < $3::timestamptz+interval '168 hours'
 AND NOT EXISTS (SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.airline_id=o.airline_id
 AND m.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text
 AND m.phase='departed')
 ORDER BY p.revised_departure_utc,o.id LIMIT $4::integer`
};
const ms=v=>v instanceof Date?v.getTime():typeof v==='string'?Date.parse(v):NaN;
const iso=v=>new Date(v).toISOString();
const hold=(status,more={})=>({status,...more,changesPersisted:false,contractingPerformed:false,dispatchEnforced:false,flightCancellationTriggered:false});
const roleKeys=['captains','firstOfficers','cabinCrew'];
function counts(contracts){const c={captains:0,firstOfficers:0,cabinCrew:0};for(const x of contracts)for(const key of roleKeys)c[key]+=x[key];return c;}
export function calculateDelayedCrewRecovery(snapshot,evidence){
 if(snapshot?.status!=='rolling_crew_input_preview'||snapshot.invalidOccurrenceCount!==0||
 snapshot.cabinHeadcountReconciled!==true||!Array.isArray(snapshot.flights)||
 !Array.isArray(snapshot.pilots)||!Array.isArray(snapshot.cabinMembers)||
 !Array.isArray(snapshot.preferredAssignments)||
 typeof snapshot.planningCutoffUtc!=='string')return hold('crew_recovery_snapshot_unverified');
 if(snapshot.unboundDeparturesLast7Days!==0||snapshot.unresolvedCaptureIssues!==0)
 return hold('crew_history_incomplete');
 if(snapshot.alreadyReportedFutureFlights!==0)
 return hold('already_reported_duty_protected');
 if(!Array.isArray(evidence)||evidence.length>100)return hold('delay_evidence_limit_or_type_invalid');
 if(!evidence.length)return hold('no_verified_delayed_flights',{affectedFlights:0,internalReplacements:0,externalCrewAssignments:counts([])});
 const flights=new Map(snapshot.flights.map(f=>[f.id,f]));
 if(flights.size!==snapshot.flights.length)return hold('duplicate_flight_input');
 const assessed=[],updates=[],excluded=new Set(),seen=new Set();
 const allowed=new Set(['delayed_crew_duty_windows_fit','delayed_crew_replacement_required','delayed_external_contract_review_required']);
 for(const e of evidence){
  const original=flights.get(e?.flightId),a=e?.assessment;
  const dep=ms(e?.effectiveDepartureUtc),arr=ms(e?.effectiveArrivalUtc);
  if(!original||seen.has(e.flightId)||e.isDelayed!==true||e.dispatchAllowed!==true||
   !Number.isFinite(dep)||!Number.isFinite(arr)||!Number.isFinite(ms(e.originalDepartureUtc))||
   ms(e.originalDepartureUtc)!==ms(original.departureUtc)||ms(e.originalArrivalUtc)!==ms(original.arrivalUtc)||
   dep<ms(original.departureUtc)||arr<=dep||dep<ms(snapshot.planningCutoffUtc)||
   a?.dispatchEnforced!==false||!allowed.has(a?.status)||
   a?.occurrenceId!==e.flightId||
   ms(a.revisedDepartureUtc)!==dep||ms(a.revisedArrivalUtc)!==arr||
   a.planChanged!==false||a.contractsChanged!==false||
   !Array.isArray(a.employees)||a.employeesAssessed!==a.employees.length||!Number.isInteger(a.employeesRequiringReplacementOrReview)||
   a.employeesRequiringReplacementOrReview<0||a.employeesRequiringReplacementOrReview>a.employees.length)
   return hold('unverified_or_conflicting_delayed_slot',{flightId:e?.flightId??null});
  seen.add(e.flightId);
  const failed=a.employees.filter(x=>x.status!=='duty_window_fits');
  if(failed.length!==a.employeesRequiringReplacementOrReview)return hold('delayed_duty_failures_unreconciled',{flightId:e.flightId});
  for(const person of failed){
   if(typeof person.employeeId!=='string'||!person.employeeId)
    return hold('delayed_crew_employee_unverified',{flightId:e.flightId});
   excluded.add(person.employeeId);
  }
  updates.push({flightId:e.flightId,status:'delayed',departureUtc:iso(dep),arrivalUtc:iso(arr)});
  assessed.push({flightId:e.flightId,assessmentStatus:a.status,replacementRequired:failed.length,
   previousExternalContractReview:a.status==='delayed_external_contract_review_required',
   effectiveDepartureUtc:iso(dep),effectiveArrivalUtc:iso(arr)});
 }
 // Existing crew with a failed verified duty window cannot be silently kept
 // on the affected sector. Blocking that person across this one preview is
 // conservative: other future legs may also require a separate reallocation.
 const excludedKnown=new Set([...snapshot.pilots,...snapshot.cabinMembers].map(x=>x.id));
 if([...excluded].some(x=>!excludedKnown.has(x)))return hold('reported_or_unavailable_crew_requires_protected_review');
 const eligible={
  ...snapshot,pilots:snapshot.pilots.filter(p=>!excluded.has(p.id)),
  cabinMembers:snapshot.cabinMembers.filter(c=>!excluded.has(c.id))
 };
 let substitution;
 try{substitution=previewCrewSubstitutions(eligible,{previousAssignments:snapshot.preferredAssignments,
 planningCutoffUtc:snapshot.planningCutoffUtc,flightUpdates:updates});}
 catch{return hold('crew_recovery_rotation_or_input_invalid');}
 if(substitution.status!=='crew_substitution_preview')
 return hold(substitution.status,{affectedFlights:assessed.length,assessedFlights:assessed});
 const revised=new Map(updates.map(x=>[x.flightId,x]));
 const revisedFlights=eligible.flights.map(f=>{
  const u=revised.get(f.id);return u?{...f,departureUtc:u.departureUtc,arrivalUtc:u.arrivalUtc}:f;
 }).filter(f=>ms(f.departureUtc)<ms(snapshot.windowStartUtc)+168*3600000);
 let mixed=null;
 if(substitution.shortages.length){
  try{mixed=planWeeklyCrew({...eligible,flights:revisedFlights,planNotBeforeUtc:snapshot.planningCutoffUtc},
   {externalCrewPreview:true});}
  catch{return hold('external_recovery_rotation_invalid',{affectedFlights:assessed.length,assessedFlights:assessed});}
 }
 const byChanges=new Map(substitution.changes.map(c=>[c.flightId,c.replacements]));
 const byContract=new Map((mixed?.externalContracts||[]).map(c=>[c.flightId,c]));
 const flightsResult=assessed.map(x=>{
  const changes=byChanges.get(x.flightId)||{};
  const replacementCount=roleKeys.reduce((n,k)=>n+(changes[k]?.added?.length||0),0);
  const newContract=byContract.get(x.flightId);
  return {...x,internalReplacementAssignments:replacementCount,
   proposedExternalCaptains:newContract?.captains||0,
   proposedExternalFirstOfficers:newContract?.firstOfficers||0,
   proposedExternalCabin:newContract?.cabinCrew||0,
   action:x.previousExternalContractReview?'existing_contract_retiming_review':
   newContract?'external_crew_requote_required':
   substitution.shortages.some(s=>s.flightId===x.flightId)?'unresolved_crew_shortage':
   replacementCount?'qualified_reserve_approval_required':'original_roster_revalidation_required'};
 });
 const contractors=mixed?.externalContracts||[];
 const backlog=substitution.shortages.length;
 return hold('delayed_crew_recovery_preview',{
  affectedFlights:assessed.length,assessedFlights:flightsResult,
  reassignedFlights:substitution.changes.length,
  unresolvedInternalShortages:backlog,
  externalContractFlightsProposed:contractors.length,
  externalCrewAssignments:counts(contractors),
  extendedDutyFlights:substitution.shortages.filter(s=>s.reason==='extended_duty_policy_required').length,
  deferredFlights:substitution.deferredFlightIds?.length||0,
  aircraftRotationVerified:true,
  requiresIndependentContractRequote:contractors.length>0||flightsResult.some(x=>x.previousExternalContractReview),
  rosterValidatedForRevisedSlot:false,financeSettled:false,
  canAutomaticallyDispatch:false,
  // Internal crew identities never leave the private worker through this summary.
  });
}
export async function prepareDelayedCrewRecovery({client,playerId,airlineId,limit=50}={}){
 if(typeof client?.query!=='function'||!Number.isInteger(limit)||limit<1||limit>100)
 throw Error('INVALID_DELAYED_RECOVERY_REQUEST');
 const c=(await client.query(SQL.clock)).rows?.[0]?.now,now=ms(c);
 if(!Number.isFinite(now))throw Error('UNVERIFIED_GAME_CLOCK');
 const windowStartUtc=iso(now+60000);
 const [snap,slots]=await Promise.all([
  client.query(SQL.rolling,[playerId,airlineId,windowStartUtc]),
  client.query(SQL.delays,[playerId,airlineId,windowStartUtc,limit+1])
 ]);
 const snapshot=snap.rows?.[0]?.result;
 if(!Array.isArray(slots.rows)||slots.rows.length>limit)
 return hold('delayed_crew_review_limit_exceeded');
 const review=calculateDelayedCrewRecovery(snapshot,slots.rows);
 return {...review,airlineId};
}
