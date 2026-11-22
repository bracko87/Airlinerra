CREATE OR REPLACE FUNCTION airlinerra_game.section9_invalidate_fleet_crew_capacity_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE old_airline uuid;new_airline uuid;target uuid;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF to_jsonb(NEW)=to_jsonb(OLD) THEN RETURN NEW;END IF;
  IF TG_TABLE_NAME='section9_dated_flight_occurrences_v1' AND
    (to_jsonb(OLD)-ARRAY['booking_status','booked_seats','recognized_revenue_usd'])=(to_jsonb(NEW)-ARRAY['booking_status','booked_seats','recognized_revenue_usd']) AND
    (((to_jsonb(OLD)->>'booking_status')='cancelled')=((to_jsonb(NEW)->>'booking_status')='cancelled'))
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
END $function$
;
