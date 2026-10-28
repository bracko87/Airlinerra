import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {handleLocalCatalogRequest,LOCAL_CATALOG_PATHS} from './local-preview-catalog.mjs';

const sourceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = process.argv.includes('--built') ? path.resolve(sourceRoot,'../dist') : sourceRoot;
const port = Number(process.env.PORT || (process.argv.includes('--built') ? 5188 : 5187));
const types = {'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.svg':'image/svg+xml','.webp':'image/webp','.png':'image/png','.ico':'image/x-icon'};
createServer(async (req, res) => {
  try {
    let pathname = decodeURIComponent(new URL(req.url || '/', 'http://localhost').pathname);
    if (pathname === '/') pathname = '/index.html';
    if (pathname === '/health') pathname = '/health.html';
    if(Object.values(LOCAL_CATALOG_PATHS).includes(pathname)){
      if(!process.argv.includes('--built')||port!==5188||
         !['localhost:5188','127.0.0.1:5188'].includes(req.headers.host||'')){
        res.writeHead(403).end('Local preview only');return;
      }
      const origin='http://'+req.headers.host;
      let size=0;const chunks=[];
      for await(const chunk of req){
        size+=chunk.length;
        if(size>512){res.writeHead(413).end('Too large');return;}
        chunks.push(chunk);
      }
      const request=new Request(origin+pathname,{
        method:req.method,headers:{
          origin:req.headers.origin||'',
          'content-type':req.headers['content-type']||''
        },
        body:req.method==='POST'?Buffer.concat(chunks):undefined
      });
      const response=await handleLocalCatalogRequest(request);
      res.writeHead(response.status,Object.fromEntries(response.headers.entries()));
      res.end(await response.text());return;
    }
    // This simulated email/registration UI is served only by the loopback
    // built-site preview. It is never copied into the Netlify build output.
    const localRegistrationFiles={
      '/__local_registration__/':'registration.html',
      '/__local_registration__/registration.mjs':'registration.mjs',
      '/__local_registration__/state.mjs':'state.mjs',
      '/__local_registration__/style.css':'style.css'
    };
    if(Object.hasOwn(localRegistrationFiles,pathname)){
      if(!process.argv.includes('--built')||port!==5188||
         !['localhost:5188','127.0.0.1:5188'].includes(req.headers.host||'')||
         req.method!=='GET'){
        res.writeHead(403).end('Local preview only');return;
      }
      const file=path.resolve(sourceRoot,'dev-only',localRegistrationFiles[pathname]);
      const body=await readFile(file);
      res.writeHead(200,{
        'Content-Type':types[path.extname(file)]||'text/html; charset=utf-8',
        'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',
        'Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'"
      });
      res.end(body);return;
    }
    const filename = path.resolve(root, '.' + pathname);
    if (!filename.startsWith(root + path.sep)) { res.writeHead(403).end('Forbidden'); return; }
    if (!(await stat(filename)).isFile()) { res.writeHead(404).end('Not found'); return; }
    const body = await readFile(filename);
    res.writeHead(200, { 'Content-Type': types[path.extname(filename)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end(body);
  } catch { res.writeHead(404).end('Not found'); }
}).listen(port, '127.0.0.1', () => console.log(`Airlinerra ${process.argv.includes('--built')?'built-site preview':'source development'} server: http://localhost:${port}`));
