-- Owner-scoped bootstrap input for the pure weekly scheduler.
-- This initial preview deliberately does not claim that dated flight coverage
-- is complete or that operational duty histories have been integrated.
CREATE FUNCTION airlinerra_game.section9_owned_weekly_crew_input_v1(p_player uuid,p_airline uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE flights jsonb; pilots jsonb; cabin jsonb; invalid_count integer; pool_ok boolean; active_count integer;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_WEEKLY_CREW_INPUT_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RETURN jsonb_build_object('status','blocked_airline_not_owned');END IF;
 IF p_start IS NULL OR NOT isfinite(p_start) OR p_start<'2000-01-01'::timestamptz OR p_start>'2199-12-01'::timestamptz THEN RETURN jsonb_build_object('status','invalid_preview_window');END IF;
 SELECT count(*) INTO active_count FROM airlinerra_game.airline_flight_schedule_drafts_v1 s WHERE s.airline_id=p_airline AND s.world_id=1 AND s.status='active';
 WITH raw AS (
 SELECT o.*,s.configuration_id,s.version current_version,s.status schedule_status,p.qualification_group,p.maximum_cabin_crew,p.seat_basis,
 CASE WHEN p.seat_basis='cargo_zero' THEN 0 ELSE o.verified_passenger_seats END seats
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 LEFT JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id
 LEFT JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=s.configuration_id
 WHERE o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled' AND o.departure_utc>=p_start AND o.departure_utc<p_start+interval '168 hours'
 ), checked AS (
 SELECT *,CASE WHEN seats<=19 THEN 0 ELSE (seats+49)/50 END cabin_required,
 (qualification_group IS NOT NULL AND current_version=schedule_version AND schedule_status='active' AND seats IS NOT NULL AND
 ((seat_basis='cargo_zero' AND seats=0) OR (seat_basis<>'cargo_zero' AND seats>0))) valid
 FROM raw
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'aircraftId',aircraft_inventory_id,'group',qualification_group,'origin',origin_airport_key,'destination',destination_airport_key,'departureUtc',departure_utc,'arrivalUtc',arrival_utc,'cabinRequired',cabin_required) ORDER BY departure_utc,id) FILTER(WHERE valid AND cabin_required<=maximum_cabin_crew),'[]'),
 count(*) FILTER(WHERE valid IS DISTINCT FROM true OR cabin_required IS NULL OR cabin_required>maximum_cabin_crew)
 INTO flights,invalid_count FROM checked;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',pr.crew_id,'initialAirport',b.initial_airport_key,'locationEffectiveUtc',b.location_effective_utc,'baseTimezone',ap.timezone_iana,'employmentFrom',r.game_effective_date,'history','[]'::jsonb,'permissions',q.permissions) ORDER BY pr.crew_id),'[]') INTO pilots
 FROM airlinerra_game.section9_pilot_profiles_v1 pr JOIN airlinerra_game.section9_pilot_base_assignments_v1 b ON b.crew_id=pr.crew_id AND b.airline_id=pr.airline_id
 JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.crew_id=pr.crew_id AND r.airline_id=pr.airline_id
 JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.base_airport_key
 CROSS JOIN LATERAL (
 SELECT coalesce(jsonb_agg(jsonb_build_object('group',q.qualification_group,'issued',q.issued_game_date,'expires',q.expires_game_date,'active',q.qualification_status='active','captain',airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,'captain'),'firstOfficer',airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,'first_officer')) ORDER BY q.qualification_group),'[]') permissions
 FROM airlinerra_game.section9_pilot_family_permissions_v1 q WHERE q.crew_id=pr.crew_id AND q.airline_id=pr.airline_id
 ) q
 WHERE pr.airline_id=p_airline AND r.employment_status='verified_employed' AND r.game_effective_date IS NOT NULL
 AND ap.timezone_iana IS NOT NULL AND EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=ap.timezone_iana);
 SELECT NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_cabin_crew_pools_v1 p WHERE p.airline_id=p_airline AND p.employed_count<>(SELECT count(*) FROM airlinerra_game.section9_cabin_crew_members_v1 m WHERE m.airline_id=p.airline_id AND m.base_airport_key=p.base_airport_key AND m.role=p.role)) INTO pool_ok;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',m.member_id,'role',m.role,'initialAirport',m.initial_airport_key,'locationEffectiveUtc',m.location_effective_utc,'baseTimezone',ap.timezone_iana,'employmentFrom',m.effective_game_date,'history','[]'::jsonb) ORDER BY m.member_id),'[]') INTO cabin
 FROM airlinerra_game.section9_cabin_crew_members_v1 m JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=m.world_id AND ap.airport_key=m.base_airport_key
 WHERE m.airline_id=p_airline AND m.employment_status='employed' AND m.role IN('flight_attendant','cabin_supervisor','purser') AND pool_ok
 AND ap.timezone_iana IS NOT NULL AND EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=ap.timezone_iana);
 RETURN jsonb_build_object('status','weekly_crew_bootstrap_input_preview','windowStartUtc',p_start,'flights',flights,'pilots',pilots,'cabinMembers',cabin,'invalidOccurrenceCount',invalid_count,'activeScheduleCount',active_count,'cabinHeadcountReconciled',pool_ok,'dutyHistoryIntegrated',false,'scheduleCompletenessVerified',false,'dispatchEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_weekly_crew_input_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
