/** Read-only World 1 airport profile sourced from approved roster + research tables.
 * No simulation, user ledger, or operations mutation. Only authenticated callers.
 * All provisional and missing data remain explicitly identified.
 */
export const AIRPORT_PROFILE_PATH='/api/v1/player/airport-profile';
const KEY=/^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const CATEGORIES=new Set(['Local','Regional','Medium','Large','Major Hub','Mega Hub']);
export const validAirportKey=value=>typeof value==='string'&&KEY.test(value);
export const AIRPORT_PROFILE_SQL=`
 SELECT a.airport_key,a.airport_name,a.airport_code,a.country_iso,
        a.municipality AS roster_municipality,
        p.game_official_name,p.official_name_verified,
        p.game_municipality,p.region_iso,p.region_display_name,
        p.latitude_deg::text AS latitude_deg,p.longitude_deg::text AS longitude_deg,
        p.coordinates_verification,p.coordinates_source_type,
        p.icao_reported,p.iata_reported,p.game_display_code,
        p.approved_category,p.provisional_category,
        p.timezone_iana,p.timezone_candidate_iana,
        p.game_elevation_ft::text AS game_elevation_ft,
        p.game_elevation_provenance,
        p.airport_kind,
        f.terminal_count,f.passenger_gate_count,f.aircraft_stand_count,
        f.operating_hours_local,f.curfew_details,f.noise_restrictions,
        f.facility_status,
        ops.game_operating_hours_summary,ops.operating_hours_basis AS game_operating_hours_basis,
        ops.max_day_game_noise_class,ops.max_night_game_noise_class,
        ops.noise_limit_basis,ops.time_restrictions AS game_time_restrictions,
        wx.forecast_status,wx.is_current AS forecast_is_current,
        wx.provider_fetched_at AS weather_provider_fetched_at,
        wx.forecast_valid_through AS weather_valid_through,
        wx.temperature_c AS weather_temperature_c,wx.weather_symbol,
        wx.precipitation_mm AS weather_precipitation_mm,
        wx.wind_speed_kmh AS weather_wind_kmh,
        wx.next_24h_local_3hourly AS weather_next_24h,
        wx.required_attribution AS weather_attribution,
        (
          SELECT jsonb_agg(
            jsonb_build_object(
              'name',r.runway_designator,
              'lengthM',r.length_m,
              'widthM',r.width_m,
              'surface',r.surface_reported,
              'operationalStatus',r.operational_status,
              'verification',r.verification
            ) ORDER BY r.length_m DESC NULLS LAST,r.runway_designator
          ) FROM airlinerra_game.airport_runway_inventory r
          WHERE r.world_id=a.world_id AND r.airport_key=a.airport_key
        ) AS runways
 FROM airlinerra_game.approved_game_airports a
 LEFT JOIN airlinerra_game.airport_reference_profiles p
    ON p.world_id=a.world_id AND p.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.airport_facilities f
    ON f.world_id=a.world_id AND f.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section5_airport_operating_summary_v1 ops
    ON ops.world_id=a.world_id AND ops.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section5_airport_weather_profile_v1 wx
    ON wx.world_id=a.world_id AND wx.airport_key=a.airport_key
 WHERE a.world_id=1 AND a.airport_key=$1::text
 LIMIT 1`;
const nullableString=x=>typeof x==='string'&&x.trim()?x.trim():null;
const numberOrNull=x=>{
 if(x===null||x===undefined||x==='')return null;
 const n=Number(x);return Number.isFinite(n)?n:null;
};
const isoDateOrNull=x=>x instanceof Date&&!Number.isNaN(x.getTime())?
 x.toISOString():nullableString(x);
