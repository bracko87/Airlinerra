import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
test('production gameplay release gates remain closed',async()=>{
 const [model,client,page,build,overlay,site,netlify]=await Promise.all([
 read('../website/player-app-model.mjs'),read('../website/player-read-client.mjs'),
 read('../website/private-player-app.html'),read('../website/dev-scripts/build.mjs'),
 read('../website/dev-scripts/invited-overlay.mjs'),read('../website/dev-scripts/dev.mjs'),
 read('../netlify.toml')
 ]);
 assert.match(model,/AIRLINE_CREATION_ENABLED=false/);
 assert.match(model,/GAME_READ_API_CONNECTED=false/);
 assert.match(client,/PLAYER_READ_API_ENABLED=false/);
 assert.match(page,/id="setup-create-airline" disabled>Create airline/);
 assert.match(page,/No balance is credited by loading this page/);
 assert.match(site,/process\.argv\.includes\('--built'\)/);
 assert.doesNotMatch(netlify,/\[functions\]/);
 assert.doesNotMatch(build,/dev-data|local-preview-catalog/);
 assert.doesNotMatch(overlay,/dev-data|local-preview-catalog/);
 assert.doesNotMatch(page,/service_role|sb_secret_/);
});
