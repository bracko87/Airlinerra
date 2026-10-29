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
export function renderAirlineDashboard(doc,{airline=null,worlds=[],ledgerEntries=null}={}){
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
