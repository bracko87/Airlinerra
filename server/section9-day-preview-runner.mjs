/**
 * Section 9 backend-only, batch-oriented read-only forecast runner.
 * This is the actual bridge from VERIFIED operational schedules to the
 * demand/allocation model; no player data or browser request can supply flights.
 *
 * Do not use its output as a booking/financial ledger entry. Adjacent game
 * dates may share connecting flight legs; settlement requires a separate
 * atomic cross-date capacity reservation by the activated flight engine.
 */
import {section9DiscoverReachableMarkets,section9SimulateDay}
 from './section9-network-demand-engine.mjs';

export const SECTION9_DAY_SQL=Object.freeze({
 flights:`SELECT airlinerra_game.section9_verified_daily_flight_page_v1(
  1::smallint,$1::date,$2::integer,$3::uuid) AS result`,
 airportPolicies:`SELECT p.airport_key AS "airportKey",
  p.minimum_transfer_minutes AS "minimumTransferMinutes",
  p.airport_background AS background,
  f.cargo_handling_available AS "cargoHandling"
  FROM airlinerra_game.section9_airport_transfer_policy_v1 p
  JOIN airlinerra_game.airport_facilities f ON f.world_id=p.world_id
   AND f.airport_key=p.airport_key
  WHERE p.world_id=1 AND p.airport_key=ANY($1::text[])`,
 agreements:`SELECT left_airline_id::text AS "leftAirlineId",
  right_airline_id::text AS "rightAirlineId",
  'active'::text AS "agreementStatus",
  (left_approved_at IS NOT NULL) AS "leftApproved",
  (right_approved_at IS NOT NULL) AS "rightApproved",
  valid_from AS "validFrom",valid_until AS "validUntil"
  FROM airlinerra_game.section9_interline_agreements_v1
  WHERE world_id=1 AND agreement_status='active'
   AND left_approved_at IS NOT NULL AND right_approved_at IS NOT NULL
   AND valid_from<$1::timestamptz
   AND (valid_until IS NULL OR valid_until>=$2::timestamptz)`,
 markets:`SELECT airlinerra_game.section9_market_batch_v1(
  1::smallint,$1::smallint,$2::jsonb) AS result`
});
const isoDay=/^\d{4}-\d{2}-\d{2}$/;
const dayValid=v=>typeof v==='string'&&isoDay.test(v)&&
 Number.isFinite(Date.parse(v+'T00:00:00Z'))&&
 new Date(v+'T00:00:00Z').toISOString().slice(0,10)===v;
