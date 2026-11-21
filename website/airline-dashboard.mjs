/** Authenticated airline overview renderer.
 * The only connected figures today are the owned airline cash and its
 * owner-scoped ledger. Never substitute imaginary flights or traffic.
 */
import {renderFinancialCharts} from './airline-finance-charts.mjs';
export const AIRLINERRA_WORLD_NAMES=Object.freeze({
 1:'Horizon',2:'Atlas',3:'Odyssey'
});
export function worldDisplayName(id,worlds=[]){
 const n=Number(id);
 const live=Array.isArray(worlds)?worlds.find(w=>Number(w?.id)===n):null;
 return typeof live?.name==='string'&&live.name.trim()?live.name.trim():
  AIRLINERRA_WORLD_NAMES[n]||'Game world';
}
export function dashboardMoney(value){
 const amount=Number(value);
 return typeof value!=='string'&&typeof value!=='number'||!Number.isFinite(amount)
  ?'-':new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',
     maximumFractionDigits:0,minimumFractionDigits:0}).format(amount);
}
export function normalizeDashboardLedger(entries){
 if(!Array.isArray(entries))return null;
 return entries.slice(0,5).filter(entry=>
  typeof entry?.kind==='string'&&/^[A-Z][A-Z0-9_]{0,40}$/.test(entry.kind)&&
  (typeof entry?.amountUsd==='string'||typeof entry?.amountUsd==='number')&&
  Number.isFinite(Number(entry.amountUsd))&&
  typeof entry?.recordedAt==='string'&&Number.isFinite(Date.parse(entry.recordedAt))
 ).map(entry=>Object.freeze({kind:entry.kind,amountUsd:String(entry.amountUsd),
  recordedAt:entry.recordedAt}));
}
export function renderCompanyNews(doc,airline,worlds,entries){
 const root=doc.getElementById('dashboard-news-items');if(!root)return;
 root.replaceChildren();
 if(!airline?.name){const p=doc.createElement('p');p.className='dashboard-data-note';p.textContent='Connect an airline to view recorded company milestones.';root.append(p);return;}
 const event=Array.isArray(entries)?entries.find(e=>e.kind==='STARTING_CAPITAL'&&Number.isFinite(Date.parse(e.recordedAt))):null;
 // Two compact rows: verified date - headline; a short one/two-line summary.
 // No icon, invented timestamp, or additional status copy inside the story.
 const row=doc.createElement('article');row.className='dashboard-company-story';
 const heading=doc.createElement('div');heading.className='dashboard-company-story-heading';
 if(event){
  const time=doc.createElement('time');const date=new Date(event.recordedAt);
  time.dateTime=date.toISOString();
  time.textContent=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Berlin',
   day:'2-digit',month:'short',year:'numeric'}).format(date);
  heading.append(time);
 }else{
  const unknown=doc.createElement('span');unknown.className='dashboard-company-date-missing';
  unknown.textContent='Date unavailable';heading.append(unknown);
 }
 const separator=doc.createElement('span');separator.className='dashboard-company-story-separator';
 separator.textContent=' - ';
 const title=doc.createElement('span');title.className='dashboard-company-story-title';
 title.textContent=airline.name+' registered on '+worldDisplayName(airline.worldId,worlds);
 heading.append(separator,title);
 const description=doc.createElement('p');description.className='dashboard-company-story-description';
 description.textContent=event?
  'Opening capital recorded. You can now plan your fleet and network.':
  'Your airline is registered. More company milestones will appear when recorded.';
 row.append(heading,description);root.append(row);
}
/** Render only validated, server-generated experience data. Empty history is not a satisfaction score. */
export function renderPassengerReputation(doc,airline){
 const $=id=>doc.getElementById(id);
 const p=airline?.passengerReputation;
 const valid=p&&typeof p.reputation==='number'&&Number.isFinite(p.reputation)&&p.reputation>=0&&p.reputation<=100&&Number.isSafeInteger(p.passengerExperiences)&&p.passengerExperiences>=0;
 const format=v=>new Intl.NumberFormat('en-US',{maximumFractionDigits:1}).format(v);
 const put=(id,value)=>{const node=$(id);if(node)node.textContent=value;};
 put('dashboard-reputation',valid?format(p.reputation)+' / 100':'Not available');
 put('dashboard-satisfaction',valid&&p.passengerExperiences>0&&typeof p.averageSatisfaction==='number'&&Number.isFinite(p.averageSatisfaction)&&p.averageSatisfaction>=0&&p.averageSatisfaction<=100?format(p.averageSatisfaction)+' / 100':'No experiences yet');
 if(!valid)put('dashboard-satisfaction','Not available');
 put('dashboard-experience-count',valid?new Intl.NumberFormat('en-US').format(p.passengerExperiences):'-');
 const measured=valid&&p.demandEffectEnabled===true&&typeof p.potentialDemandMultiplier==='number'&&Number.isFinite(p.potentialDemandMultiplier)&&p.potentialDemandMultiplier>=0.75&&p.potentialDemandMultiplier<=1.15;
 const pct=measured?(p.potentialDemandMultiplier-1)*100:0;
 put('dashboard-reputation-demand',measured?(Math.abs(pct)<0.005?'Neutral':(pct>0?'+':'')+format(pct)+'%'):valid?'Not activated':'Not available');
 put('dashboard-reputation-note',!valid?'Reputation data is not available.':p.passengerExperiences===0?'Starting reputation. No recorded passenger experiences yet.': 'Based on passenger-weighted flight and disruption experiences over the last 90 game days.');
 const meter=$('dashboard-reputation-meter');
 if(meter){meter.hidden=!valid;if(valid)meter.value=p.reputation;}
}
export function renderAirlineDashboard(doc,{airline=null,worlds=[],ledgerEntries=null}={}){
 renderPassengerReputation(doc,airline);
 const $=id=>doc.getElementById(id);
 if($('dashboard-finance-cash'))
  $('dashboard-finance-cash').textContent=airline?.cashUsd!==undefined?
   dashboardMoney(airline.cashUsd):'-';
 // Keep all operational status fields explicit until the corresponding
 // authenticated production engines exist. A missing feed does not mean zero.
 for(const id of ['dashboard-passengers','dashboard-cargo','dashboard-served-airports',
  'dashboard-active-routes','dashboard-completed-flights',
  'dashboard-finance-revenue','dashboard-finance-expenses','dashboard-finance-net']){
  const element=$(id);if(element)element.textContent='Not available';
 }
 const count=$('dashboard-flights-count');
 if(count)count.textContent='Not connected';
 const body=$('dashboard-flights-body');
 if(body){
  const tr=doc.createElement('tr'),cell=doc.createElement('td');
  cell.colSpan=5;cell.className='dashboard-empty-cell';
  cell.textContent='Flight tracking is not connected yet. Live flights will appear here when the operations engine is active.';
  tr.append(cell);body.replaceChildren(tr);
 }
 renderCompanyNews(doc,airline,worlds,ledgerEntries);
 renderFinancialCharts(doc,{cash:airline?.cashUsd??null,ledgerEntries});
}
