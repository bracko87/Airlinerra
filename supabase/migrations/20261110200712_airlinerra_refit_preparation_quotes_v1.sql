-- Stage 1 of trusted cabin refits: immutable, owner-scoped preparation only.
-- NO installed-seat updates, money movement, grounding, flight dispatch or cron.
-- IMPORTANT: a prepared quote IS NOT an appointment, contract or live refit.
CREATE TABLE airlinerra_game.cabin_refit_prepared_quotes_v1 (
 quote_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK (world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL
  REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 request_id uuid NOT NULL,
 airport_key text NOT NULL,
 provider_key text NOT NULL,
 draft_updated_at timestamptz NOT NULL,
 cabin_snapshot jsonb NOT NULL CHECK (jsonb_typeof(cabin_snapshot)='object'),
 equipment_usd numeric(14,2) NOT NULL CHECK (equipment_usd>=0),
 installation_usd numeric(14,2) NOT NULL CHECK (installation_usd>0),
 total_usd numeric(14,2) NOT NULL CHECK (total_usd=equipment_usd+installation_usd),
 estimated_downtime_hours smallint NOT NULL CHECK (estimated_downtime_hours IN (24,48)),
 status text NOT NULL DEFAULT 'prepared_not_booked'
  CHECK (status='prepared_not_booked'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE (airline_id,request_id),
 FOREIGN KEY (world_id,airport_key,provider_key)
  REFERENCES airlinerra_game.maintenance_facility_locations_v1(world_id,airport_key,provider_key)
);
CREATE INDEX cabin_refit_quote_aircraft_idx
 ON airlinerra_game.cabin_refit_prepared_quotes_v1(aircraft_inventory_id,created_at DESC);
ALTER TABLE airlinerra_game.cabin_refit_prepared_quotes_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.cabin_refit_prepared_quotes_v1
 FROM PUBLIC,anon,authenticated;

-- Invoked ONLY through the protected backend after token verification.
-- An ordinary authenticated browser cannot invoke it or write this table.
CREATE FUNCTION airlinerra_game.prepare_owned_cabin_refit_quote_v1(
 p_player_id uuid, p_airline_id uuid,p_aircraft_inventory_id uuid,
 p_airport_key text,p_provider_key text,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $fn$
DECLARE
 v_airframe record; v_draft record; v_site record;
 v_e record;v_p record;v_b record;v_f record;
 v_installed integer; v_count integer;v_used numeric;
 v_equipment numeric(14,2);v_labor numeric(14,2);
 v_total numeric(14,2);v_hours smallint;
 v_snapshot jsonb; v_quote record;
BEGIN
 IF p_player_id IS NULL OR p_airline_id IS NULL
 OR p_aircraft_inventory_id IS NULL OR p_request_id IS NULL
 OR p_airport_key IS NULL OR length(p_airport_key)>100
 OR length(p_airport_key)<2 OR p_provider_key IS NULL
 OR length(p_provider_key)>100 OR length(p_provider_key)<2
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='INVALID_CABIN_REFIT_QUOTE_REQUEST'; END IF;
 SELECT i.id,i.configuration_id,s.reference_seat_units,s.use_type
 INTO v_airframe FROM airlinerra_game.airline_aircraft_inventory i
 JOIN airlinerra_game.cabin_model_standard_v1 s
  ON s.configuration_id=i.configuration_id
 JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.world_id=1
 JOIN airlinerra_game.world_memberships w ON w.world_id=1
  AND w.player_id=a.owner_player_id AND w.state='active'
 WHERE i.id=p_aircraft_inventory_id AND i.airline_id=p_airline_id
  AND a.owner_player_id=p_player_id
 FOR SHARE OF i;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='CABIN_REFIT_AIRCRAFT_NOT_OWNED'; END IF;
 IF v_airframe.use_type='cargo' OR v_airframe.reference_seat_units<=0 THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='CABIN_REFIT_NOT_PASSENGER_AIRCRAFT';
 END IF;
 SELECT r.airport_key,r.provider_key,f.game_cost_multiplier
 INTO v_site FROM airlinerra_game.cabin_refit_facility_types_v1 r
 JOIN airlinerra_game.maintenance_facility_locations_v1 f
  ON f.world_id=r.world_id AND f.airport_key=r.airport_key
  AND f.provider_key=r.provider_key
 WHERE r.world_id=1 AND r.configuration_id=v_airframe.configuration_id
  AND r.airport_key=p_airport_key AND r.provider_key=p_provider_key
  AND r.planning_status='game_planning_approved';
 IF NOT FOUND OR v_site.game_cost_multiplier IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='CABIN_REFIT_PROVIDER_NOT_APPROVED_FOR_MODEL';
 END IF;
 SELECT * INTO v_draft FROM airlinerra_game.aircraft_cabin_drafts_v1
 WHERE aircraft_inventory_id=p_aircraft_inventory_id
  AND airline_id=p_airline_id AND planning_status='draft'
 FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',
 MESSAGE='CABIN_REFIT_SAVE_DESIGN_FIRST'; END IF;
 SELECT * INTO v_e FROM airlinerra_game.cabin_seat_types_v1
  WHERE seat_code=v_draft.economy_type AND cabin_class='economy';
 SELECT * INTO v_p FROM airlinerra_game.cabin_seat_types_v1
  WHERE seat_code=v_draft.premium_type AND cabin_class='premium';
 SELECT * INTO v_b FROM airlinerra_game.cabin_seat_types_v1
  WHERE seat_code=v_draft.business_type AND cabin_class='business';
 SELECT * INTO v_f FROM airlinerra_game.cabin_seat_types_v1
  WHERE seat_code=v_draft.first_type AND cabin_class='first';
 IF v_e.seat_code IS NULL OR v_p.seat_code IS NULL
  OR v_b.seat_code IS NULL OR v_f.seat_code IS NULL
  OR least(v_e.seat_pitch_inches,v_p.seat_pitch_inches,
   v_b.seat_pitch_inches,v_f.seat_pitch_inches)<=0
  OR v_draft.extra_legroom_cm<0 OR v_draft.extra_legroom_cm>20
 THEN RAISE EXCEPTION USING ERRCODE='P0001',
  MESSAGE='CABIN_REFIT_INVALID_SEAT_SELECTION'; END IF;
 v_count:=v_draft.economy_seats+v_draft.premium_seats+
  v_draft.business_seats+v_draft.first_seats;
 IF v_count<1 OR v_count>850 THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='CABIN_REFIT_INVALID_SEAT_COUNT';
 END IF;
 v_used:=v_draft.economy_seats*v_e.equivalent_economy_units*
  (1+v_draft.extra_legroom_cm/(v_e.seat_pitch_inches*2.54))+
  v_draft.premium_seats*v_p.equivalent_economy_units*
  (1+v_draft.extra_legroom_cm/(v_p.seat_pitch_inches*2.54))+
  v_draft.business_seats*v_b.equivalent_economy_units*
  (1+v_draft.extra_legroom_cm/(v_b.seat_pitch_inches*2.54))+
  v_draft.first_seats*v_f.equivalent_economy_units*
  (1+v_draft.extra_legroom_cm/(v_f.seat_pitch_inches*2.54));
 IF v_used>v_airframe.reference_seat_units+0.00000001 THEN
  RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='CABIN_REFIT_LAYOUT_EXCEEDS_SPACE'; END IF;
 SELECT (installed_economy+installed_premium+installed_business+installed_first)
 INTO v_installed FROM airlinerra_game.aircraft_installed_cabins_v1
 WHERE airline_id=p_airline_id AND aircraft_inventory_id=p_aircraft_inventory_id;
 IF v_installed IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='CABIN_REFIT_INSTALLED_LAYOUT_NOT_FOUND'; END IF;
 v_equipment:=(v_draft.economy_seats*v_e.indicative_install_usd+
  v_draft.premium_seats*v_p.indicative_install_usd+
  v_draft.business_seats*v_b.indicative_install_usd+
  v_draft.first_seats*v_f.indicative_install_usd)::numeric(14,2);
 v_labor:=round((5000+v_count*150+v_installed*75)*v_site.game_cost_multiplier,0);
 v_total:=v_equipment+v_labor;
 v_hours:=CASE WHEN v_draft.premium_seats+v_draft.business_seats+
  v_draft.first_seats>0 THEN 48 ELSE 24 END;
 v_snapshot:=jsonb_build_object(
  'economy',v_draft.economy_seats,'premium',v_draft.premium_seats,
  'business',v_draft.business_seats,'first',v_draft.first_seats,
  'economyType',v_draft.economy_type,'premiumType',v_draft.premium_type,
  'businessType',v_draft.business_type,'firstType',v_draft.first_type,
  'extraLegroomCm',v_draft.extra_legroom_cm,
  'configurationId',v_airframe.configuration_id);
 INSERT INTO airlinerra_game.cabin_refit_prepared_quotes_v1 (
  airline_id,aircraft_inventory_id,request_id,airport_key,provider_key,
  draft_updated_at,cabin_snapshot,equipment_usd,installation_usd,
  total_usd,estimated_downtime_hours)
 VALUES(p_airline_id,p_aircraft_inventory_id,p_request_id,p_airport_key,
  p_provider_key,v_draft.updated_at,v_snapshot,v_equipment,v_labor,
  v_total,v_hours)
 ON CONFLICT(airline_id,request_id) DO NOTHING RETURNING * INTO v_quote;
 IF NOT FOUND THEN
  SELECT * INTO v_quote FROM airlinerra_game.cabin_refit_prepared_quotes_v1
  WHERE airline_id=p_airline_id AND request_id=p_request_id;
  IF NOT FOUND OR v_quote.aircraft_inventory_id<>p_aircraft_inventory_id
   OR v_quote.airport_key<>p_airport_key
   OR v_quote.provider_key<>p_provider_key
   OR v_quote.cabin_snapshot<>v_snapshot OR v_quote.draft_updated_at<>v_draft.updated_at
  THEN RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='CABIN_REFIT_IDEMPOTENCY_KEY_REUSED'; END IF;
 END IF;
 RETURN jsonb_build_object(
  'status','prepared_not_booked','quoteId',v_quote.quote_id,
  'airlineId',p_airline_id,'aircraftInventoryId',p_aircraft_inventory_id,
  'airportKey',p_airport_key,'providerKey',p_provider_key,
  'equipmentUsd',v_quote.equipment_usd::text,
  'removalInstallationUsd',v_quote.installation_usd::text,
  'estimatedTotalUsd',v_quote.total_usd::text,
  'estimatedDowntimeHours',v_quote.estimated_downtime_hours,
  'quotedDraftVersion',v_quote.draft_updated_at,
  'moneyCharged',false,'aircraftGrounded',false,
  'installedSeatsChanged',false,'appointmentBooked',false);
END;$fn$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.prepare_owned_cabin_refit_quote_v1(
 uuid,uuid,uuid,text,text,uuid) FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.cabin_refit_prepared_quotes_v1 IS
 'Immutable non-binding, provisional cabin refit quotes; never a charged/active refit.';
