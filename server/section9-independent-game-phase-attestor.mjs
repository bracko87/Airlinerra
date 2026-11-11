/**
 * Private independent GAME flight phase attestor.
 * This is not a public/player API, clock writer or movement signer.
 * It records a signed phase decision ONLY after the database independently
 * verifies an existing active certified schedule, server time, six signed
 * clearances, authorized execution release and current physical aircraft state.
 * The separate fenced movement ingress must still move the aircraft.
 * No tickets, fuel, money or salary transactions are performed.
 */
import {createHmac,timingSafeEqual} from 'node:crypto';
import {independentOperationAttestationPayload}
 from './section9-independent-flight-operation-authorizer.mjs';

const ID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const EVENT=/^operate-v1\.[a-f0-9]{32}\.[0-9]{8}\.[1-7]\.(departed|arrived)$/;
const REF=/^[A-Za-z0-9._:-]{12,128}$/;
const UTC=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const validDay=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const validUtc=s=>typeof s==='string'&&UTC.test(s)&&
 Number.isFinite(Date.parse(s))&&new Date(s).toISOString().slice(0,19)+'Z'===s;

export const SECTION9_GAME_PHASE_ATTESTATION_SQL=Object.freeze({
 gate:'SELECT airlinerra_game.section9_independent_game_phase_gate_v1($1::uuid,$2::uuid,$3::date,$4::text) AS result',
 insert:`INSERT INTO airlinerra_game.section9_independent_operated_flight_evidence_v1(
 world_id,airline_id,aircraft_inventory_id,schedule_id,schedule_version,
 flight_occurrence_id,flight_local_date,weekly_entry,phase,event_id,
 scheduled_event_utc,actual_event_utc,operation_reference,
 certified_clock_receipt_id,evidence_source,signature)
 VALUES($1::smallint,$2::uuid,$3::uuid,$4::uuid,$5::integer,
 $6::text,$7::date,$8::smallint,$9::text,$10::text,
 $11::timestamptz,$12::timestamptz,$13::text,
 $14::text,$15::text,$16::text)
 ON CONFLICT (event_id) DO NOTHING RETURNING event_id`,
 replay:`SELECT world_id::int AS "worldId",airline_id::text AS "airlineId",
 aircraft_inventory_id::text AS "aircraftInventoryId",
 schedule_id::text AS "scheduleId",schedule_version AS "scheduleVersion",
 flight_occurrence_id AS "flightOccurrenceId",
 to_char(flight_local_date,'YYYY-MM-DD') AS "flightLocalDate",
 weekly_entry::int AS "weeklyEntry",phase,event_id AS "eventId",
 to_char(scheduled_event_utc AT TIME ZONE 'UTC',
 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS "scheduledEventUtc",
 to_char(actual_event_utc AT TIME ZONE 'UTC',
 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS "actualEventUtc",
 operation_reference AS "operationReference",
 certified_clock_receipt_id AS "certifiedClockReceiptId",
 evidence_source AS "evidenceSource",signature
 FROM airlinerra_game.section9_independent_operated_flight_evidence_v1
 WHERE event_id=$1::text LIMIT 1`
});
const keys=Object.freeze(['worldId','airlineId','aircraftInventoryId',
 'scheduleId','scheduleVersion','flightOccurrenceId','flightLocalDate',
 'weeklyEntry','phase','eventId','scheduledEventUtc','actualEventUtc',
 'operationReference','certifiedClockReceiptId','evidenceSource']);
