import test from 'node:test';
import assert from 'node:assert/strict';
import {createAirportOfficeClient,AIRPORT_OFFICE_DRAFT_API_ENABLED} from '../website/airport-office-client.mjs';
import {readFile} from 'node:fs/promises';
const ORIGIN='http://localhost:5188';
const auth={getAccessToken:async()=>'private-token-very-long'};
function harness(responses){
 const calls=[];
 const client=createAirportOfficeClient({auth,origin:ORIGIN,local:true,enabled:true,
  fetchImpl:async(url,request)=>{
   calls.push({url,...request});
   const next=responses.shift()||{status:503,body:{}};
   return {ok:next.status>=200&&next.status<300,status:next.status,
    json:async()=>next.body};
  }});
 return {client,calls};
}
test('client feature remains disabled and uses no database when off',async()=>{
 assert.equal(AIRPORT_OFFICE_DRAFT_API_ENABLED,false);
 let network=0;
 const client=createAirportOfficeClient({auth,origin:ORIGIN,local:true,
  fetchImpl:async()=>{network++;throw Error('unwanted network')}});
 await assert.rejects(client.list({worldId:1}),/not enabled/i);
 assert.equal(network,0);
 assert.throws(()=>createAirportOfficeClient({auth,origin:ORIGIN,local:false,enabled:true}));
});
test('browser client only uses same-origin bearer API; never transmits airline IDs or fees',async()=>{
 const h=harness([
  {status:200,body:{offices:[{key:'OURAIRPORTS:4344',type:'station',status:'draft',name:'Sarajevo'}]}},
  {status:201,body:{office:{key:'OURAIRPORTS:4344',type:'station',status:'draft'}}},
  {status:200,body:{removed:true}}
 ]);
 assert.equal((await h.client.list({worldId:1})).length,1);
 assert.equal((await h.client.save({worldId:1,airportKey:'OURAIRPORTS:4344',type:'station'})).type,'station');
 assert.equal(await h.client.remove({worldId:1,airportKey:'OURAIRPORTS:4344'}),true);
 assert.deepEqual(h.calls.map(c=>JSON.parse(c.body).operation),['list','save','remove']);
 for(const c of h.calls){
  assert.equal(c.url,ORIGIN+'/api/v1/player/airport-offices');
  assert.equal(c.credentials,'omit');
  assert.equal(c.headers.authorization,'Bearer private-token-very-long');
  assert.doesNotMatch(c.body,/airlineId|salary|fee|activate/);
 }
});
test('client rejects bad inputs before network, bad replies and unavailable API',async()=>{
 const h=harness([{status:503,body:{}},{status:200,body:{offices:[{type:'hub',status:'active'}]}}]);
 await assert.rejects(h.client.save({worldId:4,airportKey:'OURAIRPORTS:4344',type:'hub'}));
 await assert.rejects(h.client.remove({worldId:1,airportKey:'__bad'}));
 assert.equal(h.calls.length,0);
 await assert.rejects(h.client.list({worldId:1}),/unavailable/i);
 await assert.rejects(h.client.list({worldId:1}),/Invalid office directory/i);
});
test('browser workspace keeps local-only plans separate and build copies gated client',async()=>{
 const [office,operations,player,overlay]=await Promise.all([
  readFile(new URL('../website/airline-airports-office.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/airline-operations-center.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/dev-scripts/invited-overlay.mjs',import.meta.url),'utf8')
 ]);
 assert.match(office,/const localEntries=/);
 assert.match(office,/remoteEntries/);
 assert.match(office,/never transfer browser drafts at login/);
 assert.match(office,/officeClient\.save/);
 assert.match(office,/officeClient\.remove/);
 assert.match(operations,/airportOfficeController\?\.updateData\(value\)/);
 assert.match(player,/AIRPORT_OFFICE_DRAFT_API_ENABLED/);
 assert.match(overlay,/'airport-office-client.mjs'/);
});
