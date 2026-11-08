import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9DayPreviewRunner,SECTION9_DAY_SQL}
 from '../server/section9-day-preview-runner.mjs';
import {section9DiscoverReachableMarkets} from '../server/section9-network-demand-engine.mjs';

const date='2026-11-09';
const flight=(id,airlineId,origin,destination,start,end)=>{
 const scheduleId='11111111-1111-4111-8111-11111111111'+id.slice(-1);
 return {
  id:scheduleId+':'+date+':1',scheduleId,weeklyEntry:1,
  localTimeStatus:'valid',airlineId,origin,destination,
  marketDate:date,departureUtc:start,arrivalUtc:end,
  passengerSeats:80,cargoTonnes:1,fareUsd:100,cargoRateUsd:60,
  weeklyDepartures:7,status:'operational_verified'
 };
};
const one=flight('f1','airlineA','A','B','2026-11-09T09:00:00Z','2026-11-09T10:00:00Z');
const two=flight('f2','airlineB','B','C','2026-11-09T11:10:00Z','2026-11-09T12:10:00Z');

test('Trusted daily runner returns empty when game has no activated flights',async()=>{
 const calls=[];
 const runner=createSection9DayPreviewRunner({database:{connect:async()=>({
  query:async(sql,args)=>{calls.push({sql,args});
   assert.equal(sql,SECTION9_DAY_SQL.flights);
   return {rows:[{result:[]}]};
  },release(){}
 })}});
 const result=await runner.preview({gameDate:date});
 assert.equal(result.status,'no_active_flights');
 assert.equal(result.flights.length,0);
 assert.equal(result.writesToAirlineLedger,false);
 assert.equal(calls.length,3);
});
test('Rejected local date never contacts the database',async()=>{
 let touched=false;
 const runner=createSection9DayPreviewRunner({database:{connect:async()=>{touched=true;}}});
 await assert.rejects(runner.preview({gameDate:'2026-99-35'}),/INVALID_GAME_DATE/);
 assert.equal(touched,false);
});

test('Discovery includes an A->C market even when no airline operates A->C directly',()=>{
 const agreements=[{leftAirlineId:'airlineA',rightAirlineId:'airlineB',
  agreementStatus:'active',leftApproved:true,rightApproved:true,
  validFrom:'2026-11-01T00:00:00Z'}];
 const airports={B:{minimumTransferMinutes:55,cargoHandling:true}};
 const yes=section9DiscoverReachableMarkets({
  flights:[one,two],marketDate:date,agreements,airports});
 assert.deepEqual(yes.pairs,[{origin:'A',destination:'B'},
  {origin:'A',destination:'C'},{origin:'B',destination:'C'}]);
 const no=section9DiscoverReachableMarkets({
  flights:[one,two],marketDate:date,airports});
 assert.deepEqual(no.pairs,[{origin:'A',destination:'B'},{origin:'B',destination:'C'}]);
});

test('Runner batches true market demand, checks partnerships and avoids shared-leg overbooking',async()=>{
 let calls=0,marketCalls=0,released=0;
 const runner=createSection9DayPreviewRunner({database:{connect:async()=>({
  release(){released++;},
  query:async(sql,args)=>{
   calls++;
   if(sql===SECTION9_DAY_SQL.flights)
    return {rows:[{result:args[0]===date?[one,two]:[]}]};
   if(sql===SECTION9_DAY_SQL.airportPolicies)
    return {rows:['A','B','C'].map(airportKey=>({
     airportKey,minimumTransferMinutes:55,background:'major_city',cargoHandling:true
    }))};
   if(sql===SECTION9_DAY_SQL.agreements)
    return {rows:[{leftAirlineId:'airlineA',rightAirlineId:'airlineB',
     agreementStatus:'active',leftApproved:true,rightApproved:true,
     validFrom:'2026-11-01T00:00:00Z',validUntil:null}]};
   if(sql===SECTION9_DAY_SQL.markets){
    marketCalls++;
    const pairs=JSON.parse(args[1]);
    return {rows:[{result:pairs.map(p=>({...p,
      passengers:p.origin==='A'&&p.destination==='C'?60:30,
      cargoTonnes:1}))}]};
   }
   throw Error('Unexpected SQL');
  }
 })}});
 const result=await runner.preview({gameDate:date});
 assert.equal(result.status,'forecast_only');
 assert.equal(result.discovery.discoveredMarketPairs,3);
 assert.equal(marketCalls,1);
 assert.ok(calls>=6);
 assert.equal(released,1);
 assert.ok(result.flights.every(x=>x.passengers<=x.passengerSeats));
 assert.ok(result.flights.every(x=>x.cargoTonnes<=x.cargoCapacityTonnes));
 assert.ok(result.passengers.markets.some(x=>typeof x.marketId==='string'&&x.allocated>0));
 assert.equal(result.writesToAirlineLedger,false);
 assert.equal(result.flightActivationAllowed,false);
});


test('Verified occurrence pagination keeps two same-schedule departures across a page boundary',async()=>{
 const base=flight('f3','airlineA','A','B',
  '2026-11-09T09:00:00Z','2026-11-09T10:00:00Z');
 // Synthetic high-volume schedule: 1001 entries under one schedule UUID.
 const mk=index=>({...base,id:base.scheduleId+':'+date+':'+index,weeklyEntry:index});
 const first=Array.from({length:1000},(_,i)=>mk(i+1));
 const second=[mk(1001)];
 const seen=[];
 const runner=createSection9DayPreviewRunner({database:{connect:async()=>({
  release(){},
  async query(sql,args){
   if(sql===SECTION9_DAY_SQL.flights){
    seen.push(args);
    if(args[0]!==date)return {rows:[{result:[]}]};
    if(args[2]===null)return {rows:[{result:first}]};
    assert.equal(args[2],base.scheduleId);
    assert.equal(args[3],1000);
    return {rows:[{result:second}]};
   }
   if(sql===SECTION9_DAY_SQL.airportPolicies){
    return {rows:['A','B'].map(airportKey=>({
     airportKey,minimumTransferMinutes:25,background:'major_city',cargoHandling:true
    }))};
   }
   if(sql===SECTION9_DAY_SQL.agreements)return {rows:[]};
   if(sql===SECTION9_DAY_SQL.markets)return {
    rows:[{result:[{origin:'A',destination:'B',passengers:0,cargoTonnes:0}]}]
   };
   throw Error('Unexpected SQL');
  }
 })}});
 const result=await runner.preview({gameDate:date});
 assert.equal(result.flights.length,1001);
 assert.equal(new Set(result.flights.map(x=>x.flightId)).size,1001);
 assert.equal(seen.filter(x=>x[0]===date).length,2);
});

test('DST ambiguous local departure must fail before any market allocation',async()=>{
 const bad={...one,localTimeStatus:'ambiguous'};
 let marketsQueried=false;
 const runner=createSection9DayPreviewRunner({database:{connect:async()=>({
  release(){},
  async query(sql,args){
   if(sql===SECTION9_DAY_SQL.flights)
    return {rows:[{result:args[0]===date?[bad]:[]}]};
   marketsQueried=true;
   throw Error('Market lookup must never run');
  }
 })}});
 await assert.rejects(runner.preview({gameDate:date}),
  /INVALID_OR_AMBIGUOUS_FLIGHT_OCCURRENCE/);
 assert.equal(marketsQueried,false);
});
