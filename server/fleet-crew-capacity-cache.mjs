import {buildFleetCrewCapacity} from './fleet-crew-capacity-engine.mjs';
// All reads and writes are owner-scoped; only the trusted process computes the payload.
export async function readCachedFleetCrewCapacity(client,playerId,airlineId){
 const params=[playerId,airlineId];
 for(let attempt=0;attempt<2;attempt++){
  const cache=(await client.query('SELECT airlinerra_game.section9_read_fleet_crew_capacity_cache_v1($1::uuid,$2::uuid) AS result',params)).rows?.[0]?.result;
  if(cache?.status==='capacity_cache_hit'&&cache.payload?.status==='fleet_crew_capacity'&&cache.payload.airlineId===airlineId)return {...cache.payload,cacheHit:true,computedAt:cache.computedAt};
  if(cache?.status!=='capacity_cache_miss'||!Number.isSafeInteger(cache.revision))throw Error('CAPACITY_CACHE_UNVERIFIED');
  const snapshot=(await client.query('SELECT airlinerra_game.section9_owned_fleet_crew_capacity_input_v1($1::uuid,$2::uuid) AS result',params)).rows?.[0]?.result;
  if(snapshot?.airlineId!==airlineId)throw Error('CAPACITY_INPUT_UNVERIFIED');
  const payload=buildFleetCrewCapacity(snapshot);
  const stored=(await client.query('SELECT airlinerra_game.section9_store_fleet_crew_capacity_cache_v1($1::uuid,$2::uuid,$3::bigint,$4::jsonb) AS result',[...params,cache.revision,JSON.stringify(payload)])).rows?.[0]?.result;
  if(stored?.status==='capacity_cache_stored')return {...payload,cacheHit:false};
  if(stored?.status!=='capacity_cache_revision_changed')throw Error('CAPACITY_CACHE_WRITE_UNVERIFIED');
 }
 return {status:'capacity_changed_retry',airlineId};
}
