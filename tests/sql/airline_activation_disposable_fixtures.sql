-- Disposable PostgreSQL only. Never run against the real Airlinerra project.
-- Operators explicitly opt IN the test account/world/airport setup here.
insert into auth.users (id,email_confirmed_at,banned_until) values
  ('11111111-1111-4111-8111-111111111111',now(),null),
  ('22222222-2222-4222-8222-222222222222',now(),null),
  ('33333333-3333-4333-8333-333333333333',now(),null),
  ('44444444-4444-4444-8444-444444444444',now(),now()+interval '3 days'),
  ('55555555-5555-4555-8555-555555555555',now(),null),
  ('66666666-6666-4666-8666-666666666666',now(),null);

insert into airlinerra_game.legal_release_policy
  (id,terms_version,privacy_version,is_published,approved_at)
values (true,'test-v1','test-v1',true,now());

insert into airlinerra_game.account_consents
  (player_id,terms_version,privacy_version)
select id,'test-v1','test-v1' from auth.users
 where id <> '66666666-6666-4666-8666-666666666666';

-- Additional negative-test accounts are created *after* consent setup:
-- they deliberately have no legal acceptance record.
insert into auth.users (id,email_confirmed_at,is_anonymous,deleted_at)
values
  ('77777777-7777-4777-8777-777777777777',null,false,null),
  ('88888888-8888-4888-8888-888888888888',now(),true,null),
  ('99999999-9999-4999-8999-999999999999',now(),false,now());

update public.airlinerra_game_worlds
  set state='registration_open'
where id in (1,2);

insert into airlinerra_game.approved_game_airports
  (world_id,source_airport_id,approval_reference)
values (1,101,'ISOLATED-TEST-ONLY'),
       (2,202,'ISOLATED-TEST-ONLY');

-- Synthetic expired trial, paid-without-trial, suspended membership.
insert into airlinerra_game.account_entitlements
  (player_id,trial_started_at,trial_ends_at,membership_state)
values
  ('22222222-2222-4222-8222-222222222222',
    '2026-10-01T00:00:00Z','2026-10-08T00:00:00Z','expired'),
  ('33333333-3333-4333-8333-333333333333',
    null,null,'active');

insert into airlinerra_game.world_memberships
  (world_id,player_id,state)
values (1,'55555555-5555-4555-8555-555555555555','suspended');

update airlinerra_game.platform_release_gate
  set enabled=true,changed_at=now()
where id=true;
