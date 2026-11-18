-- One-time verified original registration provenance staging. No certificate or fee.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_stage_verified_original_registry_v1(p_airline uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare a record; k record; n int;
begin
 if current_user is distinct from 'postgres' then
  raise exception using errcode='42501',message='AOC_ORIGINAL_REGISTRY_TRUSTED_ONLY';end if;
 select * into a from airlinerra_game.airlines
  where id=p_airline and world_id=1 for update;
 if not found then return jsonb_build_object('status','AIRLINE_NOT_FOUND',
  'identityStaged',false,'certificateIssued',false,'feeCharged',false);end if;
 if not exists (select 1 from airlinerra_game.world_memberships m
  where m.world_id=1 and m.player_id=a.owner_player_id and m.state='active')
 or (select count(*) from airlinerra_game.airlines other
  where other.world_id=1 and other.owner_player_id=a.owner_player_id)<>1
 or exists(select 1 from airlinerra_game.holding_groups_v1 h
  where h.world_id=1 and h.owner_player_id=a.owner_player_id
   and h.original_airline_id is distinct from p_airline)
 or exists(select 1 from airlinerra_game.section9_aoc_operating_companies_v1 other
  where other.airline_id=p_airline and other.company_source<>'original')
 then return jsonb_build_object('status','ORIGINAL_AIRLINE_OWNERSHIP_NOT_VERIFIED',
  'identityStaged',false,'certificateIssued',false,'feeCharged',false);end if;
 -- The one immutable game-funded original registration matches the airline
 -- creation time; no synthetic registration/backdating or assumed certificate.
 select count(*) into n from airlinerra_game.airline_ledger l
 where l.airline_id=p_airline and l.entry_kind='STARTING_CAPITAL'
  and l.amount_usd=5000000.00 and l.recorded_at=a.created_at;
 if n<>1 or (select count(*) from airlinerra_game.airline_ledger l
  where l.airline_id=p_airline and l.entry_kind='STARTING_CAPITAL')<>1
 then return jsonb_build_object('status','ORIGINAL_REGISTRATION_LEDGER_NOT_VERIFIED',
 'identityStaged',false,'certificateIssued',false,'feeCharged',false);end if;
 select * into k from airlinerra_game.section9_aoc_operating_companies_v1
  where airline_id=p_airline for update;
 if found then
  if k.company_source='original' and k.identity_evidence_reference=
  'verified-original-airline-registration-v1-'||p_airline::text
   and k.subsidiary_id is null and k.holding_id is null then
   return jsonb_build_object('status','ALREADY_STAGED','identityStaged',true,
   'certificateIssued',false,'feeCharged',false,'flightsActivated',false);
  end if;
  raise exception using errcode='42501',message='AOC_EXISTING_COMPANY_CLASSIFICATION_CONFLICT';
 end if;
 insert into airlinerra_game.section9_aoc_operating_companies_v1
  (airline_id,world_id,company_source,business_kind,identity_evidence_reference)
 values(p_airline,1,'original','passenger',
  'verified-original-airline-registration-v1-'||p_airline::text);
 return jsonb_build_object('status','ORIGINAL_IDENTITY_STAGED',
 'identityStaged',true,'certificateIssued',false,
 'feeCharged',false,'flightsActivated',false);
end $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_aoc_stage_verified_original_registry_v1(uuid) FROM public,anon,authenticated;
