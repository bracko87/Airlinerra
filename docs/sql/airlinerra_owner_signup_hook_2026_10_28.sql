-- Applied to the connected Airlinerra Supabase project 2026-10-28.
-- Enable ONLY as Supabase Auth > Hooks > Before User Created during
-- the owner-first production self-registration pilot. No invitation needed.
-- Operator-approved email list already exists in a protected private table.
grant usage on schema airlinerra_game to supabase_auth_admin;
grant select(email) on airlinerra_game.owner_premium_email_reservations to supabase_auth_admin;

create or replace function public.airlinerra_owner_signup_gate(event jsonb)
returns jsonb language plpgsql security invoker set search_path=''
as $gate$
declare v_email text;
begin
  v_email:=lower(btrim(coalesce(event->'user'->>'email','')));
  if v_email<>'' and exists(
    select 1 from airlinerra_game.owner_premium_email_reservations r
    where r.email=v_email
  ) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error',jsonb_build_object(
   'http_code',403,'message','Registration is not yet open for this account.'));
end;
$gate$;

revoke execute on function public.airlinerra_owner_signup_gate(jsonb)
  from public,anon,authenticated;
grant execute on function public.airlinerra_owner_signup_gate(jsonb)
  to supabase_auth_admin;
-- An owner signup RLS policy for supabase_auth_admin was applied in the
-- production migration. Never grant browser SELECT on this private table.
