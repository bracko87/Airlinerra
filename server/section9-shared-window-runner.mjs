/**
 * Private multi-day demand preview: a single allocation across all market days.
 * Reads only real operationally verified flight occurrences from the protected
 * Supabase reader. No browser-supplied flights, cargo capacities or passenger
 * demand are trusted; does not settle revenue or issue tickets.
 *
 * This deliberately does not replace the existing daily settlement writer:
 * neighbouring previews cannot independently finalize the same itinerary.
 * Final commercial settlement requires atomic physical-flight reservations.
 */
import {SECTION9_DAY_SQL} from './section9-day-preview-runner.mjs';
import {
 section9SimulateSharedWindow,section9DiscoverSharedWindowPairs
} from './section9-shared-window-engine.mjs';

const ISO_DAY=/^\d{4}-\d{2}-\d{2}$/;
const dayGood=d=>typeof d==='string'&&ISO_DAY.test(d)&&
 Number.isFinite(Date.parse(d+'T00:00:00Z'))&&
 new Date(d+'T00:00:00Z').toISOString().slice(0,10)===d;
const addDay=(d,i)=>new Date(Date.parse(d+'T00:00:00Z')+i*86400000)
 .toISOString().slice(0,10);
const iso=d=>d instanceof Date?d.toISOString():String(d);
const decode=v=>{
 if(Array.isArray(v))return v;
 if(typeof v==='string'){
  const parsed=JSON.parse(v);if(Array.isArray(parsed))return parsed;
 }
 throw Error('SECTION9_SHARED_WINDOW_INVALID_DB_RESPONSE');
};
const groups=(list,max)=>{
 const output=[];
 for(let i=0;i<list.length;i+=max)output.push(list.slice(i,i+max));
 return output;
};

