/**
 * Private read-only client for unreleased flight-execution and commercial-
 * finance sources. This is deliberately NOT a certificate issuer: the
 * independent signing keys and same-transaction database rechecks for those
 * two certificate types do not yet exist.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TYPES=Object.freeze(['trusted_flight_execution','commercial_finance']);
const validDay=s=>typeof s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&
 !Number.isNaN(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s&&
 s>='2000-01-01'&&s<='2199-12-01';
export const SECTION9_UNRELEASED_SOURCE_SQL=
 'SELECT airlinerra_game.section9_execution_finance_certificate_source_preflight_v1('+
 '$1::uuid,$2::uuid,$3::integer,$4::date,$5::text) AS result';
export function createSection9UnreleasedCertificateSourceReader({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_SOURCE_DATABASE_REQUIRED');
 return Object.freeze({
  async inspect({airlineId,scheduleId,scheduleVersion,gameDate,clearanceType}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(scheduleId||'')||
    !Number.isInteger(scheduleVersion)||scheduleVersion<1||
    !validDay(gameDate)||!TYPES.includes(clearanceType))
    throw Error('SECTION9_INVALID_UNRELEASED_CERTIFICATE_SOURCE_REQUEST');
   const client=await database.connect();
   try{
    const response=await client.query(SECTION9_UNRELEASED_SOURCE_SQL,
     [airlineId,scheduleId,scheduleVersion,gameDate,clearanceType]);
    const proof=response?.rows?.[0]?.result;
    if(response?.rowCount!==1||!proof||
     proof.worldId!==1||proof.airlineId!==airlineId||
     proof.scheduleId!==scheduleId||
     proof.scheduleVersion!==scheduleVersion||
     proof.gameDate!==gameDate||proof.clearanceType!==clearanceType||
     proof.readOnly!==true||proof.verified!==false||
     proof.certificateIssued!==false||proof.sourceAuthorityReleased!==false||
     proof.flightActivated!==false||proof.movementRecorded!==false||
     proof.bookingsCreated!==false||proof.ledgerPosted!==false||
     !['blocked_unreleased_execution_finance_source',
       'source_preflight_complete_not_certifiable'].includes(proof.status)||
     !Array.isArray(proof.blockers))
     throw Error('SECTION9_UNTRUSTED_UNRELEASED_SOURCE_RESPONSE');
    return Object.freeze({
     status:proof.status,clearanceType,scheduleId,
     blockers:Object.freeze([...proof.blockers]),
     sourceAuthorityReleased:false,certificateIssued:false,
     certificationComplete:false,scheduleActivated:false,
     flightActivated:false,bookingsCreated:false,ledgerPosted:false
    });
   }finally{client.release();}
  }
 });
}
