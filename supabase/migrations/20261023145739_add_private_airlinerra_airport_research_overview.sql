create or replace view airlinerra.airport_research_overview
with (security_invoker=true)
as
with latest_sources as (
  select distinct on (source_path) source_path,source_git_blob_sha
  from airlinerra.research_source_snapshots
  where import_status='VERIFIED'
  order by source_path,verified_at desc nulls last,recorded_at desc
), classified as (
  select r.airport_key, r.row_data as review_data
  from airlinerra.research_source_rows r
  join latest_sources s on s.source_path=r.source_path and s.source_git_blob_sha=r.source_git_blob_sha
  where r.source_path='data/airports/classification/airport_classification_review.csv'
), flagged as (
  select r.airport_key, r.row_data->>'review_priority' as military_priority,
         r.row_data->>'civilian_commercial_status' as civil_source_status
  from airlinerra.research_source_rows r
  join latest_sources s on s.source_path=r.source_path and s.source_git_blob_sha=r.source_git_blob_sha
  where r.source_path='data/airports/identity/military_use_review_queue.csv'
), civil as (
  select r.airport_key, r.row_data->>'civilian_evidence_class' as civilian_evidence_class
  from airlinerra.research_source_rows r
  join latest_sources s on s.source_path=r.source_path and s.source_git_blob_sha=r.source_git_blob_sha
  where r.source_path='data/airports/identity/military_use_civilian_evidence.csv'
)
select a.airport_key,a.source_type,a.source_airport_id,a.country_iso,a.airport_name,a.municipality,
       a.source_ident,a.source_gps_code,a.latitude_deg,a.longitude_deg,
       a.longest_qualifying_runway_m,a.longest_qualifying_surface,
       a.runway_screen_status,
       coh.cohort,
       c.review_data->>'provisional_category' as github_provisional_category,
       c.review_data->>'decision_status' as github_classification_decision,
       c.review_data->>'passenger_activity_signal' as passenger_research_status,
       c.review_data->>'cargo_activity_signal' as cargo_research_status,
       g.proposed_category as database_proposed_category,
       g.final_category as database_final_category,
       coalesce(ac.review_status,'NOT_STARTED') as access_review_status,
       coalesce(ac.game_admission_status,'NOT_APPROVED') as game_admission_status,
       (f.airport_key is not null) as military_name_review_flag,
       f.military_priority,
       civ.civilian_evidence_class,
       (a.source_type='OURAIRPORTS' and nullif(btrim(a.municipality),'') is null) as municipality_not_reported,
       (a.source_type='OURAIRPORTS' and nullif(btrim(a.source_gps_code),'') is null) as gps_code_not_reported,
       (ac.airport_key is null) as access_review_not_started,
       (g.airport_key is null) as classification_review_not_started,
       array_remove(array[
         case when ac.airport_key is null then 'ACCESS_REVIEW_NOT_STARTED' end,
         case when g.airport_key is null then 'CLASSIFICATION_REVIEW_NOT_STARTED' end,
         case when a.source_type='OURAIRPORTS' and nullif(btrim(a.municipality),'') is null then 'MUNICIPALITY_NOT_REPORTED' end,
         case when f.airport_key is not null and civ.airport_key is null then 'MILITARY_NAME_FLAG_EVIDENCE_NEEDED' end,
         case when a.source_type='OURAIRPORTS' and nullif(btrim(a.source_gps_code),'') is null then 'GPS_NOT_REPORTED' end,
         case when g.final_category is null then 'FINAL_CATEGORY_NOT_APPROVED' end
       ]::text[],null) as outstanding_research_flags
from airlinerra.airport_registry a
left join airlinerra.airport_cohorts coh using(airport_key)
left join airlinerra.airport_access_reviews ac using(airport_key)
left join airlinerra.airport_game_profiles g using(airport_key)
left join classified c using(airport_key)
left join flagged f using(airport_key)
left join civil civ using(airport_key);
revoke all on airlinerra.airport_research_overview from public, anon, authenticated;
comment on view airlinerra.airport_research_overview is 'Private research overview; unknown identifiers and name-based military hints do not imply ineligibility. No gameplay activation.';