export function createSection9SharedWindowRunner({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_DATABASE_REQUIRED');
 return Object.freeze({
  async preview({startGameDate,marketDays=3,onProgress}={}){
   if(!dayGood(startGameDate)||!Number.isInteger(marketDays)||
     marketDays<2||marketDays>7||
     (onProgress!==undefined&&typeof onProgress!=='function'))
    throw Error('SECTION9_INVALID_SHARED_WINDOW_REQUEST');

   const dates=Array.from({length:marketDays},(_,i)=>addDay(startGameDate,i));
   // Read a one-day buffer on either side for valid 12-hour transfers.
   const flightDates=Array.from({length:marketDays+2},(_,i)=>
    addDay(startGameDate,i-1));
   const client=await database.connect();
   try{
    const flights=[],seen=new Set();
    for(const day of flightDates){
     let cursorSchedule=null,cursorEntry=null,page=0;
     while(true){
      if(++page>300)throw Error('SECTION9_SHARED_WINDOW_PAGING_REQUIRES_SHARDING');
      const response=await client.query(SECTION9_DAY_SQL.flights,
       [day,1000,cursorSchedule,cursorEntry]);
      const found=decode(response.rows?.[0]?.result);
      if(onProgress)await onProgress({stage:'verified_flights',gameDate:day});
      for(const row of found){
       const valid=row.status==='operational_verified'&&
        row.marketDate===day&&row.localTimeStatus==='valid'&&
        typeof row.scheduleId==='string'&&
        /^[0-9a-f-]{36}$/i.test(row.scheduleId)&&
        Number.isInteger(row.weeklyEntry)&&row.weeklyEntry>=1&&
        row.weeklyEntry<=10000&&
        row.id===row.scheduleId+':'+day+':'+row.weeklyEntry;
       if(!valid)throw Error('SECTION9_SHARED_WINDOW_UNVERIFIED_OCCURRENCE');
       if(seen.has(row.id))throw Error('SECTION9_SHARED_WINDOW_DUPLICATE_OCCURRENCE');
       seen.add(row.id);
       flights.push({
        ...row,
        departureUtc:iso(row.departureUtc),arrivalUtc:iso(row.arrivalUtc),
        passengerSeats:Number(row.passengerSeats),
        cargoTonnes:Number(row.cargoTonnes),
        fareUsd:Number(row.fareUsd),cargoRateUsd:Number(row.cargoRateUsd),
        weeklyDepartures:Number(row.weeklyDepartures)
       });
       if(flights.length>300000)
        throw Error('SECTION9_SHARED_WINDOW_REQUIRES_NETWORK_SHARDING');
      }
      if(found.length<1000)break;
      const last=found[found.length-1];
      if(cursorSchedule===last.scheduleId&&cursorEntry>=last.weeklyEntry)
       throw Error('SECTION9_SHARED_WINDOW_STALLED_CURSOR');
      cursorSchedule=last.scheduleId;cursorEntry=last.weeklyEntry;
     }
    }
    if(!flights.length){
     return {...section9SimulateSharedWindow({
      marketDates:dates,flights:[],markets:[]}),
      status:'no_active_flights',source:'verified_operational_schedules'};
    }
    const airportsKeys=[...new Set(flights.flatMap(f=>[f.origin,f.destination]))];
    const airportRows=[];
    for(const keys of groups(airportsKeys,1000)){
     const response=await client.query(SECTION9_DAY_SQL.airportPolicies,[keys]);
     airportRows.push(...response.rows);
     if(onProgress)await onProgress({stage:'airport_policies'});
    }
    const airports=Object.fromEntries(airportRows.map(r=>[r.airportKey,{
     minimumTransferMinutes:Number(r.minimumTransferMinutes),
     background:r.background,cargoHandling:r.cargoHandling===true
    }]));
    if(airportsKeys.some(key=>!Number.isInteger(airports[key]?.minimumTransferMinutes)))
     throw Error('SECTION9_SHARED_WINDOW_MISSING_AIRPORT_POLICY');

    const upper=addDay(dates[dates.length-1],4)+'T00:00:00Z';
    const lower=addDay(dates[0],-3)+'T00:00:00Z';
    const agreementResponse=await client.query(SECTION9_DAY_SQL.agreements,
     [upper,lower]);
    const agreements=agreementResponse.rows.map(x=>({
     ...x,validFrom:iso(x.validFrom),
     validUntil:x.validUntil?iso(x.validUntil):null
    }));

    const discovery=section9DiscoverSharedWindowPairs({
     marketDates:dates,flights,airports,agreements,maxPairs:100000
    });
    const markets=[];
    for(const group of discovery.groups){
     for(const batch of groups(group.pairs,500)){
      const response=await client.query(SECTION9_DAY_SQL.markets,
       [Number(group.marketDate.slice(5,7)),JSON.stringify(batch)]);
      const values=decode(response.rows?.[0]?.result);
      const expected=new Set(batch.map(p=>p.origin+'|'+p.destination));
      if(values.length!==expected.size)
       throw Error('SECTION9_SHARED_WINDOW_INCOMPLETE_MARKET_BATCH');
      for(const market of values){
       const marketKey=market.origin+'|'+market.destination;
       if(!expected.delete(marketKey))
        throw Error('SECTION9_SHARED_WINDOW_MISMATCHED_MARKET');
       const passengers=Number(market.passengers),
        cargoTonnes=Number(market.cargoTonnes);
       if(!Number.isFinite(passengers)||passengers<0||
          !Number.isFinite(cargoTonnes)||cargoTonnes<0)
        throw Error('SECTION9_SHARED_WINDOW_INVALID_MARKET_CAPACITY');
       markets.push({
        id:group.marketDate+'|'+market.origin+'|'+market.destination,
        origin:market.origin,destination:market.destination,
        marketDate:group.marketDate,passengers,cargoTonnes,
        referenceFareUsd:100,referenceCargoRateUsd:100
       });
      }
      if(expected.size)throw Error('SECTION9_SHARED_WINDOW_UNRESOLVED_MARKETS');
      if(onProgress)await onProgress({stage:'market_batch',gameDate:group.marketDate});
     }
    }
    if(onProgress)await onProgress({stage:'shared_capacity_allocation'});
    const result=section9SimulateSharedWindow({
     marketDates:dates,flights,markets,airports,agreements
    });
    return {...result,
     source:'verified_operational_schedules',
     discovery:{originDestinationMarkets:discovery.count,
      candidateConnectionChecks:discovery.groups.reduce(
       (s,g)=>s+g.candidateConnectionsExamined,0)},
     requiresAtomicBooking:true};
   }finally{client.release();}
  }
 });
}
