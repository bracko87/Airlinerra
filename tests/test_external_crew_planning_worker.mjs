import test from 'node:test';
import assert from 'node:assert/strict';
import {prepareExternalCrewPlan,previewExternalCrewPlan} from '../server/external-crew-planning-worker.mjs';
import {validateFleetAcquisitionRequest} from '../server/fleet-acquisition-service.mjs';
import {runRollingCrewReplanning} from '../server/rolling-crew-replacement-worker.mjs';
const now='2026-11-23T00:00:00Z',start='2026-11-24T00:00:00Z',id='11111111-1111-4111-8111-111111111111';
const flight={id:'f1',aircraftId:'airframe',group:'family:12',origin:'BEG',destination:'LHR',departureUtc:'2026-11-24T06:00:00Z',arrivalUtc:'2026-11-24T09:00:00Z',cabinRequired:4};
const snapshot={status:'weekly_crew_bootstrap_input_preview',windowStartUtc:start,flights:[flight],pilots:[],cabinMembers:[],invalidOccurrenceCount:0,cabinHeadcountReconciled:true};
function mock({release=true,saveStatus='validated_preview',authorizeStatus='external_crew_contract_authorized',unauthorized=false,history=false,reported=false,existing=[]}={}){
 const calls=[];
 const client={async query(sql,args=[]){calls.push({sql,args});const row=result=>({rowCount:1,rows:[{result}]});
  if(sql==='BEGIN'||sql==='COMMIT'||sql==='ROLLBACK')return {rows:[]};
  if(sql.includes(' FOR UPDATE'))return {rowCount:unauthorized?0:1,rows:[]};
  if(sql.includes('verified_world_instant'))return {rows:[{now}]};
  if(sql.includes('owned_weekly_crew_input'))return row(snapshot);
  if(sql.includes('owned_rolling_crew_input')){assert.ok(Date.parse(args[2])>Date.parse(now));return row({...snapshot,status:'rolling_crew_input_preview',windowStartUtc:args[2],planningCutoffUtc:now,unboundDeparturesLast7Days:history?1:0,unresolvedCaptureIssues:0,alreadyReportedFutureFlights:reported?1:0});}
  if(sql.includes('external_crew_quote'))return {rows:[{flightId:flight.id,result:{status:'external_crew_quote',occurrenceId:flight.id,physicalFlightId:'physical-1',qualificationGroup:flight.group,captains:1,firstOfficers:1,cabinCrew:4,plannedDepartureUtc:flight.departureUtc,plannedArrivalUtc:flight.arrivalUtc,estimatedCostUsd:3000,contractingEnabled:release}}]};
  if(sql.includes('external_crew_contracts_v1'))return {rows:existing};
  if(sql.includes('authorize_external_crew'))return row({status:authorizeStatus,physicalFlightId:'physical-1',quotedCostUsd:3000,ledgerPosted:false});
  if(sql.includes('save_owned_crew_plan')||sql.includes('save_owned_rolling_crew_plan'))return row({status:saveStatus,saved:saveStatus==='validated_preview'});
  throw Error('Unexpected query '+sql);
 }};
 return {client,calls};
}
const opts=client=>({client,airlineId:id,playerId:id,planId:id,windowStartUtc:start,save:true,authorizeExternal:true,maxExternalCostUsd:3000});
test('browser preview is owner-scoped, read-only and contains no internal roster',async()=>{const m=mock();const r=await previewExternalCrewPlan({client:m.client,playerId:id,airlineId:id});assert.equal(r.contractFlights,1);assert.equal(r.externalRoles.cabinCrew,4);assert.equal(r.estimatedCostUsd,3000);assert.equal(r.contractingPerformed,false);assert.equal(r.plan,undefined);assert.ok(m.calls.every(c=>c.sql.startsWith('SELECT')));});
test('private worker commits only after verified contracts and roster save',async()=>{const m=mock();const r=await prepareExternalCrewPlan(opts(m.client));assert.equal(r.saved,true);assert.equal(r.plan.assignments[0].captains.length,0);assert.equal(m.calls.at(-1).sql,'COMMIT');assert.ok(m.calls.find(c=>c.sql.includes('authorize_external_crew')));});
test('disabled release, missing authorization and budget all prevent contract writes',async()=>{for(const [m,overrides] of [[mock({release:false}),{}],[mock(),{authorizeExternal:false}],[mock(),{maxExternalCostUsd:2999.99}]]){const r=await prepareExternalCrewPlan({...opts(m.client),...overrides});assert.equal(r.saved,false);assert.equal(m.calls.at(-1).sql,'ROLLBACK');assert.ok(!m.calls.some(c=>c.sql.includes('authorize_external_crew')));}});
test('authorization or validated-plan failure rolls back all writes',async()=>{for(const m of [mock({saveStatus:'live_duty_history_required'}),mock({authorizeStatus:'external_crew_insufficient_funds'})]){const r=await prepareExternalCrewPlan(opts(m.client));assert.equal(r.saved,false);assert.equal(m.calls.at(-1).sql,'ROLLBACK');assert.ok(!m.calls.some(c=>c.sql==='COMMIT'));}});
test('unowned company and incomplete actual history fail closed',async()=>{const m=mock({unauthorized:true});assert.equal((await prepareExternalCrewPlan(opts(m.client))).status,'external_crew_airline_not_owned');const k=mock({history:true});assert.equal((await previewExternalCrewPlan({client:k.client,playerId:id,airlineId:id})).status,'external_crew_history_requires_review');});
test('browser action admits no charge, contract counts or owner override',()=>{assert.equal(validateFleetAcquisitionRequest({action:'external-crew-preview',airlineId:id}),true);assert.equal(validateFleetAcquisitionRequest({action:'external-crew-preview',airlineId:id,authorizeExternal:true}),false);assert.equal(validateFleetAcquisitionRequest({action:'external-crew-preview',airlineId:id,playerId:id}),false);});

