-- Restrict Licence 5 to operator approval only; no shipment-class grant exists yet.
-- Remove a redundant preliminary scope function. Authoritative scope stays fail-closed
-- for every dangerous-goods shipment until a separate commodity permission is built.
DROP FUNCTION IF EXISTS airlinerra_game.licence5_dg_flight_scope_v1(uuid);
CREATE OR REPLACE FUNCTION airlinerra_game.licence5_dg_shipment_preflight_v1(
 p_airline uuid,p_dangerous_goods_class text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE base jsonb;
BEGIN
 base:=airlinerra_game.licence5_dg_operator_scope_v1(p_airline);
 RETURN jsonb_build_object(
 'status','DANGEROUS_GOODS_COMMODITY_AUTHORIZATION_NOT_RELEASED',
 'airlineId',p_airline,
 'operatorLicenceValid',base->'authorized',
 'dangerousGoodsClass',CASE WHEN p_dangerous_goods_class ~ '^([1-9]|[1-9]\.[1-9])$'
   THEN p_dangerous_goods_class ELSE NULL END,
 'dangerousGoodsShipmentAuthorized',false,
 'routeAuthorized',false,'flightActivated',false
 );
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence5_dg_shipment_preflight_v1(uuid,text)
 FROM PUBLIC,anon,authenticated,service_role;
DO $cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-licence5-dg-review-v1')
 THEN PERFORM cron.schedule('airlinerra-licence5-dg-review-v1','*/5 * * * *',
  'SELECT airlinerra_game.licence5_review_due_dg_game_applications_v1(25)');
 END IF;
END $cron$;