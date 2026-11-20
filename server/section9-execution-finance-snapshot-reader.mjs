/**
 * PRIVATE source-snapshot reader for the not-yet-released execution and
 * finance authorities. Reads real DB-computed version-bound evidence.
 * Does NOT issue, sign, ingest, or authorize certificates.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE=/^\d{4}-\d{2}-\d{2}$/;
const TYPES=new Set(['trusted_flight_execution','commercial_finance']);
const FINGERPRINT=/^[a-f0-9]{32}$/;
export const SECTION9_EXECUTION_FINANCE_SNAPSHOT_SQL=
 'SELECT airlinerra_game.section9_execution_finance_source_snapshot_v1('+
 '$1::uuid,$2::uuid,$3::integer,$4::date,$5::text) AS result';
export function createSection9ExecutionFinanceSnapshotReader({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_SNAPSHOT_DATABASE_REQUIRED');
 return Object.freeze({
  async inspect({airlineId,scheduleId,scheduleVersion,gameDate,clearanceType}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(scheduleId||'')||
    !Number.isInteger(scheduleVersion)||scheduleVersion<1||
    !DATE.test(gameDate||'')||
    !Number.isFinite(Date.parse(gameDate+'T00:00:00Z'))||
    new Date(gameDate+'T00:00:00Z').toISOString().slice(0,10)!==gameDate||
    gameDate<'2000-01-01'||gameDate>'2199-12-01'||
    !TYPES.has(clearanceType))
    throw Error('SECTION9_INVALID_SOURCE_SNAPSHOT_REQUEST');
   const client=await database.connect();
   try{
    const r=await client.query(SECTION9_EXECUTION_FINANCE_SNAPSHOT_SQL,
     [airlineId,scheduleId,scheduleVersion,gameDate,clearanceType]);
    const p=r?.rows?.[0]?.result;
    if(r?.rowCount!==1||!p||p.worldId!==1||
     p.airlineId!==airlineId||p.scheduleId!==scheduleId||
     p.scheduleVersion!==scheduleVersion||p.gameDate!==gameDate||
     p.clearanceType!==clearanceType||p.readOnly!==true||
     p.verified!==false||p.certificateIssued!==false||
     p.sourceAuthorityReleased!==false||
     p.flightActivated!==false||p.movementRecorded!==false||
     p.bookingsCreated!==false||p.ledgerPosted!==false||
     typeof p.candidateReady!=='boolean'||
     !Array.isArray(p.blockers)||
     p.snapshotVersion!=='SECTION9_INDEPENDENT_SOURCE_SNAPSHOT_CANDIDATE_V1')
     throw Error('SECTION9_UNTRUSTED_SOURCE_SNAPSHOT');
    if(p.candidateReady){
     if(p.status!=='source_snapshot_candidate_not_authorized'||
       p.blockers.length!==0||
       !FINGERPRINT.test(p.sourceFingerprint||'')||
       p.sourceReference!=='candidate-execution-finance-v1-'+p.sourceFingerprint)
      throw Error('SECTION9_UNTRUSTED_SOURCE_SNAPSHOT');
    }else if(p.status!=='blocked_unreleased_execution_finance_source_snapshot'||
     p.sourceFingerprint!==null||p.sourceReference!==null)
     throw Error('SECTION9_UNTRUSTED_SOURCE_SNAPSHOT');
    return Object.freeze({
     status:p.status,scheduleId,clearanceType,
     candidateReady:p.candidateReady,sourceFingerprint:p.sourceFingerprint,
     blockers:Object.freeze([...p.blockers]),
     verified:false,certificateIssued:false,sourceAuthorityReleased:false,
     flightActivated:false,bookingsCreated:false,ledgerPosted:false
    });
   }finally{client.release();}
  }
 });
}
