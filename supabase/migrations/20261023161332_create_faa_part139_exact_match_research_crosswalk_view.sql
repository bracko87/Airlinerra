create or replace view airlinerra.airport_part139_crosswalk
with (security_invoker=true) as
select
 v.airport_key,r.airport_name,r.municipality,r.country_iso,v.faa_state,v.faa_identifier,
 g.proposed_category as proposed_airlinerra_category,
 v.runway_length_m,v.runway_surface,v.runway_condition,
 v.part139_certificate_status,
 (s.source_row is not null) as on_2026_faa_part139_list,
 s.part139_class as faa_part139_class,
 s.arff_index,
 nullif(btrim(s.inactive_status),'') as faa_inactive_status,
 s.airport_name as faa_published_airport_name,
 s.associated_city as faa_published_city,
 case when s.source_row is null then 90
      when nullif(btrim(s.inactive_status),'') is not null then 80
      when s.part139_class='I' then 10
      when s.part139_class='II' then 20
      when s.part139_class='III' then 30
      when s.part139_class='IV' then 40
      else 70 end as part139_followup_priority,
 case
  when s.source_row is null then 'Not listed on the FAA 2026-09-03 Part 139 roster; do not infer airport closure or prohibition of small charter/cargo. Confirm applicable operator authorization separately.'
  when nullif(btrim(s.inactive_status),'') is not null then 'FAA row explicitly marked inactive: verify current certificate status, actual passenger operations and airport-specific restrictions before any game consideration.'
  when s.part139_class='I' then 'FAA class I listed. Check actual scheduled large/small carrier service and operational authorization; certification alone does not establish an active passenger route.'
  when s.part139_class='II' then 'FAA class II listed. Check actual scheduled small-carrier and unscheduled large-carrier service; large scheduled passenger service not authorized by this class.'
  when s.part139_class='III' then 'FAA class III listed. Check actual scheduled small-carrier service; not a large-carrier certificate.'
  when s.part139_class='IV' then 'FAA class IV listed for unscheduled large-carrier passenger operations. Do not infer scheduled airline service; small charter/cargo need separate checks.'
  else 'Unusual official FAA classification: verify manually.'
 end as part139_next_action,
 v.scheduled_passenger_verification,v.small_aircraft_charter_verification,
 v.cargo_flight_verification,v.game_admission_status,
 date '2026-09-03' as official_roster_effective_date,
 'https://www.faa.gov/sites/faa.gov/files/arp-aas-part139-cert-status-table-2026-09-03.xlsx' as official_source_url,
 s.source_row as faa_source_row
from airlinerra.airport_commercial_verification v
join airlinerra.airport_registry r using (airport_key)
left join airlinerra.airport_game_profiles g using(airport_key)
left join airlinerra.faa_part139_source_rows s
  on s.effective_date='2026-09-03' and s.state=v.faa_state and s.faa_identifier=v.faa_identifier;
revoke all on airlinerra.airport_part139_crosswalk from public,anon,authenticated;
comment on view airlinerra.airport_part139_crosswalk is
 'Private 2026-09-03 FAA Part 139 exact-code and state crosswalk for 1,929 expansion airports. Part 139 classes I-IV differ from six Airlinerra game categories; unlisted is NOT commercially prohibited.';
