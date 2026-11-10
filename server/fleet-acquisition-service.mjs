/** Secure World 1 aircraft purchase/lease market, server-side only.
 * Monetary price, airline ownership and registration checks live in PostgreSQL.
 * This service never activates live flights.
 */
export const FLEET_ACQUISITION_API_ROUTE='/api/v1/player/fleet-acquisition';
const ORIGIN='https://airlinerra.com';
const BEARER=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const REGISTRATION=/^[A-Z0-9][A-Z0-9-]{2,18}[A-Z0-9]$/u;
const HEADERS={'content-type':'application/json; charset=utf-8','cache-control':'no-store',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer'};
const respond=(status,value)=>Response.json(value,{status,headers:HEADERS});
const uuid=value=>typeof value==='string'&&UUID.test(value);
export function validateFleetAcquisitionRequest(body){
 if(!body||typeof body!=='object'||Array.isArray(body)||
    typeof body.action!=='string'||!uuid(body.airlineId))return false;
 if(body.action==='list')return Object.keys(body).length===2 &&
  Object.keys(body).every(k=>['action','airlineId'].includes(k));
 if(body.action==='list-used')return Object.keys(body).length>=5 &&
  Object.keys(body).every(k=>['action','airlineId','page','filterMode','search','manufacturer','family','model','configuration'].includes(k)) &&
  Number.isInteger(body.page)&&body.page>=0&&body.page<=1000 &&
  ['all','purchase','lease'].includes(body.filterMode)&&
  typeof body.search==='string'&&body.search.length<=60&&
  !/[\u0000-\u001F\u007F]/u.test(body.search)&&
  ['manufacturer','family','model','configuration'].every(k=>
    body[k]===undefined||(typeof body[k]==='string'&&body[k].length<=100&&
      !/[\u0000-\u001F\u007F]/u.test(body[k])));
 if(body.action==='bid-used')return Object.keys(body).length===6 &&
  Object.keys(body).every(k=>['action','airlineId','listingId','bidUsd','registration','requestId'].includes(k)) &&
  uuid(body.listingId)&&uuid(body.requestId)&&typeof body.bidUsd==='string' &&
  /^[1-9][0-9]{2,11}(?:\.[0-9]{1,2})?$/u.test(body.bidUsd) &&
  typeof body.registration==='string' &&
  REGISTRATION.test(body.registration.trim().toUpperCase());
 if(body.action==='cabin-overview')return Object.keys(body).length===2 &&
  Object.keys(body).every(k=>['action','airlineId'].includes(k));
 if(body.action==='cabin-save-draft')return Object.keys(body).length>=11 &&
  Object.keys(body).length<=12 &&
  Object.keys(body).every(k=>['action','airlineId','aircraftInventoryId',
   'economy','premium','business','first','economyType','premiumType','businessType','firstType','extraLegroomCm'].includes(k)) &&
  (body.extraLegroomCm===undefined||
   (typeof body.extraLegroomCm==='number'&&Number.isFinite(body.extraLegroomCm)&&
    body.extraLegroomCm>=0&&body.extraLegroomCm<=20&&
    Math.abs(body.extraLegroomCm*10-Math.round(body.extraLegroomCm*10))<1e-8)) &&
  uuid(body.aircraftInventoryId)&&
  ['economy','premium','business','first'].every(k=>
   Number.isInteger(body[k])&&body[k]>=0&&body[k]<=850) &&
  ['economyType','premiumType','businessType','firstType'].every(k=>
   typeof body[k]==='string'&&/^[a-z][a-z0-9_]{2,39}$/u.test(body[k])) &&
  body.economy+body.premium+body.business+body.first>0;
 if(body.action==='cabin-quote-status')return Object.keys(body).length===3 &&
  Object.keys(body).every(k=>['action','airlineId','aircraftInventoryId'].includes(k))&&
  uuid(body.aircraftInventoryId);
 if(body.action==='cabin-prepare-quote')return Object.keys(body).length===6 &&
  Object.keys(body).every(k=>['action','airlineId','aircraftInventoryId',
    'airportKey','providerKey','requestId'].includes(k)) &&
  uuid(body.aircraftInventoryId)&&uuid(body.requestId)&&
  typeof body.airportKey==='string'&&/^[A-Za-z0-9:_-]{2,100}$/u.test(body.airportKey)&&
  typeof body.providerKey==='string'&&/^[a-z0-9-]{2,100}$/u.test(body.providerKey);
 if(body.action==='maintenance-preview')return Object.keys(body).length===3 &&
  Object.keys(body).every(k=>['action','airlineId','aircraftInventoryId'].includes(k)) &&
  uuid(body.aircraftInventoryId);
 if(body.action==='check-delivery')return Object.keys(body).length===3 &&
  Object.keys(body).every(k=>['action','airlineId','orderId'].includes(k)) && uuid(body.orderId);
 if(body.action==='update-nickname')return Object.keys(body).length===4 &&
  Object.keys(body).every(k=>['action','airlineId','aircraftInventoryId','nickname'].includes(k)) &&
  uuid(body.aircraftInventoryId) && typeof body.nickname==='string' &&
  body.nickname.trim().length<=40 && !/[\u0000-\u001F\u007F]/u.test(body.nickname);
 if(body.action==='acquire')return Object.keys(body).length===5 &&
  Object.keys(body).every(k=>['action','airlineId','offerId','registration','requestId'].includes(k)) &&
  uuid(body.offerId)&&uuid(body.requestId)&&typeof body.registration==='string' &&
  REGISTRATION.test(body.registration.trim().toUpperCase());
 return false;
}
export const FLEET_SQL=Object.freeze({
 owner:"SELECT a.id,a.cash_usd::text AS \"cashUsd\" FROM airlinerra_game.airlines a "+
  "JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id "+
  "WHERE a.id=$1::uuid AND a.owner_player_id=$2::uuid AND a.world_id=1 AND w.state='active'",
 offers:"SELECT o.offer_id::text AS \"offerId\",o.configuration_id::int AS \"configurationId\", "+
  "o.transaction_type AS \"transactionType\",o.offer_status AS \"offerStatus\", "+
  "c.configuration_review_status AS \"configurationReviewStatus\", "+
  "o.upfront_price_usd::text AS \"upfrontPriceUsd\", "+
  "o.recurring_monthly_usd::text AS \"recurringMonthlyUsd\",o.contract_months AS \"contractMonths\", "+
  "o.delivery_days AS \"deliveryDays\",c.manufacturer_name AS manufacturer,c.model_name AS model, "+
  "c.family_name AS family,c.configuration_code AS configuration, "+
  "c.use_type AS \"useType\",c.reference_passenger_capacity AS \"referenceSeats\", "+
  "stock.stocked_units AS \"stockUnits\",stock.stock_delivery_days AS \"stockDeliveryDays\", "+
  "cap.aircraft_per_day AS \"manufacturerDailyCapacity\", "+
  "CASE WHEN stock.stocked_units>0 THEN 'stock' ELSE 'factory_queue' END AS \"deliverySource\", "+
  "CASE WHEN stock.stocked_units>0 THEN clock_timestamp()+make_interval(days=>stock.stock_delivery_days) "+
  "ELSE ((greatest(coalesce(cap.next_factory_day,current_date+14),current_date+14)+ "+
  "CASE WHEN cap.next_factory_day>=current_date+14 AND cap.scheduled_on_next_day>=cap.aircraft_per_day "+
  "THEN 1 ELSE 0 END)::timestamp AT TIME ZONE 'UTC')+interval '1 day' "+
  "END AS \"estimatedDeliveryUtc\", "+
  "r.reference_price_usd::text AS \"referencePriceUsd\", "+
  "r.reference_year AS \"referencePriceYear\",r.evidence_kind AS \"priceEvidence\" "+
  "FROM airlinerra_game.aircraft_acquisition_offers_v1 o "+
  "JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=o.configuration_id "+
  "LEFT JOIN airlinerra_game.factory_model_stock_v1 stock "+
  "ON stock.world_id=1 AND stock.configuration_id=o.configuration_id "+
  "LEFT JOIN airlinerra_game.factory_manufacturer_capacity_v1 cap "+
  "ON cap.world_id=1 AND cap.manufacturer_name=c.manufacturer_name "+
  "LEFT JOIN airlinerra_game.aircraft_model_reference_prices_v1 r "+
  "ON r.configuration_id=o.configuration_id "+
  "WHERE o.world_id=1 AND o.offer_status IN('published','draft') "+
  "AND o.pricing_basis='AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2' "+
  "AND c.production_status='in_production' "+
  "AND c.production_start_year<=extract(year from now()) "+
  "AND (c.production_end_year IS NULL OR c.production_end_year>=extract(year from now())) "+
  "AND c.model_catalog_status='service_verified' AND c.civilian_service_status='active' "+
  "AND NOT EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 x WHERE x.configuration_id=o.configuration_id) "+
  "ORDER BY c.manufacturer_name,c.model_name,o.transaction_type,o.offer_id LIMIT 150",
 marketState:"SELECT m.release_state AS \"releaseState\",m.lease_enabled AS \"leaseEnabled\", "+
  "w.state AS \"worldState\", "+
  "(m.release_state='live' AND w.state='active' AND "+
  "w.opens_at IS NOT NULL AND w.opens_at<=clock_timestamp()) AS \"marketOpen\", "+
  "clock_timestamp() AS \"serverNowUtc\" "+
  "FROM airlinerra_game.aircraft_market_control_v1 m "+
  "JOIN public.airlinerra_game_worlds w ON w.id=m.world_id WHERE m.world_id=1",
 usedLots:"SELECT l.listing_id::text AS \"listingId\", "+
  "l.configuration_id::int AS \"configurationId\", "+
  "l.offering_type AS \"offeringType\",l.manufacture_year AS \"manufactureYear\", "+
  "l.condition_pct::text AS \"conditionPct\", "+
  "l.next_c_check_in_hours::text AS \"nextCCheckInHours\", "+
  "l.provisional_new_value_usd::text AS \"provisionalNewValueUsd\", "+
  "l.opening_bid_usd::text AS \"openingBidUsd\", "+
  "l.min_bid_increment_usd::text AS \"minIncrementUsd\", "+
  "l.highest_bid_usd::text AS \"highestBidUsd\", "+
  "l.fixed_lease_deposit_usd::text AS \"leaseDepositUsd\", "+
  "l.lease_months AS \"leaseMonths\", "+
  "l.status,l.bid_count AS \"bidCount\", "+
  "l.close_after_utc AS \"closeAfterUtc\", "+
  "(l.highest_bid_airline_id=$1::uuid) AS \"myHighestBid\", "+
  "c.manufacturer_name AS manufacturer,c.model_name AS model, "+
  "c.family_name AS family,c.configuration_code AS configuration,c.use_type AS \"useType\", "+
  "seller.display_name AS \"sellerName\",seller.is_fictional AS \"sellerFictional\", "+
  "r.reference_price_usd::text AS \"referencePriceUsd\", "+
  "r.reference_year AS \"referencePriceYear\",r.evidence_kind AS \"priceEvidence\", "+
  "c.production_start_year AS \"productionStartYear\", "+
  "c.production_end_year AS \"productionEndYear\", "+
  "l.price_basis AS \"pricingBasis\" "+
  "FROM airlinerra_game.used_aircraft_auction_lots_v1 l "+
  "JOIN airlinerra.aircraft_catalog_configuration_inventory c "+
  "ON c.configuration_id=l.configuration_id "+
  "JOIN airlinerra_game.aircraft_market_sellers_v1 seller ON seller.seller_id=l.seller_id "+
  "LEFT JOIN airlinerra_game.aircraft_model_reference_prices_v1 r ON r.configuration_id=l.configuration_id "+
  "WHERE l.world_id=1 AND l.status IN('available','bidding') "+
  "AND ($2::text='all' OR l.offering_type=$2::text) "+
  "AND ($3::text='' OR position(lower($3::text) in lower("+
  "c.manufacturer_name||' '||c.model_name||' '||coalesce(c.family_name,'')||' '||seller.display_name))>0) "+
  "AND ($5::text='' OR c.manufacturer_name=$5::text) "+
  "AND ($6::text='' OR c.family_name=$6::text) "+
  "AND ($7::text='' OR c.model_name=$7::text) "+
  "AND ($8::text='' OR c.configuration_code=$8::text) "+
  "ORDER BY CASE WHEN l.status='bidding' THEN 0 ELSE 1 END, "+
  "CASE WHEN l.status='bidding' THEN l.close_after_utc END NULLS LAST,"+
  "c.manufacturer_name,c.model_name,l.opening_bid_usd,l.listing_id "+
  "LIMIT 30 OFFSET ($4::integer*30)",
 usedCount:"SELECT count(*)::int AS total "+
  "FROM airlinerra_game.used_aircraft_auction_lots_v1 l "+
  "JOIN airlinerra.aircraft_catalog_configuration_inventory c "+
  "ON c.configuration_id=l.configuration_id "+  "JOIN airlinerra_game.aircraft_market_sellers_v1 seller ON seller.seller_id=l.seller_id "+

  "WHERE l.world_id=1 AND l.status IN('available','bidding') "+
  "AND ($1::text='all' OR l.offering_type=$1::text) "+
  "AND ($2::text='' OR position(lower($2::text) in lower("+
  "c.manufacturer_name||' '||c.model_name||' '||coalesce(c.family_name,'')||' '||seller.display_name))>0) "+
  "AND ($3::text='' OR c.manufacturer_name=$3::text) "+
  "AND ($4::text='' OR c.family_name=$4::text) "+
  "AND ($5::text='' OR c.model_name=$5::text) "+
  "AND ($6::text='' OR c.configuration_code=$6::text)",
 usedCatalog:"SELECT DISTINCT c.configuration_id::int AS \"configurationId\", "+
  "c.manufacturer_name AS manufacturer,c.family_name AS family, "+
  "c.model_name AS model,c.configuration_code AS configuration,c.use_type AS \"useType\" "+
  "FROM airlinerra_game.used_aircraft_auction_lots_v1 l "+
  "JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=l.configuration_id "+
  "WHERE l.world_id=1 AND l.status IN('available','bidding') "+
  "ORDER BY manufacturer,family,model,configuration,\"configurationId\"",
 usedBid:"SELECT airlinerra_game.place_used_aircraft_bid_v1("+
  "$1::uuid,$2::uuid,$3::uuid,$4::numeric,$5::text,$6::uuid) AS result",
 fleet:"SELECT i.id::text AS id,i.configuration_id::int AS \"configurationId\", "+
  "i.registration,i.nickname,i.ownership_type AS \"ownershipType\",i.fleet_status AS \"fleetStatus\", "+
  "c.manufacturer_name AS manufacturer,c.model_name AS model,c.family_name AS family, "+
  "c.configuration_code AS configuration,c.use_type AS \"useType\", "+
  "c.reference_passenger_capacity AS \"referenceSeats\",c.maximum_cargo_payload_kg::text AS \"cargoKg\", "+
  "p.location_status AS \"locationStatus\",p.airport_key AS \"locationAirportKey\", "+
  "ap.airport_name AS \"locationAirportName\",ap.airport_code AS \"locationAirportCode\", "+
  "p.current_flight_occurrence_id AS \"currentFlightOccurrenceId\", "+
  "o.order_id::text AS \"orderId\",o.order_status AS \"deliveryStatus\",o.delivery_due_at AS \"deliveryDueAt\", "+
  "o.delivery_home_airport_key AS \"deliveryAirportKey\",o.transaction_type AS \"acquisitionType\", "+
  "o.paid_upfront_usd::text AS \"paidUpfrontUsd\", "+
  "o.recurring_monthly_usd::text AS \"recurringMonthlyUsd\", "+
  "o.contract_months AS \"contractMonths\",o.created_at AS \"acquisitionDate\", "+
  "i.created_at AS \"fleetAddedAt\", "+
  "c.production_start_year AS \"modelProductionStartYear\", "+
  "c.production_end_year AS \"modelProductionEndYear\", "+
  "c.technical_review_status AS \"technicalReviewStatus\", "+
  "c.engine_option AS \"engineOption\",c.crew_required AS \"referenceCrewRequired\", "+
  "c.range_km::text AS \"rangeKm\",c.cruise_speed_kmh::text AS \"cruiseSpeedKmh\", "+
  "c.fuel_burn_full_kg_per_hour::text AS \"cruiseFuelKgPerHour\", "+
  "fuelplans.empty_kg_per_100km::text AS \"emptyFuelKgPer100Km\", "+
  "fuelplans.half_kg_per_100km::text AS \"halfFuelKgPer100Km\", "+
  "fuelplans.full_kg_per_100km::text AS \"fullFuelKgPer100Km\", "+
  "fuelplans.rate_evidence AS \"fuelRateStatus\", "+
  "fuelplans.confidence_class AS \"fuelConfidenceClass\", "+
  "fuelplans.reference_peer_model AS \"fuelPeerModel\", "+
  "fuelplans.reference_peer_configuration_id::text AS \"fuelPeerConfigurationId\", "+
  "fuelplans.fuel_type_status AS \"fuelTypeStatus\", "+
  "fueltype.fuel_family AS \"fuelFamily\", "+
  "fueltype.fuel_evidence_class AS \"fuelFamilyEvidence\", "+
  "fueltype.evidence_source_url AS \"fuelFamilySourceUrl\", "+
  "fueltype.verified_aircraft_fuel_grade AS \"verifiedFuelGrade\", "+
  "fueltype.inferred_without_installed_engine AS \"fuelModelWithoutEngine\", "+
  "fueltype.research_fuel_family AS \"historicalModelFuelFamily\", "+
  "fuelcap.fuel_tank_capacity_kg::text AS \"fuelTankCapacityKg\", "+
  "fuelcap.capacity_source_quality AS \"fuelTankEvidence\", "+
  "c.mtow_kg::text AS \"mtowKg\",c.mlw_kg::text AS \"mlwKg\", "+
  "c.wingspan_m::text AS \"wingspanM\",c.length_m::text AS \"lengthM\", "+
  "c.height_m::text AS \"heightM\",c.takeoff_runway_m::text AS \"takeoffRunwayM\", "+
  "c.landing_runway_m::text AS \"landingRunwayM\", "+
  "media.storage_bucket_id AS \"catalogImageBucket\", "+
  "media.storage_object_path AS \"catalogImagePath\" "+
  "FROM airlinerra_game.airline_aircraft_inventory i "+
  "LEFT JOIN airlinerra_game.aircraft_acquisition_orders_v1 o "+
  "ON o.aircraft_inventory_id=i.id AND o.airline_id=i.airline_id "+
  "LEFT JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=i.configuration_id "+
  "LEFT JOIN airlinerra_game.aircraft_fuel_planning_profiles_v1 fuelplans "+
  "ON fuelplans.configuration_id=i.configuration_id "+
  "LEFT JOIN airlinerra_game.aircraft_game_fuel_family_v1 fueltype "+
  "ON fueltype.configuration_id=i.configuration_id "+
  "LEFT JOIN airlinerra.aircraft_catalog_fuel_capacity_game_v1 fuelcap "+
  "ON fuelcap.configuration_id=i.configuration_id "+
  "LEFT JOIN LATERAL (SELECT m.storage_bucket_id,m.storage_object_path "+
  "FROM airlinerra.aircraft_configuration_media m "+
  "WHERE m.configuration_id=i.configuration_id AND m.is_approved=true "+
  "ORDER BY CASE WHEN m.image_role='hero' THEN 0 ELSE 1 END,m.storage_object_path LIMIT 1) media ON true "+
  "LEFT JOIN airlinerra_game.section9_aircraft_current_position_v1 p "+
  "ON p.aircraft_inventory_id=i.id AND p.airline_id=i.airline_id "+
  "LEFT JOIN airlinerra_game.approved_game_airports ap "+
  "ON ap.world_id=p.world_id AND ap.airport_key=p.airport_key "+
  "WHERE i.airline_id=$1::uuid ORDER BY i.created_at DESC,i.id LIMIT 250",
 maintenance:"SELECT v.check_code AS \"checkCode\",v.display_name AS label, "+
  "v.downtime_hours AS \"durationHours\",v.airport_scope AS \"airportScope\", "+
  "p.calendar_interval_hours AS \"calendarIntervalHours\", "+
  "p.calendar_interval_months AS \"calendarIntervalMonths\", "+
  "p.flight_hour_interval::text AS \"flightHourInterval\", "+
  "v.group_id AS \"groupId\",v.group_name AS \"groupName\", "+
  "v.manufacture_year AS \"manufactureYear\",v.condition_pct::text AS \"conditionPct\", "+
  "v.verified_tracking_started_utc AS \"verifiedTrackingStartedUtc\", "+
  "v.tracked_flight_hours::text AS \"trackedFlightHours\", "+
  "v.tracked_flight_cycles::text AS \"trackedFlightCycles\", "+
  "v.last_completed_utc AS \"lastCompletedUtc\", "+
  "v.last_completed_at_flight_hours::text AS \"lastCompletedFlightHours\", "+
  "v.base_estimate_usd::text AS \"baseEstimateUsd\", "+
  "v.cost_evidence AS \"costEvidence\" "+
  "FROM airlinerra_game.aircraft_maintenance_check_overview_v1 v "+
  "JOIN airlinerra_game.maintenance_check_policy_v1 p ON p.check_code=v.check_code "+
  "WHERE v.airline_id=$1::uuid AND v.aircraft_inventory_id=$2::uuid "+
  "ORDER BY CASE v.check_code WHEN 'daily' THEN 1 WHEN 'weekly' THEN 2 "+
  "WHEN 'a' THEN 3 WHEN 'b' THEN 4 WHEN 'c' THEN 5 ELSE 6 END",
 maintenanceSites:"SELECT c.check_code AS \"checkCode\",a.airport_key AS \"airportKey\", "+
  "a.airport_code AS \"airportCode\",a.airport_name AS \"airportName\", "+
  "f.provider_name AS provider,f.continent,f.game_cost_multiplier::text AS \"siteMultiplier\" "+
  "FROM airlinerra_game.maintenance_airport_capabilities_v1 c "+
  "JOIN airlinerra_game.maintenance_facility_locations_v1 f "+
  "ON f.world_id=c.world_id AND f.airport_key=c.airport_key AND f.provider_key=c.provider_key "+
  "JOIN airlinerra_game.approved_game_airports a "+
  "ON a.world_id=c.world_id AND a.airport_key=c.airport_key "+
  "WHERE c.approval_status='game_approved' "+
  "AND c.configuration_id=(SELECT i.configuration_id FROM airlinerra_game.airline_aircraft_inventory i "+
  "WHERE i.airline_id=$1::uuid AND i.id=$2::uuid) "+
  "ORDER BY a.airport_code,c.check_code LIMIT 100",
 cabinTypes:"SELECT seat_code AS \"code\",cabin_class AS \"cabinClass\",label, "+
  "seat_pitch_inches::text AS \"pitchInches\", "+
  "seat_width_inches::text AS \"widthInches\", "+
  "equivalent_economy_units::text AS \"spaceUnits\", "+
  "indicative_install_usd AS \"installUsd\", "+
  "real_product_reference AS \"realProduct\",source_url AS \"sourceUrl\", "+
  "geometry_basis AS \"geometryBasis\" "+
  "FROM airlinerra_game.cabin_seat_types_v1 "+
  "ORDER BY CASE cabin_class WHEN 'economy' THEN 1 WHEN 'premium' THEN 2 "+
  "WHEN 'business' THEN 3 ELSE 4 END,equivalent_economy_units,seat_code",
 cabinGeometry:"SELECT configuration_id::int AS \"configurationId\", "+
  "to_jsonb(economy_columns) AS \"economyColumns\", "+
  "to_jsonb(premium_columns) AS \"premiumColumns\", "+
  "to_jsonb(business_columns) AS \"businessColumns\", "+
  "to_jsonb(first_columns) AS \"firstColumns\", "+
  "review_status AS \"reviewStatus\",source_url AS \"sourceUrl\", "+
  "manually_verified AS \"manuallyVerified\" "+
  "FROM airlinerra_game.cabin_model_row_geometry_v1 "+
  "ORDER BY configuration_id LIMIT 400",
 cabinAircraft:"SELECT i.id::text AS \"aircraftInventoryId\",i.configuration_id::int AS \"configurationId\", "+
  "i.registration,i.ownership_type AS \"ownershipType\", "+
  "c.manufacturer_name AS manufacturer,c.family_name AS family,c.model_name AS model, "+
  "c.use_type AS \"useType\",s.reference_seat_units::text AS \"referenceUnits\", "+
  "s.standard_economy_seats AS \"standardEconomy\", "+
  "installed.installed_economy AS \"installedEconomy\", "+
  "installed.installed_premium AS \"installedPremium\", "+
  "installed.installed_business AS \"installedBusiness\", "+
  "installed.installed_first AS \"installedFirst\", "+
  "draft.economy_seats AS \"draftEconomy\",draft.premium_seats AS \"draftPremium\", "+
  "draft.business_seats AS \"draftBusiness\",draft.first_seats AS \"draftFirst\", "+
  "draft.economy_type AS \"draftEconomyType\", "+
  "draft.premium_type AS \"draftPremiumType\", "+
  "draft.business_type AS \"draftBusinessType\", "+
  "draft.first_type AS \"draftFirstType\", "+
  "draft.extra_legroom_cm::text AS \"draftExtraLegroomCm\", "+
  "draft.updated_at AS \"draftUpdatedAt\" "+
  "FROM airlinerra_game.airline_aircraft_inventory i "+
  "JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=i.configuration_id "+
  "JOIN airlinerra_game.cabin_model_standard_v1 s ON s.configuration_id=i.configuration_id "+
  "LEFT JOIN airlinerra_game.aircraft_installed_cabins_v1 installed ON installed.aircraft_inventory_id=i.id "+
  "LEFT JOIN airlinerra_game.aircraft_cabin_drafts_v1 draft ON draft.aircraft_inventory_id=i.id "+
  "WHERE i.airline_id=$1::uuid ORDER BY i.registration LIMIT 250",
 cabinDirectory:"SELECT f.continent,a.airport_code AS \"airportCode\",a.airport_key AS \"airportKey\", "+
  "a.airport_name AS \"airportName\",f.provider_key AS \"providerKey\", "+
  "f.provider_name AS provider,f.research_status AS \"researchStatus\", "+
  "f.source_url AS \"sourceUrl\",f.game_cost_multiplier::text AS \"siteMultiplier\" "+
  "FROM airlinerra_game.maintenance_facility_locations_v1 f "+
  "JOIN airlinerra_game.approved_game_airports a "+
  "ON a.world_id=f.world_id AND a.airport_key=f.airport_key "+
  "WHERE f.world_id=1 ORDER BY f.continent,a.airport_code,f.provider_name LIMIT 150",
 cabinRefitSites:"SELECT i.id::text AS \"aircraftInventoryId\",a.airport_code AS \"airportCode\", "+
  "a.airport_name AS \"airportName\",a.airport_key AS \"airportKey\", "+
  "f.provider_name AS provider,f.provider_key AS \"providerKey\",f.continent,f.game_cost_multiplier::text AS \"siteMultiplier\" "+
  "FROM airlinerra_game.airline_aircraft_inventory i "+
  "JOIN airlinerra_game.cabin_refit_facility_types_v1 r ON r.configuration_id=i.configuration_id "+
  "JOIN airlinerra_game.maintenance_facility_locations_v1 f "+
  "ON f.world_id=r.world_id AND f.airport_key=r.airport_key AND f.provider_key=r.provider_key "+
  "JOIN airlinerra_game.approved_game_airports a "+
  "ON a.world_id=r.world_id AND a.airport_key=r.airport_key "+
  "WHERE i.airline_id=$1::uuid AND r.planning_status='game_planning_approved' "+
  "ORDER BY i.registration,a.airport_code LIMIT 500",
 cabinOwnerAircraft:"SELECT s.reference_seat_units::text AS \"referenceUnits\", "+
  "c.use_type AS \"useType\",i.configuration_id::int AS \"configurationId\", "+
  "COALESCE(installed.installed_economy,0)+COALESCE(installed.installed_premium,0)+ "+
  "COALESCE(installed.installed_business,0)+COALESCE(installed.installed_first,0) "+
  "AS \"installedSeatCount\" "+
  "FROM airlinerra_game.airline_aircraft_inventory i "+
  "JOIN airlinerra_game.cabin_model_standard_v1 s ON s.configuration_id=i.configuration_id "+
  "JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=i.configuration_id "+
  "LEFT JOIN airlinerra_game.aircraft_installed_cabins_v1 installed ON installed.aircraft_inventory_id=i.id "+
  "WHERE i.airline_id=$1::uuid AND i.id=$2::uuid",
 cabinSave:"INSERT INTO airlinerra_game.aircraft_cabin_drafts_v1 "+
  "(aircraft_inventory_id,airline_id,economy_seats,premium_seats,business_seats,first_seats, "+
  "economy_type,premium_type,business_type,first_type,extra_legroom_cm) "+
  "VALUES($2::uuid,$1::uuid,$3::int,$4::int,$5::int,$6::int,$7::text,$8::text,$9::text,$10::text,$11::numeric) "+
  "ON CONFLICT(aircraft_inventory_id) DO UPDATE "+
  "SET economy_seats=EXCLUDED.economy_seats,premium_seats=EXCLUDED.premium_seats, "+
  "business_seats=EXCLUDED.business_seats,first_seats=EXCLUDED.first_seats, "+
  "economy_type=EXCLUDED.economy_type,premium_type=EXCLUDED.premium_type, "+
  "business_type=EXCLUDED.business_type,first_type=EXCLUDED.first_type, "+
  "extra_legroom_cm=EXCLUDED.extra_legroom_cm,updated_at=now() "+
  "WHERE airlinerra_game.aircraft_cabin_drafts_v1.airline_id=EXCLUDED.airline_id "+
  "RETURNING aircraft_inventory_id::text AS \"aircraftInventoryId\",updated_at AS \"savedAt\"",
 cabinLatestQuote:"SELECT q.quote_id::text AS \"quoteId\",q.status, "+ 
  "q.airport_key AS \"airportKey\",q.provider_key AS \"providerKey\", "+
  "q.total_usd::text AS \"estimatedTotalUsd\", "+
  "q.equipment_usd::text AS \"equipmentUsd\", "+
  "q.installation_usd::text AS \"removalInstallationUsd\", "+
  "q.estimated_downtime_hours AS \"estimatedDowntimeHours\", "+
  "q.created_at AS \"preparedAt\", "+
  "COALESCE(q.draft_updated_at=d.updated_at,false) AS \"matchesCurrentDraft\", "+
  "COALESCE(r.configuration_id=i.configuration_id AND r.planning_status='game_planning_approved',false) "+
  "AS \"providerStillEligible\", "+
  "COALESCE(p.location_status='grounded' AND p.airport_key=q.airport_key,false) "+
  "AS \"confirmedAtRefitSite\", "+
  "COALESCE(g.authoritative_clock_connected,false) AS \"clockConnected\", "+
  "COALESCE(g.trusted_flight_execution_release='ACTIVATED',false) "+
  "AS \"flightEngineReleased\", "+
  "COALESCE(g.automatic_flight_and_fuel_settlement_enabled,false) "+
  "AS \"financialSystemReleased\" "+
  "FROM airlinerra_game.cabin_refit_prepared_quotes_v1 q "+
  "JOIN airlinerra_game.airline_aircraft_inventory i "+
  "ON i.id=q.aircraft_inventory_id AND i.airline_id=q.airline_id "+
  "LEFT JOIN airlinerra_game.aircraft_cabin_drafts_v1 d "+
  "ON d.aircraft_inventory_id=q.aircraft_inventory_id AND d.airline_id=q.airline_id "+
  "LEFT JOIN airlinerra_game.cabin_refit_facility_types_v1 r "+
  "ON r.world_id=1 AND r.airport_key=q.airport_key AND "+
  "r.provider_key=q.provider_key AND r.configuration_id=i.configuration_id "+
  "LEFT JOIN airlinerra_game.section9_aircraft_current_position_v1 p "+
  "ON p.world_id=1 AND p.aircraft_inventory_id=q.aircraft_inventory_id "+
  "AND p.airline_id=q.airline_id "+
  "LEFT JOIN airlinerra_game.section9_flight_engine_readiness_audit_v1 g "+
  "ON g.world_id=1 "+
  "WHERE q.airline_id=$1::uuid AND q.aircraft_inventory_id=$2::uuid "+
  "ORDER BY q.created_at DESC,q.quote_id DESC LIMIT 1",
 cabinPrepareQuote:"SELECT airlinerra_game.prepare_owned_cabin_refit_quote_v1("+
  "$1::uuid,$2::uuid,$3::uuid,$4::text,$5::text,$6::uuid) AS result",
 delivery:"SELECT airlinerra_game.check_owned_aircraft_delivery_v1($1::uuid,$2::uuid,$3::uuid) AS result",
 nickname:"UPDATE airlinerra_game.airline_aircraft_inventory i "+
  "SET nickname=NULLIF(btrim($3::text),''),updated_at=now() "+
  "WHERE i.id=$2::uuid AND i.airline_id=$1::uuid "+
  "RETURNING i.id::text AS id,i.nickname",
 acquire:"SELECT airlinerra_game.order_new_factory_aircraft_v2("+
  "$1::uuid,$2::uuid,$3::uuid,$4::text,$5::uuid) AS result"
});
export function createFleetAcquisitionHandler({verifyUserToken,database}={}){
 if(typeof verifyUserToken!=='function'||typeof database?.connect!=='function')
  throw Error('Protected fleet dependencies required');
 return async function handleFleetAcquisition(request){
  if(!(request instanceof Request))return respond(400,{error:'Invalid request'});
  if(request.method!=='POST')return respond(405,{error:'POST required'});
  // The function is mounted at the fleet-acquisition slug by Supabase.
  // The Edge runtime may internally rewrite Request.url. Do not treat that
  // internal URL as a browser-origin security signal. Like the already-working
  // schedule service, require the pinned external origin and route header.
  // Auth, company ownership and every action are still checked below.
  const url=new URL(request.url);
  if(url.search||url.hash||request.headers.get('origin')!==ORIGIN||
     request.headers.get('x-airlinerra-route')!==FLEET_ACQUISITION_API_ROUTE)
    return respond(403,{error:'Forbidden'});
  if(request.headers.get('content-type')!=='application/json')
    return respond(415,{error:'JSON required'});
  const token=BEARER.exec(request.headers.get('authorization')||'')?.[1];
  if(!token)return respond(401,{error:'Verified session required'});
  let body;
  try{
   const raw=await request.arrayBuffer();
   if(raw.byteLength>1024)return respond(413,{error:'Request too large'});
   body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(raw));
  }catch{return respond(400,{error:'Invalid JSON request'});}
  if(!validateFleetAcquisitionRequest(body))
    return respond(400,{error:'Invalid aircraft request'});
  const verification=await verifyUserToken(token);
  const playerId=verification?.user?.id;
  if(verification?.error||!uuid(playerId))
    return respond(401,{error:'Verified session required'});
  let client;
  try{
   client=await database.connect();
   if(body.action==='list'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const [offers,fleet]=await Promise.all([
     client.query(FLEET_SQL.offers),client.query(FLEET_SQL.fleet,[body.airlineId])
    ]);
    return respond(200,{airlineId:body.airlineId,cashUsd:owner.rows[0].cashUsd,
     offers:offers.rows,fleet:fleet.rows,liveFlightActivation:false});
   }
   if(body.action==='list-used'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const [state,listed,count,catalog]=await Promise.all([
     client.query(FLEET_SQL.marketState),
     client.query(FLEET_SQL.usedLots,[body.airlineId,body.filterMode,body.search.trim(),body.page,
      body.manufacturer||'',body.family||'',body.model||'',body.configuration||'']),
     client.query(FLEET_SQL.usedCount,[body.filterMode,body.search.trim(),
      body.manufacturer||'',body.family||'',body.model||'',body.configuration||'']),
     client.query(FLEET_SQL.usedCatalog)
    ]);
    const market=state.rows?.[0];
    return respond(200,{airlineId:body.airlineId,page:body.page,
     pageSize:30,total:count.rows?.[0]?.total||0,offers:listed.rows,catalog:catalog.rows,
     marketOpen:market?.marketOpen===true,leaseEnabled:market?.leaseEnabled===true,
     worldState:market?.worldState||'unavailable',
     serverNowUtc:market?.serverNowUtc||null,
     auctionRule:'rolling_15_minutes_after_each_valid_higher_bid',
     noBidsNoExpiry:true});
   }
   if(body.action==='bid-used'){
    const result=await client.query(FLEET_SQL.usedBid,[
     playerId,body.airlineId,body.listingId,body.bidUsd,
     body.registration.trim().toUpperCase(),body.requestId
    ]);
    if(result.rowCount!==1||!result.rows?.[0]?.result)
     return respond(503,{error:'Auction bid could not be confirmed'});
    return respond(200,result.rows[0].result);
   }
   if(body.action==='cabin-overview'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const [types,aircraft,directory,refitSites,geometry]=await Promise.all([
     client.query(FLEET_SQL.cabinTypes),
     client.query(FLEET_SQL.cabinAircraft,[body.airlineId]),
     client.query(FLEET_SQL.cabinDirectory),
     client.query(FLEET_SQL.cabinRefitSites,[body.airlineId]),
     client.query(FLEET_SQL.cabinGeometry)
    ]);
    return respond(200,{airlineId:body.airlineId,seatTypes:types.rows,aircraft:aircraft.rows,
     directory:directory.rows,refitSites:refitSites.rows,geometries:geometry.rows,
     previewOnly:true,installedLayoutsImmutable:true,canActivateRefit:false});
   }
   if(body.action==='cabin-save-draft'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const aircraft=await client.query(FLEET_SQL.cabinOwnerAircraft,[body.airlineId,body.aircraftInventoryId]);
    const airframe=aircraft.rows?.[0];
    if(!airframe)return respond(404,{error:'Aircraft not found in your airline'});
    if(airframe.useType==='cargo')return respond(409,{reason:'CARGO_AIRCRAFT_NO_PASSENGER_CABIN'});
    const choices=[['economy',body.economyType,body.economy],
     ['premium',body.premiumType,body.premium],
     ['business',body.businessType,body.business],
     ['first',body.firstType,body.first]];
    const defs=await client.query(FLEET_SQL.cabinTypes);
    const types=new Map(defs.rows.map(t=>[t.code,t]));
    let used=0,installUsd=0;
    const extraCm=body.extraLegroomCm??0;
    for(const [group,type,count] of choices){
     const seat=types.get(type);
     if(!seat||seat.cabinClass!==group)
      return respond(400,{reason:'INVALID_CABIN_SEAT_TYPE'});
     const pitch=Number(seat.pitchInches);
     if(!Number.isFinite(pitch)||pitch<=0)
      return respond(503,{reason:'SEAT_PITCH_REFERENCE_UNAVAILABLE'});
     used+=count*Number(seat.spaceUnits)*(1+extraCm/(pitch*2.54));
     installUsd+=count*Number(seat.installUsd);
    }
    const capacity=Number(airframe.referenceUnits);
    if(!Number.isFinite(capacity)||capacity<=0||used>capacity+1e-8)
      return respond(409,{reason:'CABIN_LAYOUT_EXCEEDS_REFERENCE_SPACE',spaceUsed:Math.round(used*100)/100,
       availableSpace:capacity});
    const stored=await client.query(FLEET_SQL.cabinSave,[
     body.airlineId,body.aircraftInventoryId,body.economy,body.premium,
     body.business,body.first,body.economyType,body.premiumType,body.businessType,body.firstType,extraCm]);
    if(stored.rowCount!==1)return respond(409,{reason:'CABIN_DRAFT_CANNOT_BE_SAVED'});
    const nextSeatCount=body.economy+body.premium+body.business+body.first;
    const existing=Number(airframe.installedSeatCount||0);
    const laborUsd=5000+nextSeatCount*150+existing*75;
    return respond(200,{...stored.rows[0],airlineId:body.airlineId,
     totalSeats:nextSeatCount,extraLegroomCm:extraCm,
     usedSpace:Math.round(used*100)/100,availableSpace:capacity,
     spacePct:Math.round(used/capacity*1000)/10,
     estimatedSeatEquipmentUsd:Math.round(installUsd),
     estimatedRemovalAndInstallationUsd:Math.round(laborUsd),
     estimatedRefitTotalUsd:Math.round(installUsd+laborUsd),
     quoteOnly:true,chargedUsd:0,
     indicativeDowntimeHours:body.premium+body.business+body.first>0?48:24,
     status:'draft_saved_not_installed',canScheduleRefit:false,
     aircraftLocationUnchanged:true,liveSeatsUnchanged:true,cashDebited:false});
   }
   if(body.action==='cabin-quote-status'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const latest=await client.query(FLEET_SQL.cabinLatestQuote,[
     body.airlineId,body.aircraftInventoryId
    ]);
    const q=latest.rows?.[0];
    if(!q)return respond(200,{status:'no_quote',airlineId:body.airlineId,
     aircraftInventoryId:body.aircraftInventoryId,canBookRefit:false});
    const blockers=['REFIT_APPOINTMENTS_NOT_RELEASED','GAME_HOUR_CLOCK_NOT_CONNECTED'];
    if(q.matchesCurrentDraft!==true)blockers.push('SAVED_DESIGN_CHANGED');
    if(q.providerStillEligible!==true)blockers.push('PROVIDER_NOT_TYPE_ELIGIBLE');
    if(q.confirmedAtRefitSite!==true)blockers.push('AIRCRAFT_NOT_CONFIRMED_AT_FACILITY');
    if(q.clockConnected!==true)blockers.push('GAME_DAY_CLOCK_NOT_CONNECTED');
    if(q.flightEngineReleased!==true)blockers.push('FLIGHT_OPERATIONS_NOT_ACTIVATED');
    if(q.financialSystemReleased!==true)blockers.push('FINANCIAL_SETTLEMENT_NOT_ACTIVATED');
    return respond(200,{
     status:q.status,airlineId:body.airlineId,aircraftInventoryId:body.aircraftInventoryId,
     quoteId:q.quoteId,airportKey:q.airportKey,providerKey:q.providerKey,
     estimatedTotalUsd:q.estimatedTotalUsd,equipmentUsd:q.equipmentUsd,
     removalInstallationUsd:q.removalInstallationUsd,
     estimatedDowntimeHours:q.estimatedDowntimeHours,preparedAt:q.preparedAt,
     matchesCurrentDraft:q.matchesCurrentDraft===true,
     blockers,canBookRefit:false,appointmentBooked:false,
     moneyCharged:false,installedSeatsChanged:false
    });
   }
   if(body.action==='cabin-prepare-quote'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const quote=await client.query(FLEET_SQL.cabinPrepareQuote,[
     playerId,body.airlineId,body.aircraftInventoryId,body.airportKey,
     body.providerKey,body.requestId
    ]);
    if(quote.rowCount!==1||!quote.rows?.[0]?.result)
     return respond(503,{error:'Verified cabin refit quote unavailable'});
    return respond(200,quote.rows[0].result);
   }
   if(body.action==='maintenance-preview'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const [checks,sites]=await Promise.all([
     client.query(FLEET_SQL.maintenance,[body.airlineId,body.aircraftInventoryId]),
     client.query(FLEET_SQL.maintenanceSites,[body.airlineId,body.aircraftInventoryId])
    ]);
    if(!checks.rows.length)return respond(404,{error:'No maintenance profile for this owned aircraft'});
    return respond(200,{
     airlineId:body.airlineId,aircraftInventoryId:body.aircraftInventoryId,
     checks:checks.rows,maintenanceSites:sites.rows,
     previewOnly:true,canScheduleMaintenance:false,canBookFerryFlight:false,
     status:'planning_not_activated'
    });
   }
   if(body.action==='check-delivery'){
    const result=await client.query(FLEET_SQL.delivery,[playerId,body.airlineId,body.orderId]);
    if(result.rowCount!==1||!result.rows[0]?.result)
      return respond(503,{error:'Delivery status could not be confirmed'});
    return respond(200,result.rows[0].result);
   }
   if(body.action==='update-nickname'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const changed=await client.query(FLEET_SQL.nickname,[
     body.airlineId,body.aircraftInventoryId,body.nickname
    ]);
    if(changed.rowCount!==1)return respond(404,{error:'Aircraft not found in your fleet'});
    return respond(200,changed.rows[0]);
   }
   const registration=body.registration.trim().toUpperCase();
   const result=await client.query(FLEET_SQL.acquire,[
    playerId,body.airlineId,body.offerId,registration,body.requestId
   ]);
   if(result.rowCount!==1||!result.rows[0]?.result)
    return respond(503,{error:'Aircraft order was not confirmed'});
   return respond(200,result.rows[0].result);
  }catch(err){
   const code=typeof err?.code==='string'?err.code:'';
   if(code==='42501')return respond(403,{error:'Airline not owned by verified player'});
   if(code==='22023')return respond(400,{error:'Invalid aircraft registration or request'});
   if(code==='23505')return respond(409,{reason:'AIRCRAFT_REGISTRATION_ALREADY_TAKEN'});
   if(code==='P0001'){
    const allowed=new Set([
     'AIRLINE_WORLD_NOT_ACTIVE_FOR_ACQUISITION',
     'ACQUISITION_IDEMPOTENCY_KEY_REUSED','AIRCRAFT_OFFER_NOT_AVAILABLE',
     'AIRCRAFT_CONFIGURATION_NOT_RELEASED_FOR_PLAYER_MARKET',
     'GROUP3_AIRCRAFT_NOT_RELEASED_FOR_FLEET',
     'AIRCRAFT_REGISTRATION_ALREADY_TAKEN','INSUFFICIENT_AIRLINE_CASH',
     'AIRLINE_WORLD_NOT_ACTIVE_FOR_DELIVERY',
     'AIRCRAFT_MARKET_NOT_OPEN','NEW_AIRCRAFT_MODEL_NOT_ELIGIBLE',
     'AIRCRAFT_LEASE_BILLING_NOT_ACTIVE','USED_AIRCRAFT_OFFER_NOT_AVAILABLE',
     'AUCTION_REQUEST_ID_ALREADY_USED','AUCTION_IDEMPOTENCY_KEY_REUSED',
     'AUCTION_CLOSED_PENDING_SETTLEMENT','ALREADY_HIGHEST_BIDDER',
     'AUCTION_BID_BELOW_REQUIRED_AMOUNT','AUCTION_ESCROW_INCONSISTENT',
     'CABIN_REFIT_NOT_PASSENGER_AIRCRAFT',
     'CABIN_REFIT_PROVIDER_NOT_APPROVED_FOR_MODEL',
     'CABIN_REFIT_SAVE_DESIGN_FIRST','CABIN_REFIT_INVALID_SEAT_SELECTION',
     'CABIN_REFIT_INVALID_SEAT_COUNT','CABIN_REFIT_LAYOUT_EXCEEDS_SPACE',
     'CABIN_REFIT_INSTALLED_LAYOUT_NOT_FOUND',
     'CABIN_REFIT_IDEMPOTENCY_KEY_REUSED'
    ]);
    return respond(409,{reason:allowed.has(err.message)?err.message:'AIRCRAFT_ACQUISITION_UNAVAILABLE'});
   }
   return respond(503,{error:'Fleet service temporarily unavailable'});
  }finally{try{client?.release()}catch{/* no sensitive DB details */}}
 };
}
