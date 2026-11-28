import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
const manifest=JSON.parse(readFileSync('docs/aircraft-storage-release-manifest.json','utf8'));
const billing=JSON.parse(readFileSync('docs/aircraft-storage-billing-class-candidates.json','utf8'));
assert.equal(manifest.productionAuthorized,false);
assert.equal(manifest.executionMode,'inventory_only');
assert.equal(manifest.status,'candidate_order_unverified');
const components=manifest.groups.flatMap(g=>g.components).concat(manifest.separateReview);
const paths=components.map(c=>c.path);
assert.equal(paths.length,new Set(paths).size,'Duplicate component');
assert.deepEqual([...paths].sort(),readdirSync('server/sql').filter(x=>/^aircraft_storage_.*\.sql$/.test(x)).map(x=>'server/sql/'+x).sort(),'Inventory completeness');
for(const c of components){
 const bytes=readFileSync(c.path);
 const actual=createHash('sha1').update('blob '+bytes.length+'\0').update(bytes).digest('hex');
 assert.equal(actual,c.gitBlobSha,'SQL revision drift: '+c.path);
}
assert.equal(billing.status,'proposed_game_balance_review_not_approved');
const ids=new Set(),totals={regional:0,narrowbody:0,widebody:0},counts={regional:0,narrowbody:0,widebody:0};
for(const f of billing.families){
 assert.ok(Number.isSafeInteger(f.family_id)&&f.family_id>0);
 assert.ok(!ids.has(f.family_id),'Duplicate aircraft family');
 ids.add(f.family_id);
 assert.ok(f.family_name&&f.manufacturer_name);
 assert.ok(Object.hasOwn(totals,f.billingClass));
 assert.ok(Number.isSafeInteger(f.configurations)&&f.configurations>0);
 totals[f.billingClass]+=f.configurations;
 counts[f.billingClass]++;
}
assert.equal(ids.size,81);
assert.deepEqual(totals,{regional:129,narrowbody:75,widebody:67});
assert.deepEqual(counts,{regional:46,narrowbody:19,widebody:16});
console.log('PASS pinned '+paths.length+' storage SQL components; complete inventory and exact Git blob revisions');
console.log('PASS proposed pricing classification: 81 families, 271 configurations; production not authorized');

const familyBytes=readFileSync('docs/aircraft-storage-billing-class-candidates.json');
const configurationReview=JSON.parse(readFileSync('docs/aircraft-storage-billing-configuration-candidates.json','utf8'));
assert.equal(configurationReview.status,'proposed_game_balance_review_not_approved');
assert.equal(configurationReview.catalogueDate,billing.catalogueDate);
assert.equal(configurationReview.familyMappingBlob,createHash('sha1').update('blob '+familyBytes.length+'\0').update(familyBytes).digest('hex'),'Family review drift');
const configurationIds=new Set(),familyCounts=new Map(),families=new Map(billing.families.map(f=>[f.family_id,f]));
for(const c of configurationReview.configurations){
 assert.ok(Number.isSafeInteger(c.configuration_id)&&c.configuration_id>0);
 assert.ok(Number.isSafeInteger(c.variant_id)&&c.variant_id>0);
 assert.ok(typeof c.configuration_code==='string'&&c.configuration_code.length>0);
 assert.ok(!configurationIds.has(c.configuration_id),'Duplicate configuration ID');
 configurationIds.add(c.configuration_id);
 assert.ok(families.has(c.family_id),'Unknown aircraft family');
 assert.equal(c.billingClass,families.get(c.family_id).billingClass,'Family/class mismatch: '+c.configuration_id);
 familyCounts.set(c.family_id,(familyCounts.get(c.family_id)||0)+1);
}
assert.equal(configurationIds.size,271);
for(const f of billing.families) assert.equal(familyCounts.get(f.family_id),f.configurations,'Family configuration count mismatch');
const seedSql=readFileSync('server/sql/aircraft_storage_billing_class_staging_review.sql','utf8');
const seedBlock=seedSql.split('INSERT INTO airlinerra_game.storage_billing_class_candidates_v1 VALUES\n');
assert.equal(seedBlock.length,2);
const lines=seedBlock[1].slice(0,seedBlock[1].indexOf(';')+1).trim().split('\n');
const sqlRows=lines.map(line=>{
 const match=line.match(/^\((\d+),(\d+),(\d+),'([^']+)','(regional|narrowbody|widebody)'\)[,;]$/);
 assert.ok(match,'Unrecognized configuration seed row');
 return {configuration_id:Number(match[1]),family_id:Number(match[2]),variant_id:Number(match[3]),configuration_code:match[4],billingClass:match[5]};
});
assert.deepEqual(sqlRows.sort((a,b)=>a.configuration_id-b.configuration_id),[...configurationReview.configurations].sort((a,b)=>a.configuration_id-b.configuration_id),'SQL seed differs from reviewed configuration inventory');
console.log('PASS exact 271-row billing seed matches all 81 reviewed families and configuration identities');
