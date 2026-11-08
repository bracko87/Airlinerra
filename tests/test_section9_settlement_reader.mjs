import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9SettlementPreflightRunner,SECTION9_COMPLETED_FLIGHT_SQL}
 from '../server/section9-settlement-preflight-runner.mjs';

const center='2026-11-09',before='2026-11-08',after='2026-11-10';
const scheduleId='11111111-1111-4111-8111-111111111111',
 airlineId='22222222-2222-4222-8222-222222222222';
const flight=(index=1,fields={})=>({
 flightId:scheduleId+':'+center+':'+index,scheduleId,weeklyEntry:index,
 scheduleVersion:1,commercialPlanVersion:1,
 capacitySource:'verified_activated_schedule',
 verificationSource:'proved-layout',
 airlineId,marketDate:center,
 departureUtc:'2026-11-09T10:00:00Z',
 arrivalUtc:'2026-11-09T12:00:00Z',
 passengerSeats:100,passengers:70,directPassengers:50,connectingPassengers:20,
 cargoCapacityTonnes:2,cargoTonnes:0.5,
 ticketRevenueUsd:700,cargoRevenueUsd:50,...fields
});
function dbFor(byDate){
 const requests=[];let releases=0;
 return {requests,releaseCount:()=>releases,
  database:{async connect(){
   return {release(){releases++},async query(sql,args){
    assert.equal(sql,SECTION9_COMPLETED_FLIGHT_SQL);
    requests.push(args);
    const [day,cursor,limit]=args;
    assert.equal(limit,5);
    const p=byDate[day];
    if(!p)return {rowCount:1,rows:[{result:{
     gameDate:day,status:'missing',readOnly:true,chunks:[]}}]};
    const all=p.chunks||[];
    return {rowCount:1,rows:[{result:{
     gameDate:day,status:p.status||'completed',readOnly:true,
     flightRows:p.flightRows??all.flatMap(c=>c.rows).length,
     chunks:all.filter(c=>c.chunkNumber>cursor).slice(0,limit)
    }}]};
   }};
  }}};
}
test('Actual saved completed snapshots are loaded through private chunk pages',async()=>{
 const source=dbFor({
  [before]:{chunks:[{chunkNumber:0,rows:[flight()]}]},
  [center]:{chunks:[{chunkNumber:0,rows:[flight(1,{
   passengers:20,directPassengers:0,connectingPassengers:20,
   cargoTonnes:0.5,ticketRevenueUsd:200,cargoRevenueUsd:50
  })]}]},
  [after]:{chunks:[],flightRows:0}
 });
 const runner=createSection9SettlementPreflightRunner({database:source.database});
 const result=await runner.inspect({targetDate:center});
 assert.equal(result.status,'preview_reconciled');
 assert.equal(result.overlappingFlightOccurrences,1);
 assert.equal(result.futureLedgerIntents.find(x=>x.kind==='PASSENGER_REVENUE').amountUsd,900);
 assert.equal(result.futureLedgerIntents.find(x=>x.kind==='CARGO_REVENUE').amountUsd,100);
 assert.equal(result.ledgerPostingAllowed,false);
 assert.equal(source.releaseCount(),1);
 assert.equal(source.requests.length,3);
});
test('Missing completed neighboring day blocks any future ledger intents',async()=>{
 const source=dbFor({
  [before]:{chunks:[]},
  [center]:{chunks:[{chunkNumber:0,rows:[flight()]}]}
 });
 const runner=createSection9SettlementPreflightRunner({database:source.database});
 const result=await runner.inspect({targetDate:center});
 assert.equal(result.status,'blocked_incomplete_neighboring_forecasts');
 assert.deepEqual(result.missingCompletedDates,[after]);
 assert.equal(result.ledgerPostingAllowed,false);
 assert.equal(source.releaseCount(),1);
});
test('Chunk paging retains all results across a five-chunk boundary',async()=>{
 const chunks=Array.from({length:6},(_,i)=>({
  chunkNumber:i,rows:[flight(i+1,{
   passengers:1,directPassengers:1,connectingPassengers:0,
   ticketRevenueUsd:10,cargoTonnes:0,cargoRevenueUsd:0
  })]
 }));
 const source=dbFor({
  [before]:{chunks:[]},
  [center]:{chunks,flightRows:6},
  [after]:{chunks:[]}
 });
 const runner=createSection9SettlementPreflightRunner({database:source.database});
 const result=await runner.inspect({targetDate:center});
 assert.equal(result.status,'preview_reconciled');
 assert.equal(result.uniqueFlightOccurrences,6);
 assert.equal(result.totalFlightRowsChecked,6);
 assert.equal(source.requests.filter(r=>r[0]===center).length,2);
});
test('Missing completed chunk causes failure, not silent partial settlement',async()=>{
 const source=dbFor({
  [before]:{chunks:[]},
  [center]:{chunks:[{chunkNumber:0,rows:[flight()]}],flightRows:2},
  [after]:{chunks:[]}
 });
 await assert.rejects(
  createSection9SettlementPreflightRunner({database:source.database})
   .inspect({targetDate:center}),
  /SECTION9_SETTLEMENT_READER_MISSING_COMPLETED_ROWS/
 );
 assert.equal(source.releaseCount(),1);
});
test('No database access for malformed date',async()=>{
 let touched=false;
 const runner=createSection9SettlementPreflightRunner({
  database:{async connect(){touched=true;}}
 });
 await assert.rejects(runner.inspect({targetDate:'2026-02-31'}),
  /SECTION9_INVALID_SETTLEMENT_INSPECTION/);
 assert.equal(touched,false);
});
