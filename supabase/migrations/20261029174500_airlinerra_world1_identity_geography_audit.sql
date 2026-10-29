-- World 1: comprehensive per-airport, per-field Identity & Geography audit.
-- This is an auditable SOURCE REPORTING inventory, not independent verification.
-- Unknown is not No. Unreported IATA/ICAO codes may legitimately be unassigned.
create table if not exists airlinerra_game.airport_identity_geography_audit (
 world_id smallint not null,
 airport_key text not null,
 official_name_status text not null
   check (official_name_status in ('source_reported_unverified','official_verified')),
 code_statuses jsonb not null,
 municipality_status text not null,
 region_status text not null,
 country_status text not null,
 coordinates_status text not null,
 timezone_status text not null,
 elevation_status text not null,
 fields_not_reported text[] not null,
 fields_to_verify text[] not null,
 source_manifest text not null,
 audit_status text not null default 'source_audited'
   check (audit_status in ('source_audited','researching','reviewed')),
 audit_run_on date not null default current_date,
 reviewed_by text,
 reviewed_on date,
 primary key(world_id,airport_key),
 foreign key (world_id,airport_key) references
  airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict,
 check(audit_status<>'reviewed' or (reviewed_by is not null and reviewed_on is not null))
);
alter table airlinerra_game.airport_identity_geography_audit enable row level security;
revoke all on airlinerra_game.airport_identity_geography_audit from PUBLIC,anon,authenticated;
create index if not exists airport_identity_audit_status_idx
 on airlinerra_game.airport_identity_geography_audit(world_id,audit_status);
insert into airlinerra_game.airport_identity_geography_audit
(world_id,airport_key,official_name_status,code_statuses,municipality_status,region_status,
 country_status,coordinates_status,timezone_status,elevation_status,fields_not_reported,
 fields_to_verify,source_manifest)
select p.world_id,p.airport_key,'source_reported_unverified',
 jsonb_build_object(
  'game_catalog_code',case when nullif(btrim(p.catalog_code),'') is not null
     then 'source_reported_unverified' else 'not_reported' end,
  'source_ident',case when nullif(btrim(p.source_ident),'') is not null
     then 'source_reported_unverified' else 'not_reported' end,
  'icao',case when nullif(btrim(p.icao_reported),'') is not null
     then 'source_reported_unverified' else 'not_reported' end,
  'iata',case when nullif(btrim(p.iata_reported),'') is not null
     then 'source_reported_unverified' else 'not_reported' end,
  'gps',case when nullif(btrim(p.gps_reported),'') is not null
     then 'source_reported_unverified' else 'not_reported' end,
  'local',case when nullif(btrim(p.local_reported),'') is not null
     then 'source_reported_unverified' else 'not_reported' end
 ),
 case when nullif(btrim(p.municipality),'') is null then 'not_reported'
  else 'source_reported_unverified' end,
 case when nullif(btrim(p.region_iso),'') is null then 'not_reported'
  else 'source_reported_unverified' end,
 case when nullif(btrim(p.country_iso),'') is null then 'not_reported'
  else 'source_reported_unverified' end,
 case when p.latitude_deg is null or p.longitude_deg is null then
   case when p.airport_kind='fictional' then 'fictional_site_unassigned'
   else 'not_reported' end
  else 'source_reported_unverified' end,
 case when p.timezone_iana is null then 'not_reported'
  else 'source_reported_unverified' end,
 case when p.elevation_ft is null then 'not_reported'
  else 'source_reported_unverified' end,
 array_remove(array[
  case when nullif(btrim(p.catalog_code),'') is null then 'catalog_code' end,
  case when nullif(btrim(p.source_ident),'') is null then 'source_ident' end,
  case when nullif(btrim(p.icao_reported),'') is null then 'icao_not_reported' end,
  case when nullif(btrim(p.iata_reported),'') is null then 'iata_not_reported' end,
  case when nullif(btrim(p.gps_reported),'') is null then 'gps_not_reported' end,
  case when nullif(btrim(p.local_reported),'') is null then 'local_code_not_reported' end,
  case when nullif(btrim(p.municipality),'') is null then 'municipality' end,
  case when nullif(btrim(p.region_iso),'') is null then 'region' end,
  case when p.latitude_deg is null or p.longitude_deg is null then 'airport_coordinates' end,
  case when p.timezone_iana is null then 'iana_timezone' end,
  case when p.elevation_ft is null then 'elevation_ft' end,
  'official_name_verification'
 ]::text[],null),
 array_remove(array[
  'official_name',
  case when p.catalog_code is not null then 'catalog_code' end,
  case when p.icao_reported is not null then 'icao' end,
  case when p.iata_reported is not null then 'iata' end,
  case when p.gps_reported is not null then 'gps' end,
  case when p.municipality is not null then 'municipality' end,
  case when p.region_iso is not null then 'region' end,
  'country',
  case when p.latitude_deg is not null and p.longitude_deg is not null then 'coordinates' end
 ]::text[],null),
 'APPROVED_WORLD1_INTERNAL_DIRECTORY;OURAIRPORTS_IDENTITY_SNAPSHOT=11e4de2834aff6ab54c1f8fc89b8679ea3d08418'
from airlinerra_game.airport_reference_profiles p
where p.world_id=1
on conflict (world_id,airport_key) do nothing;
