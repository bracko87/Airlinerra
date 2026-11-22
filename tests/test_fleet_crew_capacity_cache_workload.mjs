import test from 'node:test';
import assert from 'node:assert/strict';
import {readCachedFleetCrewCapacity} from '../server/fleet-crew-capacity-cache.mjs';
test('cached dashboard scales by reads, not repeated planning calculations',async()=>{
 for(const n of [100,1000,10000]){
  const cache=new Map();let inputReads=0,hits=0;
  const client={async query(sql,args){
   const id=args[1];let result;
   if(sql.includes('read_fleet_crew_capacity_cache'))result=cache.has(id)?{status:'capacity_cache_hit',revision:0,payload:cache.get(id),computedAt:'2026-11-22T12:00:00Z'}:{status:'capacity_cache_miss',revision:0};
   else if(sql.includes('owned_fleet_crew_capacity_input')){inputReads++;result={status:'fleet_crew_capacity_input',airlineId:id,fleet:[],bases:[],forecast:{cabinCrewCount:0},availableFromUtc:'2026-11-22T12:00:00Z',input:{windowStartUtc:'2026-11-22T14:01:00Z',pilots:[],cabinMembers:[],flights:[],invalidOccurrenceCount:0,cabinHeadcountReconciled:true}};}
   else if(sql.includes('store_fleet_crew_capacity_cache')){cache.set(id,JSON.parse(args[3]));result={status:'capacity_cache_stored'};}
   else throw Error('Unexpected SQL');
   return {rows:[{result}]};
  }};
  for(let i=0;i<n;i++)for(let j=0;j<10;j++){const r=await readCachedFleetCrewCapacity(client,'owner-'+i,'airline-'+i);assert.equal(r.status,'fleet_crew_capacity');hits+=Number(r.cacheHit);}
  assert.equal(inputReads,n);assert.equal(hits,9*n);
 }
});