function verifyDecision(d,r){
 if(d?.status!=='independent_game_phase_authorized'||d.verified!==true||
 d.readOnly!==true||d.movementRecorded!==false||
 d.bookingsCreated!==false||d.ledgerPosted!==false||
 d.worldId!==1||d.approvedClearances!==6||
 !REF.test(d.certifiedClockReceiptId||'')||
 !REF.test(d.operationReference||'')||!validUtc(d.actualEventUtc))
 throw Error('SECTION9_UNTRUSTED_INDEPENDENT_GAME_PHASE_DECISION');
 const e=d.event;
 if(!e||e.worldId!==1||e.airlineId!==r.airlineId||
 e.aircraftInventoryId!==r.aircraftId||e.eventId!==r.eventId||
 !ID.test(e.scheduleId||'')||!Number.isSafeInteger(e.scheduleVersion)||
 e.scheduleVersion<1||!validDay(e.flightLocalDate)||
 !Number.isInteger(e.weeklyEntry)||e.weeklyEntry<1||e.weeklyEntry>7||
 !['departed','arrived'].includes(e.phase)||!validUtc(e.scheduledEventUtc)||
 e.scheduledEventUtc.slice(0,10)!==r.gameDate||
 e.flightOccurrenceId!==e.scheduleId+':'+e.flightLocalDate+':'+e.weeklyEntry||
 e.eventId!=='operate-v1.'+e.scheduleId.replaceAll('-','')+'.'+
 e.flightLocalDate.replaceAll('-','')+'.'+e.weeklyEntry+'.'+e.phase||
 e.activatedAndCapacityVerified!==true)
 throw Error('SECTION9_UNTRUSTED_PHASE_EVENT_IDENTITY');
 const a=Date.parse(e.scheduledEventUtc),b=Date.parse(d.actualEventUtc);
 if(b<a||b>a+10800000||d.actualEventUtc.slice(0,10)!==r.gameDate)
 throw Error('SECTION9_PHASE_EVIDENCE_OUTSIDE_TIME_WINDOW');
 return Object.freeze({
  worldId:1,airlineId:e.airlineId,aircraftInventoryId:e.aircraftInventoryId,
  scheduleId:e.scheduleId,scheduleVersion:e.scheduleVersion,
  flightOccurrenceId:e.flightOccurrenceId,flightLocalDate:e.flightLocalDate,
  weeklyEntry:e.weeklyEntry,phase:e.phase,eventId:e.eventId,
  scheduledEventUtc:e.scheduledEventUtc,actualEventUtc:d.actualEventUtc,
  operationReference:d.operationReference,
  certifiedClockReceiptId:d.certifiedClockReceiptId,
  evidenceSource:'independent_trusted_flight_engine'
 });
}
function sameAndSigned(existing,expected,secret){
 if(!existing||!keys.every(k=>k==='actualEventUtc'?
  validUtc(existing[k]):existing[k]===expected[k])||
 !/^[a-f0-9]{64}$/.test(existing.signature||''))
 return false;
 const a=Buffer.from(existing.signature,'hex'),
 b=createHmac('sha256',secret)
 .update(independentOperationAttestationPayload(existing),'utf8').digest();
 return a.length===b.length&&timingSafeEqual(a,b);
}
export function createSection9IndependentGamePhaseAttestor({
 database,independentAttestationSecret
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_GAME_PHASE_DATABASE_REQUIRED');
 if(typeof independentAttestationSecret!=='string'||
 independentAttestationSecret.length<32)
  throw Error('SECTION9_INDEPENDENT_ATTESTATION_SECRET_REQUIRED');
 const secret=Buffer.from(independentAttestationSecret,'utf8');
 return Object.freeze({
  async attestDuePhase({airlineId,aircraftId,gameDate,eventId}={}){
   if(!ID.test(airlineId||'')||!ID.test(aircraftId||'')||
   !validDay(gameDate)||!EVENT.test(eventId||'')||
   eventId.slice(-19,-11)!==gameDate.replaceAll('-',''))
    throw Error('SECTION9_INVALID_GAME_PHASE_ATTEST_REQUEST');
   const client=await database.connect();let started=false;
   try{
    await client.query('BEGIN');started=true;
    const result=await client.query(SECTION9_GAME_PHASE_ATTESTATION_SQL.gate,
     [airlineId,aircraftId,gameDate,eventId]);
    if(result.rowCount!==1||!result.rows?.[0]?.result)
     throw Error('SECTION9_GAME_PHASE_GATE_UNAVAILABLE');
    const decision=result.rows[0].result;
    if(decision.verified===false&&
       decision.readOnly===true&&decision.movementRecorded===false&&
       decision.bookingsCreated===false&&decision.ledgerPosted===false&&
       typeof decision.status==='string'&&decision.status!=='independent_game_phase_authorized'){
      await client.query('ROLLBACK');started=false;
      return {status:decision.status,attestationRecorded:false,
       movementRecorded:false,ledgerPosted:false,flightActivated:false};
    }
    const proof=verifyDecision(decision,{airlineId,aircraftId,gameDate,eventId});
    const signature=createHmac('sha256',secret)
      .update(independentOperationAttestationPayload(proof),'utf8').digest('hex');
    const args=[proof.worldId,proof.airlineId,proof.aircraftInventoryId,
     proof.scheduleId,proof.scheduleVersion,proof.flightOccurrenceId,
     proof.flightLocalDate,proof.weeklyEntry,proof.phase,proof.eventId,
     proof.scheduledEventUtc,proof.actualEventUtc,proof.operationReference,
     proof.certifiedClockReceiptId,proof.evidenceSource,signature];
    const stored=await client.query(SECTION9_GAME_PHASE_ATTESTATION_SQL.insert,args);
    let replayed=false;
    if(stored.rowCount===0){
     const prior=await client.query(SECTION9_GAME_PHASE_ATTESTATION_SQL.replay,
      [eventId]);
     if(prior.rowCount!==1||!sameAndSigned(prior.rows?.[0],proof,secret))
      throw Error('SECTION9_INDEPENDENT_PHASE_EVIDENCE_CONFLICT');
     replayed=true;
    }else if(stored.rowCount!==1||stored.rows?.[0]?.event_id!==eventId)
      throw Error('SECTION9_INDEPENDENT_PHASE_EVIDENCE_NOT_CONFIRMED');
    await client.query('COMMIT');started=false;
    return {status:replayed?'independent_phase_attestation_replayed':
      'independent_phase_attestation_recorded',
      eventId,phase:proof.phase,attestationRecorded:!replayed,
      movementRecorded:false,ledgerPosted:false,flightActivated:false};
   }catch{
    if(started)try{await client.query('ROLLBACK');}catch{}
    throw Error('SECTION9_PRIVATE_INDEPENDENT_PHASE_ATTESTATION_FAILED');
   }finally{client.release();}
  }
 });
}
