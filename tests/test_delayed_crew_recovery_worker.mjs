import test from 'node:test';
import assert from 'node:assert/strict';
import {calculateDelayedCrewRecovery,prepareDelayedCrewRecovery} from '../server/delayed-crew-recovery-worker.mjs';
import {validateFleetAcquisitionRequest} from '../server/fleet-acquisition-service.mjs';
const id='11111111-1111-4111-8111-111111111111';
const start='2026-11-24T00:00:00Z';
const flight={id:'f1',aircraftId:'a',group:'family:12',origin:'BEG',destination:'LHR',
 departureUtc:'2026-11-24T06:00:00Z',arrivalUtc:'2026-11-24T09:00:00Z',cabinRequired:1};
const person=(id,role)=>({id,initialAirport:'BEG',locationEffectiveUtc:'2026-11-23T00:00:00Z',baseTimezone:'Europe/Belgrade',employmentFrom:'2026-11-23',history:[],
 ...(role==='cabin'?{role:'flight_attendant'}:{permissions:[{group:'family:12',issued:'2026-11-23',expires:'2027-11-23',active:true,captain:role==='captain',firstOfficer:role==='firstOfficer'}]})});
const snapshot={status:'rolling_crew_input_preview',windowStartUtc:start,planningCutoffUtc:'2026-11-23T00:00:00Z',flights:[flight],
 pilots:[person('captain','captain'),person('reserve','captain'),person('fo','firstOfficer')],cabinMembers:[person('fa','cabin'),person('extra','cabin')],
 preferredAssignments:[{flightId:'f1',captains:['captain'],firstOfficers:['fo'],cabinCrew:['fa']}],
 invalidOccurrenceCount:0,cabinHeadcountReconciled:true,unboundDeparturesLast7Days:0,unresolvedCaptureIssues:0,alreadyReportedFutureFlights:0};
const assess=(status,failed=[])=>({status,occurrenceId:'f1',revisedDepartureUtc:'2026-11-24T07:00:00Z',revisedArrivalUtc:'2026-11-24T10:00:00Z',employeesRequiringReplacementOrReview:failed.length,
 employees:[...['captain','fo','fa'].map(employeeId=>({employeeId,status:failed.includes(employeeId)?'duty_limit_exceeded':'duty_window_fits'}))],
 dispatchEnforced:false,planChanged:false,contractsChanged:false});
const evidence=(status='delayed_crew_duty_windows_fit',failed=[])=>[{flightId:'f1',originalDepartureUtc:flight.departureUtc,originalArrivalUtc:flight.arrivalUtc,
 effectiveDepartureUtc:'2026-11-24T07:00:00Z',effectiveArrivalUtc:'2026-11-24T10:00:00Z',isDelayed:true,dispatchAllowed:true,assessment:assess(status,failed)}];
test('bounded verified delay retains qualified original crew where duty still fits',()=>{const r=calculateDelayedCrewRecovery(snapshot,evidence());assert.equal(r.status,'delayed_crew_recovery_preview');assert.equal(r.affectedFlights,1);assert.equal(r.unresolvedInternalShortages,0);assert.equal(r.externalContractFlightsProposed,0);assert.equal(r.canAutomaticallyDispatch,false);});
test('overtime captain replaced with qualified reserve, not crew teleported across airports',()=>{
 const r=calculateDelayedCrewRecovery(snapshot,evidence('delayed_crew_replacement_required',['captain']));
 assert.equal(r.status,'delayed_crew_recovery_preview');assert.equal(r.assessedFlights[0].internalReplacementAssignments,1);
 assert.equal(r.assessedFlights[0].action,'qualified_reserve_approval_required');
 const far={...snapshot,pilots:snapshot.pilots.map(p=>p.id==='reserve'?{...p,initialAirport:'LHR'}:p)};
 const x=calculateDelayedCrewRecovery(far,evidence('delayed_crew_replacement_required',['captain']));
 assert.equal(x.assessedFlights[0].action,'external_crew_requote_required');assert.equal(x.externalCrewAssignments.captains,1);
 assert.equal(x.contractingPerformed,false);assert.equal(x.financeSettled,false);
});
test('all unavailable crew produce external quote requirement but never charges or dispatch',()=>{
 const r=calculateDelayedCrewRecovery(snapshot,evidence('delayed_crew_replacement_required',['captain','fo','fa']));
 assert.equal(r.externalCrewAssignments.captains,1);assert.equal(r.externalCrewAssignments.firstOfficers,1);assert.equal(r.externalCrewAssignments.cabinCrew,1);
 assert.equal(r.canAutomaticallyDispatch,false);assert.equal(r.requiresIndependentContractRequote,true);
});
test('unverified slot, past report, unknown employee and altered assessment reject',()=>{
 const modified=evidence();modified[0].dispatchAllowed=false;
 assert.equal(calculateDelayedCrewRecovery(snapshot,modified).status,'unverified_or_conflicting_delayed_slot');
 assert.equal(calculateDelayedCrewRecovery({...snapshot,alreadyReportedFutureFlights:1},evidence()).status,'already_reported_duty_protected');
 const x=evidence('delayed_crew_replacement_required',['stranger']);assert.equal(calculateDelayedCrewRecovery(snapshot,x).status,'reported_or_unavailable_crew_requires_protected_review');
 const y=evidence();y[0].assessment.contractsChanged=true;assert.equal(calculateDelayedCrewRecovery(snapshot,y).status,'unverified_or_conflicting_delayed_slot');
});
test('owner-scoped recovery only executes SELECT and no client write action',async()=>{
 const calls=[];const client={async query(sql,args){calls.push({sql,args});
 if(sql.includes('verified_world_instant'))return {rows:[{now:'2026-11-23T00:00:00Z'}]};
 if(sql.includes('owned_rolling_crew_input'))return {rows:[{result:snapshot}]};
 if(sql.includes('replacement_slot_pairs'))return {rows:evidence()};
 throw Error('Unexpected SQL');}};
 const r=await prepareDelayedCrewRecovery({client,playerId:id,airlineId:id});
 assert.equal(r.status,'delayed_crew_recovery_preview');assert.equal(r.airlineId,id);
 assert.ok(calls.every(c=>/^\s*SELECT/.test(c.sql)));
 assert.match(calls.at(-1).sql,/owner_player_id=\$1::uuid/);
 assert.equal(validateFleetAcquisitionRequest({action:'delayed-crew-recovery-preview',airlineId:id}),true);
 assert.equal(validateFleetAcquisitionRequest({action:'delayed-crew-recovery-preview',airlineId:id,execute:true}),false);
});
test('limit overflow and invalid limit fail closed',async()=>{
 await assert.rejects(prepareDelayedCrewRecovery({client:{query:async()=>{}},limit:101}),/INVALID_DELAYED_RECOVERY_REQUEST/);
 const client={async query(sql){if(sql.includes('clock'))return {rows:[{now:'2026-11-23T00:00:00Z'}]};if(sql.includes('verified_world_instant'))return {rows:[{now:'2026-11-23T00:00:00Z'}]};if(sql.includes('owned_rolling_crew_input'))return {rows:[{result:snapshot}]};return {rows:evidence().concat(evidence())};}};
 assert.equal((await prepareDelayedCrewRecovery({client,playerId:id,airlineId:id,limit:1})).status,'delayed_crew_review_limit_exceeded');
});
