-- World 1 source: real-time Berlin game clock at hour precision.
-- Only valid while the authoritative game day matches Berlin's date AND
-- the independent daily receipt and producer status agree. Never fabricate
-- a future game time when official day updates are delayed or stopped.
-- This is a time read-only proof, not a flight/movement release.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 time_now timestamptz:=clock_timestamp();
 date_berlin date;
 midnight_berlin timestamptz;
 clock_row record;
 producer record;
 world_row record;
 receipt record;
 ready boolean:=false;
BEGIN
 date_berlin:=(time_now AT TIME ZONE 'Europe/Berlin')::date;
 midnight_berlin:=date_berlin::timestamp AT TIME ZONE 'Europe/Berlin';
 SELECT state,opens_at INTO world_row FROM public.airlinerra_game_worlds
 WHERE id=1;
 SELECT * INTO clock_row
 FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 SELECT * INTO producer
 FROM airlinerra_game.section9_clock_producer_schedule_v1 WHERE world_id=1;
 SELECT game_date,engine_event_id,event_hmac_sha256,accepted_at
 INTO receipt
 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
 WHERE world_id=1 AND game_date=date_berlin
 ORDER BY accepted_at DESC LIMIT 1;
 ready:=world_row.state='active'
  AND world_row.opens_at IS NOT NULL
  AND world_row.opens_at<=time_now
  AND producer.producer_status='enabled'
  AND producer.enabled_at IS NOT NULL
  AND clock_row.clock_source='authoritative_game_engine'
  AND clock_row.confirmed_game_date=date_berlin
  AND clock_row.last_verified_at IS NOT NULL
  AND clock_row.last_verified_at BETWEEN midnight_berlin-interval '2 minutes'
                                     AND time_now+interval '2 seconds'
  AND length(coalesce(clock_row.engine_proof_ref,''))>=12
  AND receipt.game_date=date_berlin
  AND receipt.accepted_at BETWEEN midnight_berlin-interval '2 minutes'
                                AND time_now+interval '2 seconds'
  AND receipt.engine_event_id='horizon-world1-day-'||date_berlin::text
  AND receipt.event_hmac_sha256 ~ '^[a-f0-9]{64}$';
 RETURN jsonb_build_object(
 'status',CASE WHEN ready THEN 'verified_berlin_realtime_hour'
    ELSE 'blocked_game_day_hour_not_synchronized' END,
 'worldId',1,'gameDate',clock_row.confirmed_game_date,
 'berlinDate',date_berlin,
 'authoritativeGameHourAvailable',coalesce(ready,false),
 'gameHourUtc',CASE WHEN ready THEN date_trunc('second',time_now) ELSE NULL END,
 'timeSource','TRUSTED_POSTGRES_UTC_CLOCK_WHILE_SIGNED_BERLIN_GAME_DAY_MATCHES',
 'readOnly',true,
 'flightActivated',false,'movementRecorded',false,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
 FROM PUBLIC,anon,authenticated,service_role;
