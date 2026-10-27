/**
 * Opt-in, non-deploying hosted account composition.
 * The currently shipped static website imports NONE of these modules.
 *
 * A later private Netlify preview can use this module after explicit
 * function-scoped configuration. It has NO route registration by itself.
 */
import {parseHostedRuntimeConfig} from './hosted-runtime-config.mjs';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {createHostedAccountStack} from './hosted-account-stack.mjs';

export async function buildPrivatePreviewAccountApp({
  env={},
  fetchImpl=globalThis.fetch,
  loadPg=()=>import('pg')
}={}) {
  const config=parseHostedRuntimeConfig(env);
  if(!config.enabled) {
    return Object.freeze({
      enabled:false,
      handler:createHostedAccountStack({enabled:false}),
      close:async()=>{}
    });
  }
  if(typeof loadPg!=='function')throw new Error('A trusted database driver is required.');
  // Lazy loading means disabled deployments never load a privileged DB driver
  // or create connections. Driver installation/bundling is a separate host gate.
  const driver=await loadPg();
  const Pool=driver?.Pool||driver?.default?.Pool;
  if(typeof Pool!=='function')throw new Error('Supported PostgreSQL driver not available.');
  const pool=new Pool({
    connectionString:config.dbUrl,
    ssl:{rejectUnauthorized:true},
    max:2,
    idleTimeoutMillis:2500,
    connectionTimeoutMillis:5000,
    query_timeout:10000,
    statement_timeout:8000,
    allowExitOnIdle:true
  });
  try {
    const verifyUserToken=createHostedAuthVerifier({
      authUrl:config.supabaseUrl,
      publishableKey:config.publishableKey,
      fetchImpl
    });
    const handler=createHostedAccountStack({
      enabled:true,
      publicOrigin:config.publicOrigin,
      verifyUserToken,
      database:pool,
      termsPath:config.termsPath,
      privacyPath:config.privacyPath
    });
    return Object.freeze({
      enabled:true,
      handler,
      close:async()=>{await pool.end();}
    });
  }catch{
    try{await pool.end();}catch{ /* preserve safe error */ }
    throw new Error('Private preview account service could not be configured.');
  }
}
