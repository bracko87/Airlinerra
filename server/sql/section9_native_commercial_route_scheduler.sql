-- Deployment bootstrap for native route certification worker.
-- Run only after server/sql/section9_native_commercial_route_certifier.sql
-- and with commercial release paused. Generates secrets inside encrypted
-- Vault; does not display, export or store key material in source control.
BEGIN;
DO $guard$
DECLARE kind text;name_to_create text;j record;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1 AND release_state='paused')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1 AND release_state='disabled')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1 AND release_state='paused')
 THEN RAISE EXCEPTION 'RELEASE_NOT_PAUSED';END IF;
 IF has_table_privilege('anon','vault.decrypted_secrets','SELECT') OR has_table_privilege('authenticated','vault.decrypted_secrets','SELECT')
 THEN RAISE EXCEPTION 'PUBLIC_VAULT_ACCESS';END IF;
 FOREACH kind IN ARRAY ARRAY['operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance'] LOOP
  name_to_create:='airlinerra_game_clearance_'||kind||'_v1';
  IF NOT EXISTS(SELECT 1 FROM vault.secrets WHERE name=name_to_create) THEN
   PERFORM vault.create_secret(encode(extensions.gen_random_bytes(48),'hex'),name_to_create,'Private Airlinerra game clearance HMAC key; not for client access');
  END IF;
 END LOOP;
 SELECT jobid,command INTO j FROM cron.job WHERE jobname='airlinerra-game-certified-roundtrip-finalizer-v1';
 IF NOT FOUND THEN RAISE EXCEPTION 'MISSING_CERTIFICATION_JOB';END IF;
 IF j.command='SELECT airlinerra_game.section9_auto_certify_queued_roundtrips_v1(10); SELECT airlinerra_game.section9_auto_finish_certified_roundtrip_batch_v1(10);' THEN RETURN;END IF;
 IF j.command IS DISTINCT FROM 'SELECT airlinerra_game.section9_auto_finish_certified_roundtrip_batch_v1(10);' THEN RAISE EXCEPTION 'UNEXPECTED_CERTIFICATION_JOB';END IF;
 PERFORM cron.alter_job(job_id:=j.jobid,command:='SELECT airlinerra_game.section9_auto_certify_queued_roundtrips_v1(10); SELECT airlinerra_game.section9_auto_finish_certified_roundtrip_batch_v1(10);');
END $guard$;
COMMIT;
