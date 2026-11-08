/**
 * Private Section 9 batch settlement PREPARATION. This is not revenue posting.
 *
 * The actual activation system must verify crews, aircraft rotation, airport
 * rights and operating slots before forecasts can pass this gate. All
 * downstream values are derived by the database from three *completed* and
 * *materialized* demand jobs, not accepted from a browser or this process.
 */
export const SECTION9_PREPARE_SQL=
 `SELECT airlinerra_game.section9_prepare_verified_settlement_batch_v1(
 1::smallint,$1::date,$2::text,$3::integer) AS result`;

const GAME_DATE=/^\d{4}-\d{2}-\d{2}$/;
const validDate=d=>typeof d==='string'&&GAME_DATE.test(d)&&
 Number.isFinite(Date.parse(d+'T00:00:00Z'))&&
 new Date(d+'T00:00:00Z').toISOString().slice(0,10)===d;
const flightIdOk=s=>typeof s==='string'&&s.length>=10&&s.length<=120;
export function createSection9SettlementPreparationRunner({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_DATABASE_REQUIRED');
 return Object.freeze({
  async prepare({gameDate,batchSize=100,maxBatches=1000}={}){
   if(!validDate(gameDate)||!Number.isInteger(batchSize)||
      batchSize<1||batchSize>250||!Number.isInteger(maxBatches)||
      maxBatches<1||maxBatches>1000)
    throw Error('SECTION9_INVALID_SETTLEMENT_BATCH_REQUEST');
   const client=await database.connect();
   let cursor=null,visited=0,proofs=0,intents=0,flights=0;
   try{
    while(visited++<maxBatches){
     const reply=await client.query(SECTION9_PREPARE_SQL,
      [gameDate,cursor,batchSize]);
     if(reply.rowCount!==1||!reply.rows?.[0]?.result)
      throw Error('SECTION9_SETTLEMENT_DB_UNAVAILABLE');
     const result=reply.rows[0].result;
     if(result.gameDate!==gameDate||result.ledgerPosted!==false||
        result.bookingsCreated!==false)
      throw Error('SECTION9_UNSAFE_SETTLEMENT_RESULT');
     if(result.status==='blocked_incomplete_or_unmaterialized_forecasts'){
      if(visited!==1)throw Error('SECTION9_INCONSISTENT_SETTLEMENT_SOURCE');
      return {status:result.status,gameDate,processedFlights:0,
       proofsCreated:0,intentsCreated:0,readOnly:true,
       ledgerPosted:false,bookingsCreated:false};
     }
     if(result.status!=='prepared_unposted'||
       !Number.isInteger(result.flightsInspected)||
       !Number.isInteger(result.newProofs)||
       !Number.isInteger(result.newRevenueIntents)||
       result.flightsInspected<0||result.flightsInspected>batchSize||
       result.newProofs<0||result.newProofs>result.flightsInspected||
       result.newRevenueIntents<0||
       result.newRevenueIntents>2*result.flightsInspected)
      throw Error('SECTION9_INVALID_SETTLEMENT_PREPARATION_RESPONSE');
     flights+=result.flightsInspected;
     proofs+=result.newProofs;intents+=result.newRevenueIntents;
     if(result.hasMore!==true) return {
      status:'prepared_unposted',gameDate,processedFlights:flights,
      proofsCreated:proofs,intentsCreated:intents,readOnly:true,
      ledgerPosted:false,bookingsCreated:false
     };
     if(!flightIdOk(result.nextFlightCursor)||
       (cursor!==null&&result.nextFlightCursor<=cursor)||
       result.flightsInspected!==batchSize)
      throw Error('SECTION9_INVALID_SETTLEMENT_CURSOR');
     cursor=result.nextFlightCursor;
    }
    throw Error('SECTION9_PREPARATION_REQUIRES_MORE_SHARDS');
   }finally{client.release();}
  }
 });
}
