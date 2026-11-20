import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const sql=()=>readFile(new URL(
 '../supabase/migrations/20261120184000_section9_completed_flight_chain_reservation_reconciliation.sql',import.meta.url),'utf8');
test('flight chain inspector stays private, stable and cannot post money or open bookings',async()=>{
 const s=await sql();
 assert.match(s,/LANGUAGE plpgsql STABLE SECURITY INVOKER/);
 assert.match(s,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(s,/REVOKE ALL ON FUNCTION/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(s,/'canPost',false/);
 assert.match(s,/'ledgerPosted',false/);
 assert.match(s,/'flightActivated',false/);
 assert.match(s,/'bookingsCreated',false/);
 assert.doesNotMatch(s,/\b(?:INSERT INTO|UPDATE airlinerra_game|DELETE FROM|TRUNCATE|CALL)\b/i);
});
test('guard repeated phase evidence and reconcile actual reserved seats with occurrence inventory',async()=>{
 const s=await sql();
 assert.match(s,/count\(\*\) FILTER \(WHERE phase='departed'\)/);
 assert.match(s,/count\(\*\) FILTER \(WHERE phase='arrived'\)/);
 assert.match(s,/DUPLICATE_OPERATED_PHASE_RECORDS/);
 assert.match(s,/reservation_status='reserved'/);
 assert.match(s,/v_reserved_seats IS DISTINCT FROM v_occ\.booked_seats/);
 assert.match(s,/BOOKED_SEATS_RESERVATIONS_MISMATCH/);
 assert.match(s,/paid_upfront=true OR recognized_revenue_usd<>0/);
 assert.match(s,/RESERVATION_PREPAID_OR_PREMATURE_REVENUE/);
 assert.match(s,/BOOKED_SEATS_EXCEED_VERIFIED_CAPACITY/);
 assert.match(s,/verifiedReservedSeatsFromBatches/);
 assert.match(s,/prematurelyPaidOrRecognizedReservations/);
});
test('inspector does not convert present evidence to authorized settlement',async()=>{
 const s=await sql();
 assert.match(s,/EVIDENCE_CHAIN_PRESENT_REQUIRES_INDEPENDENT_SIGNATURE_AND_LEDGER_VERIFICATION/);
 assert.match(s,/SIGNED_DEPARTURE_MISSING/);
 assert.match(s,/SIGNED_ARRIVAL_MISSING/);
 assert.match(s,/FINANCE_ARRIVAL_PROOF_MISMATCH/);
 assert.match(s,/POSTED_FINANCE_RECEIPT_MISMATCH/);
 assert.match(s,/v_depart\.actual_event_utc>v_arrive\.actual_event_utc/);
});
