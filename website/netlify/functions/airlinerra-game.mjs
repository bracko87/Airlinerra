/** Airlinerra canonical production game account function.
 * The database is held privately by the Supabase Edge Function; no Netlify secrets.
 */
import {createProductionGameApi} from '../../../server/production-game-api.mjs';

export const config={
 path:[
  '/api/v1/player/overview','/api/v1/player/airports','/api/v1/player/airport-profile',
  '/api/v1/player/aircraft-library','/api/v1/player/licenses','/api/v1/player/holding-status','/api/v1/player/noise-curfew-check',
   '/api/v1/player/flight-schedule-drafts','/api/v1/player/cabin-services',
  '/api/v1/player/fleet-acquisition','/api/v1/player/permission-applications',
  '/api/v1/onboarding/context','/api/v1/legal/consents',
  '/api/v1/airlines','/api/v1/registration/readiness'
 ],
 rateLimit:{action:'rate_limit',aggregateBy:'ip',windowSize:60,windowLimit:60}
};
const app=createProductionGameApi();
export default async function airlinerraGame(request){
 return app(request);
}
