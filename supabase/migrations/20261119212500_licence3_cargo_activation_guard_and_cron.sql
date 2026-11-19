-- Independent last-line schedule gate for cargo-company service scope.
-- Planning remains possible without a cargo licence; activating a cargo
-- airline schedule requires its own approved, active Licence 3 and AOC.
CREATE OR REPLACE FUNCTION airlinerra_game.licence3_guard_cargo_schedule_activation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE kind text; permit jsonb;
BEGIN
 IF NEW.world_id IS DISTINCT FROM 1 OR NEW.status IS DISTINCT FROM 'active'
   OR NEW.operationally_verified IS DISTINCT FROM true
 THEN RETURN NEW;END IF;
 IF TG_OP='UPDATE' AND OLD.status='active'
   AND OLD.operationally_verified=true AND
   NEW.airline_id IS NOT DISTINCT FROM OLD.airline_id
 THEN RETURN NEW;END IF;
 SELECT business_kind INTO kind FROM airlinerra_game.section9_aoc_operating_companies_v1
 WHERE airline_id=NEW.airline_id AND world_id=1;
 IF kind IS DISTINCT FROM 'cargo' THEN RETURN NEW;END IF;
 permit:=airlinerra_game.licence3_cargo_flight_scope_v1(NEW.airline_id);
 IF permit->>'authorized' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION USING ERRCODE='23514',
   MESSAGE='CARGO_OPERATIONS_LICENCE3_REQUIRED_FOR_ACTIVATION';END IF;
 RETURN NEW;
END $fn$;
DROP TRIGGER IF EXISTS licence3_cargo_schedule_activation_guard_v1 ON airlinerra_game.airline_flight_schedule_drafts_v1;
CREATE TRIGGER licence3_cargo_schedule_activation_guard_v1
 BEFORE INSERT OR UPDATE OF status,operationally_verified,airline_id
 ON airlinerra_game.airline_flight_schedule_drafts_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.licence3_guard_cargo_schedule_activation_v1();
REVOKE ALL ON FUNCTION airlinerra_game.licence3_guard_cargo_schedule_activation_v1() FROM PUBLIC,anon,authenticated,service_role;
DO $cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-cargo-licence3-review-v1')
 THEN PERFORM cron.schedule('airlinerra-cargo-licence3-review-v1',
 '*/5 * * * *','SELECT airlinerra_game.licence3_review_due_cargo_game_applications_v1(25)');
 END IF;
END $cron$;
