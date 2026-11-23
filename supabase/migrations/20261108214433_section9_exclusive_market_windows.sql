-- Prevent independent or changed simulation windows from allocating the
-- SAME origin market day twice. Market-day demand partitions are disjoint.
-- Adjacent windows may still share a physical onward flight: the existing
-- physical inventory lock enforces its total passenger and cargo capacity.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_prevent_overlapping_hold_windows_v1()
 RETURNS trigger LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
BEGIN
 -- Serialize concurrent job registration, not the calculation itself.
 PERFORM pg_catalog.pg_advisory_xact_lock(92009261::bigint);
 IF TG_OP='UPDATE' AND (
  NEW.world_id=OLD.world_id AND
  NEW.start_game_date=OLD.start_game_date AND
  NEW.market_days=OLD.market_days
 ) THEN RETURN NEW;END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_capacity_hold_plans_v1 j
   WHERE j.world_id=NEW.world_id
    AND (TG_OP<>'UPDATE' OR j.id<>NEW.id)
    AND daterange(j.start_game_date,j.start_game_date+j.market_days,'[)')
      && daterange(NEW.start_game_date,
                   NEW.start_game_date+NEW.market_days,'[)')
    AND NOT (
     j.start_game_date=NEW.start_game_date
     AND j.market_days=NEW.market_days
    )
 ) THEN
  RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_OVERLAPPING_DEMAND_WINDOW_NOT_ALLOWED';
 END IF;
 RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS section9_demand_window_overlap_guard
 ON airlinerra_game.section9_capacity_hold_plans_v1;
CREATE TRIGGER section9_demand_window_overlap_guard
 BEFORE INSERT OR UPDATE OF start_game_date,market_days,world_id
 ON airlinerra_game.section9_capacity_hold_plans_v1
 FOR EACH ROW EXECUTE FUNCTION
  airlinerra_game.section9_prevent_overlapping_hold_windows_v1();
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_prevent_overlapping_hold_windows_v1()
 FROM PUBLIC,anon,authenticated;
