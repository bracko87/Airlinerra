-- Applied to Airlinerra Supabase World 1 on 2026-11-17.
-- Unified airport read interface: both cohorts appear; ONLY verified/admitted airports can dispatch.
-- This is NOT a commercial release or a licence/flight permission grant.
create or replace view airlinerra_game.airport_unified_operations_v1
with (security_invoker = true)
as
select c.world_id,c.airport_key,c.source_group,c.airport_name,c.game_lookup_code,c.country_iso,c.game_category,
       c.latitude_deg,c.longitude_deg,c.timezone_iana,
       c.game_runway_length_m,c.game_terminal_count,c.game_terminal_stands,c.game_remote_stands,c.game_cargo_stands,
       c.game_terminal_slot_per_10m,c.game_remote_slot_per_10m,c.game_cargo_slot_per_10m,
       c.game_nighttime_ban,c.game_noise_restrictions,c.restriction_basis,
       c.game_daily_outbound_passengers,c.game_daily_outbound_cargo_tonnes,c.game_season_profile,
       c.game_landing_fee_usd,c.game_parking_per_day_usd,c.game_departing_pax_fee_usd,
       c.game_data_status,
       true as included_in_unified_catalogue,
       case when c.source_group='GROUP_1' then true else coalesce(r.ready_for_owner_release_review,false) end as admission_review_ready,
       case when c.source_group='GROUP_1' then true else coalesce(r.admitted_to_world1,false) end as admitted_to_world,
       case when c.source_group='GROUP_1' then true else coalesce(r.operationally_authorized,false) end as operationally_authorized,
       case when c.source_group='GROUP_1' then true else coalesce(r.can_activate_flights,false) end as dispatch_eligible_by_airport_admission,
       case when c.source_group='GROUP_1' then 'EXISTING_APPROVED'
            when coalesce(r.documented_commercial_prohibition,false) then 'DOCUMENTED_PROHIBITION'
            else coalesce(r.readiness_status,'ADMISSION_REVIEW_UNAVAILABLE') end as admission_status,
       case when c.source_group='GROUP_1' then array[]::text[] else coalesce(r.unresolved_gates,array['admission_review_unavailable']::text[]) end as unresolved_admission_gates
from airlinerra_game.airport_sections1_8_combined_catalog_v1 c
left join airlinerra_game.airport_group2_admission_readiness_v1 r
 on c.source_group='GROUP_2' and c.airport_key=r.airport_key;
comment on view airlinerra_game.airport_unified_operations_v1 is 'Unified read-only game airport interface for Groups 1 and 2. Group provenance retained. Data inclusion is NOT dispatch authorization. Source-neutral for future consumers; do not use for automatic release without admission gating.';