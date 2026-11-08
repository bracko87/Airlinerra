import test from 'node:test';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {section9SimulateSharedWindow,section9DiscoverSharedWindowPairs}
 from '../server/section9-shared-window-engine.mjs';
import {section9SimulateDay} from '../server/section9-network-demand-engine.mjs';

const monday='2026-11-09',tuesday='2026-11-10';
const f=(id,day,airline,from,to,start,end,extras={})=>({
 id,marketDate:day,airlineId:airline,
 origin:from,destination:to,status:'operational_verified',
 departureUtc:start,arrivalUtc:end,passengerSeats:70,
 cargoTonnes:3,fareUsd:100,cargoRateUsd:80,...extras
});
const first=f('first',monday,'one','A','B',
 '2026-11-09T23:00:00Z','2026-11-10T00:00:00Z');
const shared=f('shared',tuesday,'two','B','C',
 '2026-11-10T01:00:00Z','2026-11-10T02:00:00Z');
const aToC={id:'monday-A-C',origin:'A',destination:'C',
 marketDate:monday,passengers:60,cargoTonnes:2};
const bToC={id:'tuesday-B-C',origin:'B',destination:'C',
 marketDate:tuesday,passengers:60,cargoTonnes:2};
const airports={B:{minimumTransferMinutes:30,
 background:'major_city',cargoHandling:true}};
const agreements=[{
 leftAirlineId:'one',rightAirlineId:'two',
 agreementStatus:'active',leftApproved:true,rightApproved:true,
 validFrom:'2026-01-01T00:00:00Z'
}];

test('Independent dates can double-book; shared window conserves the physical flight',()=>{
 const mondayOnly=section9SimulateDay({
  flights:[first,shared],markets:[aToC],airports,agreements});
 const tuesdayOnly=section9SimulateDay({
  flights:[first,shared],markets:[bToC],airports,agreements});
 assert.equal(mondayOnly.flights.find(x=>x.flightId==='shared').passengers,60);
 assert.equal(tuesdayOnly.flights.find(x=>x.flightId==='shared').passengers,60);
 assert.equal(60+60>shared.passengerSeats,true);
 const result=section9SimulateSharedWindow({
  marketDates:[monday,tuesday],flights:[first,shared],
  markets:[aToC,bToC],airports,agreements
 });
 const leg=result.flights.find(x=>x.flightId==='shared');
 const allocated=result.passengers.markets.reduce((n,m)=>n+m.allocated,0);
 assert.equal(leg.passengers,70);
 assert.equal(allocated,70);
 assert.equal(result.passengers.markets.reduce((n,m)=>n+m.unserved,0),50);
 assert.equal(leg.cargoTonnes,3);
 assert.ok(result.cargo.markets.reduce((n,m)=>n+m.allocated,0)<=3);
 assert.equal(result.bookingsCreated,false);
 assert.equal(result.settlementAuthority,false);
 assert.equal(result.ledgerPosted,false);
 assert.equal(result.window.sharedPhysicalInventory,true);
});

test('Market discovery sees across midnight but never duplicates market-date pair',()=>{
 const p=section9DiscoverSharedWindowPairs({
  marketDates:[monday,tuesday],flights:[first,shared],
  airports,agreements
 });
 assert.ok(p.pairs.some(x=>x.marketDate===monday&&x.origin==='A'&&x.destination==='C'));
 assert.ok(p.pairs.some(x=>x.marketDate===tuesday&&x.origin==='B'&&x.destination==='C'));
 assert.equal(new Set(p.pairs.map(x=>[x.marketDate,x.origin,x.destination].join('|'))).size,p.count);
});

test('Expired partnership cannot route prior-day travellers onto next day flight',()=>{
 const expired=[{...agreements[0],validUntil:'2026-11-09T23:30:00Z'}];
 const r=section9SimulateSharedWindow({
  marketDates:[monday,tuesday],flights:[first,shared],
  markets:[aToC,bToC],airports,agreements:expired
 });
 assert.equal(r.passengers.markets.find(x=>x.marketId===aToC.id).allocated,0);
 assert.equal(r.passengers.markets.find(x=>x.marketId===bToC.id).allocated,60);
});

test('Same market days in any input order produce deterministic combined output',()=>{
 const one=section9SimulateSharedWindow({
  marketDates:[monday,tuesday],flights:[first,shared],
  markets:[aToC,bToC],airports,agreements});
 const reversed=section9SimulateSharedWindow({
  marketDates:[monday,tuesday],flights:[shared,first],
  markets:[bToC,aToC],airports,agreements});
 assert.deepEqual(one.flights,reversed.flights);
 assert.deepEqual(one.passengers.markets,reversed.passengers.markets);
});

test('Malformed/overlapping dates or duplicate occurrence fail closed',()=>{
 for(const dates of [
  [tuesday,monday],[monday,monday],
  [monday,'2026-11-12'],[monday,'bad-date'],[monday]
 ]){
  assert.throws(()=>section9SimulateSharedWindow({
   marketDates:dates,flights:[first],markets:[]}),
   /SECTION9_INVALID_SHARED_WINDOW|SECTION9_WINDOW_DAYS_NOT_CONTIGUOUS/);
 }
 assert.throws(()=>section9SimulateSharedWindow({
  marketDates:[monday,tuesday],flights:[first,first],markets:[]}),
  /SECTION9_DUPLICATE_FLIGHT_OCCURRENCE/);
});

test('Synthetic 500 airlines x 100 flights x 2 market dates uses shared capacity once',()=>{
 const flights=[],markets=[];
 for(let n=0;n<500;n++){
  const from='O'+n,to='D'+n;
  for(const [day,dateCode] of [[monday,'09'],[tuesday,'10']]){
   markets.push({id:day+'-'+n,origin:from,destination:to,
    marketDate:day,passengers:13000,cargoTonnes:0});
   for(let i=0;i<100;i++)flights.push(f(day+'-'+n+'-'+i,day,'a'+n,
    from,to,'2026-11-'+dateCode+'T08:00:00Z',
    '2026-11-'+dateCode+'T10:00:00Z',
    {passengerSeats:180,cargoTonnes:0}));
  }
 }
 const start=performance.now();
 const result=section9SimulateSharedWindow({
  marketDates:[monday,tuesday],flights,markets});
 const ms=performance.now()-start;
 assert.equal(result.flights.length,100000);
 assert.equal(result.passengers.markets.length,1000);
 assert.ok(result.flights.every(x=>x.passengers<=x.passengerSeats));
 assert.ok(result.passengers.markets.every(x=>x.allocated===13000));
 console.log('Section9 shared 100k occurrence / 500 airline 2-day synthetic duration_ms='+Math.round(ms));
});
