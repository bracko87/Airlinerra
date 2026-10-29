-- World 1: review the 16 absent ICAO codes without inventing allocations.
-- Source/local IDs MUST NOT be promoted into ICAO until verified in a
-- nationally authoritative location-indicator source or ICAO Doc 7910.
create table if not exists airlinerra_game.airport_identifier_resolution (
  world_id smallint not null,
  airport_key text not null,
  identifier_system text not null
    check (identifier_system in ('ICAO','IATA','GPS','LOCAL')),
  proposed_identifier text,
  proposal_kind text not null
    check (proposal_kind in ('possible_icao','faa_or_local_identifier',
     'national_location_identifier','historic_assignment',
     'reassigned_elsewhere','owner_fictional_identifier','none_identified')),
  resolution_status text not null
    check (resolution_status in ('candidate_review','local_only_reported',
      'historical_do_not_reuse','reassigned_do_not_reuse',
      'fictional_not_official','missing_research_required',
      'authority_verified_assigned','authority_verified_unassigned')),
  explanation text not null,
  source_urls jsonb not null default '[]'::jsonb
    check (jsonb_typeof(source_urls)='array'),
  checked_on date not null default current_date,
  authority_verified_on date,
  source_authority text,
  approved_for_icao_profile boolean not null default false,
  primary key(world_id,airport_key,identifier_system),
  foreign key (world_id,airport_key)
    references airlinerra_game.airport_reference_profiles(world_id,airport_key)
    on delete restrict,
  check (approved_for_icao_profile=false or (
    identifier_system='ICAO' and resolution_status='authority_verified_assigned'
    and authority_verified_on is not null and source_authority is not null
    and proposed_identifier ~ '^[A-Z]{4}$')),
  check (resolution_status not in ('authority_verified_assigned','authority_verified_unassigned')
         or (authority_verified_on is not null and source_authority is not null))
);
alter table airlinerra_game.airport_identifier_resolution enable row level security;
revoke all on airlinerra_game.airport_identifier_resolution from PUBLIC,anon,authenticated;
create index if not exists airport_identifier_resolution_status_idx
 on airlinerra_game.airport_identifier_resolution(world_id,identifier_system,resolution_status);
