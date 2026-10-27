/**
 * Server-only Netlify dependency bridge (NOT copied into public dist/).
 *
 * Netlify installs dependencies under website/node_modules. An explicit
 * static import here ensures its Functions bundler includes pg and its
 * transitive modules when code is staged under ../server/.
 *
 * Importing this module does NOT open a connection, inspect credentials,
 * or authorize a serverless API route. Pool creation remains guarded by
 * independent preview/production release checks in preview-account-app.
 */
import pg from 'pg';

export async function loadServerPostgresDriver(){
  return pg;
}
