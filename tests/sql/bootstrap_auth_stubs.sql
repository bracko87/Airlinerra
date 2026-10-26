-- ONLY for the throwaway GitHub Actions PostgreSQL 17 database.
-- Minimal Supabase-compatible Auth objects required to compile the Airlinerra
-- SQL drafts. These are NOT a substitute for real Supabase Auth integration.
create role anon nologin;
create role authenticated nologin;
create schema auth;

create table auth.users (
  id uuid primary key,
  email_confirmed_at timestamptz,
  is_anonymous boolean not null default false,
  banned_until timestamptz,
  deleted_at timestamptz
);

create function auth.uid()
returns uuid language sql stable set search_path = ''
as $auth_stub$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$auth_stub$;

create function auth.jwt()
returns jsonb language sql stable set search_path = ''
as $auth_stub$
  select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb, '{}'::jsonb)
$auth_stub$;

grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
grant execute on function auth.jwt() to authenticated;
