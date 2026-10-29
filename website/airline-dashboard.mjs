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
 renderFinancialCharts(doc,{cash:airline?.cashUsd??null,ledgerEntries});
}
