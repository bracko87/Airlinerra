import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('Aircraft Profile uses the same main My routes panel and flat rows, not boxed dashboard cards',async()=>{
 const [workspace,css,operations]=await Promise.all([
  read('website/airline-workspace.mjs'),read('website/player-app.css'),
  read('website/airline-operations-center.mjs')]);
 assert.ok(workspace.includes("'fleet-aircraft':()=>card('Aircraft details'"));
 assert.ok(operations.includes("card('My routes'"));
 for(const id of ['fleet-aircraft-image','fleet-aircraft-image-save','fleet-aircraft-image-reset',
  'fleet-detail-manufacture-year','fleet-detail-condition','fleet-detail-flight-hours',
  'fleet-detail-mtow','fleet-detail-range','fleet-detail-upfront','fleet-detail-monthly-lease',
  'fleet-maintenance-preview']){
   assert.ok(workspace.includes(id),'missing aircraft profile '+id);
 }
 assert.ok(workspace.includes('fleet-detail-row'));
 assert.ok(css.includes('.fleet-detail-grid>.fleet-detail-row'));
 assert.ok(css.includes('border-bottom:1px solid var(--line)'));
 assert.ok(css.includes('.fleet-aircraft-profile-top'));
 assert.ok(css.includes('.fleet-aircraft-image-frame'));
 assert.ok(css.includes('@media(max-width:620px)'));
 assert.doesNotMatch(css,/\.fleet-detail-grid>div\{background:#f5f8fc/);
});
test('aircraft picture is per-tail private and owner-verified, never shared between aircraft',async()=>{
 const [auth,migration,workspace]=await Promise.all([
  read('website/invited-tester-auth.mjs'),
  read('supabase/migrations/20261110185000_aircraft_per_tail_private_images.sql'),
  read('website/airline-workspace.mjs')]);
 for(const method of ['uploadAircraftImage','getAircraftImageUrl','removeAircraftImage'])
  assert.ok(auth.includes(method));
 assert.ok(auth.includes("user.id+'/'+airlineId+'/'+aircraftInventoryId+'/aircraft.webp'"));
 assert.ok(migration.includes('owner_player_id=auth.uid()'));
 assert.ok(migration.includes('JOIN airlinerra_game.airline_aircraft_inventory'));
 assert.ok(migration.includes('airlinerra-aircraft-images'));
 assert.ok(migration.includes('public=false'));
 assert.ok(workspace.includes('photoPendingId!==aircraft.id'));
 assert.ok(workspace.includes('selectedFleetAircraftId!==aircraftId'));
 assert.ok(workspace.includes('catalogPhotoUrl'));
});
test('verified model data and recorded costs are rendered with truthful missing-data labels',async()=>{
 const [fleet,workspace]=await Promise.all([
  read('server/fleet-acquisition-service.mjs'),read('website/airline-workspace.mjs')]);
 for(const field of ['catalogImagePath','catalogImageBucket','paidUpfrontUsd','recurringMonthlyUsd',
   'contractMonths','engineOption','mtowKg','rangeKm','cruiseSpeedKmh',
   'modelProductionStartYear','fleetAddedAt','verifiedTrackingStartedUtc'])
   assert.ok(fleet.includes(field),'private fleet API missing '+field);
 assert.ok(workspace.includes('updateAirframeDetails(rows[0])'));
 assert.ok(workspace.includes('fmtAircraftNumber'));
 assert.ok(workspace.includes('Not recorded'));
 assert.ok(workspace.includes('Not available — no verified tail valuation'));
 assert.ok(workspace.includes('Not calculated — no operated flights'));
 assert.ok(workspace.includes('canScheduleMaintenance!==false'));
 assert.ok(workspace.includes('maintenanceSites'));
});
test('real airline page receives image adapter; generic model art is never altered',async()=>{
 const [app,auth,client]=await Promise.all([
  read('website/player-app.mjs'),read('website/invited-tester-auth.mjs'),
  read('website/fleet-acquisition-client.mjs')]);
 assert.ok(app.includes('aircraftMedia:auth'));
 assert.ok(auth.includes("client.storage.from('airlinerra-aircraft-images')"));
 assert.ok(client.includes('maintenancePreview'));
 assert.ok(client.includes('updateNickname'));
});
