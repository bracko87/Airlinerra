CREATE OR REPLACE FUNCTION airlinerra.enforce_game_airport_activation()
RETURNS trigger LANGUAGE plpgsql
SET search_path TO 'airlinerra', 'pg_temp'
AS $function$
BEGIN
  -- Preserve the separately authorized original 3,140-airport simulation cohort.
  IF NEW.active AND NEW.world_number=1 AND EXISTS(
    SELECT 1 FROM airlinerra.airport_game_foundation_release_members m
    JOIN airlinerra.airport_game_foundation_release_authorizations a ON a.release_key=m.release_key
    JOIN airlinerra.airport_cohorts c ON c.airport_key=m.airport_key AND c.cohort='ORIGINAL_3140'
    JOIN airlinerra.airport_registry r ON r.airport_key=m.airport_key
    JOIN airlinerra.airport_game_profiles p ON p.airport_key=m.airport_key
    WHERE m.airport_key=NEW.airport_key AND m.world_number=1
      AND a.world_number=1 AND a.cohort='ORIGINAL_3140'
      AND a.release_purpose='SIMULATION_GAME_CATALOG' AND a.authorized_airport_count=3140
      AND r.runway_screen_status='RUNWAY_QUALIFIED'
      AND r.longest_qualifying_runway_m>=1200
      AND p.proposed_category IN('Local','Regional','Medium','Large','Major Hub','Mega Hub')
  ) THEN RETURN NEW; END IF;

  -- Owner-authorized 27 Oct 2026 simulation-only historical runway admission.
  -- Do not infer civilian or commercial flight permissions from this path.
  IF NEW.active AND NEW.world_number=1 AND EXISTS (
    SELECT 1
    FROM airlinerra_game.approved_game_airports g
    JOIN airlinerra.airport_expansion_final_decision_queue q ON q.airport_key=g.airport_key
    JOIN airlinerra.airport_registry r ON r.airport_key=g.airport_key
    JOIN airlinerra.airport_game_profiles p ON p.airport_key=g.airport_key
    WHERE g.world_id=1 AND g.airport_key=NEW.airport_key
      AND g.approval_reference='SIMULATION_ONLY:HISTORICAL_PAVED_1200M_USER_APPROVED_2026_10_27'
      AND q.decision_status='ACCEPT'
      AND r.runway_screen_status='RUNWAY_QUALIFIED'
      AND r.longest_qualifying_runway_m>=1200
      AND (r.longest_qualifying_surface ~* '(ASP|CONC|CON|BITUM)' OR upper(r.longest_qualifying_surface)='PEM')
      AND p.proposed_category IN('Local','Regional','Medium','Large','Major Hub','Mega Hub')
      AND NOT EXISTS (
       SELECT 1 FROM airlinerra.airport_access_reviews ar
       WHERE ar.airport_key=r.airport_key AND ar.civilian_access_status='CLOSED_ALL_AIR_TRAFFIC_BY_FRENCH_LAW_2021'
      )
      AND NOT EXISTS (
       SELECT 1 FROM airlinerra.airport_expansion_selection_phase3 s
       WHERE s.airport_key=r.airport_key AND s.runway_condition='FAILED'
      )
  ) THEN RETURN NEW; END IF;

  -- Retain original full verification gate for any other active airport.
  IF NEW.active AND NOT EXISTS (
    SELECT 1 FROM airlinerra.airport_access_reviews a
    JOIN airlinerra.airport_game_profiles p ON p.airport_key=a.airport_key
    WHERE a.airport_key=NEW.airport_key
      AND a.game_admission_status='APPROVED_FOR_GAME'
      AND a.owner_approved_at IS NOT NULL AND a.approved_by IS NOT NULL
      AND a.identity_status='VERIFIED' AND a.paved_runway_status='VERIFIED'
      AND a.civilian_access_status='VERIFIED' AND a.commercial_permission_status='VERIFIED'
      AND p.final_category IS NOT NULL AND p.category_approved_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Airlinerra airport is not approved for gameplay activation: %',NEW.airport_key;
  END IF;
  RETURN NEW;
END
$function$;