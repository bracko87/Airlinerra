-- World 1 Airlinerra design-only release configuration.
-- Crew is postponed for first operational game phase, as requested by
-- project owner. This is NOT an independent operational approval.
-- No flights/slots/licences/bookings/charges are enabled or created.
INSERT INTO airlinerra_game.section9_activation_release_policy_v1
 (world_id,release_state,release_reference,approved_by,reviewed_at,enabled_at,crew_mode)
VALUES
 (1::smallint,'paused',
  'GAME_DESIGN_PHASE1_CREW_DEFERRED_NOT_OPERATIONAL_RELEASE_V1',
  'game_design_configuration_only',
  clock_timestamp(),NULL,'deferred_phase1')
ON CONFLICT(world_id) DO NOTHING;
