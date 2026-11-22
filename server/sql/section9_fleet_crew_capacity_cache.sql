-- Owner-scoped cache of the *derived*, advisory fleet/crew capacity summary.
-- No personnel data or client-side schedule calculation is trusted for writes.
CREATE TABLE airlinerra_game.section9_fleet_crew_capacity_cache_v1(
 airline_id uuid PRIMARY KEY REFERENCES airlinerra_game.airlines(id) ON DELETE CASCADE,
 revision bigint NOT NULL DEFAULT 0 CHECK(revision>=0),
 payload jsonb,computed_at timestamptz,
 CHECK((payload IS NULL)=(computed_at IS NULL)),
 CHECK(payload IS NULL OR jsonb_typeof(payload)='object')
);
ALTER TABLE airlinerra_game.section9_fleet_crew_capacity_cache_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_fleet_crew_capacity_cache_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE old_airline uuid;new_airline uuid;target uuid;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF to_jsonb(NEW)=to_jsonb(OLD) THEN RETURN NEW;END IF;
  IF TG_TABLE_NAME='section9_dated_flight_occurrences_v1' AND
    (to_jsonb(OLD)-ARRAY['booking_status','booked_seats','recognized_revenue_usd'])=(to_jsonb(NEW)-ARRAY['booking_status','booked_seats','recognized_revenue_usd']) AND
    ((OLD.booking_status='cancelled')=(NEW.booking_status='cancelled'))
  THEN RETURN NEW;END IF;
 END IF;
 IF TG_OP<>'INSERT' THEN old_airline:=OLD.airline_id;END IF;
 IF TG_OP<>'DELETE' THEN new_airline:=NEW.airline_id;END IF;
 FOR target IN SELECT DISTINCT x FROM unnest(ARRAY[old_airline,new_airline]) x WHERE x IS NOT NULL ORDER BY x LOOP
  -- Skip cascaded deletes after the airline was removed.
  IF EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=target) THEN
   INSERT INTO airlinerra_game.section9_fleet_crew_capacity_cache_v1(airline_id,revision) VALUES(target,1)
   ON CONFLICT(airline_id) DO UPDATE SET revision=airlinerra_game.section9_fleet_crew_capacity_cache_v1.revision+1,payload=NULL,computed_at=NULL;
  END IF;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;
CREATE TRIGGER section9_invalidate_capacity_fleet AFTER INSERT OR DELETE OR UPDATE OF configuration_id,fleet_status,airline_id ON airlinerra_game.airline_aircraft_inventory FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_occurrence AFTER INSERT OR DELETE OR UPDATE OF departure_utc,arrival_utc,origin_airport_key,destination_airport_key,schedule_version,aircraft_inventory_id,verified_passenger_seats,booking_status,airline_id ON airlinerra_game.section9_dated_flight_occurrences_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_schedule AFTER INSERT OR DELETE OR UPDATE OF status,version,configuration_id,weekly_schedule,airline_id ON airlinerra_game.airline_flight_schedule_drafts_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_pilots AFTER INSERT OR DELETE OR UPDATE OF employment_status,monthly_salary_usd,game_effective_date,airline_id ON airlinerra_game.section9_airline_crew_roster_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_rank AFTER INSERT OR DELETE OR UPDATE OF career_rank,airline_id ON airlinerra_game.section9_pilot_profiles_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_qualification AFTER INSERT OR DELETE OR UPDATE OF qualification_status,captain_permission,first_officer_permission,issued_game_date,expires_game_date,qualification_group,airline_id ON airlinerra_game.section9_pilot_family_permissions_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_base AFTER INSERT OR DELETE OR UPDATE ON airlinerra_game.section9_crew_bases_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_pilot_base AFTER INSERT OR DELETE OR UPDATE ON airlinerra_game.section9_pilot_base_assignments_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_cabin AFTER INSERT OR DELETE OR UPDATE ON airlinerra_game.section9_cabin_crew_members_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_cabin_pool AFTER INSERT OR DELETE OR UPDATE ON airlinerra_game.section9_cabin_crew_pools_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE TRIGGER section9_invalidate_capacity_absence AFTER INSERT OR DELETE OR UPDATE ON airlinerra_game.section9_crew_unavailability_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1();
CREATE FUNCTION airlinerra_game.section9_read_fleet_crew_capacity_cache_v1(p_player uuid,p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE c record;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO c FROM airlinerra_game.section9_fleet_crew_capacity_cache_v1 WHERE airline_id=p_airline;
 IF FOUND AND c.payload IS NOT NULL AND c.computed_at>=statement_timestamp()-interval '1 hour' THEN
 RETURN jsonb_build_object('status','capacity_cache_hit','revision',c.revision,'computedAt',c.computed_at,'payload',c.payload);END IF;
 RETURN jsonb_build_object('status','capacity_cache_miss','revision',coalesce(c.revision,0));
END $$;
CREATE FUNCTION airlinerra_game.section9_store_fleet_crew_capacity_cache_v1(p_player uuid,p_airline uuid,p_revision bigint,p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE n int;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_revision IS NULL OR p_revision<0 OR p_payload->>'status' IS DISTINCT FROM 'fleet_crew_capacity' OR p_payload->>'airlineId' IS DISTINCT FROM p_airline::text OR p_payload->>'dispatchEnforced' IS DISTINCT FROM 'false' OR jsonb_typeof(p_payload->'families') IS DISTINCT FROM 'array' OR octet_length(p_payload::text)>1000000 THEN RETURN jsonb_build_object('status','capacity_cache_invalid_payload');END IF;
 INSERT INTO airlinerra_game.section9_fleet_crew_capacity_cache_v1(airline_id,revision) VALUES(p_airline,0) ON CONFLICT(airline_id) DO NOTHING;
 UPDATE airlinerra_game.section9_fleet_crew_capacity_cache_v1 SET payload=p_payload,computed_at=clock_timestamp() WHERE airline_id=p_airline AND revision=p_revision;
 GET DIAGNOSTICS n=ROW_COUNT;
 RETURN jsonb_build_object('status',CASE WHEN n=1 THEN 'capacity_cache_stored' ELSE 'capacity_cache_revision_changed' END);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1(),airlinerra_game.section9_read_fleet_crew_capacity_cache_v1(uuid,uuid),airlinerra_game.section9_store_fleet_crew_capacity_cache_v1(uuid,uuid,bigint,jsonb) FROM PUBLIC,anon,authenticated,service_role;