const countOrNull=x=>{
 const n=numberOrNull(x);
 return n!==null&&Number.isInteger(n)&&n>=0?n:null;
};
export function serializeAirportProfile(row){
 if(!row||!validAirportKey(row.airport_key))throw Error('Invalid airport profile');
 const runways=Array.isArray(row.runways)?row.runways.slice(0,20).map(r=>({
  name:nullableString(r.name),lengthM:numberOrNull(r.lengthM),
  widthM:numberOrNull(r.widthM),surface:nullableString(r.surface),
  operationalStatus:nullableString(r.operationalStatus),
  verification:nullableString(r.verification)
 })):[];
 const category=nullableString(row.approved_category)||nullableString(row.provisional_category);
 return Object.freeze({
  key:row.airport_key,worldId:1,
  name:nullableString(row.game_official_name)||row.airport_name,
  nameChecked:Boolean(nullableString(row.official_name_verified)),
  code:nullableString(row.airport_code),
  icao:nullableString(row.icao_reported),
  iata:nullableString(row.iata_reported),
  countryIso:nullableString(row.country_iso),
  municipality:nullableString(row.game_municipality)||nullableString(row.roster_municipality),
  region:nullableString(row.region_display_name)||nullableString(row.region_iso),
  latitude:numberOrNull(row.latitude_deg),longitude:numberOrNull(row.longitude_deg),
  coordinatesStatus:nullableString(row.coordinates_verification),
  coordinatesSource:nullableString(row.coordinates_source_type),
  category:CATEGORIES.has(category)?category:null,
  categoryStatus:nullableString(row.approved_category)?'approved':'provisional',
  timezone:nullableString(row.timezone_iana)||nullableString(row.timezone_candidate_iana),
  timezoneStatus:nullableString(row.timezone_iana)?'checked':'candidate',
  elevationFt:numberOrNull(row.game_elevation_ft),
  elevationStatus:nullableString(row.game_elevation_provenance),
  airportKind:nullableString(row.airport_kind),
  runways,
  facilities:{
   terminals:countOrNull(row.terminal_count),
   gates:countOrNull(row.passenger_gate_count),
   stands:countOrNull(row.aircraft_stand_count),
   operatingHours:nullableString(row.game_operating_hours_summary)||
     nullableString(row.operating_hours_local),
   curfew:nullableString(row.curfew_details)||
     (Array.isArray(row.game_time_restrictions)&&row.game_time_restrictions.length?
      row.game_time_restrictions.map(r=>[r.localStart,r.localEnd].join('-')+
       ' '+(r.operation||'both')+' ('+(r.kind||'restriction')+')').join('; '):null),
   noise:nullableString(row.noise_restrictions)||
     ('Game max noise class: daytime '+(countOrNull(row.max_day_game_noise_class)??5)+
      '/5, nighttime '+(countOrNull(row.max_night_game_noise_class)??5)+
      '/5 (game estimates, not ICAO certifications)'),
   status:nullableString(row.facility_status)
  },
  operations:{
   hoursBasis:nullableString(row.game_operating_hours_basis),
   noiseBasis:nullableString(row.noise_limit_basis),
   dayMaxNoiseClass:countOrNull(row.max_day_game_noise_class),
   nightMaxNoiseClass:countOrNull(row.max_night_game_noise_class),
   timeRestrictions:Array.isArray(row.game_time_restrictions)?
     row.game_time_restrictions.slice(0,20).map(item=>({
       code:nullableString(item.code),kind:nullableString(item.kind),
       operation:nullableString(item.operation),
       localStart:nullableString(item.localStart),
       localEnd:nullableString(item.localEnd),
       source:nullableString(item.source),
       details:nullableString(item.details),
       gameEnforcement:item.gameEnforcement===true,
       exceptionsExpected:item.exceptionsExpected===true
     })):[]
  },
  weather:{
   status:nullableString(row.forecast_status)||'AWAITING_FIRST_FORECAST',
   isCurrent:row.forecast_is_current===true,
   fetchedAt:isoDateOrNull(row.weather_provider_fetched_at),
   validThrough:isoDateOrNull(row.weather_valid_through),
   temperatureC:numberOrNull(row.weather_temperature_c),
   symbol:nullableString(row.weather_symbol),
   precipitationMm:numberOrNull(row.weather_precipitation_mm),
   windKmh:numberOrNull(row.weather_wind_kmh),
   attribution:nullableString(row.weather_attribution),
   next24h:Array.isArray(row.weather_next_24h)?
    row.weather_next_24h.slice(0,10).map(point=>({
      time:nullableString(point.time),
      temperatureC:numberOrNull(point.temperature_c),
      symbol:nullableString(point.weather_symbol),
      precipitationMm:numberOrNull(point.precipitation_mm),
      windKmh:numberOrNull(point.wind_speed_kmh)
    })):[]
  }
 });
}
