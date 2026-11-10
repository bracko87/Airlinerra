-- Production-safe regression probe: intentionally forged IDs, no persistent writes.
-- Execute with a privileged testing connection. Expected: GROUP2_NOT_YET_ADMITTED.
DO $test$
DECLARE outcome text; before_drafts bigint; after_drafts bigint;
 before_slots bigint; after_slots bigint;
BEGIN
 SELECT count(*) INTO before_drafts FROM airlinerra_game.airline_flight_schedule_drafts_v1;
 SELECT count(*) INTO before_slots FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1;
 BEGIN
  PERFORM airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
   '00000000-0000-4000-8000-000000000001'::uuid,
   '00000000-0000-4000-8000-000000000002'::uuid,
   '00000000-0000-4000-8000-000000000003'::uuid,
   'AB123','OURAIRPORTS:20581','OURAIRPORTS:46583',
   '2026-11-10T14:00:00Z'::timestamptz,
   '2026-11-10T19:00:00Z'::timestamptz,
   '[{"day":1,"time":"06:00"}]'::jsonb,NULL,'terminal','terminal'
  );
  outcome:='NO_ERROR';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  GET STACKED DIAGNOSTICS outcome=MESSAGE_TEXT;
 END;
 IF outcome<>'SECTION6_GROUP2_NOT_YET_ADMITTED'
 THEN RAISE EXCEPTION 'Expected denial, got %',outcome;END IF;
 SELECT count(*) INTO after_drafts FROM airlinerra_game.airline_flight_schedule_drafts_v1;
 SELECT count(*) INTO after_slots FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1;
 IF before_drafts<>after_drafts OR before_slots<>after_slots
 THEN RAISE EXCEPTION 'Schedule/slot records changed';END IF;
END $test$;
