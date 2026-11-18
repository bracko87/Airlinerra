-- AOC release remains hard blocked until independently approved cutover.
BEGIN;
ALTER TABLE airlinerra_game.section9_aoc_release_policy_v1
 ADD CONSTRAINT section9_aoc_release_not_before_verified_cutover_v1
 CHECK (issuance_enabled=false AND safety_events_enabled=false
 AND renewal_enabled=false AND flight_enforcement_enabled=false);
COMMIT;