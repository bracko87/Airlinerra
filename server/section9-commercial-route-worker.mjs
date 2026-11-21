/**
 * Private commercial schedule worker. Processes the existing saved roundtrip
 * queue with the real independent signing modules and atomic pair finalizer.
 * No browser endpoint, caller-selected schedule, clock override or release
 * switch. A trusted host must supply the private DB pool and five distinct keys.
 */
import {createSection9RoundtripCertificationCoordinator,SECTION9_ROUNDTRIP_REQUIRED_AUTHORITIES}
 from './section9-roundtrip-certification-coordinator.mjs';
import {createSection9SignedCertificationIngress} from './section9-signed-certification-ingress.mjs';
import {createSection9GamePermissionVerifierIssuer} from './section9-game-permission-verifier-issuer.mjs';
import {createSection9GameSlotClearanceIssuer} from './section9-game-slot-clearance-issuer.mjs';
import {createSection9ExecutionFinanceEvidenceSigner} from './section9-execution-finance-evidence-signer.mjs';

export const SECTION9_COMMERCIAL_ROUTE_SQL=Object.freeze({
 readiness:`SELECT r.world_id,r.world_state,r.authoritative_clock_connected,r.clock_producer_enabled,
 r.trusted_flight_execution_release,r.fuel_transaction_release,r.automatic_flight_and_fuel_settlement_enabled,
 airlinerra_game.section9_verified_berlin_game_hour_v1() AS game_hour
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 r WHERE r.world_id=1`,
 queue:`SELECT pair_key::text,airline_id::text,outbound_schedule_id::text,return_schedule_id::text,
 outbound_version,return_version
 FROM airlinerra_game.section9_private_roundtrip_certification_queue_v1
 WHERE world_id=1 AND status='awaiting_independent_certification'
 ORDER BY staged_at,pair_key LIMIT $1::integer`,
 finish:`SELECT airlinerra_game.section9_finish_staged_certified_roundtrip_v1($1::uuid) AS result`
});
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validDay=s=>typeof s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const ready=r=>r?.world_id===1&&r.world_state==='active'&&
 r.authoritative_clock_connected===true&&r.clock_producer_enabled===true&&
 r.trusted_flight_execution_release==='ACTIVATED'&&r.fuel_transaction_release==='ACTIVATED'&&
 r.automatic_flight_and_fuel_settlement_enabled===true&&
 r.game_hour?.authoritativeGameHourAvailable===true&&validDay(r.game_hour.gameDate);

export function createSection9CommercialRouteWorker({database,authoritySecrets}={}){
 if(typeof database?.connect!=='function')throw Error('SECTION9_COMMERCIAL_ROUTE_PRIVATE_DB_REQUIRED');
 const keys=SECTION9_ROUNDTRIP_REQUIRED_AUTHORITIES.map(t=>authoritySecrets?.[t]);
 if(keys.some(k=>typeof k!=='string'||k.length<32)||new Set(keys).size!==keys.length)
  throw Error('SECTION9_COMMERCIAL_ROUTE_FIVE_DISTINCT_KEYS_REQUIRED');
 const make=type=>{
  const key=authoritySecrets[type];
  const certificationIngress=createSection9SignedCertificationIngress({database,clearanceType:type,verifierSecret:key});
  if(type==='airport_slot_capacity')return createSection9GameSlotClearanceIssuer({database,slotAuthoritySecret:key,certificationIngress});
  if(type==='operator_licence'||type==='route_traffic_rights')return createSection9GamePermissionVerifierIssuer({database,clearanceType:type,verifierSecret:key,certificationIngress});
  return createSection9ExecutionFinanceEvidenceSigner({database,clearanceType:type,authoritySecret:key,certificationIngress});
 };
 const coordinator=createSection9RoundtripCertificationCoordinator({
  operatorIssuer:make('operator_licence'),routeRightsIssuer:make('route_traffic_rights'),
  slotIssuer:make('airport_slot_capacity'),executionIssuer:make('trusted_flight_execution'),financeIssuer:make('commercial_finance')
 });
 async function query(sql,args=[]){
  const c=await database.connect();
  try{return await c.query(sql,args);}finally{c.release();}
 }
 return Object.freeze({
  async runBatch({limit=10}={}){
   if(!Number.isInteger(limit)||limit<1||limit>50)throw Error('SECTION9_COMMERCIAL_ROUTE_BATCH_LIMIT');
   const state=await query(SECTION9_COMMERCIAL_ROUTE_SQL.readiness);
   if(state.rowCount!==1||!ready(state.rows[0]))return {status:'commercial_route_release_blocked',checked:0,activated:0,waiting:0};
   const gameDate=state.rows[0].game_hour.gameDate;
   const rows=await query(SECTION9_COMMERCIAL_ROUTE_SQL.queue,[limit]);
   if(!Array.isArray(rows.rows)||rows.rows.length>limit)throw Error('SECTION9_COMMERCIAL_ROUTE_INVALID_QUEUE');
   const summary={status:'commercial_route_batch_completed',checked:0,activated:0,waiting:0};
   for(const row of rows.rows){
    if(!UUID.test(row.pair_key)||!UUID.test(row.airline_id)||!UUID.test(row.outbound_schedule_id)||
     !UUID.test(row.return_schedule_id)||row.outbound_schedule_id===row.return_schedule_id)
     throw Error('SECTION9_COMMERCIAL_ROUTE_INVALID_PAIR');
    summary.checked++;
    const result=await coordinator.certifyPreparedPair({
     airlineId:row.airline_id,outboundScheduleId:row.outbound_schedule_id,returnScheduleId:row.return_schedule_id,
     outboundVersion:row.outbound_version,returnVersion:row.return_version,gameDate
    });
    if(result.certificationComplete!==true||result.confirmedCertificates!==10){
     summary.waiting++;continue;
    }
    // The real SQL finalizer independently locks and rechecks all ten
    // current signed receipts, ownership, clock, release, aircraft and seats.
    const final=await query(SECTION9_COMMERCIAL_ROUTE_SQL.finish,[row.pair_key]);
    const proof=final.rows?.[0]?.result;
    if(final.rowCount!==1||proof?.ledgerPosted!==false)
     throw Error('SECTION9_COMMERCIAL_ROUTE_INVALID_FINALIZER_RESULT');
    if(proof.status==='certified_roundtrip_operating_inventory_committed'&&
     proof.pairKey===row.pair_key&&proof.operatingRouteCreatedNow===true&&proof.ticketSalesOpen===true&&
     Number(proof.outboundSaleableOccurrences)>0&&Number(proof.returnSaleableOccurrences)>0)summary.activated++;
    else if(proof.status==='certified_roundtrip_pair_already_active'&&proof.pairKey===row.pair_key&&proof.replayed===true)summary.activated++;
    else if(['certification_pair_waiting_for_independent_approvals','blocked_unverified_game_hour'].includes(proof.status))summary.waiting++;
    else throw Error('SECTION9_COMMERCIAL_ROUTE_UNEXPECTED_FINALIZER_STATE');
   }
   return summary;
  }
 });
}
