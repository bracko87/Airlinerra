-- READ ONLY commercial-flight release audit, necessary gates only.
create or replace view airlinerra_game.section9_commercial_flight_release_blockers_v1 with (security_invoker=true) as
 SELECT e.world_id,
    e.authoritative_clock_connected AS game_clock_ready,
    e.saved_flight_schedules,
    e.active_flight_schedules,
    e.operational_certification_records,
    e.verified_movement_records,
    e.settled_flight_records,
    e.trusted_flight_execution_release,
    e.fuel_transaction_release,
    e.automatic_flight_and_fuel_settlement_enabled,
    COALESCE(a.release_state, 'missing'::text) AS activation_policy,
    COALESCE(x.release_state, 'missing'::text) AS execution_policy,
    COALESCE(f.release_state, 'missing'::text) AS finance_policy,
    ( SELECT count(*)::integer AS count
           FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 m
          WHERE m.operational_dispatch_release = 'RELEASED'::text AND m.financial_settlement_release = 'RELEASED'::text AND m.game_calculation_ready) AS fuel_models_fully_released,
    ( SELECT count(*)::integer AS count
           FROM airlinerra_game.section9_private_roundtrip_certification_queue_v1) AS staged_pairs,
    array_remove(ARRAY[
        CASE
            WHEN e.authoritative_clock_connected IS DISTINCT FROM true THEN 'GAME_CLOCK_NOT_CONNECTED'::text
            ELSE NULL::text
        END,
        CASE
            WHEN a.release_state IS DISTINCT FROM 'enabled'::text THEN 'SCHEDULE_ACTIVATION_RELEASE_PAUSED'::text
            ELSE NULL::text
        END,
        CASE
            WHEN x.release_state IS DISTINCT FROM 'enabled'::text THEN 'TRUSTED_FLIGHT_EXECUTION_RELEASE_DISABLED'::text
            ELSE NULL::text
        END,
        CASE
            WHEN f.release_state IS DISTINCT FROM 'approved'::text THEN 'FLIGHT_FINANCE_RELEASE_PAUSED'::text
            ELSE NULL::text
        END,
        CASE
            WHEN e.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'::text THEN 'EXECUTION_ENGINE_NOT_ACTIVATED'::text
            ELSE NULL::text
        END,
        CASE
            WHEN e.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'::text OR e.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true THEN 'FUEL_AND_AUTOMATIC_SETTLEMENT_NOT_ACTIVATED'::text
            ELSE NULL::text
        END,
        CASE
            WHEN NOT (EXISTS ( SELECT 1
               FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 m
              WHERE m.operational_dispatch_release = 'RELEASED'::text AND m.financial_settlement_release = 'RELEASED'::text AND m.game_calculation_ready)) THEN 'NO_AIRCRAFT_FUEL_MODEL_OPERATIONALLY_RELEASED'::text
            ELSE NULL::text
        END,
        CASE
            WHEN e.active_flight_schedules = 0 THEN 'NO_ACTIVE_CERTIFIED_FLIGHTS'::text
            ELSE NULL::text
        END], NULL::text) AS outstanding_release_gates,
    e.authoritative_clock_connected AND a.release_state = 'enabled'::text AND x.release_state = 'enabled'::text AND f.release_state = 'approved'::text AND e.trusted_flight_execution_release = 'ACTIVATED'::text AND e.fuel_transaction_release = 'ACTIVATED'::text AND e.automatic_flight_and_fuel_settlement_enabled AND e.active_flight_schedules > 0 AND (EXISTS ( SELECT 1
           FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 m
          WHERE m.operational_dispatch_release = 'RELEASED'::text AND m.financial_settlement_release = 'RELEASED'::text AND m.game_calculation_ready)) AS basic_release_gates_satisfied
   FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 e
     LEFT JOIN airlinerra_game.section9_activation_release_policy_v1 a USING (world_id)
     LEFT JOIN airlinerra_game.section9_trusted_execution_release_policy_v1 x USING (world_id)
     LEFT JOIN airlinerra_game.section9_flight_finance_posting_release_v1 f USING (world_id);
revoke all on airlinerra_game.section9_commercial_flight_release_blockers_v1 from public,anon,authenticated;
