-- Recruitment preferences and durable acquisition notices; no hiring authority yet.
CREATE TABLE airlinerra_game.section9_crew_recruitment_preferences_v1(
 airline_id uuid PRIMARY KEY REFERENCES airlinerra_game.airlines(id),
 mode text NOT NULL CHECK(mode IN('manual','automatic_minimum','automatic_reserves')),
 reserve_percent integer NOT NULL CHECK(reserve_percent BETWEEN 0 AND 30 AND reserve_percent%5=0),
 monthly_budget_usd bigint NOT NULL CHECK(monthly_budget_usd BETWEEN 0 AND 1000000000),
 version integer NOT NULL CHECK(version>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((mode='automatic_reserves' AND reserve_percent>=5) OR (mode<>'automatic_reserves' AND reserve_percent=0))
);
CREATE TABLE airlinerra_game.section9_crew_acquisition_notice_ack_v1(
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL,
 acknowledged_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(airline_id,aircraft_inventory_id)
);
ALTER TABLE airlinerra_game.section9_crew_recruitment_preferences_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_crew_acquisition_notice_ack_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_crew_recruitment_preferences_v1,airlinerra_game.section9_crew_acquisition_notice_ack_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_owned_crew_recruitment_settings_v1(p_player uuid,p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE settings jsonb; notices jsonb; pending integer;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='CREW_RECRUITMENT_NOT_OWNED';END IF;
 SELECT jsonb_build_object('mode',mode,'reservePercent',reserve_percent,'monthlyBudgetUsd',monthly_budget_usd,'version',version) INTO settings FROM airlinerra_game.section9_crew_recruitment_preferences_v1 WHERE airline_id=p_airline;
 SELECT count(*) INTO pending FROM airlinerra_game.airline_aircraft_inventory i WHERE i.airline_id=p_airline AND i.fleet_status='in_service' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_acquisition_notice_ack_v1 n WHERE n.airline_id=i.airline_id AND n.aircraft_inventory_id=i.id);
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO notices FROM (
 SELECT i.id AS "aircraftId",i.registration,i.ownership_type AS "ownershipType",c.manufacturer_name AS manufacturer,c.model_name AS model,c.family_name AS family,p.qualification_group AS "qualificationGroup"
 FROM airlinerra_game.airline_aircraft_inventory i
 LEFT JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=i.configuration_id
 LEFT JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=i.configuration_id
 WHERE i.airline_id=p_airline AND i.fleet_status='in_service' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_acquisition_notice_ack_v1 n WHERE n.airline_id=i.airline_id AND n.aircraft_inventory_id=i.id)
 ORDER BY i.created_at DESC,i.id LIMIT 100
 ) x;
 RETURN jsonb_build_object('airlineId',p_airline,'status','crew_recruitment_settings','settings',coalesce(settings,'{"mode":"manual","reservePercent":0,"monthlyBudgetUsd":0,"version":0}'::jsonb),'pendingNoticeCount',pending,'notices',notices,'automaticHiringEnabled',false,'salaryPostingEnabled',false);
END $$;
CREATE FUNCTION airlinerra_game.section9_save_owned_crew_recruitment_settings_v1(p_player uuid,p_airline uuid,p_mode text,p_reserve integer,p_budget bigint,p_version integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE existing integer;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_mode IS NULL OR p_mode NOT IN('manual','automatic_minimum','automatic_reserves') OR p_reserve IS NULL OR p_reserve NOT BETWEEN 0 AND 30 OR p_reserve%5<>0 OR (p_mode='automatic_reserves')<>(p_reserve>=5) OR p_budget IS NULL OR p_budget NOT BETWEEN 0 AND 1000000000 OR p_version IS NULL OR p_version<0 THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 SELECT version INTO existing FROM airlinerra_game.section9_crew_recruitment_preferences_v1 WHERE airline_id=p_airline;
 IF coalesce(existing,0)<>p_version THEN RETURN jsonb_build_object('status','settings_version_conflict');END IF;
 INSERT INTO airlinerra_game.section9_crew_recruitment_preferences_v1(airline_id,mode,reserve_percent,monthly_budget_usd,version) VALUES(p_airline,p_mode,p_reserve,p_budget,1)
 ON CONFLICT(airline_id) DO UPDATE SET mode=excluded.mode,reserve_percent=excluded.reserve_percent,monthly_budget_usd=excluded.monthly_budget_usd,version=section9_crew_recruitment_preferences_v1.version+1,updated_at=clock_timestamp();
 RETURN airlinerra_game.section9_owned_crew_recruitment_settings_v1(p_player,p_airline);
END $$;
CREATE FUNCTION airlinerra_game.section9_ack_owned_crew_acquisition_notice_v1(p_player uuid,p_airline uuid,p_aircraft uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline AND fleet_status='in_service') THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 INSERT INTO airlinerra_game.section9_crew_acquisition_notice_ack_v1(airline_id,aircraft_inventory_id) VALUES(p_airline,p_aircraft) ON CONFLICT DO NOTHING;
 RETURN airlinerra_game.section9_owned_crew_recruitment_settings_v1(p_player,p_airline);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_crew_recruitment_settings_v1(uuid,uuid),airlinerra_game.section9_save_owned_crew_recruitment_settings_v1(uuid,uuid,text,integer,bigint,integer),airlinerra_game.section9_ack_owned_crew_acquisition_notice_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
