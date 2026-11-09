/**
 * Section 9 verified aircraft delivery-position importer.
 * BACKEND ONLY. No player HTTP action, no cron enabled.
 *
 * Only records ORIGINAL delivery location from existing acquisition order +
 * independently approved inspection + current verified in-game clock.
 * The SQL procedure itself verifies source identity, evidence and approval.
 * Does not claim present-day position or any operated-flight movements.
 */
export const SECTION9_POSITION_SQL=Object.freeze({
 sync:`SELECT airlinerra_game.section9_sync_approved_delivery_positions_v1(
   $1::integer) AS result`
});
export function createSection9DeliveryPositionWorker({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_POSITION_DATABASE_REQUIRED');
 return Object.freeze({
  async runBatch({maxPositions=25}={}){
   if(!Number.isInteger(maxPositions)||maxPositions<1||maxPositions>100)
    throw Error('SECTION9_INVALID_POSITION_SYNC_LIMIT');
   const client=await database.connect();
   try{
    const query=await client.query(SECTION9_POSITION_SQL.sync,[maxPositions]);
    const result=query.rows?.[0]?.result;
    if(query.rowCount!==1||!result||result.ledgerPosted!==false||
       result.bookingsCreated!==false||
       result.readOnlyCommercialFlights!==true||
       !['blocked_unverified_world_clock',
         'delivery_position_batch_processed'].includes(result.status)||
       !Number.isInteger(result.recorded)||result.recorded<0||
       result.recorded>maxPositions)
     throw Error('SECTION9_UNTRUSTED_DELIVERY_POSITION_RESULT');
    if(result.status==='blocked_unverified_world_clock'&&result.recorded!==0)
     throw Error('SECTION9_POSITION_RECORDED_WITHOUT_CLOCK');
    if(result.status==='delivery_position_batch_processed'&&
      result.maxBatch!==maxPositions)
     throw Error('SECTION9_DELIVERY_POSITION_SYNC_BATCH_MISMATCH');
    return result;
   }finally{client.release();}
  }
 });
}
