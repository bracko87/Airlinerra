import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {renderCompanyNews} from '../website/airline-dashboard.mjs';
import {FINANCE_CHART_COLORS,verifiedCashMix} from '../website/airline-finance-charts.mjs';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
function node(tag){
 return {tag,children:[],className:'',textContent:'',dateTime:'',
   append(...children){this.children.push(...children)},
   replaceChildren(...children){this.children=children}};
}
const dom=()=>{
 const items=node('div');
 return {items,doc:{createElement:node,getElementById:id=>id==='dashboard-news-items'?items:null}};
};
test('company newsletter is exactly date - headline, then at most two-line description; no icon',()=>{
 const {items,doc}=dom();
 renderCompanyNews(doc,{name:'Panonian',worldId:1},[{id:1,name:'Horizon'}],
  [{kind:'STARTING_CAPITAL',amountUsd:'5000000.00',recordedAt:'2026-10-29T08:12:26Z'}]);
 assert.equal(items.children.length,1);
 const story=items.children[0];
 assert.equal(story.tag,'article');
 assert.equal(story.className,'dashboard-company-story');
 assert.equal(story.children.length,2);
 const heading=story.children[0];
 const [date,separator,title]=heading.children;
 assert.equal(date.tag,'time');
 assert.equal(date.textContent,'29 Oct 2026');
 assert.equal(separator.textContent,' - ');
 assert.equal(title.textContent,'Panonian registered on Horizon');
 const description=story.children[1];
 assert.equal(description.tag,'p');
 assert.equal(description.className,'dashboard-company-story-description');
 assert.match(description.textContent,/Opening capital recorded/);
 assert.ok(!JSON.stringify(story).includes('dashboard-company-story-mark'));
});
test('without financial milestone, news does not fabricate a date',()=>{
 const {items,doc}=dom();
 renderCompanyNews(doc,{name:'Panonian',worldId:1},[{id:1,name:'Horizon'}],[]);
 assert.equal(items.children[0].children[0].children[0].textContent,'Date unavailable');
});
test('Airlinerra finance palette is bright blue and orange; no fictional expense slice',async()=>{
 assert.deepEqual(FINANCE_CHART_COLORS,{income:'#1976bf',expenses:'#ff741f'});
 const mix=verifiedCashMix('5000000.00',[{kind:'STARTING_CAPITAL',
  amountUsd:'5000000.00',recordedAt:'2026-10-29T08:12:26Z'}]);
 assert.equal(mix.costs,0);
 assert.equal(mix.cashShare,1);
 const script=await read('../website/airline-finance-charts.mjs');
 assert.match(script,/stroke:FINANCE_CHART_COLORS\.income/);
 assert.match(script,/stroke:FINANCE_CHART_COLORS\.expenses/);
 assert.match(script,/mix\.costs>0&&mix\.total>0/);
});
test('new operations menu begins with hub review and continues to routes',async()=>{
 const html=await read('../website/private-player-app.html');
 const section=html.slice(html.indexOf('data-nav-group="operations"'),
  html.indexOf('data-nav-group="fleet"'));
 assert.deepEqual([...section.matchAll(/data-view-link="([^"]+)"/g)].map(m=>m[1]),
  ['hubs','route-list','routes','schedule','service','tickets','staff']);
 assert.doesNotMatch(section,/data-view-link="airline"/);
});
test('consistent medium-weight compact design across app, public, account and legal pages',async()=>{
 const paths=[
  '../website/player-app.css','../website/styles.css','../website/register.css',
  '../website/account.css','../website/legal.css','../website/studio-footer.css'
 ];
 const css=await Promise.all(paths.map(read));
 assert.match(css[0],/--manager-card-gap:18px/);
 assert.match(css[0],/\.dashboard-company-story-description\{[^}]*-webkit-line-clamp:2/);
 assert.match(css[0],/\.nav-links a\{font-weight:550/);
 assert.match(css[0],/\.dashboard-donut-key\{background:var\(--finance-blue\)/);
 for(let i=1;i<css.length;i++)
  assert.match(css[i],/font-weight:(?:570|600|610|630|640|650|660|670|680|690|700|720|730|750)/,
   'Expected medium typography in '+paths[i]);
});
