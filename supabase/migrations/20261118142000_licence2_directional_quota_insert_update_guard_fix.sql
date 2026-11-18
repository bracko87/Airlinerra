-- Avoid referencing OLD in an INSERT trigger when checking a directional quota.
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_guard_directed_route_allocation_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare v_policy record; v_permit record; v_tier record; v_preview jsonb; v_used int;
begin
 if current_user is distinct from 'postgres' then
   raise exception using errcode='42501',message='LICENCE2_ROUTE_ALLOCATION_PRIVATE_ENGINE_ONLY';
 end if;
 if new.allocation_state='cancelled' then return new;end if;
 perform pg_catalog.pg_advisory_xact_lock(583733,
   pg_catalog.hashtext(new.airline_id::text||':'||new.market_code));
 select * into v_policy from airlinerra_game.licence2_market_policy_v1
 where market_code=new.market_code;
 if v_policy.issuance_enabled is distinct from true
 or v_policy.enforcement_enabled is distinct from true then
   raise exception using errcode='42501',message='LICENCE2_ROUTE_ALLOCATION_RELEASE_DISABLED';
 end if;
 select * into v_permit from airlinerra_game.licence2_airline_market_permits_v1
 where world_id=new.world_id and airline_id=new.airline_id
 and market_code=new.market_code for update;
 if not found or v_permit.status is distinct from 'approved' then
   raise exception using errcode='42501',message='LICENCE2_VALID_APPROVED_PERMIT_REQUIRED';
 end if;
 select * into v_tier from airlinerra_game.licence2_market_levels_v1
 where market_code=new.market_code and level=v_permit.level;
 if v_tier.quota_approved is distinct from true then
   raise exception using errcode='42501',message='LICENCE2_QUOTA_POLICY_NOT_APPROVED';
 end if;
 v_preview:=airlinerra_game.licence2_foreign_route_preview_v1(
 new.airline_id,new.origin_airport_key,new.destination_airport_key,new.market_code);
 if v_preview->>'decision' is distinct from 'L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK' then
   raise exception using errcode='42501',message='LICENCE2_FOREIGN_ROUTE_NOT_AUTHORIZED';
 end if;
 if tg_op='INSERT' then
   select count(*)::int into v_used
   from airlinerra_game.licence2_directed_route_allocations_v1 x
   where x.world_id=new.world_id and x.airline_id=new.airline_id
   and x.market_code=new.market_code and x.allocation_state in ('reserved','active');
 else
   select count(*)::int into v_used
   from airlinerra_game.licence2_directed_route_allocations_v1 x
   where x.world_id=new.world_id and x.airline_id=new.airline_id
   and x.market_code=new.market_code and x.allocation_state in ('reserved','active')
   and (x.origin_airport_key,x.destination_airport_key) is distinct from
    (old.origin_airport_key,old.destination_airport_key);
 end if;
 if v_tier.max_active_directed_routes is not null
 and v_used>=v_tier.max_active_directed_routes then
   raise exception using errcode='23514',message='LICENCE2_DIRECTED_ROUTE_QUOTA_FULL';
 end if;
 new.updated_at:=now();
 return new;
end $function$
;
