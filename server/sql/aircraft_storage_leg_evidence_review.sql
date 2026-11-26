-- REVIEW ONLY: canonical evidence for a one-way storage flight.
-- This is an input to the future signed movement/fuel adapter, not a movement.
-- Never place a storage-only airport in the commercial catalogue to satisfy FKs.
BEGIN;
CREATE FUNCTION airlinerra_game.aircraft_storage_leg_evidence_v1(p_physical text)
RETURNS TABLE(request_id uuid,airline_id uuid,aircraft_inventory_id uuid,owner_player_id uuid,
 configuration_id bigint,origin_airport_key text,destination_airport_key text,
 departure_utc timestamptz,arrival_utc timestamptz,flight_local_date date,flight_occurrence_id text,
 purpose text,quoted_cost_usd numeric,quote jsonb)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT r.id,r.airline_id,r.aircraft_inventory_id,r.owner_player_id,i.configuration_id,
 r.origin_airport_key,r.destination_airport_key,r.departure_utc,r.arrival_utc,
 (r.departure_utc AT TIME ZONE 'UTC')::date,
 r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1',
 'storage_inbound'::text,r.quoted_cost_usd,r.quote
 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=r.aircraft_inventory_id AND i.airline_id=r.airline_id
 JOIN airlinerra_game.airlines a ON a.id=r.airline_id AND a.world_id=1 AND a.owner_player_id=r.owner_player_id
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=r.owner_player_id AND w.state='active'
 WHERE current_user='postgres' AND r.world_id=1 AND r.status='awaiting_slot_and_dispatch_release'
 AND i.ownership_type='owned' AND i.fleet_status='in_service'
 AND p_physical=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1'
 AND r.quote->>'status'='storage_relocation_cost_estimate'
 AND r.quote->>'passengers'='0' AND r.quote->>'cargoTonnes'='0' AND r.quote->>'ticketRevenueUsd'='0'
 AND r.quote->>'fuelRangeConfirmed'='true'
 AND (r.quote->>'directOperatingCostUsd')::numeric=r.quoted_cost_usd
 AND (r.quote->>'configurationId')::bigint=i.configuration_id
 AND r.arrival_utc=r.departure_utc+make_interval(mins=>(r.quote#>>'{phases,totalMinutes}')::integer)
 AND airlinerra_game.aircraft_storage_airport_admission_v1(r.destination_airport_key,'storage_inbound')->>'eligible'='true'
 AND EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 u
 WHERE u.world_id=1 AND u.airport_key=r.origin_airport_key AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 s
 WHERE s.world_id=1 AND s.request_id=r.id AND s.direction='departure' AND s.airport_key=r.origin_airport_key AND s.movement_utc=r.departure_utc)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 s
 WHERE s.world_id=1 AND s.request_id=r.id AND s.direction='arrival' AND s.airport_key=r.destination_airport_key AND s.movement_utc=r.arrival_utc)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.airline_id=r.airline_id AND s.aircraft_inventory_id=r.aircraft_inventory_id AND s.status='active')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j
 WHERE j.airline_id=r.airline_id AND j.aircraft_inventory_id=r.aircraft_inventory_id AND j.status IN ('scheduled','in_progress','payment_required'))
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 t
 WHERE t.aircraft_inventory_id=r.aircraft_inventory_id AND t.status='reserved');
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_leg_evidence_v1(text) FROM PUBLIC,anon,authenticated,service_role;

-- No trusted movement HMAC is generated here. The future engine will sign
-- this exact domain-separated payload after all dispatch gates have passed.
CREATE FUNCTION airlinerra_game.aircraft_storage_event_signing_payload_v1(p_physical text,p_phase text)
RETURNS text LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT concat_ws(E'\n','airlinerra-storage-event-v1',l.airline_id::text,l.aircraft_inventory_id::text,
 l.flight_occurrence_id,p_phase,l.origin_airport_key,l.destination_airport_key,
 to_char((CASE WHEN p_phase='departed' THEN l.departure_utc ELSE l.arrival_utc END) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
 'storage-v1:'||l.flight_occurrence_id||':'||p_phase)
 FROM airlinerra_game.aircraft_storage_leg_evidence_v1(p_physical) l
 WHERE current_user='postgres' AND p_phase IN ('departed','arrived');
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_event_signing_payload_v1(text,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
