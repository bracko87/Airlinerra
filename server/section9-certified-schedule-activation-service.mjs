/**
 * World 1 schedule activation COMMIT, private backend only.
 *
 * This service cannot approve a schedule itself. A separate independent
 * operational authority must approve the exact owner and schedule version.
 * The PostgreSQL transaction then rechecks six signed sources, the official
 * game day, aircraft, crew, slots, rights, current location and admin release.
 * No public endpoint, automatic calls, movement, bookings or ledger posting.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const validDay=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s&&
 s>='2000-01-01'&&s<='2199-12-01';

export const SECTION9_COMMIT_ACTIVATION_SQL=Object.freeze({
 commit:`SELECT airlinerra_game.section9_commit_certified_schedule_activation_v1(
 $1::uuid,$2::uuid,$3::uuid,$4::integer,$5::date,$6::integer) AS result`
});
const BLOCKED=new Set([
 'blocked_stale_schedule_version','blocked_schedule_not_draft',
 'blocked_activation_not_fully_certified'
]);
const safe=x=>x?.flightActivated===false&&x?.movementRecorded===false&&
 x?.bookingsCreated===false&&x?.ledgerPosted===false;

export function createSection9CertifiedScheduleActivationService({
 database,releaseAuthority
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_ACTIVATION_DATABASE_REQUIRED');
 if(typeof releaseAuthority?.authorizeActivation!=='function')
  throw Error('SECTION9_INDEPENDENT_ACTIVATION_RELEASE_AUTHORITY_REQUIRED');
 return Object.freeze({
  async activate({airlineId,scheduleId,expectedVersion,gameDate,days=28}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(scheduleId||'')||
      !Number.isInteger(expectedVersion)||expectedVersion<1||
      !validDay(gameDate)||!Number.isInteger(days)||days<7||days>42)
    throw Error('SECTION9_INVALID_ACTIVATION_COMMIT_REQUEST');

   const request=Object.freeze({airlineId,scheduleId,expectedVersion,gameDate,days});
   const approval=await releaseAuthority.authorizeActivation(request);
   if(approval?.authorized!==true||
      approval?.source!=='independent_operational_release_authority'||
      !UUID.test(approval.ownerPlayerId||'')||
      approval.airlineId!==airlineId||
      approval.scheduleId!==scheduleId||
      approval.expectedVersion!==expectedVersion||
      approval.gameDate!==gameDate||
      approval.days!==days)
    throw Error('SECTION9_ACTIVATION_COMMIT_NOT_AUTHORIZED');

   const client=await database.connect();
   try{
    const db=await client.query(SECTION9_COMMIT_ACTIVATION_SQL.commit,[
     approval.ownerPlayerId,airlineId,scheduleId,expectedVersion,gameDate,days
    ]);
    const x=db.rows?.[0]?.result;
    if(db.rowCount!==1||!safe(x)||x.scheduleId!==scheduleId)
     throw Error('SECTION9_UNSAFE_ACTIVATION_COMMIT_DB_RESPONSE');
    if(x.status==='certified_schedule_activated'){
     if(x.scheduleActivated!==true||x.scheduleVersion!==expectedVersion||
        x.worldId!==1)
      throw Error('SECTION9_UNCONFIRMED_SCHEDULE_ACTIVATION');
    }else if(BLOCKED.has(x.status)){
     if(x.scheduleActivated!==false)
      throw Error('SECTION9_UNSAFE_BLOCKED_ACTIVATION_RESULT');
    }else throw Error('SECTION9_UNKNOWN_ACTIVATION_COMMIT_STATUS');
    return x;
   }finally{
    client.release();
   }
  }
 });
}
