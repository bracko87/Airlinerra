-- Subsidiary-only management delegation. Defaults grant no spending permission.
CREATE TABLE airlinerra_game.section9_management_responsibility_roles_v1(
 responsibility_key text PRIMARY KEY,label text NOT NULL,manager_role text NOT NULL
);
INSERT INTO airlinerra_game.section9_management_responsibility_roles_v1 VALUES
 ('pilots','Pilots','crew_staffing_manager'),('cabin','Cabin crew','crew_staffing_manager'),
 ('station','Station agents','ground_operations_manager'),('ground','Ground handling employees','ground_operations_manager'),
 ('maintenance','Maintenance technicians','technical_manager'),('customer','Customer service employees','customer_service_manager'),
 ('administrative','Administrative employees','hr_manager');
CREATE TABLE airlinerra_game.section9_management_responsibilities_v1(
 airline_id uuid PRIMARY KEY REFERENCES airlinerra_game.airlines(id),version int NOT NULL CHECK(version>0),policies jsonb NOT NULL CHECK(jsonb_typeof(policies)='object'),updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
-- Reserved for a future verified management employment contract integration.
CREATE TABLE airlinerra_game.section9_management_appointments_v1(
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),manager_role text NOT NULL CHECK(manager_role IN('crew_staffing_manager','ground_operations_manager','technical_manager','customer_service_manager','hr_manager')),
 employment_contract_reference text NOT NULL UNIQUE,active boolean NOT NULL DEFAULT false,
 PRIMARY KEY(airline_id,manager_role)
);
CREATE TABLE airlinerra_game.section9_crew_capacity_policy_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),cancellation_risk_below_pct int NOT NULL CHECK(cancellation_risk_below_pct=80),replacement_target_pct int NOT NULL CHECK(replacement_target_pct=90),full_staffing_pct int NOT NULL CHECK(full_staffing_pct=100),strong_reserves_pct int NOT NULL CHECK(strong_reserves_pct=110),capacity_dispatch_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_crew_capacity_policy_v1 VALUES(1,80,90,100,110,false);
ALTER TABLE airlinerra_game.section9_management_responsibility_roles_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_management_responsibilities_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_management_appointments_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_crew_capacity_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_management_responsibility_roles_v1,airlinerra_game.section9_management_responsibilities_v1,airlinerra_game.section9_management_appointments_v1,airlinerra_game.section9_crew_capacity_policy_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_crew_capacity_status_v1(p_pct numeric)
RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path TO pg_catalog AS $$
 SELECT jsonb_build_object('status',CASE WHEN p_pct IS NULL OR p_pct<0 THEN 'unknown' WHEN p_pct>110 THEN 'strong_reserves' WHEN p_pct>=100 THEN 'fully_staffed' WHEN p_pct>=90 THEN 'sufficient' WHEN p_pct>=80 THEN 'understaffed' WHEN p_pct>=60 THEN 'high_risk' ELSE 'critical' END,
 'crewShortageCancellationEligible',CASE WHEN p_pct>=0 THEN p_pct<80 ELSE NULL END,'dispatchEnforced',false);
$$;
CREATE FUNCTION airlinerra_game.section9_owned_management_responsibilities_v1(p_player uuid,p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE saved record;rows jsonb;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO saved FROM airlinerra_game.section9_management_responsibilities_v1 WHERE airline_id=p_airline;
 SELECT jsonb_agg(jsonb_build_object('key',r.responsibility_key,'label',r.label,'managerRole',r.manager_role,'mode',coalesce(saved.policies->>r.responsibility_key,'manual'),'managerAppointed',coalesce(m.active,false)) ORDER BY r.responsibility_key) INTO rows FROM airlinerra_game.section9_management_responsibility_roles_v1 r LEFT JOIN airlinerra_game.section9_management_appointments_v1 m ON m.airline_id=p_airline AND m.manager_role=r.manager_role;
 RETURN jsonb_build_object('status','management_responsibilities','airlineId',p_airline,'version',coalesce(saved.version,0),'roles',rows,'managerAppointmentsPlayerOnly',true,'delegatedHiringEnabled',false);
END $$;
CREATE FUNCTION airlinerra_game.section9_save_owned_management_responsibilities_v1(p_player uuid,p_airline uuid,p_version int,p_policies jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE old_version int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF jsonb_typeof(p_policies) IS DISTINCT FROM 'object' OR p_version IS NULL OR p_version<0 THEN RETURN jsonb_build_object('status','invalid_management_policies');END IF;
 IF (SELECT count(*) FROM jsonb_object_keys(p_policies))<>(SELECT count(*) FROM airlinerra_game.section9_management_responsibility_roles_v1) OR EXISTS(SELECT 1 FROM jsonb_each_text(p_policies) e LEFT JOIN airlinerra_game.section9_management_responsibility_roles_v1 r ON r.responsibility_key=e.key WHERE r.responsibility_key IS NULL OR e.value IS NULL OR e.value NOT IN('manual','approval','auto')) THEN RETURN jsonb_build_object('status','invalid_management_policies');END IF;
 SELECT version INTO old_version FROM airlinerra_game.section9_management_responsibilities_v1 WHERE airline_id=p_airline;
 IF coalesce(old_version,0)<>p_version THEN RETURN jsonb_build_object('status','management_version_conflict');END IF;
 INSERT INTO airlinerra_game.section9_management_responsibilities_v1(airline_id,version,policies) VALUES(p_airline,p_version+1,p_policies) ON CONFLICT(airline_id) DO UPDATE SET version=excluded.version,policies=excluded.policies,updated_at=clock_timestamp();
 RETURN airlinerra_game.section9_owned_management_responsibilities_v1(p_player,p_airline);
END $$;
CREATE FUNCTION airlinerra_game.section9_owned_fleet_crew_capacity_input_v1(p_player uuid,p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE start_at timestamptz;inp jsonb;ov jsonb;fleet jsonb;
BEGIN
 ov:=airlinerra_game.section9_owned_shared_crew_hiring_overview_v1(p_player,p_airline);
 -- Rolling window starts after the reporting lead time; near-term duties are
 -- not falsely represented as available for new assignments.
 start_at:=date_trunc('minute',airlinerra_game.section9_verified_world_instant_v1())+interval '121 minutes';
 inp:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,start_at);
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x."qualificationGroup"),'[]') INTO fleet FROM(
 SELECT p.qualification_group AS "qualificationGroup",string_agg(DISTINCT c.family_name,', ' ORDER BY c.family_name) label,count(*) AS "aircraftCount"
 FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=f.configuration_id
 JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=f.configuration_id
 WHERE f.airline_id=p_airline AND f.fleet_status='in_service' GROUP BY p.qualification_group)x;
 RETURN jsonb_build_object('status','fleet_crew_capacity_input','airlineId',p_airline,'fleet',fleet,'bases',ov->'bases','forecast',ov->'forecast','input',inp,'availableFromUtc',start_at-interval '120 minutes','policy',(SELECT to_jsonb(c) FROM airlinerra_game.section9_crew_capacity_policy_v1 c WHERE world_id=1));
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_crew_capacity_status_v1(numeric),airlinerra_game.section9_owned_management_responsibilities_v1(uuid,uuid),airlinerra_game.section9_save_owned_management_responsibilities_v1(uuid,uuid,int,jsonb),airlinerra_game.section9_owned_fleet_crew_capacity_input_v1(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
