-- AIRLINERRA used aircraft auction v1 - MARKET CONTENT STAGED.
-- No real auction bids or payments unless world and server-controlled market gate are live.
-- Source aircraft are GAME-GENERATED fictional listings, not actual airframes for sale.
CREATE TABLE airlinerra_game.aircraft_market_control_v1 (
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 release_state text NOT NULL DEFAULT 'disabled' CHECK(release_state IN ('disabled','live')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO airlinerra_game.aircraft_market_control_v1(world_id,release_state)
 VALUES(1,'disabled') ON CONFLICT DO NOTHING;

CREATE TABLE airlinerra_game.used_aircraft_auction_lots_v1 (
 listing_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 offering_type text NOT NULL CHECK(offering_type IN ('purchase','lease')),
 manufacture_year smallint NOT NULL CHECK(manufacture_year BETWEEN 1930 AND 2100),
 condition_pct numeric(5,2) NOT NULL CHECK(condition_pct BETWEEN 25 AND 100),
 next_c_check_in_hours numeric(10,2) NOT NULL CHECK(next_c_check_in_hours BETWEEN 0 AND 5500),
 provisional_new_value_usd numeric(14,2) NOT NULL CHECK(provisional_new_value_usd>=100000),
 opening_bid_usd numeric(14,2) NOT NULL CHECK(opening_bid_usd>=100),
 min_bid_increment_usd numeric(14,2) NOT NULL CHECK(min_bid_increment_usd>=10),
 fixed_lease_deposit_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(fixed_lease_deposit_usd>=0),
 lease_months smallint CHECK(lease_months BETWEEN 1 AND 120),
 status text NOT NULL DEFAULT 'available'
  CHECK(status IN ('available','bidding','awarded','withdrawn')),
 highest_bid_usd numeric(14,2),
 highest_bid_airline_id uuid REFERENCES airlinerra_game.airlines(id),
 highest_bid_player_id uuid,
 highest_registration text,
 last_bid_utc timestamptz,
 close_after_utc timestamptz,
 bid_count integer NOT NULL DEFAULT 0 CHECK(bid_count>=0),
 winning_bid_id uuid,
 awarded_airline_id uuid REFERENCES airlinerra_game.airlines(id),
 awarded_inventory_id uuid REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 awarded_at_utc timestamptz,
 price_basis text NOT NULL DEFAULT 'game_estimate_weight_age_condition_next_c_check_v1',
 source_kind text NOT NULL DEFAULT 'fictional_game_generated_used_airframe',
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK((offering_type='purchase' AND fixed_lease_deposit_usd=0 AND lease_months IS NULL)
   OR (offering_type='lease' AND fixed_lease_deposit_usd>0 AND lease_months IS NOT NULL)),
 CHECK((status='available' AND highest_bid_usd IS NULL AND highest_bid_airline_id IS NULL
 AND highest_registration IS NULL AND last_bid_utc IS NULL AND close_after_utc IS NULL
 AND winning_bid_id IS NULL AND awarded_at_utc IS NULL)
 OR (status='bidding' AND highest_bid_usd IS NOT NULL AND
 highest_bid_airline_id IS NOT NULL AND highest_registration IS NOT NULL
 AND close_after_utc IS NOT NULL AND last_bid_utc IS NOT NULL AND
 winning_bid_id IS NOT NULL AND awarded_at_utc IS NULL)
 OR (status='awarded' AND winning_bid_id IS NOT NULL AND awarded_at_utc IS NOT NULL
 AND awarded_airline_id IS NOT NULL AND awarded_inventory_id IS NOT NULL)
 OR (status='withdrawn'))
);
CREATE INDEX used_aircraft_market_visible_idx ON airlinerra_game.used_aircraft_auction_lots_v1
 (world_id,status,configuration_id,created_at DESC);
CREATE INDEX used_aircraft_market_deadline_idx ON airlinerra_game.used_aircraft_auction_lots_v1
 (close_after_utc) WHERE status='bidding';
CREATE UNIQUE INDEX used_aircraft_market_reserved_registration_v1
 ON airlinerra_game.used_aircraft_auction_lots_v1(upper(highest_registration))
 WHERE status='bidding';
CREATE UNIQUE INDEX used_aircraft_market_awarded_inventory_v1
 ON airlinerra_game.used_aircraft_auction_lots_v1(awarded_inventory_id)
 WHERE awarded_inventory_id IS NOT NULL;

CREATE TABLE airlinerra_game.used_aircraft_auction_bids_v1 (
 bid_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 listing_id uuid NOT NULL REFERENCES airlinerra_game.used_aircraft_auction_lots_v1(listing_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 player_id uuid NOT NULL,
 request_id uuid NOT NULL,
 registration text NOT NULL CHECK(registration~'^[A-Z0-9][A-Z0-9-]{2,18}[A-Z0-9]$'),
 bid_usd numeric(14,2) NOT NULL CHECK(bid_usd>=100),
 held_usd numeric(14,2) NOT NULL CHECK(held_usd>0),
 hold_status text NOT NULL DEFAULT 'held' CHECK(hold_status IN ('held','refunded','settled')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(airline_id,request_id)
);
CREATE INDEX used_aircraft_bids_listing_idx ON airlinerra_game.used_aircraft_auction_bids_v1
 (listing_id,created_at DESC);

-- Separate financial event kinds make auction holds and refunds auditable.
ALTER TABLE airlinerra_game.airline_ledger DROP CONSTRAINT IF EXISTS valid_entry_kind;
ALTER TABLE airlinerra_game.airline_ledger ADD CONSTRAINT valid_entry_kind CHECK(
 entry_kind IN('STARTING_CAPITAL','AIRCRAFT_PURCHASE','AIRCRAFT_LEASE',
 'REVENUE','EXPENSE','ADJUSTMENT','AIRCRAFT_AUCTION_HOLD','AIRCRAFT_AUCTION_REFUND'));

-- Seed *new production* offers using currently usable, non-experimental models.
-- Manufacturer prices are modelled game estimates; not official list prices.
INSERT INTO airlinerra_game.aircraft_acquisition_offers_v1
 (world_id,configuration_id,transaction_type,upfront_price_usd,recurring_monthly_usd,
 contract_months,delivery_days,offer_status,pricing_basis)
SELECT 1,c.configuration_id,v.transaction_type,
 CASE WHEN v.transaction_type='purchase' THEN p.price_usd
 ELSE greatest(1000,round((p.price_usd*.0065*2)/1000)*1000) END,
 CASE WHEN v.transaction_type='lease' THEN greatest(500,round((p.price_usd*.0065)/1000)*1000) ELSE 0 END,
 CASE WHEN v.transaction_type='lease' THEN 60 ELSE NULL END,
 CASE WHEN c.mtow_kg>=160000 THEN 300 WHEN c.mtow_kg>=80000 THEN 220
 WHEN c.mtow_kg>=30000 THEN 180 ELSE 120 END,
 'published','AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'
FROM airlinerra.aircraft_catalog_configuration_inventory c
CROSS JOIN (VALUES ('purchase'),('lease')) v(transaction_type)
CROSS JOIN LATERAL
 (SELECT round((4200000+55000000*power(c.mtow_kg::numeric/78000,.85))/10000)*10000 AS price_usd)p
WHERE c.production_status='in_production'
 AND c.model_catalog_status='service_verified' AND c.civilian_service_status='active'
 AND c.mtow_kg>0 AND c.production_start_year<=extract(year from now())
 AND (c.production_end_year IS NULL OR c.production_end_year>=extract(year from now()))
 AND NOT EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 g
    WHERE g.configuration_id=c.configuration_id)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_acquisition_offers_v1 old
  WHERE old.configuration_id=c.configuration_id AND old.transaction_type=v.transaction_type
   AND old.pricing_basis='AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2');

-- Remove legacy fixed-price used deals from public sale. Existing orders remain intact.
UPDATE airlinerra_game.aircraft_acquisition_offers_v1
 SET offer_status='retired',updated_at=now()
 WHERE offer_status='published'
 AND pricing_basis='AIRLINERRA_GAME_BALANCE_V1:reference_used_airframe_no_tail_claim';

-- Seed 2 purchase + 1 lease per eligible used configuration. These are individually
-- fictional game stocks, not 3 sales of a real airframe. Unsold lots do not expire.
WITH model AS (
 SELECT c.configuration_id,c.production_start_year,
  least(coalesce(c.production_end_year,extract(year from now())::int),
   extract(year from now())::int) last_year,c.mtow_kg,
  c.family_name,c.model_name,mg.group_id,g.c_usd
 FROM airlinerra.aircraft_catalog_configuration_inventory c
 JOIN airlinerra_game.maintenance_model_group_v1 mg USING(configuration_id)
 JOIN airlinerra_game.maintenance_cost_groups_v1 g USING(group_id)
 WHERE c.model_catalog_status='service_verified'
  AND c.civilian_service_status='active'
  AND c.production_start_year IS NOT NULL
  AND c.production_start_year<=extract(year from now())::int
  AND c.mtow_kg>0
  AND NOT EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 x
    WHERE x.configuration_id=c.configuration_id)
),frames AS (
 SELECT m.*,s.seq,s.offering_type,
  greatest(m.production_start_year,least(m.last_year,
   extract(year from now())::int-(7+mod((m.configuration_id+s.seq)::int,24))))::smallint AS build_year,
  (76+mod((m.configuration_id*3+s.seq*13)::int,22))::numeric(5,2) AS cond,
  (180+mod((m.configuration_id*53+s.seq*101)::int,4700))::numeric(10,2) as c_remaining
 FROM model m CROSS JOIN (VALUES(1,'purchase'),(2,'purchase'),(3,'lease')) s(seq,offering_type)
 WHERE m.production_start_year<=m.last_year
),valued AS (
 SELECT f.*,
 round((4200000+55000000*power(f.mtow_kg::numeric/78000,.85))/10000)*10000 as new_usd
 FROM frames f
),offer_prices AS (
 SELECT v.*,
 greatest(100000::numeric,round(
  (v.new_usd*(.10+.90*exp(-(extract(year from now())-v.build_year)/11.0))*
    (.70+v.cond*.003)
   - CASE WHEN v.c_remaining<500 THEN v.c_usd
          WHEN v.c_remaining<1100 THEN v.c_usd*.5 ELSE v.c_usd*.15 END)
 /1000)*1000) AS used_usd
 FROM valued v
)
INSERT INTO airlinerra_game.used_aircraft_auction_lots_v1
 (world_id,configuration_id,offering_type,manufacture_year,condition_pct,
 next_c_check_in_hours,provisional_new_value_usd,opening_bid_usd,min_bid_increment_usd,
 fixed_lease_deposit_usd,lease_months)
SELECT 1,configuration_id,offering_type,build_year,cond,c_remaining,new_usd,
 CASE WHEN offering_type='purchase' THEN used_usd
 ELSE greatest(500,round(used_usd*.0105/100)*100) END,
 CASE WHEN offering_type='purchase' THEN greatest(1000,round(used_usd*.01/100)*100)
 ELSE greatest(50,round(used_usd*.000105/10)*10) END,
 CASE WHEN offering_type='lease' THEN greatest(1000,round(used_usd*.0105*2/100)*100) ELSE 0 END,
 CASE WHEN offering_type='lease' THEN 36 ELSE NULL END
FROM offer_prices v
WHERE NOT EXISTS(
 SELECT 1 FROM airlinerra_game.used_aircraft_auction_lots_v1 existing
 WHERE existing.configuration_id=v.configuration_id AND existing.source_kind='fictional_game_generated_used_airframe'
);

ALTER TABLE airlinerra_game.aircraft_market_control_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.used_aircraft_auction_lots_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.used_aircraft_auction_bids_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_market_control_v1,
 airlinerra_game.used_aircraft_auction_lots_v1,
 airlinerra_game.used_aircraft_auction_bids_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.used_aircraft_auction_lots_v1 IS
 'Game-generated used-market lot. Offer exists until first valid bid; then rolling 15-minute auction. RELEASE DISABLED until separate verified auction engine is enabled.';
