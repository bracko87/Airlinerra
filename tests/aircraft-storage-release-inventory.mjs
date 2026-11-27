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
