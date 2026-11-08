import test from 'node:test';
import assert from 'node:assert/strict';
import {section9AllocatePassengers,section9AllocateCargo,section9OfferWeight}
 from '../server/section9-demand-allocation.mjs';

const offer=(id,flightIds,options={})=>({id,flightIds,
 fareUsd:100,referenceFareUsd:100,weeklyDepartures:7,...options});

test('120 travellers are allocated once between two airlines',()=>{
 const result=section9AllocatePassengers({
  markets:[{id:'A-B',demand:120,offers:[
   offer('cheap',['f1'],{marketingBoost:0.2}),
   offer('expensive',['f2'],{fareUsd:140})
  ]}],
  flightCapacity:{f1:100,f2:100}
 });
 const x=result.marketTotals[0];
 assert.equal(x.demand,120);assert.equal(x.allocated,120);assert.equal(x.unserved,0);
 assert.equal(Object.values(result.flightUsed).reduce((a,b)=>a+b,0),120);
 assert.ok(result.flightUsed.f1>result.flightUsed.f2);
});

test('connecting passengers consume both flight capacities but count as one traveller',()=>{
 const result=section9AllocatePassengers({
  markets:[
   {id:'A-C',demand:90,offers:[offer('connection',['A-B','B-C'],
    {connectionMinutes:90,minimumTransferMinutes:55})]},
   {id:'B-C',demand:50,offers:[offer('direct',['B-C'])]}
  ],
  flightCapacity:{'A-B':70,'B-C':100}
 });
 assert.equal(result.marketTotals[0].allocated,70);
 assert.equal(result.marketTotals[1].allocated,30);
 assert.equal(result.flightUsed['A-B'],70);
 assert.equal(result.flightUsed['B-C'],100);
 assert.equal(result.marketTotals[0].unserved,20);
});

test('marketing changes distribution but never invents passengers',()=>{
 const markets=boost=>[{id:'G-H',demand:200,offers:[
  offer('airlineA',['a'],{marketingBoost:boost}),
  offer('airlineB',['b'])
 ]}];
 const normal=section9AllocatePassengers({markets:markets(0),flightCapacity:{a:300,b:300}});
 const promoted=section9AllocatePassengers({markets:markets(0.25),flightCapacity:{a:300,b:300}});
 assert.equal(normal.marketTotals[0].allocated,200);
 assert.equal(promoted.marketTotals[0].allocated,200);
 assert.ok(promoted.flightUsed.a>normal.flightUsed.a);
 assert.equal(section9OfferWeight(offer('a',['a'],{marketingBoost:99})),
  section9OfferWeight(offer('a',['a'],{marketingBoost:0.25})));
});

test('cargo tonnes are a separate supply pool and conserve fractional tonnage',()=>{
 const result=section9AllocateCargo({
  markets:[{id:'X-Y',demand:4.5,offers:[offer('c',['cargo']),offer('b',['belly'])]}],
  flightCapacity:{cargo:3,belly:2}
 });
 assert.equal(result.marketTotals[0].allocated,4.5);
 assert.ok(result.flightUsed.cargo<=3);
 assert.ok(result.flightUsed.belly<=2);
});

test('rejects duplicate markets and itineraries with invalid or repeated legs',()=>{
 assert.throws(()=>section9AllocatePassengers({
  markets:[{id:'A',demand:1,offers:[]},{id:'A',demand:1,offers:[]}],
  flightCapacity:{}
 }));
 assert.throws(()=>section9AllocatePassengers({
  markets:[{id:'A',demand:5,offers:[offer('x',['a','a'])]}],
  flightCapacity:{a:10}
 }));
 assert.throws(()=>section9AllocatePassengers({
  markets:[{id:'A',demand:5,offers:[offer('x',['a','b','c'])]}],
  flightCapacity:{a:10,b:10,c:10}
 }));
});

test('500 players x 100 flight departures: bounded batch, no per-passenger loops',()=>{
 const markets=[];const flightCapacity=new Map();
 for(let player=0;player<500;player++){
  const offers=[];
  for(let flight=0;flight<100;flight++){
   const id='p'+player+'f'+flight;
   flightCapacity.set(id,180);
   offers.push(offer(id,[id],{fareUsd:80+flight%30}));
  }
  markets.push({id:'market-'+String(player).padStart(4,'0'),demand:10000,offers});
 }
 const result=section9AllocatePassengers({markets,flightCapacity});
 assert.equal(result.marketTotals.length,500);
 assert.equal(result.allocations.length,50000);
 assert.ok(result.marketTotals.every(x=>x.allocated===10000));
 assert.ok(result.marketTotals.every(x=>x.unserved===0));
 assert.ok(Object.values(result.flightRemaining).every(x=>x>=0));
});
