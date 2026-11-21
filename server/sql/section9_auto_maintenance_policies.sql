BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aircraft_auto_maintenance_policies_v1(
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE CASCADE,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 check_code text NOT NULL REFERENCES airlinerra_game.maintenance_check_policy_v1(check_code),
 airport_key text NOT NULL,provider_key text NOT NULL,enabled boolean NOT NULL DEFAULT false,
 max_cost_usd numeric(14,2) NOT NULL CHECK(max_cost_usd>0),
 updated_at timestamptz NOT NULL DEFAULT now(),last_attempt_at timestamptz,last_result text,
 PRIMARY KEY(aircraft_inventory_id,check_code)
);
ALTER TABLE airlinerra_game.section9_aircraft_auto_maintenance_policies_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_aircraft_auto_maintenance_policies_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_auto_maintenance_policy_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_action text,p_check text DEFAULT NULL,p_airport text DEFAULT NULL,p_provider text DEFAULT NULL,p_enabled boolean DEFAULT NULL,p_max_cost numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE offers jsonb; offer jsonb; result jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_MAINTENANCE_POLICY_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.owner_player_id=p_player AND a.world_id=1 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE i.id=p_aircraft AND i.airline_id=p_airline AND i.ownership_type IN ('owned','leased')) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='MAINTENANCE_AIRCRAFT_NOT_OWNED';END IF;
 IF p_action='save' THEN
  IF p_check IS NULL OR p_enabled IS NULL THEN RAISE EXCEPTION 'Invalid maintenance policy';END IF;
  IF p_enabled THEN
   offers:=airlinerra_game.section9_owned_ai_maintenance_quotes_v1(p_player,p_airline,p_aircraft,p_check,p_airport);
   SELECT value INTO offer FROM jsonb_array_elements(offers->'quotes') WHERE value->>'providerKey'=p_provider AND value->>'airportKey'=p_airport;
   IF offer IS NULL OR p_max_cost IS NULL OR p_max_cost<(offer->>'priceUsd')::numeric OR p_max_cost>10000000 THEN RETURN jsonb_build_object('status','invalid_maintenance_policy_quote','saved',false);END IF;
   INSERT INTO airlinerra_game.section9_aircraft_auto_maintenance_policies_v1(aircraft_inventory_id,airline_id,check_code,airport_key,provider_key,enabled,max_cost_usd)
   VALUES(p_aircraft,p_airline,p_check,p_airport,p_provider,true,p_max_cost)
   ON CONFLICT(aircraft_inventory_id,check_code) DO UPDATE SET airport_key=excluded.airport_key,provider_key=excluded.provider_key,enabled=true,max_cost_usd=excluded.max_cost_usd,updated_at=now(),last_attempt_at=NULL,last_result=NULL;
  ELSE
   UPDATE airlinerra_game.section9_aircraft_auto_maintenance_policies_v1 SET enabled=false,updated_at=now() WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline AND check_code=p_check;
  END IF;
 ELSIF p_action<>'list' THEN RAISE EXCEPTION 'Invalid maintenance policy action';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('checkCode',check_code,'airportKey',airport_key,'providerKey',provider_key,'enabled',enabled,'maxCostUsd',max_cost_usd,'lastAttemptAt',last_attempt_at,'lastResult',last_result) ORDER BY check_code),'[]'::jsonb) INTO result FROM airlinerra_game.section9_aircraft_auto_maintenance_policies_v1 WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline;
 RETURN jsonb_build_object('status','aircraft_auto_maintenance_policies','saved',p_action='save','policies',result,'aircraftInventoryId',p_aircraft,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_auto_maintenance_policy_v1(uuid,uuid,uuid,text,text,text,text,boolean,numeric) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_schedule_maintenance_v1(p_limit int DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE pol record; v_now timestamptz; due jsonb; ck jsonb; q jsonb; offer jsonb; res jsonb; decision text; booked int:=0; blocked int:=0; checked int:=0;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_AUTO_MAINTENANCE_ONLY';END IF;
 IF p_limit NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION 'Invalid limit';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF NOT pg_try_advisory_xact_lock(583734,0) THEN RETURN jsonb_build_object('status','already_running','booked',0);END IF;
 FOR pol IN SELECT p.*,a.owner_player_id FROM airlinerra_game.section9_aircraft_auto_maintenance_policies_v1 p JOIN airlinerra_game.airlines a ON a.id=p.airline_id AND a.world_id=1 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=p.aircraft_inventory_id AND i.airline_id=p.airline_id AND i.fleet_status='in_service' JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=a.owner_player_id AND w.state='active'
 WHERE p.enabled AND (p.last_attempt_at IS NULL OR p.last_attempt_at<=v_now-interval '10 minutes') AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j WHERE j.aircraft_inventory_id=p.aircraft_inventory_id AND j.status IN ('scheduled','in_progress','payment_required'))
 ORDER BY p.last_attempt_at NULLS FIRST,p.aircraft_inventory_id,CASE p.check_code WHEN 'd' THEN 1 WHEN 'c' THEN 2 WHEN 'b' THEN 3 WHEN 'a' THEN 4 WHEN 'weekly' THEN 5 ELSE 6 END LIMIT p_limit FOR UPDATE OF p SKIP LOCKED
 LOOP
  BEGIN
   checked:=checked+1;
   due:=airlinerra_game.section9_owned_game_maintenance_due_v1(pol.owner_player_id,pol.airline_id,pol.aircraft_inventory_id,(v_now AT TIME ZONE 'Europe/Berlin')::date);
   SELECT value INTO ck FROM jsonb_array_elements(due->'checks') WHERE value->>'checkCode'=pol.check_code;
   IF ck IS NULL THEN decision:='maintenance_due_status_unavailable';
   ELSIF ck->>'currentlyDue' IS DISTINCT FROM 'true' THEN decision:='not_due';
   ELSE
    q:=airlinerra_game.section9_owned_ai_maintenance_quotes_v1(pol.owner_player_id,pol.airline_id,pol.aircraft_inventory_id,pol.check_code,pol.airport_key);
    SELECT value INTO offer FROM jsonb_array_elements(q->'quotes') WHERE value->>'providerKey'=pol.provider_key;
    IF offer IS NULL THEN decision:='provider_unavailable';
    ELSIF (offer->>'priceUsd')::numeric>pol.max_cost_usd THEN decision:='price_exceeds_limit';
    ELSE
     res:=airlinerra_game.section9_book_ai_maintenance_v1(pol.owner_player_id,pol.airline_id,pol.aircraft_inventory_id,pol.check_code,pol.airport_key,pol.provider_key,NULL);
     decision:=coalesce(res->>'status','booking_unverified');
     IF res->>'created'='true' THEN booked:=booked+1;ELSE blocked:=blocked+1;END IF;
    END IF;
   END IF;
   UPDATE airlinerra_game.section9_aircraft_auto_maintenance_policies_v1 SET last_attempt_at=v_now,last_result=decision WHERE aircraft_inventory_id=pol.aircraft_inventory_id AND check_code=pol.check_code AND enabled;
  EXCEPTION WHEN OTHERS THEN
   blocked:=blocked+1;
   UPDATE airlinerra_game.section9_aircraft_auto_maintenance_policies_v1 SET last_attempt_at=v_now,last_result='automatic_booking_failed' WHERE aircraft_inventory_id=pol.aircraft_inventory_id AND check_code=pol.check_code AND enabled;
  END;
 END LOOP;
 RETURN jsonb_build_object('status','auto_maintenance_processed','checked',checked,'booked',booked,'blocked',blocked,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_schedule_maintenance_v1(int) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;