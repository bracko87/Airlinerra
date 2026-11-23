import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const source=()=>readFile(new URL(
 '../supabase/migrations/20261117110000_section9_game_fuel_custody_supply_dispatch_v1.sql',
 import.meta.url),'utf8');

test('fuel custody and supplier/flight event tables are private, permanent and unique',async()=>{
 const s=await source();
 for(const t of [
 'section9_aircraft_game_fuel_custody_v1',
 'section9_game_approved_fuel_load_receipts_v1',
 'section9_game_flight_fuel_departure_receipts_v1',
 'section9_game_flight_fuel_arrival_receipts_v1'
 ]) {
  assert.match(s,new RegExp('CREATE TABLE IF NOT EXISTS airlinerra_game\\."'+t+'"'));
  assert.match(s,new RegExp('ALTER TABLE airlinerra_game\\."'+t+'" ENABLE ROW LEVEL SECURITY'));
  assert.match(s,new RegExp('REVOKE ALL ON TABLE airlinerra_game\\."'+t+'"'));
 }
 assert.match(s,/PRIMARY KEY \(physical_flight_id\)/);
 assert.match(s,/PRIMARY KEY \(source_event_id\)/);
 assert.match(s,/CONSTRAINT.*arrival_engine_event_id_key/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
});

test('predeparture checks authoritative fuel balance, reserved seats, exact airport and event provenance',async()=>{
 const s=await source();
 assert.match(s,/section9_verify_game_fuel_before_departure_v1/);
 assert.match(s,/section9_verified_berlin_game_hour_v1/);
 assert.match(s,/section9_game_reserve_aware_fuel_quote_v1/);
 assert.match(s,/IF total_minutes NOT BETWEEN 30 AND 1800/);
 assert.match(s,/section9_aircraft_game_fuel_custody_v1 c/);
 assert.match(s,/FOR UPDATE/);
 assert.match(s,/custody\.at_airport_key IS DISTINCT FROM r\.origin_airport_key/);
 assert.match(s,/custody\.fuel_game_family IS DISTINCT FROM fuel_model\.fuel_game_family/);
 assert.match(s,/section9_game_approved_fuel_load_receipts_v1 t/);
 assert.match(s,/t\.source_status='game_authority_approved'/);
 assert.match(s,/section9_game_flight_fuel_arrival_receipts_v1 a/);
 assert.match(s,/blocked_missing_verified_aircraft_fuel_onboard/);
 assert.match(s,/blocked_insufficient_aircraft_fuel_including_reserve/);
 assert.match(s,/minimumPlannedFuelOnBoardKg/);
});

test('auto game-only fuel top-up requires operating release and verified aircraft game location',async()=>{
 const s=await source();
 assert.match(s,/section9_auto_supply_game_only_fuel_v1/);
 assert.match(s,/blocked_game_fuel_auto_supply_unreleased/);
 assert.match(s,/airlinerra_game\.section9_owned_aircraft_operational_position_v1/);
 assert.match(s,/verified_original_game_starter_position/);
 assert.match(s,/blocked_no_game_airport_fuel_service/);
 assert.match(s,/GAME_ONLY_AUTO_FUEL_SERVICE_V1_/);
 assert.match(s,/game_authority_approved/);
 assert.match(s,/fuelTopUpKg',add_qty/);
 assert.match(s,/realWorldFuelGradeCertified',false/);
 assert.match(s,/chargedNow',false,'ledgerPosted',false/);
});

test('departure fuel receipt is exactly once and tied to a signed movement',async()=>{
 const s=await source();
 assert.match(s,/section9_capture_verified_departure_fuel_v1/);
 assert.match(s,/SECTION9_FUEL_DEPARTURE_RECEIPT_REPLAY_CHANGED/);
 assert.match(s,/SECTION9_FUEL_CHANGED_AFTER_TRUSTED_PREFLIGHT/);
 assert.match(s,/INSERT INTO airlinerra_game\.section9_game_flight_fuel_departure_receipts_v1/);
 assert.match(s,/source_kind IS DISTINCT FROM 'signed_operated_game_flight_v1'/);
 assert.match(s,/planned_trip_burn_kg/);
 assert.match(s,/planned_holding_reserve_kg/);
 assert.match(s,/SECTION9_DEPARTURE_FUEL_RECEIPT_NOT_ATOMIC/);
});

test('arrival fuel burns one trip only and moves remaining tank to destination',async()=>{
 const s=await source();
 assert.match(s,/section9_apply_verified_arrival_fuel_burn_once_v1/);
 assert.match(s,/SECTION9_ARRIVAL_FUEL_REPLAY_INCONSISTENT/);
 assert.match(s,/SECTION9_FLIGHT_FUEL_CUSTODY_CHANGED_IN_TRANSIT_ROLLBACK/);
 assert.match(s,/new_kg:=fuel_custody\.onboard_kg-departure\.planned_trip_burn_kg/);
 assert.match(s,/new_kg<departure\.planned_contingency_kg\+departure\.planned_holding_reserve_kg/);
 assert.match(s,/INSERT INTO airlinerra_game\.section9_game_flight_fuel_arrival_receipts_v1/);
 assert.match(s,/SET onboard_kg=new_kg,at_airport_key=arrival\.destination_airport_key/);
 assert.match(s,/revision=revision\+1/);
 assert.match(s,/SECTION9_ARRIVAL_FUEL_CUSTODY_NOT_ATOMIC_ROLLBACK/);
});

test('dispatch refuses missing fuel and atomically rolls back flight movements if fuel fails',async()=>{
 const s=await source();
 assert.match(s,/section9_auto_dispatch_due_flight_events_v1/);
 assert.match(s,/fuel_supply:=airlinerra_game\.section9_auto_supply_game_only_fuel_v1/);
 assert.match(s,/fuel_check:=airlinerra_game\.section9_verify_game_fuel_before_departure_v1/);
 assert.match(s,/reason:='GAME_AIRPORT_FUEL_TOPUP_NOT_AVAILABLE'/);
 assert.match(s,/section9_capture_verified_departure_fuel_v1/);
 assert.match(s,/SECTION9_UNVERIFIED_DEPARTURE_FUEL_ROLLS_BACK_MOVEMENT/);
 assert.match(s,/section9_apply_verified_arrival_fuel_burn_once_v1/);
 assert.match(s,/SECTION9_UNVERIFIED_ARRIVAL_FUEL_ROLLS_BACK_MOVEMENT/);
 assert.match(s,/section9_apply_arrival_airframe_usage_once_v1/);
 assert.match(s,/'actualFuelSettlementConnected',false/);
});

test('finance preparation needs signed flight fuel burn but never recognizes revenue early',async()=>{
 const s=await source();
 assert.match(s,/section9_prepare_actual_ticket_postarrival_finance_v1/);
 assert.match(s,/blocked_missing_signed_flight_fuel_burn_receipt/);
 assert.match(s,/burn\.arrival_engine_event_id=arrival\.engine_event_id/);
 assert.match(s,/takeoff\.planned_trip_burn_kg=burn\.trip_burn_kg/);
 assert.match(s,/'readyToPost',false,'ledgerPosted',false/);
 assert.doesNotMatch(s,/INSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(s,/UPDATE airlinerra_game\.airlines/i);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
});


test('fuel preflight, signed dispatch and cancellation retain shared transaction guards',async()=>{
 const [fuel,cancel,signed]=await Promise.all([
  source(),
  readFile(new URL('../server/sql/section9_disruption_decision_and_cancellation.sql',import.meta.url),'utf8'),
  readFile(new URL('../supabase/migrations/20261113232000_section9_private_signed_operated_flight_dispatch_v1.sql',import.meta.url),'utf8')
 ]);
 const dispatch=fuel.slice(fuel.indexOf('CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1('));
 const cancelFn=cancel.slice(cancel.indexOf('CREATE OR REPLACE FUNCTION airlinerra_game.section9_cancel_unflown_occurrence_v1('),
  cancel.indexOf('REVOKE ALL ON FUNCTION airlinerra_game.section9_cancel_unflown_occurrence_v1('));
 assert.match(dispatch,/pg_try_advisory_xact_lock\(583729,10041\)/);
 assert.match(cancelFn,/pg_advisory_xact_lock\(583729,10041\)/);
 assert.match(cancelFn,/section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id=physical FOR UPDATE/);
 assert.match(cancelFn,/section9_dated_flight_occurrences_v1 WHERE id=p_occurrence FOR UPDATE/);
 assert.match(cancelFn,/o\.booking_status<>'open'/);
 assert.match(cancelFn,/section9_operated_flight_movements_v1 WHERE flight_occurrence_id=physical/);
 assert.match(dispatch,/section9_verify_game_fuel_before_departure_v1/);
 assert.match(dispatch,/section9_record_signed_operated_flight_movement_v1/);
 assert.match(dispatch,/section9_capture_verified_departure_fuel_v1/);
 assert.match(dispatch,/UPDATE airlinerra_game\.section9_dated_flight_occurrences_v1\s+SET booking_status='closed' WHERE id=evt\.occurrence_id\s+AND booking_status='open'/);
 assert.match(dispatch,/IF changed<>1 THEN RAISE EXCEPTION[\s\S]*?SECTION9_DEPARTURE_BOOKING_CLOSE_UNCONFIRMED_ROLLBACK/);
 assert.match(signed,/SECTION9_OPERATED_EVENT_REPLAY_CONFLICT/);
 const ixLock=dispatch.indexOf('pg_try_advisory_xact_lock(583729,10041)');
 const ixMovement=dispatch.indexOf('section9_record_signed_operated_flight_movement_v1(',ixLock);
 const ixFuelReceipt=dispatch.indexOf('section9_capture_verified_departure_fuel_v1(',ixMovement);
 const ixClose=dispatch.indexOf("SET booking_status='closed' WHERE id=evt.occurrence_id",ixFuelReceipt);
 assert.ok(ixLock>=0 && ixMovement>ixLock && ixFuelReceipt>ixMovement && ixClose>ixFuelReceipt,
  'Dispatch must hold shared cancellation lock through signed movement, fuel receipt and conditional booking close');
});
