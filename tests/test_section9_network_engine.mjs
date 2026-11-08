import test from 'node:test';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {section9SimulateDay} from '../server/section9-network-demand-engine.mjs';

const date='2026-11-09';
const f=(id,airlineId,origin,destination,start,end,extras={})=>({
 id,airlineId,origin,destination,marketDate:date,
 departureUtc:start,arrivalUtc:end,status:'operational_verified',
 passengerSeats:100,cargoTonnes:4,fareUsd:100,cargoRateUsd:100,
 ...extras
});
const a=f('a','alpha','A','B','2026-11-09T09:00:00Z','2026-11-09T10:00:00Z');
const b=f('b','beta','B','C','2026-11-09T11:00:00Z','2026-11-09T12:00:00Z');
const direct=f('c','alpha','A','C','2026-11-09T09:20:00Z','2026-11-09T12:00:00Z',{
 fareUsd:180,passengerSeats:120
});
const market={id:'A-C',origin:'A',destination:'C',marketDate:date,
 passengers:150,cargoTonnes:3,referenceFareUsd:170,referenceCargoRateUsd:100};
const airportRules={B:{minimumTransferMinutes:55,background:'major_city',cargoHandling:true}};
const allow=[{leftAirlineId:'alpha',rightAirlineId:'beta',agreementStatus:'active',
 leftApproved:true,rightApproved:true,validFrom:'2026-01-01T00:00:00Z'}];

test('A->B->C connections require authorized bilateral partnership',()=>{
 const noPartner=section9SimulateDay({flights:[a,b,direct],markets:[market],airports:airportRules});
 assert.equal(noPartner.passengers.markets[0].allocated,120);
 assert.equal(noPartner.flights.find(x=>x.flightId==='a').passengers,0);
 const withPartner=section9SimulateDay({flights:[a,b,direct],markets:[market],
  airports:airportRules,agreements:allow});
 assert.equal(withPartner.passengers.markets[0].allocated,150);
 const used=Object.fromEntries(withPartner.flights.map(x=>[x.flightId,x.passengers]));
 assert.equal(used.a,used.b);
 assert.equal(used.a+used.c,150);
 assert.equal(withPartner.passengers.markets[0].unserved,0);
 assert.equal(withPartner.writesToAirlineLedger,false);
 assert.equal(withPartner.authorizesFlightActivation,false);
});

test('Minimum transfer exact threshold works; short and above 12h blocked',()=>{
 const short={...b,departureUtc:'2026-11-09T10:30:00Z',arrivalUtc:'2026-11-09T11:30:00Z'};
 let result=section9SimulateDay({flights:[a,short],markets:[market],
  airports:airportRules,agreements:allow});
 assert.equal(result.diagnostics.connectionsFound,0);
 const exactly={...b,departureUtc:'2026-11-09T10:55:00Z',
  arrivalUtc:'2026-11-09T11:55:00Z'};
 result=section9SimulateDay({flights:[a,exactly],markets:[market],
  airports:airportRules,agreements:allow});
 assert.equal(result.diagnostics.connectionsFound,1);
 const long={...b,departureUtc:'2026-11-09T22:01:00Z',
  arrivalUtc:'2026-11-09T23:01:00Z'};
 result=section9SimulateDay({flights:[a,long],markets:[market],
  airports:airportRules,agreements:allow});
 assert.equal(result.diagnostics.connectionsFound,0);
});

test('Expiring agreements or single approval do not create connections',()=>{
 const expired=[{...allow[0],validUntil:'2026-09-01T00:00:00Z'}];
 const single=[{...allow[0],rightApproved:false}];
 for(const agreements of [expired,single]){
  const result=section9SimulateDay({flights:[a,b],markets:[market],
   airports:airportRules,agreements});
  assert.equal(result.diagnostics.connectionsFound,0);
 }
});

test('Destination tourism does not block direct demand; tourist transfer hubs are less preferred',()=>{
 const normal=section9SimulateDay({flights:[a,b,direct],markets:[market],
  airports:airportRules,agreements:allow});
 const tourist=section9SimulateDay({flights:[a,b,direct],markets:[market],
  airports:{B:{...airportRules.B,background:'tourism'}},agreements:allow});
 const find=(result,id)=>result.flights.find(x=>x.flightId===id).passengers;
 assert.ok(find(tourist,'a')<find(normal,'a'));
 assert.equal(tourist.passengers.markets[0].allocated,150);
});

