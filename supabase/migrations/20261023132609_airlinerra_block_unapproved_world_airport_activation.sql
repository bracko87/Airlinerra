
create or replace function airlinerra.enforce_game_airport_activation()
returns trigger language plpgsql security invoker
set search_path = airlinerra, pg_temp
as $function$
begin
  if new.active and not exists (
    select 1 from airlinerra.airport_access_reviews a
    join airlinerra.airport_game_profiles p on p.airport_key = a.airport_key
    where a.airport_key = new.airport_key
      and a.game_admission_status = 'APPROVED_FOR_GAME'
      and a.owner_approved_at is not null
      and a.approved_by is not null
      and a.identity_status = 'VERIFIED'
      and a.paved_runway_status = 'VERIFIED'
      and a.civilian_access_status = 'VERIFIED'
      and a.commercial_permission_status = 'VERIFIED'
      and p.final_category is not null
      and p.category_approved_at is not null
  ) then
    raise exception 'Airlinerra airport is not approved for gameplay activation: %', new.airport_key;
  end if;
  return new;
end;
$function$;
drop trigger if exists enforce_game_airport_activation on airlinerra.airport_world_activation;
create trigger enforce_game_airport_activation
before insert or update of active,airport_key on airlinerra.airport_world_activation
for each row execute function airlinerra.enforce_game_airport_activation();