test('rolling execution validates completed duty snapshot and uses rolling save, never bootstrap save',async()=>{
 const m=mock();const r=await runRollingCrewReplanning({...opts(m.client),execute:true});
 assert.equal(r.saved,true);assert.equal(r.rolling,true);
 assert.ok(m.calls.some(c=>c.sql.includes('owned_rolling_crew_input')));
 assert.ok(m.calls.some(c=>c.sql.includes('save_owned_rolling_crew_plan')));
 assert.ok(!m.calls.some(c=>c.sql.includes('save_owned_crew_plan_preview')));
 assert.equal(m.calls.at(-1).sql,'COMMIT');
});
test('rolling preview never writes and already-reported duties are protected before contracting',async()=>{
 const m=mock();const preview=await runRollingCrewReplanning({...opts(m.client),execute:false});
 assert.equal(preview.saved,false);assert.ok(m.calls.every(c=>c.sql.startsWith('SELECT')));
 const held=mock({reported:true});const r=await runRollingCrewReplanning({...opts(held.client),execute:true});
 assert.equal(r.status,'active_duty_continuation_required');assert.equal(held.calls.at(-1).sql,'ROLLBACK');
 assert.ok(!held.calls.some(c=>c.sql.includes('authorize_external_crew')));
 const history=mock({history:true});assert.equal((await runRollingCrewReplanning({...opts(history.client),execute:true})).status,'crew_history_incomplete');
});
test('rolling replan preserves original reference of unchanged existing contract',async()=>{
 const m=mock({existing:[{flightId:'f1',reference:'prior-plan-contract',quotedCostUsd:'3000.00'}],authorizeStatus:'external_crew_contract_already_authorized'});
 const r=await runRollingCrewReplanning({...opts(m.client),execute:true});
 assert.equal(r.saved,true);assert.equal(r.contractingPerformed,false);
 assert.equal(m.calls.find(c=>c.sql.includes('authorize_external_crew')).args.at(-1),'prior-plan-contract');
 const changed=mock({existing:[{flightId:'f1',reference:'prior-plan-contract',quotedCostUsd:'3100.00'}]});
 assert.equal((await runRollingCrewReplanning({...opts(changed.client),execute:true})).status,'existing_external_contract_requires_review');
 assert.equal(changed.calls.at(-1).sql,'ROLLBACK');
});
