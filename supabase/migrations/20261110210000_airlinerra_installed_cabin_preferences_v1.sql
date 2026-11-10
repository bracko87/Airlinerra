-- Persist the REAL installed seat types and extra row pitch separately from drafts.
-- Safe additive migration: this does not install a draft or debit an airline.
ALTER TABLE airlinerra_game.aircraft_installed_cabins_v1
 ADD COLUMN IF NOT EXISTS installed_economy_type text NOT NULL DEFAULT 'eco_standard'
  REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 ADD COLUMN IF NOT EXISTS installed_premium_type text NOT NULL DEFAULT 'premium_standard'
  REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 ADD COLUMN IF NOT EXISTS installed_business_type text NOT NULL DEFAULT 'business_standard'
  REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 ADD COLUMN IF NOT EXISTS installed_first_type text NOT NULL DEFAULT 'first_standard'
  REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 ADD COLUMN IF NOT EXISTS installed_extra_legroom_cm numeric(4,1) NOT NULL DEFAULT 0
  CHECK(installed_extra_legroom_cm BETWEEN 0 AND 20);

-- Private server read model. Security invoker + revoked API grants ensure
-- this is not a player-controlled or publicly queryable comfort claim.
-- Model estimates use precisely the same formula as cabin-configuration-manager.
CREATE OR REPLACE VIEW airlinerra_game.section9_installed_cabin_comfort_v1
 WITH (security_invoker=true) AS
SELECT
 i.aircraft_inventory_id,
 i.airline_id,
 i.configuration_id,
 i.installed_source,
 i.installed_extra_legroom_cm AS extra_legroom_cm,
 (i.installed_economy+i.installed_premium+i.installed_business+i.installed_first)::integer AS installed_seats,
 round(
  (
   i.installed_economy * greatest(15::numeric,least(96::numeric,49+(e.equivalent_economy_units-1)*3+i.installed_extra_legroom_cm*1.35))+
   i.installed_premium * greatest(15::numeric,least(96::numeric,61+(p.equivalent_economy_units-1)*3+i.installed_extra_legroom_cm*1.35))+
   i.installed_business * greatest(15::numeric,least(96::numeric,72+(b.equivalent_economy_units-1)*3+i.installed_extra_legroom_cm*1.35))+
   i.installed_first * greatest(15::numeric,least(96::numeric,80+(f.equivalent_economy_units-1)*3+i.installed_extra_legroom_cm*1.35))
  )/nullif(i.installed_economy+i.installed_premium+i.installed_business+i.installed_first,0)
 )::integer AS comfort_rating,
 'server_verified_installed_v1'::text AS evidence_kind
FROM airlinerra_game.aircraft_installed_cabins_v1 i
JOIN airlinerra_game.airline_aircraft_inventory frame
 ON frame.id=i.aircraft_inventory_id AND frame.airline_id=i.airline_id
 AND frame.configuration_id=i.configuration_id
JOIN airlinerra_game.cabin_model_standard_v1 model ON model.configuration_id=i.configuration_id
JOIN airlinerra_game.cabin_seat_types_v1 e
 ON e.seat_code=i.installed_economy_type AND e.cabin_class='economy'
JOIN airlinerra_game.cabin_seat_types_v1 p
 ON p.seat_code=i.installed_premium_type AND p.cabin_class='premium'
JOIN airlinerra_game.cabin_seat_types_v1 b
 ON b.seat_code=i.installed_business_type AND b.cabin_class='business'
JOIN airlinerra_game.cabin_seat_types_v1 f
 ON f.seat_code=i.installed_first_type AND f.cabin_class='first'
WHERE i.installed_economy+i.installed_premium+i.installed_business+i.installed_first>0
 AND (
 i.installed_economy*e.equivalent_economy_units*(1+i.installed_extra_legroom_cm/(e.seat_pitch_inches*2.54))+
 i.installed_premium*p.equivalent_economy_units*(1+i.installed_extra_legroom_cm/(p.seat_pitch_inches*2.54))+
 i.installed_business*b.equivalent_economy_units*(1+i.installed_extra_legroom_cm/(b.seat_pitch_inches*2.54))+
 i.installed_first*f.equivalent_economy_units*(1+i.installed_extra_legroom_cm/(f.seat_pitch_inches*2.54))
 )<=model.reference_seat_units+0.00000001;

REVOKE ALL ON airlinerra_game.section9_installed_cabin_comfort_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.section9_installed_cabin_comfort_v1 IS
 'Server-only preference source: valid installed cabin layout, never drafts. Game-estimate comfort; no direct booking or financial settlement.';
