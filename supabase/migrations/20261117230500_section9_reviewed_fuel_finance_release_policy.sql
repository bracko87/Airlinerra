-- Private, reviewed game fuel/finance release: state remains paused until independently tested.
begin;
create table if not exists airlinerra_game.section9_fuel_and_settlement_release_policy_v1(
 world_id smallint primary key references public.airlinerra_game_worlds(id),
 release_state text not null default 'paused'
   check (release_state in ('paused','enabled')),
 review_reference text,
 approved_by text,
 approved_at timestamptz,
 enabled_at timestamptz,
 execution_producer_evidence text,
 fuel_writer_evidence text,
 settlement_writer_evidence text,
 constraint section9_fuel_settlement_private_review_check check(
  release_state='paused' or (
   length(coalesce(review_reference,''))>=20
   and length(coalesce(approved_by,''))>=12
   and approved_at is not null and enabled_at is not null
   and approved_at<=clock_timestamp() and enabled_at<=clock_timestamp()
   and length(coalesce(execution_producer_evidence,''))>=20
   and length(coalesce(fuel_writer_evidence,''))>=20
   and length(coalesce(settlement_writer_evidence,''))>=20
  )
 )
);
alter table airlinerra_game.section9_fuel_and_settlement_release_policy_v1 enable row level security;
revoke all on airlinerra_game.section9_fuel_and_settlement_release_policy_v1 from public,anon,authenticated;
insert into airlinerra_game.section9_fuel_and_settlement_release_policy_v1(world_id,release_state)
values(1,'paused') on conflict(world_id) do nothing;
create or replace view airlinerra_game.section9_flight_engine_readiness_audit_v1 as
 SELECT 1::smallint AS world_id,
    w.state AS world_state,
    w.opens_at AS world_opens_at,
    c.confirmed_game_date,
    c.clock_source,
    c.clock_source = 'authoritative_game_engine'::text AND c.confirmed_game_date IS NOT NULL AS authoritative_clock_connected,
    producer.world_id IS NOT NULL AS clock_producer_configured,
    COALESCE(producer.producer_status = 'enabled'::text, false) AS clock_producer_enabled,
    ( SELECT count(*) AS count
           FROM airlinerra_game.airline_flight_schedule_drafts_v1) AS saved_flight_schedules,
    ( SELECT count(*) AS count
           FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
          WHERE s.status = 'active'::text) AS active_flight_schedules,
    ( SELECT count(*) AS count
           FROM airlinerra_game.section9_schedule_operational_certifications_v1) AS operational_certification_records,
    ( SELECT count(*) AS count
           FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1) AS aircraft_operation_jobs,
    ( SELECT count(*) AS count
           FROM airlinerra_game.section9_operated_flight_movements_v1) AS verified_movement_records,
    ( SELECT count(*) AS count
           FROM airlinerra_game.section9_route_posted_flight_financials_v1) AS settled_flight_records,
    ( SELECT count(*) AS count
           FROM airlinerra_game.aircraft_fuel_planning_profiles_v1
          WHERE aircraft_fuel_planning_profiles_v1.full_kg_per_100km > 0::numeric) AS aircraft_fuel_planning_profiles,
    ( SELECT count(*) AS count
           FROM airlinerra_game.aircraft_game_fuel_family_v1
          WHERE aircraft_game_fuel_family_v1.fuel_family = 'TURBINE_KEROSENE_ASSUMED'::text) AS game_kerosene_aircraft_profiles,
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM airlinerra_game.section9_trusted_execution_release_policy_v1 release
              WHERE release.world_id = 1 AND release.release_state = 'enabled'::text AND release.enabled_at IS NOT NULL AND release.reviewed_at IS NOT NULL AND release.approved_by IS NOT NULL AND char_length(release.approved_by) >= 12 AND char_length(release.release_reference) >= 16)) THEN 'ACTIVATED'::text
            ELSE 'NOT_ACTIVATED'::text
        END AS trusted_flight_execution_release,
    CASE WHEN (EXISTS (
 SELECT 1 FROM airlinerra_game.section9_fuel_and_settlement_release_policy_v1 fuel
 WHERE fuel.world_id=w.id AND fuel.release_state='enabled'
 AND fuel.approved_at IS NOT NULL AND fuel.enabled_at IS NOT NULL
 AND length(fuel.review_reference)>=20
 AND length(fuel.approved_by)>=12
 AND length(fuel.execution_producer_evidence)>=20
 AND length(fuel.fuel_writer_evidence)>=20
 AND length(fuel.settlement_writer_evidence)>=20
) AND EXISTS (
 SELECT 1 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 model
 WHERE model.game_calculation_ready=true
 AND model.operational_dispatch_release='RELEASED'
 AND model.financial_settlement_release='RELEASED'
)) THEN 'ACTIVATED'::text ELSE 'NOT_ACTIVATED'::text END AS fuel_transaction_release,
    ((EXISTS (
 SELECT 1 FROM airlinerra_game.section9_fuel_and_settlement_release_policy_v1 fuel
 WHERE fuel.world_id=w.id AND fuel.release_state='enabled'
 AND fuel.approved_at IS NOT NULL AND fuel.enabled_at IS NOT NULL
 AND length(fuel.review_reference)>=20
 AND length(fuel.approved_by)>=12
 AND length(fuel.execution_producer_evidence)>=20
 AND length(fuel.fuel_writer_evidence)>=20
 AND length(fuel.settlement_writer_evidence)>=20
) AND EXISTS (
 SELECT 1 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 model
 WHERE model.game_calculation_ready=true
 AND model.operational_dispatch_release='RELEASED'
 AND model.financial_settlement_release='RELEASED'
)) AND EXISTS (
 SELECT 1 FROM airlinerra_game.section9_activation_release_policy_v1 active
 WHERE active.world_id=w.id AND active.release_state='enabled'
 AND active.crew_mode='deferred_phase1' AND active.enabled_at IS NOT NULL
) AND EXISTS (
 SELECT 1 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 running
 WHERE running.world_id=w.id AND running.release_state='enabled'
 AND running.enabled_at IS NOT NULL AND running.reviewed_at IS NOT NULL
) AND EXISTS (
 SELECT 1 FROM airlinerra_game.section9_flight_finance_posting_release_v1 finance
 WHERE finance.world_id=w.id AND finance.release_state='approved'
 AND finance.approved_at IS NOT NULL AND length(finance.approval_reference)>=20
)) AS automatic_flight_and_fuel_settlement_enabled
   FROM airlinerra_game_worlds w
     LEFT JOIN airlinerra_game.holding_world_clock_v1 c ON c.world_id = w.id
     LEFT JOIN airlinerra_game.section9_clock_producer_schedule_v1 producer ON producer.world_id = w.id
  WHERE w.id = 1;
do $$ begin
 if exists(select 1 from airlinerra_game.section9_flight_engine_readiness_audit_v1
  where automatic_flight_and_fuel_settlement_enabled=true or fuel_transaction_release='ACTIVATED')
 then raise exception 'UNEXPECTED_FLIGHT_FINANCE_RELEASE_DURING_POLICY_INSTALL';end if;
end $$;
commit;