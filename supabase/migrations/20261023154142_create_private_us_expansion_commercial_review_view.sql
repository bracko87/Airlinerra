
create or replace view airlinerra.airport_commercial_review_queue
with (security_invoker=true) as
select 
  v.airport_key, r.country_iso, r.airport_name, r.municipality,
  v.faa_state, v.faa_identifier,
  g.proposed_category as provisional_game_category,
  v.runway_length_m, v.runway_width_m, v.runway_surface, v.runway_condition,
  v.faa_ownership_type, v.faa_reported_use, v.faa_reported_airport_status,
  v.faa_match_status, v.research_priority, v.review_bucket, v.next_action,
  v.part139_certificate_status,
  v.scheduled_passenger_verification,
  v.small_aircraft_charter_verification,
  v.cargo_flight_verification,
  v.aircraft_compatibility_verification,
  v.game_admission_status,
  v.faa_source_date,v.faa_source_url,
  v.independent_review_at,v.operator_evidence_url
from airlinerra.airport_commercial_verification v
join airlinerra.airport_registry r using (airport_key)
left join airlinerra.airport_game_profiles g using (airport_key);
revoke all on airlinerra.airport_commercial_review_queue from public, anon, authenticated;
comment on view airlinerra.airport_commercial_review_queue is 'Private priority-ordered US airport commercial verification dataset. Sort by research_priority. No airport admitted for gameplay.';
