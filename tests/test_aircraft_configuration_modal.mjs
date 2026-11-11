import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {companyCabinChoices,configurationCostPreview}
 from '../website/aircraft-configuration-options.mjs';
import {standardCabinPlan} from '../website/cabin-configuration-manager.mjs';
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
const types=[
 ['eco_standard','economy',1,850],['premium_standard','premium',1.5,1700],
 ['business_standard','business',2,3000],['first_standard','first',3,5000]
].map(([code,cabinClass,spaceUnits,installUsd])=>({code,cabinClass,spaceUnits,installUsd,
 pitchInches:cabinClass==='economy'?30:cabinClass==='premium'?38:cabinClass==='business'?44:60}));
const uuid=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const base={aircraftInventoryId:uuid(1),manufacturer:'Airbus',model:'A319-100',
 useType:'passenger',referenceUnits:'156',standardEconomy:156,
 installedEconomy:156,installedPremium:0,installedBusiness:0,installedFirst:0};
const saved={...base,aircraftInventoryId:uuid(2),registration:'YU-PAN02',
 draftEconomy:112,draftPremium:0,draftBusiness:22,draftFirst:0,
 draftEconomyType:'eco_standard',draftPremiumType:'premium_standard',
 draftBusinessType:'business_standard',draftFirstType:'first_standard'};
const differentModel={...saved,aircraftInventoryId:uuid(3),registration:'YU-A320',
 model:'A320-200'};
const foreign={...saved,aircraftInventoryId:uuid(4),registration:'FOREIGN'};
function source(aircraft=[base,saved,differentModel],refitSites=[]){
 return {airlineId:uuid(9),aircraft,seatTypes:types,refitSites,
 previewOnly:true,installedLayoutsImmutable:true,canActivateRefit:false};
}
test('only exact owned model drafts appear, with a protected Default option',()=>{
 const x=companyCabinChoices(source(),base.aircraftInventoryId);
 assert.equal(x.choices[0].key,'default');
 assert.equal(x.choices[0].label,'Default');
 assert.deepEqual(x.choices.map(y=>y.key),['default',uuid(2)]);
 assert.equal(x.choices[1].available,true);
 assert.equal(x.choices[1].quote.count,134);
 assert.equal(x.canBookRefit,false);
 assert.equal(x.approvedSlot,null);
});
test('same airline but incompatible cabin capacity cannot be selected',()=>{
 const big={...saved,aircraftInventoryId:uuid(5),registration:'YU-BIG',
 draftEconomy:150,draftBusiness:50};
 const x=companyCabinChoices(source([base,big]),base.aircraftInventoryId);
 assert.equal(x.choices[1].available,false);
 assert.match(x.choices[1].quote.reason,/NO SPACE/);
});
test('unverified owner data is never rendered, no foreign-airline injection path',()=>{
 assert.equal(companyCabinChoices({...source(),previewOnly:false},base.aircraftInventoryId),null);
 assert.equal(companyCabinChoices({...source(),installedLayoutsImmutable:false},base.aircraftInventoryId),null);
 assert.equal(companyCabinChoices(source(),uuid(999)),null);
 assert.equal(companyCabinChoices(source([base,differentModel]),base.aircraftInventoryId).choices.length,1);
});
test('quote shows game estimated total equipment and refit labour, never a confirmed cost or slot',()=>{
 const site={aircraftInventoryId:base.aircraftInventoryId,airportKey:'airport:1',
  airportCode:'HAM',provider:'Approved game MRO',siteMultiplier:'1.2'};
 const x=companyCabinChoices(source([base,saved], [site]),base.aircraftInventoryId);
 const quote=configurationCostPreview(x.choices[1],x.sites[0],156);
 assert.equal(quote.valid,true);
 assert.equal(quote.equipmentUsd,112*850+22*3000);
 assert.equal(quote.downtimeHours,48);
 assert.equal(quote.totalFinalCostUsd,null);
 assert.equal(quote.labourCostUsd,Math.round((5000+134*150+156*75)*1.2));
 assert.equal(quote.indicativeTotalUsd,quote.equipmentUsd+quote.labourCostUsd);
 assert.equal(quote.chargeTriggered,undefined);
 assert.equal(quote.firstAvailableSlot,null);
 assert.equal(quote.canBook,false);
 assert.match(quote.siteName,/HAM/);
});
test('Aircraft Profile swaps columns, moves seats/cargo to lower specs, and never offers a fake booking',async()=>{
 const [workspace,modal,css,bundle]=await Promise.all([
  read('website/airline-workspace.mjs'),
  read('website/aircraft-configuration-dialog.mjs'),
  read('website/player-app.css'),
  read('website/dev-scripts/invited-overlay.mjs')
 ]);
 const left=workspace.indexOf('class="fleet-aircraft-identity-panel"');
 const right=workspace.indexOf('class="fleet-aircraft-image-panel"');
 assert.ok(left>0&&right>left,'aircraft data must appear on the left');
 const top=workspace.slice(left,workspace.indexOf('id="fleet-maintenance-preview"'));
 assert.ok(top.indexOf('id="fleet-detail-seats"')>
  top.indexOf('Airframe condition and usage'),'seats must be below');
 assert.ok(top.indexOf('id="fleet-detail-cargo"')>top.indexOf('Airframe condition and usage'));
 assert.ok(!workspace.includes('id="fleet-detail-status"'));
 assert.ok(!workspace.includes("'fleet-detail-status':"));
 assert.match(workspace,/<strong id="fleet-detail-configuration">—<\/strong>/);
 assert.match(workspace,/id="fleet-configuration-change"/);
 assert.match(workspace,/id="fleet-configuration-dialog"/);
 assert.match(workspace,/aircraftConfigurationDialog\?\.open\(\)/);
 assert.match(workspace,/goTo\('cabin-configurations'\)/);
 assert.match(modal,/client\.cabinOverview\(ownerId\)/);
 assert.match(modal,/client\.saveCabinDraft\(/);
 assert.match(modal,/draft_saved_not_installed/);
 assert.doesNotMatch(modal,/scheduleRefit|bookRefit|debitCash|chargeAirline/);
 assert.match(css,/grid-template-columns:minmax\(0,1\.15fr\) minmax\(300px,\.85fr\)/);
 assert.match(css,/\.fleet-configuration-dialog::backdrop/);
 assert.match(bundle,/'aircraft-configuration-options\.mjs'/);
 assert.match(bundle,/'aircraft-configuration-dialog\.mjs'/);
});

test('a named A319 model design is reusable from the matching aircraft profile',()=>{
 const named={designId:uuid(88),configurationId:16,name:'A319 Business Light',
  economy:132,premium:0,business:8,first:0,
  economyType:'eco_standard',premiumType:'premium_standard',
  businessType:'business_standard',firstType:'first_standard',
  extraLegroomCm:'0'};
 const target={...base,configurationId:16};
 const other={...differentModel,configurationId:32};
 const overview={...source([target,other]),modelDesigns:[named]};
 const x=companyCabinChoices(overview,target.aircraftInventoryId);
 assert.deepEqual(x.choices.map(x=>x.label),['Default','A319 Business Light']);
 assert.equal(x.choices[1].source,'Saved named model configuration');
 assert.equal(x.choices[1].available,true);
 assert.equal(x.choices[1].quote.count,140);
 const wrong=companyCabinChoices(overview,other.aircraftInventoryId);
 assert.deepEqual(wrong.choices.map(x=>x.label),['Default']);
});
