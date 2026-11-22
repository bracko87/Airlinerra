import {planWeeklyCrew} from './weekly-crew-allocation-engine.mjs';

// One-flight contractors are counts, not synthetic employees. Browser callers
// can only read the summary; writes require the private worker and explicit budget.
const SQL={
 clock:'SELECT airlinerra_game.section9_verified_world_instant_v1() AS now',
 owner:'SELECT id FROM airlinerra_game.airlines WHERE id=$1::uuid AND owner_player_id=$2::uuid AND world_id=1 FOR UPDATE',
 bootstrap:'SELECT airlinerra_game.section9_owned_weekly_crew_input_v1($1::uuid,$2::uuid,$3::timestamptz) AS result',
 rolling:'SELECT airlinerra_game.section9_owned_rolling_crew_input_v1($1::uuid,$2::uuid,$3::timestamptz) AS result',
 quote:`SELECT x."flightId" AS "flightId",airlinerra_game.section9_external_crew_quote_v1($1::uuid,x."flightId",x.captains,x."firstOfficers",x."cabinCrew") AS result FROM jsonb_to_recordset($2::jsonb) x("flightId" uuid,captains integer,"firstOfficers" integer,"cabinCrew" integer)`,
 authorized:'SELECT occurrence_id AS "flightId",source_reference AS "reference",quoted_cost_usd AS "quotedCostUsd" FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE airline_id=$1::uuid AND occurrence_id=ANY($2::uuid[])',
 authorize:'SELECT airlinerra_game.section9_authorize_external_crew_v1($1::uuid,$2::uuid,$3::int,$4::int,$5::int,$6::text) AS result',
 save:'SELECT airlinerra_game.section9_save_owned_crew_plan_preview_v1($1::uuid,$2::uuid,$3::uuid,$4::timestamptz,$5::jsonb,$6::jsonb) AS result'
};
const result=r=>r.rows?.[0]?.result;
const cents=v=>{
 if(typeof v!=='number'&&typeof v!=='string')return null;
 if(typeof v==='string'&&!/^\d+(?:\.\d{1,2})?$/.test(v))return null;
 const n=Number(v),c=Math.round(n*100);
 return Number.isFinite(n)&&n>=0&&Number.isSafeInteger(c)&&Math.abs(c-n*100)<0.00001?c:null;
};
const date=v=>v instanceof Date?v.getTime():typeof v==='string'?Date.parse(v):NaN;
const sameTime=(a,b)=>Number.isFinite(date(a))&&date(a)===date(b);
const reference=(planId,flightId)=>'mixed-crew-plan:'+planId+':'+flightId;
const blocked=(status,more={})=>({status,...more,saved:false,contractingPerformed:false,dispatchEnforced:false});
async function clock(client){
 const n=date((await client.query(SQL.clock)).rows?.[0]?.now);
 if(!Number.isFinite(n))throw Error('VERIFIED_GAME_CLOCK_UNAVAILABLE');
 return n;
}
function inputOkay(s,status){return s?.status===status&&s.invalidOccurrenceCount===0&&s.cabinHeadcountReconciled===true&&Array.isArray(s.flights);}
async function quotesFor(client,airlineId,contracts,now){
 if(contracts.length>2000)return {valid:false,reason:'external_quote_limit_reached',quotes:[],totalCents:null};
 if(!contracts.length)return {valid:true,quotes:[],totalCents:0};
 const rows=(await client.query(SQL.quote,[airlineId,JSON.stringify(contracts)])).rows||[];
 const byFlight=new Map(rows.map(x=>[x.flightId,x.result]));
 if(rows.length!==contracts.length||byFlight.size!==contracts.length)return {valid:false,reason:'external_quote_incomplete',quotes:[],totalCents:null};
 const quotes=[];let totalCents=0;
 for(const c of contracts){
  const q=byFlight.get(c.flightId),cost=cents(q?.estimatedCostUsd);
  if(q?.status!=='external_crew_quote'||q.occurrenceId!==c.flightId||typeof q.physicalFlightId!=='string'||q.qualificationGroup!==c.qualificationGroup||
   q.captains!==c.captains||q.firstOfficers!==c.firstOfficers||q.cabinCrew!==c.cabinCrew||!sameTime(q.plannedDepartureUtc,c.departureUtc)||!sameTime(q.plannedArrivalUtc,c.arrivalUtc)||cost===null||cost<=0||
   date(c.departureUtc)-120*60000<now)return {valid:false,reason:'external_quote_or_report_time_unverified',quotes:[],totalCents:null};
  totalCents+=cost;if(!Number.isSafeInteger(totalCents))throw Error('EXTERNAL_COST_OVERFLOW');
  quotes.push({...c,estimatedCostUsd:cost/100,contractingEnabled:q.contractingEnabled===true,physicalFlightId:q.physicalFlightId});
 }
 return {valid:true,quotes,totalCents};
}
function summarize(plan,quote,airlineId){
 const roles={captains:0,firstOfficers:0,cabinCrew:0};
 for(const c of plan.externalContracts)for(const k of Object.keys(roles))roles[k]+=c[k];
 return {status:'external_crew_plan_preview',airlineId,windowStartUtc:plan.windowStartUtc,flightCount:plan.flightCount,
  internalOnlyFlights:plan.assignedFlightCount-plan.externalContracts.length,contractFlights:plan.externalContracts.length,
  unresolvedFlights:plan.unassignedFlightCount,externalRoles:roles,estimatedCostUsd:quote.valid?quote.totalCents/100:null,
  quoteStatus:quote.valid?'verified_preview':quote.reason,contractingEnabled:quote.quotes.length>0&&quote.quotes.every(q=>q.contractingEnabled),
  flights:quote.quotes.slice(0,50).map(({flightId,origin,departureUtc,captains,firstOfficers,cabinCrew,estimatedCostUsd})=>({flightId,origin,departureUtc,captains,firstOfficers,cabinCrew,estimatedCostUsd})),
  detailsTruncated:quote.quotes.length>50,saved:false,contractingPerformed:false,dispatchEnforced:false,scheduleCompletenessVerified:false};
}
// Owner is checked by the HTTP handler and independently by the rolling input SQL.
// No permanent roster IDs, snapshot or write actions are returned to the browser.
export async function previewExternalCrewPlan({client,playerId,airlineId}){
 if(typeof client?.query!=='function')throw Error('INVALID_EXTERNAL_CREW_CLIENT');
 // The verified game clock can advance between statements. Leave a small
 // lead for the rolling-input boundary; flights already reporting are held.
 const now=await clock(client),start=new Date(now+60000).toISOString();
 const snapshot=result(await client.query(SQL.rolling,[playerId,airlineId,start]));
 if(!inputOkay(snapshot,'rolling_crew_input_preview'))return blocked('external_crew_input_unreconciled',{airlineId});
 if(snapshot.unboundDeparturesLast7Days!==0||snapshot.unresolvedCaptureIssues!==0||snapshot.alreadyReportedFutureFlights!==0)return blocked('external_crew_history_requires_review',{airlineId});
 const plan=planWeeklyCrew({...snapshot,planNotBeforeUtc:snapshot.planningCutoffUtc},{externalCrewPreview:true});
 const quote=await quotesFor(client,airlineId,plan.externalContracts,now);
 return summarize(plan,quote,airlineId);
}
// Private bootstrap worker. Existing live duty history is NOT overwritten.
// Contract authorizations and independently validated save commit together or
// roll back together. The live release flag still controls contracting.
export async function prepareExternalCrewPlan({client,playerId,airlineId,planId,windowStartUtc,save=false,authorizeExternal=false,maxExternalCostUsd=0}){
 if(typeof client?.query!=='function'||typeof planId!=='string'||typeof save!=='boolean'||typeof authorizeExternal!=='boolean'||cents(maxExternalCostUsd)===null)throw Error('INVALID_EXTERNAL_CREW_WORKER_INPUT');
 let inTx=false;
 const finish=async value=>{if(inTx){await client.query('ROLLBACK');inTx=false;}return value;};
 try{
  if(save){await client.query('BEGIN');inTx=true;
   const own=await client.query(SQL.owner,[airlineId,playerId]);if(own.rowCount!==1)return await finish(blocked('external_crew_airline_not_owned'));
  }
  const now=await clock(client),start=date(windowStartUtc);
  if(!Number.isFinite(start)||start<now||start>now+7*86400000)return await finish(blocked('crew_plan_window_invalid'));
  const snapshot=result(await client.query(SQL.bootstrap,[playerId,airlineId,windowStartUtc]));
  if(!inputOkay(snapshot,'weekly_crew_bootstrap_input_preview'))return await finish(blocked('external_crew_input_unreconciled'));
  if(!snapshot.flights.length)return await finish(blocked('no_dated_flights'));
  const plan=planWeeklyCrew({...snapshot,planNotBeforeUtc:new Date(now).toISOString()},{externalCrewPreview:true});
  const quote=await quotesFor(client,airlineId,plan.externalContracts,now);
  const summary=summarize(plan,quote,airlineId);
  if(!save)return {...summary,plan};
  if(plan.unassignedFlightCount!==0||!quote.valid)return await finish(blocked('external_crew_plan_incomplete',{plan,summary}));
  if(plan.externalContracts.length&&(!authorizeExternal||!summary.contractingEnabled||quote.totalCents>cents(maxExternalCostUsd)))return await finish(blocked('external_crew_authorization_not_ready',{plan,summary}));
  const proposed=new Map(quote.quotes.map(q=>[q.flightId,q]));
  const existing=(await client.query(SQL.authorized,[airlineId,plan.assignments.map(a=>a.flightId)])).rows||[];
  if(existing.some(e=>!proposed.has(e.flightId)||e.reference!==reference(planId,e.flightId)||cents(e.quotedCostUsd)!==cents(proposed.get(e.flightId).estimatedCostUsd)))return await finish(blocked('existing_external_contract_requires_review',{plan,summary}));
  for(const q of quote.quotes){
   const a=result(await client.query(SQL.authorize,[airlineId,q.flightId,q.captains,q.firstOfficers,q.cabinCrew,reference(planId,q.flightId)]));
   if(!['external_crew_contract_authorized','external_crew_contract_already_authorized'].includes(a?.status)||a.physicalFlightId!==q.physicalFlightId||a.ledgerPosted!==false||
    (a.status==='external_crew_contract_authorized'&&cents(a.quotedCostUsd)!==cents(q.estimatedCostUsd)))return await finish(blocked('external_contract_authorization_failed',{plan,summary}));
  }
  const receipt=result(await client.query(SQL.save,[playerId,airlineId,planId,windowStartUtc,JSON.stringify(snapshot),JSON.stringify(plan.assignments)]));
  if(receipt?.status!=='validated_preview'||(receipt.saved!==true&&receipt.replayed!==true))return await finish(blocked('external_crew_plan_save_failed',{plan,summary}));
  await client.query('COMMIT');inTx=false;
  return {status:'validated_preview',plan,summary,receipt,saved:true,contractingPerformed:quote.quotes.length>0,dispatchEnforced:false};
 }catch(e){if(inTx){try{await client.query('ROLLBACK');}catch{}inTx=false;}throw e;}
}
