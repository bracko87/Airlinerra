/** Airlinerra canonical production game account function.
 * Enabled ONLY with Netlify's private site environment configuration.
 */
import {createProductionGameApi} from '../../../server/production-game-api.mjs';

export const config={
 path:[
  '/api/v1/player/overview','/api/v1/player/airports',
  '/api/v1/onboarding/context','/api/v1/legal/consents',
  '/api/v1/airlines','/api/v1/registration/readiness'
 ],
 rateLimit:{action:'rate_limit',aggregateBy:'ip',windowSize:60,windowLimit:60}
};
const app=createProductionGameApi({loadPg:()=>import('pg')});
export default async function airlinerraGame(request){
 return app(request);
}
