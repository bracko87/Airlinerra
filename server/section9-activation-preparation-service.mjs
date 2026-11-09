/**
 * Private Section 9 schedule activation CERTIFICATION preparation.
 * NOT the activation endpoint. Never expose this adapter to a browser.
 *
 * Requires independent, server-only operational-release authority. The
 * database still checks actual ownership, draft version, current world
 * clock, aircraft/crew/slots and all six separate certified sources.
 * No flight, aircraft movement, booking, or financial transaction is made.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const validDay=x=>typeof x==='string'&&DAY.test(x)&&
 Number.isFinite(Date.parse(x+'T00:00:00Z'))&&
 new Date(x+'T00:00:00Z').toISOString().slice(0,10)===x&&
 x>='2000-01-01'&&x<='2199-12-01';
export const SECTION9_ACTIVATION_PREP_SQL=Object.freeze({
 prepare:`SELECT airlinerra_game.section9_prepare_certified_schedule_activation_v1(
 $1::uuid,$2::uuid,$3::uuid,$4::integer,$5::date,$6::integer) AS result`
});
export function createSection9ActivationPreparationService({
 database,independentReleaseAuthority
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_ACTIVATION_PRIVATE_DATABASE_REQUIRED');
 if(typeof independentReleaseAuthority?.authorizePreparation!=='function')
  throw Error('SECTION9_INDEPENDENT_ACTIVATION_AUTHORITY_REQUIRED');
 return Object.freeze({
  async prepare({airlineId,scheduleId,expectedVersion,gameDate,days=28}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(scheduleId||'')||
      !Number.isInteger(expectedVersion)||expectedVersion<1||
      !validDay(gameDate)||!Number.isInteger(days)||days<7||days>42)
    throw Error('SECTION9_INVALID_ACTIVATION_PREPARATION_REQUEST');
   const request=Object.freeze({airlineId,scheduleId,expectedVersion,gameDate,days});
   const permitted=await independentReleaseAuthority.authorizePreparation(request);
   // Never trust a player-provided owner ID. It must come from the
   // independently verified server context, and must match this operation.
   if(permitted?.authorized!==true||
      permitted?.source!=='independent_operational_release_authority'||
      !UUID.test(permitted.ownerPlayerId||'')||
      permitted.airlineId!==airlineId||
      permitted.scheduleId!==scheduleId||
      permitted.expectedVersion!==expectedVersion||
      permitted.gameDate!==gameDate)
    throw Error('SECTION9_ACTIVATION_PREPARATION_NOT_AUTHORIZED');
   const client=await database.connect();
   try{
    const r=await client.query(SECTION9_ACTIVATION_PREP_SQL.prepare,[
     permitted.ownerPlayerId,airlineId,scheduleId,expectedVersion,gameDate,days
    ]);
    const x=r.rows?.[0]?.result;
    if(r.rowCount!==1||!x||
       !['blocked_activation_preparation','blocked_stale_schedule_version',
         'prepared_for_future_activation_commit'].includes(x.status)||
       x.scheduleId!==scheduleId||
       x.flightActivated!==false||
       x.movementRecorded!==false||
       x.bookingsCreated!==false||
       x.ledgerPosted!==false||
       (x.status==='prepared_for_future_activation_commit')!==
          (x.prepared===true)||
       (x.status!=='prepared_for_future_activation_commit'&&x.prepared!==false))
      throw Error('SECTION9_UNSAFE_ACTIVATION_PREPARATION_RESPONSE');
    return x;
   }finally{client.release();}
  }
 });
}
