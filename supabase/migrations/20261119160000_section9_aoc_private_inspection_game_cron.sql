-- Wire the private game-day AOC inspection completion worker to existing pg_cron.
-- All AOC release and producer flags remain hard-locked off.
DO $do$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-aoc-game-inspection-completion-v1')
 THEN PERFORM cron.schedule(
  'airlinerra-aoc-game-inspection-completion-v1','*/5 * * * *',
  'SELECT airlinerra_game.section9_complete_due_aoc_game_inspections_v1(25)');
 END IF;
END $do$;