import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {REAL_PLAYER_PATHS,makeRealLocalPlayerHandler} from './real-player-read-gateway.mjs';

const sourceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = process.argv.includes('--built') ? path.resolve(sourceRoot,'../dist') : sourceRoot;
const port = Number(process.env.PORT || (process.argv.includes('--built') ? 5188 : 5187));
const isBuilt=process.argv.includes('--built');
const localApiEnabled=isBuilt&&port===5188;
const useLocalDb=process.argv.includes('--local-db');
const realPlayerHandler=localApiEnabled
  ?await makeRealLocalPlayerHandler({env:{
    ...process.env,AIRLINERRA_LOCAL_USE_DATABASE:useLocalDb?'1':'0'
  }}):null;
const types = {'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.svg':'image/svg+xml','.webp':'image/webp','.png':'image/png','.ico':'image/x-icon'};
createServer(async (req, res) => {
  try {
    let pathname = decodeURIComponent(new URL(req.url || '/', 'http://localhost').pathname);
    if (pathname === '/') pathname = '/index.html';
    if (pathname === '/health') pathname = '/health.html';
    if(REAL_PLAYER_PATHS.includes(pathname)){
      if(!realPlayerHandler||port!==5188||
        req.headers.host!=='localhost:5188'){
        res.writeHead(403).end('Local-only API');return;
      }
      let size=0;
      const chunks=[];
      for await(const chunk of req){
        size+=chunk.length;
        if(size>2048){res.writeHead(413).end('Body too large');return;}
        chunks.push(chunk);
      }
      const request=new Request('http://localhost:5188'+pathname,{
        method:req.method,headers:{
          origin:req.headers.origin||'',
          authorization:req.headers.authorization||'',
          'content-type':req.headers['content-type']||''
        },body:req.method==='POST'?Buffer.concat(chunks):undefined
      });
      const response=await realPlayerHandler(request);
      res.writeHead(response.status,Object.fromEntries(response.headers.entries()));
      res.end(await response.text());return;
    }
    const filename = path.resolve(root, '.' + pathname);
    if (!filename.startsWith(root + path.sep)) { res.writeHead(403).end('Forbidden'); return; }
    if (!(await stat(filename)).isFile()) { res.writeHead(404).end('Not found'); return; }
    const body = await readFile(filename);
    res.writeHead(200, { 'Content-Type': types[path.extname(filename)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end(body);
  } catch { res.writeHead(404).end('Not found'); }
}).listen(port, '127.0.0.1', () => {
  console.log(`Airlinerra ${isBuilt?'built-site preview':'source development'} server: http://localhost:${port}`);
  if(localApiEnabled)console.log(useLocalDb
    ?'API mode: explicit private PostgreSQL development adapter'
    :'API mode: production Supabase game data, authenticated READ ONLY. Airline creation is disabled locally.');
});
