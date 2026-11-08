import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {WEATHER_ROUTE_REFERENCE_SQL,buildWeatherReferencePreview}
 from '../server/flight-weather-reference.mjs';
import {formatRouteWeatherPreview,routePlannerMarkup} from '../website/route-planner.mjs';

test('Section 5 reference weather SQL gets both airport moments without inventing weather restrictions',()=>{
 assert.match(WEATHER_ROUTE_REFERENCE_SQL,/section5_airport_weather_forecast_v1/);
 assert.match(WEATHER_ROUTE_REFERENCE_SQL,/f\.world_id=1/);
 assert.match(WEATHER_ROUTE_REFERENCE_SQL,/OUTSIDE_FORECAST_HORIZON/);
 assert.match(WEATHER_ROUTE_REFERENCE_SQL,/FORECAST_SOURCE_STALE/);
 assert.match(WEATHER_ROUTE_REFERENCE_SQL,/interval '36 hours'/);
 assert.match(WEATHER_ROUTE_REFERENCE_SQL,/interval '1 hour'/);
 assert.match(WEATHER_ROUTE_REFERENCE_SQL,/hourly_json/);
});
test('weather reference treats valid forecast as contextual, not flight approval',()=>{
 const p=buildWeatherReferencePreview([
  {side:'origin',weather_status:'FORECAST_REFERENCE_AVAILABLE',
   scheduled_utc:new Date('2026-11-08T16:20:00Z'),
   forecast_hour_utc:'2026-11-08T16:00:00.000Z',
   weather_symbol:'partlycloudy_night',temperature_c:'4.2',
   wind_speed_kmh:'25.6',precipitation_mm:'0',visibility_m:null,
   weather_provider:'MET_NORWAY_LOCATIONFORECAST_2_0_COMPACT'},
  {side:'destination',weather_status:'OUTSIDE_FORECAST_HORIZON',
   scheduled_utc:new Date('2026-12-08T18:20:00Z'),
   weather_symbol:'rain',wind_speed_kmh:'50'}
 ]);
 assert.equal(p.origin.status,'FORECAST_REFERENCE_AVAILABLE');
 assert.equal(p.origin.temperatureC,4.2);
 assert.equal(p.origin.visibilityM,null);
 assert.equal(p.destination.status,'OUTSIDE_FORECAST_HORIZON');
 assert.equal(p.destination.windSpeedKmh,null);
 assert.equal(p.gameHardBlocked,false);
 assert.equal(p.operationalWeatherValidated,false);
 assert.equal(p.canActivateNormalFlight,false);
 assert.match(p.note,/not all weekly occurrences/);
 const display=formatRouteWeatherPreview(p);
 assert.match(display,/Departure: partlycloudy night, 4.2°C, wind 25.6 km\/h/);
 assert.match(display,/Arrival: Outside forecast horizon/);
 assert.match(display,/aviation weather clearance not provided/);
});
test('missing weather data cannot imply safe weather or change airport restrictions',()=>{
 const missing=buildWeatherReferencePreview([]);
 assert.equal(missing.origin.status,'FORECAST_QUERY_UNAVAILABLE');
 assert.equal(missing.destination.status,'FORECAST_QUERY_UNAVAILABLE');
 assert.equal(missing.canActivateNormalFlight,false);
 assert.match(formatRouteWeatherPreview(missing),/Forecast unavailable/);
 const markup=routePlannerMarkup();
 assert.match(markup,/id="route-weather-check"/);
 const edge=await readFile(new URL('../server/noise-curfew-route-edge-entry.ts',import.meta.url),'utf8');
 assert.match(edge,/WEATHER_ROUTE_REFERENCE_SQL/);
 assert.match(edge,/buildWeatherReferencePreview/);
 assert.match(edge,/weatherPreview,/);
 assert.match(edge,/gameHardBlocked:gate\.gameHardBlocked===true/);
 assert.match(edge,/canActivateNormalFlight:false/);
});
