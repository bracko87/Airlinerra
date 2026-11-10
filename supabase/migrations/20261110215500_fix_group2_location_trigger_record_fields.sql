-- Repair shared HQ/office location trigger: records have different airport field names.
CREATE OR REPLACE FUNCTION airlinerra_game.enforce_location_selection_eligibility_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $trg$
DECLARE permitted boolean;
BEGIN
 IF TG_TABLE_NAME='airlines' THEN
  SELECT hq_selectable INTO permitted
  FROM airlinerra_game.airport_location_eligibility_v1
  WHERE world_id=NEW.world_id AND airport_key=NEW.home_airport_key;
 ELSIF TG_TABLE_NAME='airport_offices' THEN
  SELECT office_selectable INTO permitted
  FROM airlinerra_game.airport_location_eligibility_v1
  WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key;
 ELSE
  RAISE EXCEPTION 'Unsupported location selection trigger source'
    USING ERRCODE='23514';
 END IF;
 IF permitted IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'Location is not eligible for selection' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $trg$;
REVOKE ALL ON FUNCTION airlinerra_game.enforce_location_selection_eligibility_v1()
 FROM PUBLIC,anon,authenticated;