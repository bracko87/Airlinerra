/**
 * Explicit opt-in localhost-only browser Auth preview.
 *
 * This is NOT the release site, and NEVER targets the airport-research
 * Supabase project. It serves virtual Auth flags in memory, without changing
 * PUBLIC_AUTH_ENABLED=false in source or in the production static build.
 * It cannot launch a public listener and does not supply backend API routes.
 */
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validatedDevelopmentAuthConfig } from '../auth-client.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const types=Object.freeze({
  '.html':'text/html; charset=utf-8',
  '.css':'text/css; charset=utf-8',
  '.js':'text/javascript; charset=utf-8',
  '.mjs':'text/javascript; charset=utf-8',
  '.svg':'image/svg+xml',
  '.webp':'image/webp',
  '.png':'image/png',
  '.ico':'image/x-icon'
});

export async function startLocalAuthPreview({
  port=5187, env=process.env, createTestAccountHandlers
}={}) {
  if (env.AIRLINERRA_LOCAL_AUTH_TEST !== '1') {
    throw new Error('Local Auth preview requires explicit opt-in.');
  }
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error('Invalid localhost preview port.');
  }
  const config=validatedDevelopmentAuthConfig({
    supabaseUrl:env.AIRLINERRA_LOCAL_SUPABASE_URL || 'http://127.0.0.1:54321',
    publishableKey:env.AIRLINERRA_LOCAL_PUBLISHABLE_KEY
  });
  if (!/^http:\/\/(?:127\.0\.0\.1|localhost):54321$/u.test(config.supabaseUrl)) {
    throw new Error('Only the local Supabase Auth stack is permitted here.');
  }
  if (createTestAccountHandlers !== undefined &&
      typeof createTestAccountHandlers !== 'function') {
    throw new Error('Trusted CI-only account handler factory required.');
  }
  let boundPort=null;
  let testHandlers=null;
  const server=createServer(async(req,res)=>{
    const headers={
      'cache-control':'no-store',
      'x-content-type-options':'nosniff',
      'x-frame-options':'DENY',
      'referrer-policy':'no-referrer',
      'content-security-policy':
        "default-src 'self'; script-src 'self' https://esm.sh; connect-src 'self' http://127.0.0.1:54321 http://localhost:54321 https://esm.sh; style-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'"
    };
    const finish=(status,body,contentType='text/plain; charset=utf-8')=>{
      res.writeHead(status,{...headers,'content-type':contentType});
      res.end(body);
    };
    try {
      if (req.headers.host !== 'localhost:'+boundPort) {
        return finish(421,'Only localhost is accepted.');
      }
      if (req.url?.startsWith('/api/v1/')) {
        const paths=new Set(['/api/v1/onboarding/context',
          '/api/v1/legal/consents','/api/v1/airlines']);
        if(!testHandlers || !paths.has(req.url))return finish(404,'Not found.');
        if(req.method!=='POST')return finish(405,'Method not allowed.');
        if(req.headers.origin!=='http://localhost:'+boundPort){
          return finish(403,'Local same-origin request required.');
        }
        if(req.headers['content-type']!=='application/json'){
          return finish(415,'JSON required.');
        }
        const chunks=[];
        let length=0;
        for await(const chunk of req){
          length+=chunk.length;
          if(length>2048)return finish(413,'Request too large.');
          chunks.push(chunk);
        }
        const request={path:req.url,method:req.method,headers:req.headers,
          body:Buffer.concat(chunks).toString('utf8')};
        const response=await testHandlers[req.url]?.(request);
        if(!response||!Number.isInteger(response.status)||
          typeof response.body!=='string')return finish(503,'Unavailable.');
        return finish(response.status,response.body,'application/json; charset=utf-8');
      }
      if (req.method!=='GET' && req.method!=='HEAD') {
        return finish(405,'Method not allowed.');
      }
      const url=new URL(req.url || '/','http://localhost');
      const pathname=decodeURIComponent(url.pathname==='/'?'/index.html':url.pathname);
      const origin='http://localhost:'+boundPort;
      if (pathname==='/__airlinerra_local_auth_config__.js') {
        const js='window.__AIRLINERRA_DEV_AUTH__ = Object.freeze('+
          JSON.stringify({...config,localSdk:true})+');\n';
        return finish(200,req.method==='HEAD'?'':js,types['.js']);
      }
      let filename=path.resolve(root,'.'+pathname);
      if (!filename.startsWith(root+path.sep)) {
        return finish(403,'Forbidden.');
      }
      if (!(await stat(filename)).isFile()) return finish(404,'Not found.');
      let body=await readFile(filename);
      if (pathname==='/account.html') {
        const html=body.toString('utf8');
        const target='<script src="account.js" type="module"></script>';
        if (!html.includes(target)) throw Error('Account preview HTML changed.');
        const prelaunchNotice='<strong>Prelaunch preview</strong> — Account creation, sign-in and password reset are not available yet. No information entered here is submitted or stored.';
        const localNotice='<strong>Local Auth test only</strong> — Test credentials are sent to the Supabase stack on your own computer. Never use production passwords or customer data.';
        if (!html.includes(prelaunchNotice)) throw Error('Account safety notice changed.');
        body=Buffer.from(html.replace(prelaunchNotice,localNotice)
          .replace(target,
            '<script src="/__airlinerra_local_auth_config__.js"></script>\n  '+target));
      } else if (pathname==='/auth-rules.mjs') {
        let script=body.toString('utf8');
        const defaultOff='export const PUBLIC_AUTH_ENABLED = false;';
        const fixedOrigins="export const ALLOWED_AUTH_ORIGINS = Object.freeze(['http://localhost:5187', 'https://airlinerra.com']);";
        if (!script.includes(defaultOff) || !script.includes(fixedOrigins)) {
          throw Error('Public Auth gates changed; local override refused.');
        }
        script=script.replace(defaultOff,'export const PUBLIC_AUTH_ENABLED = true;')
          .replace(fixedOrigins,'export const ALLOWED_AUTH_ORIGINS = Object.freeze(['+
            JSON.stringify(origin)+']);');
        body=Buffer.from(script);
      }
      return finish(200,req.method==='HEAD'?'':body,types[path.extname(filename)] || 'application/octet-stream');
    } catch {
      finish(404,'Not found.');
    }
  });
  server.requestTimeout=5000;
  server.headersTimeout=6000;
  try {
    await new Promise((resolve,reject)=>{
      server.once('error',reject);
      server.listen(port,'127.0.0.1',resolve);
    });
    boundPort=server.address().port;
    if(createTestAccountHandlers){
      testHandlers=createTestAccountHandlers('http://localhost:'+boundPort);
      for(const endpoint of ['/api/v1/onboarding/context',
        '/api/v1/legal/consents','/api/v1/airlines']){
        if(typeof testHandlers?.[endpoint]!=='function'){
          throw new Error('All local test account handlers are required.');
        }
      }
    }
    return Object.freeze({
      origin:'http://localhost:'+boundPort,
      port:boundPort,
      close:()=>new Promise((resolve,reject)=>
        server.close(error=>error?reject(error):resolve()))
    });
  } catch(error) {
    server.close();
    throw error;
  }
}

if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  startLocalAuthPreview().then(server=>{
    console.log('Airlinerra LOCAL AUTH ONLY: '+server.origin+'/account.html');
    console.log('Supabase Auth and Mailpit must be running locally. Never use real customer credentials.');
  }).catch(error=>{
    console.error('Local-only Auth preview unavailable: '+error.message);
    process.exitCode=1;
  });
}
