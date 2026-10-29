-- Add independently attributable *candidate* fields; do not set verified time zone.
alter table airlinerra_game.airport_reference_profiles
 add column if not exists timezone_candidate_iana text,
 add column if not exists timezone_candidate_source text,
 add column if not exists timezone_candidate_checked_on date,
 add column if not exists elevation_source text,
 add column if not exists elevation_verification text not null default 'not_reported'
   check (elevation_verification in ('not_reported','source_reported_unverified','verified'));
comment on column airlinerra_game.airport_reference_profiles.timezone_candidate_iana is
 'IANA tz identifier candidate matched against independent code/country/geolocation source. Not certified for flight scheduling.';
comment on column airlinerra_game.airport_reference_profiles.elevation_ft is
 'Feet above mean sea level as SOURCE REPORTED, subject to elevation_verification field; not an aeronautical altitude clearance.';
create index if not exists airport_reference_time_zone_candidate_idx
 on airlinerra_game.airport_reference_profiles(world_id,timezone_candidate_iana)
 where timezone_candidate_iana is not null;