const asList=value=>{
 if(Array.isArray(value))return value;
 if(typeof value==='string'){
  const parsed=JSON.parse(value);
  if(Array.isArray(parsed))return parsed;
 }
 throw Error('SECTION9_BACKEND_RETURNED_INVALID_LIST');
};
const iso=v=>v instanceof Date?v.toISOString():String(v);
function dayOffset(day,offset){
 return new Date(Date.parse(day+'T00:00:00Z')+offset*86400000)
  .toISOString().slice(0,10);
}
const batches=(array,n)=>{
 const out=[];for(let i=0;i<array.length;i+=n)out.push(array.slice(i,i+n));
 return out;
};
export function createSection9DayPreviewRunner({database}={}){
 if(typeof database?.connect!=='function')throw Error('Section9 private database required');
 return Object.freeze({
  async preview({gameDate,worldId=1,onProgress}={}){
   if(!dayValid(gameDate)||worldId!==1)
    throw Error('SECTION9_INVALID_GAME_DATE');
   if(onProgress!==undefined&&typeof onProgress!=='function')
    throw Error('SECTION9_INVALID_PROGRESS_CALLBACK');
   const client=await database.connect();
   try{
    const flights=[],ids=new Set();
    // The 12-hour transfer can be across an airport's local midnight.
    for(const date of [dayOffset(gameDate,-1),gameDate,dayOffset(gameDate,1)]){
     let after=null,loops=0;
     while(true){
      if(++loops>200)throw Error('SECTION9_FLIGHT_PAGE_LIMIT_REQUIRES_SHARDING');
      const reply=await client.query(SECTION9_DAY_SQL.flights,[date,1000,after]);
      const raw=asList(reply.rows?.[0]?.result);
      if(onProgress)await onProgress({phase:'flight_pages',gameDate:date});
      for(const flight of raw){
       if(ids.has(flight.id))throw Error('SECTION9_DUPLICATE_AUTHENTICATED_FLIGHT');
       ids.add(flight.id);
       flights.push({
        ...flight,departureUtc:iso(flight.departureUtc),
        arrivalUtc:iso(flight.arrivalUtc),
        passengerSeats:Number(flight.passengerSeats),
        cargoTonnes:Number(flight.cargoTonnes),
        fareUsd:Number(flight.fareUsd),
        cargoRateUsd:Number(flight.cargoRateUsd),
        weeklyDepartures:Number(flight.weeklyDepartures)
       });
       if(flights.length>300000)throw Error('SECTION9_SNAPSHOT_TOO_LARGE_REQUIRES_SHARDING');
      }
      if(raw.length<1000)break;
      after=String(raw[raw.length-1]?.scheduleId||'');
      if(!/^[0-9a-f-]{36}$/i.test(after))
       throw Error('SECTION9_INVALID_PAGING_CURSOR');
     }
    }
    if(!flights.length){
     return {...section9SimulateDay({flights:[],markets:[]}),
      gameDate,source:'verified_operational_schedules',
      status:'no_active_flights',flightActivationAllowed:false};
    }
    const airportKeys=[...new Set(flights.flatMap(f=>[f.origin,f.destination]))];
    const policyRows=[];
    for(const group of batches(airportKeys,1000)){
     const reply=await client.query(SECTION9_DAY_SQL.airportPolicies,[group]);
     policyRows.push(...reply.rows);
     if(onProgress)await onProgress({phase:'airport_policies'});
    }
    const airports=Object.fromEntries(policyRows.map(x=>[x.airportKey,{
     minimumTransferMinutes:Number(x.minimumTransferMinutes),
     background:x.background,cargoHandling:x.cargoHandling===true
    }]));
    const minDay=dayOffset(gameDate,-1)+'T00:00:00Z',
     maxDay=dayOffset(gameDate,3)+'T00:00:00Z';
    const agreementReply=await client.query(SECTION9_DAY_SQL.agreements,[maxDay,minDay]);
    const agreements=agreementReply.rows.map(x=>({...x,
     validFrom:iso(x.validFrom),validUntil:x.validUntil?iso(x.validUntil):null}));
    const discovery=section9DiscoverReachableMarkets({
     flights,airports,agreements,marketDate:gameDate,maxMarketPairs:100000
    });
    const pools=[];
    const month=Number(gameDate.slice(5,7));
    for(const pairs of batches(discovery.pairs,500)){
     const reply=await client.query(SECTION9_DAY_SQL.markets,[month,JSON.stringify(pairs)]);
     const found=asList(reply.rows?.[0]?.result);
     if(onProgress)await onProgress({phase:'market_batch'});
     if(found.length!==pairs.length)
      throw Error('SECTION9_MISSING_MARKET_BASELINE');
     for(const market of found){
      pools.push({id:gameDate+'|'+market.origin+'|'+market.destination,
       origin:market.origin,destination:market.destination,marketDate:gameDate,
       passengers:Number(market.passengers),cargoTonnes:Number(market.cargoTonnes),
       referenceFareUsd:100,referenceCargoRateUsd:100});
     }
    }
    if(onProgress)await onProgress({phase:'before_allocation'});
    const result=section9SimulateDay({
     flights,markets:pools,airports,agreements,maxItinerariesPerMarket:10000
    });
    return {...result,gameDate,source:'verified_operational_schedules',
     status:'forecast_only',flightActivationAllowed:false,
     discovery:discovery.diagnostics,
     settlementRequirements:['atomic_capacity_across_calendar_boundaries',
      'authoritative_actual_cabin_and_cargo_capacity',
      'game_financial_ledger_and_paid_campaign_gate']};
   }finally{client.release();}
  }
 });
}
