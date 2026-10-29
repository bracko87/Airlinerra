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
function renderCompanyNews(doc,airline,worlds,entries){
 const root=doc.getElementById('dashboard-news-items');if(!root)return;
 root.replaceChildren();
 if(!airline?.name){const p=doc.createElement('p');p.className='dashboard-data-note';p.textContent='Connect an airline to view recorded company milestones.';root.append(p);return;}
 const event=Array.isArray(entries)?entries.find(e=>e.kind==='STARTING_CAPITAL'&&Number.isFinite(Date.parse(e.recordedAt))):null;
 const row=doc.createElement('div');row.className='dashboard-company-story';
 const mark=doc.createElement('span');mark.className='dashboard-company-story-mark';mark.textContent='A';
 const body=doc.createElement('div'),title=doc.createElement('strong'),desc=doc.createElement('p');
 title.textContent=airline.name+' registered on '+worldDisplayName(airline.worldId,worlds);
 desc.textContent=event?'Opening capital was recorded. You can plan your network and fleet.':'Your airline is verified. New milestones will appear when recorded.';
 body.append(title,desc);
 if(event){const time=doc.createElement('time');time.dateTime=new Date(event.recordedAt).toISOString();
 time.textContent=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Berlin',day:'2-digit',month:'short',year:'numeric'}).format(new Date(event.recordedAt));body.append(time);}
 row.append(mark,body);root.append(row);
 const note=doc.createElement('p');note.className='dashboard-data-note';note.textContent='Live operational bulletins are not connected yet.';root.append(note);
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