test('Marketing only applies when authorized and cannot create travellers',()=>{
 const market2={...market,passengers:100};
 const rival={...direct,id:'r',airlineId:'beta',fareUsd:180};
 const boosted={...direct,id:'c',marketingBoost:0.25,marketingAuthorized:true};
 const unapproved={...boosted,marketingAuthorized:false};
 const result1=section9SimulateDay({flights:[unapproved,rival],markets:[market2]});
 const result2=section9SimulateDay({flights:[boosted,rival],markets:[market2]});
 const pax=x=>x.flights.find(f=>f.flightId==='c').passengers;
 assert.ok(pax(result2)>pax(result1));
 assert.equal(result2.passengers.markets[0].allocated,100);
});

test('Cargo interlining requires handling; direct and connecting cargo share leg weight',()=>{
 const none=section9SimulateDay({flights:[a,b],markets:[market],
  airports:{B:{minimumTransferMinutes:55,cargoHandling:false}},agreements:allow});
 assert.equal(none.cargo.markets[0].allocated,0);
 const yes=section9SimulateDay({flights:[a,b],markets:[market],
  airports:airportRules,agreements:allow});
 assert.equal(yes.cargo.markets[0].allocated,3);
 assert.equal(yes.flights.find(x=>x.flightId==='a').cargoTonnes,3);
 assert.equal(yes.flights.find(x=>x.flightId==='b').cargoTonnes,3);
 const total=yes.flights.reduce((v,x)=>v+x.cargoRevenueUsd,0);
 assert.equal(total,600); // 3 tonnes on each leg, priced separately.
});

test('Mixed O/D demand cannot overbook any shared leg',()=>{
 const markets=[market,{...market,id:'A-B',destination:'B',passengers:200},
  {...market,id:'B-C',origin:'B',passengers:200}];
 const res=section9SimulateDay({flights:[a,b,direct],markets,airports:airportRules,agreements:allow});
 assert.ok(res.flights.every(x=>x.passengers<=x.passengerSeats));
 assert.ok(res.flights.every(x=>x.cargoTonnes<=x.cargoCapacityTonnes));
 assert.ok(res.passengers.markets.every(x=>x.demand>=x.allocated));
 assert.ok(res.cargo.markets.every(x=>x.demand>=x.allocated));
});

test('Reject drafts, duplicate occurrences, and oversize offered-connection expansion',()=>{
 assert.throws(()=>section9SimulateDay({flights:[{...a,status:'draft'}],markets:[]}),
  /UNVERIFIED/);
 assert.throws(()=>section9SimulateDay({flights:[a,a],markets:[]}),/DUPLICATE/);
 assert.throws(()=>section9SimulateDay({flights:[a,b],markets:[market],
  airports:airportRules,agreements:allow,maxItinerariesPerMarket:0}),/INVALID_BATCH/);
});

test('500 airlines x 100 flight occurrences: 50,000-flight snapshot with bounded work',()=>{
 const flights=[],markets=[];
 for(let n=0;n<500;n++){
  const origin='O'+n,destination='D'+n;
  markets.push({id:origin+'-'+destination,origin,destination,marketDate:date,
   passengers:10000,cargoTonnes:0});
  for(let fNo=0;fNo<100;fNo++){
   flights.push(f('p'+n+'-'+fNo,'player'+n,origin,destination,
    '2026-11-09T10:00:00Z','2026-11-09T12:00:00Z',
    {passengerSeats:180,cargoTonnes:0}));
  }
 }
 const start=performance.now();
 const res=section9SimulateDay({flights,markets});
 const ms=performance.now()-start;
 assert.equal(res.flights.length,50000);
 assert.equal(res.passengers.markets.length,500);
 assert.ok(res.passengers.markets.every(x=>x.allocated===10000));
 assert.ok(res.flights.every(x=>x.passengers<=180));
 assert.equal(res.diagnostics.candidateChecks,0);
 // Diagnostic, not a timing assertion; CI hardware varies significantly.
 console.log('Section9 50k-flight synthetic batch duration_ms='+Math.round(ms));
});
