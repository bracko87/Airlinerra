/**
 * Backend-only adapter: load three completed, immutable adjacent daily
 * forecast snapshots by chunk page and reconcile shared flight capacities.
 * No HTTP/player endpoint, no game-cash or airline-ledger access.
 */
import {section9ReconcileAdjacentForecasts}
 from './section9-settlement-preflight.mjs';

export const SECTION9_COMPLETED_FLIGHT_SQL=`SELECT
 airlinerra_game.section9_completed_flight_chunk_page_v1(
  1::smallint,$1::date,$2::integer,$3::integer) AS result`;

const DAY=/^\d{4}-\d{2}-\d{2}$/;
function safeDay(date){
 return typeof date==='string'&&DAY.test(date)&&
  Number.isFinite(Date.parse(date+'T00:00:00Z'))&&
  new Date(date+'T00:00:00Z').toISOString().slice(0,10)===date;
}
const addDay=(date,delta)=>new Date(
 Date.parse(date+'T00:00:00Z')+delta*86400000).toISOString().slice(0,10);

export function createSection9SettlementPreflightRunner({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_DATABASE_REQUIRED');
 return Object.freeze({
  async inspect({targetDate,maxRows=300000}={}){
   if(!safeDay(targetDate)||!Number.isInteger(maxRows)||
      maxRows<1||maxRows>900000)
    throw Error('SECTION9_INVALID_SETTLEMENT_INSPECTION');
   const client=await database.connect();
   const snapshots=[];
   let readRows=0;
   try{
    for(const day of [addDay(targetDate,-1),targetDate,addDay(targetDate,1)]){
     const snapshot={gameDate:day,status:'missing',readOnly:true,flights:[]};
     let cursor=-1,previous=-1,pages=0,declared=null;
     while(true){
      if(++pages>200)throw Error('SECTION9_SETTLEMENT_READER_REQUIRES_SHARDING');
      const reply=await client.query(SECTION9_COMPLETED_FLIGHT_SQL,[day,cursor,5]);
      if(reply.rowCount!==1||!reply.rows?.[0]?.result)
       throw Error('SECTION9_SETTLEMENT_READER_DB_UNAVAILABLE');
      const payload=reply.rows[0].result;
      if(payload.gameDate!==day||payload.readOnly!==true)
       throw Error('SECTION9_SETTLEMENT_READER_INCONSISTENT_DATE');
      if(payload.status!=='completed'){
       snapshot.status=payload.status;
       if(!['missing','not_completed'].includes(payload.status))
        throw Error('SECTION9_SETTLEMENT_READER_INVALID_STATUS');
       break;
      }
      if(!Number.isSafeInteger(payload.flightRows)||payload.flightRows<0||
         !Array.isArray(payload.chunks))
       throw Error('SECTION9_SETTLEMENT_READER_INVALID_PAYLOAD');
      if(declared!==null&&declared!==payload.flightRows)
       throw Error('SECTION9_SETTLEMENT_READER_MUTATING_COMPLETED_JOB');
      declared=payload.flightRows;snapshot.status='completed';
      for(const chunk of payload.chunks){
       if(!Number.isInteger(chunk?.chunkNumber)||
          chunk.chunkNumber!==previous+1||
          !Array.isArray(chunk.rows)||chunk.rows.length<1||chunk.rows.length>500)
        throw Error('SECTION9_SETTLEMENT_READER_MISSING_OR_DUPLICATE_CHUNK');
       previous=chunk.chunkNumber;
       readRows+=chunk.rows.length;
       if(readRows>maxRows)throw Error('SECTION9_SETTLEMENT_READER_REQUIRES_SHARDING');
       snapshot.flights.push(...chunk.rows);
      }
      if(payload.chunks.length<5)break;
      cursor=previous;
     }
     if(snapshot.status==='completed'&&snapshot.flights.length!==declared)
      throw Error('SECTION9_SETTLEMENT_READER_MISSING_COMPLETED_ROWS');
     snapshots.push(snapshot);
    }
   }finally{client.release();}
   return section9ReconcileAdjacentForecasts({
    targetDate,snapshots,maxRows
   });
  }
 });
}
