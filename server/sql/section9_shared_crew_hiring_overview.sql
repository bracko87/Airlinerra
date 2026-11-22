CREATE FUNCTION airlinerra_game.section9_owned_shared_crew_hiring_overview_v1(p_player uuid,p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE forecast jsonb;bases jsonb;families jsonb;enabled boolean;
BEGIN
 forecast:=airlinerra_game.section9_owned_shared_crew_payroll_forecast_v1(p_player,p_airline);
 SELECT coalesce(jsonb_agg(jsonb_build_object('airportKey',b.airport_key,'timezone',ap.timezone_iana) ORDER BY b.airport_key),'[]') INTO bases
 FROM airlinerra_game.section9_crew_bases_v1 b JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.airport_key
 WHERE b.airline_id=p_airline AND EXISTS(SELECT 1 FROM pg_timezone_names n WHERE n.name=ap.timezone_iana);
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x."qualificationGroup"),'[]') INTO families FROM (
 SELECT p.qualification_group AS "qualificationGroup",string_agg(DISTINCT c.family_name,', ' ORDER BY c.family_name) AS label,count(*) AS "aircraftCount"
 FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=f.configuration_id
 JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=f.configuration_id
 WHERE f.airline_id=p_airline AND f.fleet_status<>'retired' GROUP BY p.qualification_group)x;
 SELECT manual_hiring_enabled INTO STRICT enabled FROM airlinerra_game.section9_shared_crew_employment_release_v1 WHERE world_id=1;
 RETURN jsonb_build_object('status','shared_crew_hiring_overview','airlineId',p_airline,'bases',bases,'families',families,'forecast',forecast,'manualHiringEnabled',enabled);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_shared_crew_hiring_overview_v1(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;