/**
 * Read-only DB adapter for independently signed operation attestations.
 *
 * The SQL table has NO general player access, no service-role inserts and
 * no producer configured. The private independent engine must eventually
 * write evidence only after a certified game clock and actual game execution.
 * This reader never guesses or signs evidence from a scheduled flight.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EVENT=/^[A-Za-z0-9._:-]{12,128}$/;
export const SECTION9_INDEPENDENT_EVIDENCE_SQL=Object.freeze({
 read:`select world_id::int as "worldId",
 airline_id::text as "airlineId",
 aircraft_inventory_id::text as "aircraftInventoryId",
 schedule_id::text as "scheduleId",
 schedule_version as "scheduleVersion",
 flight_occurrence_id as "flightOccurrenceId",
 to_char(flight_local_date,'YYYY-MM-DD') as "flightLocalDate",
 weekly_entry::int as "weeklyEntry",
 phase,event_id as "eventId",
 to_char(scheduled_event_utc at time zone 'UTC',
  'YYYY-MM-DD"T"HH24:MI:SS"Z"') as "scheduledEventUtc",
 to_char(actual_event_utc at time zone 'UTC',
  'YYYY-MM-DD"T"HH24:MI:SS"Z"') as "actualEventUtc",
 operation_reference as "operationReference",
 certified_clock_receipt_id as "certifiedClockReceiptId",
 evidence_source as "evidenceSource",signature
 from airlinerra_game.section9_independent_operated_flight_evidence_v1
 where world_id=1 and airline_id=$1::uuid
 and aircraft_inventory_id=$2::uuid
 and event_id=$3::text and flight_occurrence_id=$4::text
 limit 1`
});
export function createSection9IndependentOperationEvidenceReader({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_OPERATION_EVIDENCE_DATABASE_REQUIRED');
 return Object.freeze({
  async readIndependentOperationAttestation({
   worldId,airlineId,aircraftInventoryId,eventId,flightOccurrenceId
  }={}){
   if(worldId!==1||!UUID.test(airlineId||'')||
      !UUID.test(aircraftInventoryId||'')||
      !EVENT.test(eventId||'')||
      typeof flightOccurrenceId!=='string'||
      flightOccurrenceId.length<40||flightOccurrenceId.length>100)
    throw Error('SECTION9_INVALID_PRIVATE_OPERATION_EVIDENCE_IDENTITY');
   const client=await database.connect();
   try{
    const result=await client.query(SECTION9_INDEPENDENT_EVIDENCE_SQL.read,
     [airlineId,aircraftInventoryId,eventId,flightOccurrenceId]);
    if(result.rowCount===0)return null;
    if(result.rowCount!==1||!result.rows?.[0])
     throw Error('SECTION9_AMBIGUOUS_PRIVATE_OPERATION_EVIDENCE');
    const r=result.rows[0];
    if(r.worldId!==1||r.airlineId!==airlineId||
       r.aircraftInventoryId!==aircraftInventoryId||
       r.eventId!==eventId||r.flightOccurrenceId!==flightOccurrenceId)
     throw Error('SECTION9_INCONSISTENT_PRIVATE_OPERATION_EVIDENCE');
    return Object.freeze({...r});
   }finally{client.release();}
  }
 });
}
