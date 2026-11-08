/** Non-authorizing airport weather reference for Section 5 flight-draft preflight.
 * The MET Norway feed lacks certified aviation minima and visibility.
 * Weather here is a forecast preview only, never a dispatch permission or game hard ban.
 */
export const WEATHER_ROUTE_REFERENCE_SQL=String.raw`
WITH requested(side,airport_key,scheduled_utc) AS (
 VALUES ('origin'::text,$1::text,$2::timestamptz),
        ('destination'::text,$3::text,$4::timestamptz)
)
SELECT r.side,r.scheduled_utc,
 CASE
  WHEN f.airport_key IS NULL THEN 'FORECAST_MISSING'
  WHEN f.forecast_status <> 'CURRENT_FORECAST' OR
       f.provider_fetched_at IS NULL OR
       f.provider_fetched_at < now()-interval '36 hours' THEN 'FORECAST_SOURCE_STALE'
  WHEN r.scheduled_utc < f.forecast_valid_from OR
       r.scheduled_utc >= f.forecast_valid_through THEN 'OUTSIDE_FORECAST_HORIZON'
  WHEN x.item IS NULL THEN 'NO_MATCHING_FORECAST_HOUR'
  ELSE 'FORECAST_REFERENCE_AVAILABLE'
 END AS weather_status,
 x.item->>'time' AS forecast_hour_utc,
 x.item->>'weather_symbol' AS weather_symbol,
 (x.item->>'temperature_c')::numeric AS temperature_c,
 (x.item->>'wind_speed_kmh')::numeric AS wind_speed_kmh,
 (x.item->>'precipitation_mm')::numeric AS precipitation_mm,
 (x.item->>'visibility_m')::numeric AS visibility_m,
 f.weather_provider
FROM requested r
LEFT JOIN airlinerra_game.section5_airport_weather_forecast_v1 f
 ON f.world_id=1 AND f.airport_key=r.airport_key
LEFT JOIN LATERAL (
 SELECT z.item FROM jsonb_array_elements(coalesce(f.hourly_json,'[]'::jsonb)) AS z(item)
 WHERE (z.item->>'time')::timestamptz<=r.scheduled_utc
  AND (z.item->>'time')::timestamptz+interval '1 hour'>r.scheduled_utc
 ORDER BY (z.item->>'time')::timestamptz DESC LIMIT 1
) x ON true
ORDER BY r.side
`;
const finiteNumber=value=>{
 if(value===null||value===undefined||value==='')return null;
 const n=Number(value);
 return Number.isFinite(n)?n:null;
};
export function buildWeatherReferencePreview(rows){
 const entries=Array.isArray(rows)?rows:[];
 const leg=side=>{
  const row=entries.find(r=>r?.side===side);
  const status=typeof row?.weather_status==='string'?
   row.weather_status:'FORECAST_QUERY_UNAVAILABLE';
  const valid=status==='FORECAST_REFERENCE_AVAILABLE';
  return {
   status,
   scheduledUtc:typeof row?.scheduled_utc==='string'?row.scheduled_utc:
    row?.scheduled_utc instanceof Date?row.scheduled_utc.toISOString():null,
   forecastHourUtc:valid?row?.forecast_hour_utc??null:null,
   weatherSymbol:valid?row?.weather_symbol??null:null,
   temperatureC:valid?finiteNumber(row?.temperature_c):null,
   windSpeedKmh:valid?finiteNumber(row?.wind_speed_kmh):null,
   precipitationMm:valid?finiteNumber(row?.precipitation_mm):null,
   visibilityM:valid?finiteNumber(row?.visibility_m):null,
   provider:row?.weather_provider??null
  };
 };
 return {
  modelVersion:'SECTION5_REFERENCE_WEATHER_V1',
  origin:leg('origin'),destination:leg('destination'),
  representativeFlightOnly:true,
  operationalWeatherValidated:false,
  gameHardBlocked:false,
  canActivateNormalFlight:false,
  note:'Forecast for entered example departure and arrival only, not all weekly occurrences. Aviation visibility and dispatch minima are not verified. Weather does not grant flight activation.'
 };
}
