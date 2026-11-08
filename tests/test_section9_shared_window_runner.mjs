import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9SharedWindowRunner}
 from '../server/section9-shared-window-runner.mjs';
import {SECTION9_DAY_SQL}
 from '../server/section9-day-preview-runner.mjs';

const mon='2026-11-09',tue='2026-11-10';
const scheduleA='11111111-1111-4111-8111-111111111111';
const scheduleB='22222222-2222-4222-8222-222222222222';
const flight=(scheduleId,day,origin,destination,start,end,airlineId)=>({
 id:scheduleId+':'+day+':1',scheduleId,weeklyEntry:1,
 marketDate:day,status:'operational_verified',localTimeStatus:'valid',
 airlineId,origin,destination,departureUtc:start,arrivalUtc:end,
 passengerSeats:70,cargoTonnes:3,fareUsd:100,cargoRateUsd:80,
 weeklyDepartures:7
});
const one=flight(scheduleA,mon,'A','B',
 '2026-11-09T23:00:00Z','2026-11-10T00:00:00Z','one');
const two=flight(scheduleB,tue,'B','C',
 '2026-11-10T01:00:00Z','2026-11-10T02:00:00Z','two');
function source({bad=false,missingMarket=false}={}){
 const calls=[];let released=0;
 const database={connect:async()=>({
  release(){released++},
  async query(sql,args){
   calls.push({sql,args});
   if(sql===SECTION9_DAY_SQL.flights){
    const day=args[0];let result=[];
    if(day===mon)result=[one];
    if(day===tue)result=[bad?{...two,localTimeStatus:'ambiguous'}:two];
    return {rowCount:1,rows:[{result}]};
   }
   if(sql===SECTION9_DAY_SQL.airportPolicies)
    return {rows:args[0].map(airportKey=>({
     airportKey,minimumTransferMinutes:30,
     background:'major_city',cargoHandling:true}))};
   if(sql===SECTION9_DAY_SQL.agreements)
    return {rows:[{leftAirlineId:'one',rightAirlineId:'two',
      agreementStatus:'active',leftApproved:true,rightApproved:true,
      validFrom:'2026-01-01T00:00:00Z',validUntil:null}]};
   if(sql===SECTION9_DAY_SQL.markets){
    const batch=JSON.parse(args[1]);
    let result=batch.map(p=>({...p,
     passengers:p.origin==='A'&&p.destination==='C'?60:
      p.origin==='B'&&p.destination==='C'?60:0,
     cargoTonnes:p.origin==='A'&&p.destination==='C'?2:
      p.origin==='B'&&p.destination==='C'?2:0}));
    if(missingMarket)result=[];
    return {rowCount:1,rows:[{result}]};
   }
   throw Error('Unexpected SQL query');
  }
 })};
 return {database,calls,releaseCount:()=>released};
}
test('Private reader loads verified adjacent days and allocates shared capacity only once',async()=>{
 const s=source();
 const runner=createSection9SharedWindowRunner({database:s.database});
 const res=await runner.preview({startGameDate:mon,marketDays:2});
 assert.equal(res.status,'read_only_global_capacity_preview');
 assert.equal(res.window.sharedPhysicalInventory,true);
 assert.equal(res.flights.length,2);
 assert.equal(res.flights.find(x=>x.flightId===two.id).passengers,70);
 assert.equal(res.flights.find(x=>x.flightId===two.id).cargoTonnes,3);
 assert.equal(res.passengers.markets.reduce((n,m)=>n+m.allocated,0),70);
 assert.equal(res.bookingsCreated,false);
 assert.equal(res.ledgerPosted,false);
 assert.equal(res.settlementAuthority,false);
 assert.equal(s.calls.filter(c=>c.sql===SECTION9_DAY_SQL.flights).length,4);
 assert.ok(s.calls.some(c=>c.sql===SECTION9_DAY_SQL.markets));
 assert.equal(s.releaseCount(),1);
});
test('Spring/autumn ambiguous verified schedule blocks shared window entirely',async()=>{
 const s=source({bad:true});
 const runner=createSection9SharedWindowRunner({database:s.database});
 await assert.rejects(runner.preview({startGameDate:mon,marketDays:2}),
  /SECTION9_SHARED_WINDOW_UNVERIFIED_OCCURRENCE/);
 assert.equal(s.calls.some(c=>c.sql===SECTION9_DAY_SQL.markets),false);
 assert.equal(s.releaseCount(),1);
});
test('Incomplete airport markets may not silently disappear from demand',async()=>{
 const s=source({missingMarket:true});
 await assert.rejects(createSection9SharedWindowRunner({database:s.database})
  .preview({startGameDate:mon,marketDays:2}),
  /SECTION9_SHARED_WINDOW_INCOMPLETE_MARKET_BATCH/);
 assert.equal(s.releaseCount(),1);
});
test('Invalid game date and oversized windows never connect to the database',async()=>{
 let connected=false;const runner=createSection9SharedWindowRunner({
  database:{connect:async()=>{connected=true}}
 });
 for(const input of [
  {startGameDate:'2026-02-31',marketDays:2},
  {startGameDate:mon,marketDays:1},
  {startGameDate:mon,marketDays:8},
  {startGameDate:mon,marketDays:'3'}
 ]){
  await assert.rejects(runner.preview(input),/SECTION9_INVALID_SHARED_WINDOW_REQUEST/);
 }
 assert.equal(connected,false);
});
