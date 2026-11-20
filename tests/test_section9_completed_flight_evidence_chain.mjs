import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const sql=()=>readFile(new URL(
 '../supabase/migrations/20261120173500_section9_private_completed_flight_evidence_chain_inspector.sql',
 import.meta.url),'utf8');
test('private completed-flight inspector reads all stages but cannot issue a flight or post money',async()=>{
 const s=await sql();
 assert.match(s,/SECURITY INVOKER/);
 assert.match(s,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(s,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_inspect_completed_flight_chain_v1/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(s,/LANGUAGE plpgsql STABLE/);
 assert.match(s,/'canPost',false/);
 assert.match(s,/'flightActivated',false/);
 assert.match(s,/'bookingsCreated',false/);
 assert.match(s,/'ledgerPosted',false/);
 assert.doesNotMatch(s,/\b(?:INSERT INTO|UPDATE airlinerra_game|DELETE FROM|TRUNCATE|PERFORM airlinerra_game\.section9_post_completed)/i);
});
test('inspector checks immutable occurrence, signed movement pair, actual booking, aircraft receipt, approval and once-only settlement',async()=>{
 const s=await sql();
 for(const name of [
  'section9_dated_flight_occurrences_v1',
  'section9_operated_flight_movements_v1',
  'section9_arrived_aircraft_usage_receipts_v1',
  'section9_actual_ticket_finance_preparations_v1',
  'section9_flight_final_cost_approvals_v1',
  'section9_route_posted_flight_financials_v1',
  'OPERATED_MOVEMENT_PAIR_MISMATCH',
  'OCCURRENCE_MOVEMENT_MISMATCH',
  'ARRIVED_USAGE_RECEIPT_MISMATCH',
  'FINANCE_ARRIVAL_PROOF_MISMATCH',
  'COST_APPROVAL_ARRIVAL_MISMATCH',
  'POSTED_FINANCE_RECEIPT_MISMATCH'
 ])assert.ok(s.includes(name),name);
 assert.match(s,/v_depart\.actual_event_utc>v_arrive\.actual_event_utc/);
 assert.match(s,/EVIDENCE_CHAIN_PRESENT_REQUIRES_INDEPENDENT_SIGNATURE_AND_LEDGER_VERIFICATION/);
 assert.match(s,/EVIDENCE_CHAIN_INCOMPLETE/);
});
