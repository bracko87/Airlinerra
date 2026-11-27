-- Disposable CI only; install after stored-aircraft read fixture.
-- Only screens and crew candidate input are synthetic; booking functions,
-- reservations, holds, cancellation and triggers are real review code.
BEGIN;
CREATE TABLE airlinerra_game.section9_crew_plan_batches_v1(plan_id uuid PRIMARY KEY,airline_id uuid,status text);
CREATE TABLE airlinerra_game.section9_planned_crew_duties_v1(plan_id uuid,airline_id uuid,pilot_id uuid,employee_id uuid GENERATED ALWAYS AS(pilot_id) STORED,duty_end_utc timestamptz);
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_operational_screen_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure)||jsonb_build_object('airportScreenPassed',true,'departureScreen',jsonb_build_object('passed',true),'arrivalScreen',jsonb_build_object('passed',true),'licenceScreen',jsonb_build_object('allowed',true),'crewScreen',jsonb_build_object('requirementsVerified',true))
$$;
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_crew_candidates_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('status','storage_crew_candidates_found','captainsRequired',1,'firstOfficersRequired',1,'minimumCabinCrew',0,'qualificationGroup','fixture','candidateCaptains',jsonb_build_array('00000000-0000-4000-8000-000000000005'),'candidateFirstOfficers',jsonb_build_array('00000000-0000-4000-8000-000000000006'),'candidateCabinCrew','[]'::jsonb,'rotation',jsonb_build_object('startingAirport',q->>'originAirportKey','endingAirport',p_destination,'dutyStartUtc',p_departure-interval '1 hour','dutyEndUtc',(q->>'arrivalUtc')::timestamptz+interval '30 minutes'))
 FROM (SELECT airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure) q) x
$$;
CREATE FUNCTION airlinerra_game.storage_reactivation_maintenance_window_v1(uuid,uuid,uuid,timestamptz,timestamptz) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('gameMaintenanceClear',true)$$;
CREATE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('status','game_fuel_already_sufficient')$$;
CREATE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('fuelVerifiedForGame',true)$$;
COMMIT;
