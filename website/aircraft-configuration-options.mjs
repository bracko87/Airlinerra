/** Owner-scoped aircraft cabin configuration choices for the Aircraft Profile.
 * This module never installs seats, moves aircraft, books a refit, or posts money.
 * All alternatives come from the authenticated cabin-overview response.
 */
import {standardCabinPlan,evaluateCabinPlan} from './cabin-configuration-manager.mjs';

const counts=['economy','premium','business','first'];
const safeName=x=>typeof x==='string'&&x.length<=80?x:'';
const sameModel=(a,b)=>a&&b&&
 a.manufacturer===b.manufacturer&&a.model===b.model &&
 a.useType!=='cargo'&&b.useType!=='cargo';
const savedPlan=a=>{
 if(!Number.isSafeInteger(a?.draftEconomy))return null;
 const plan={};
 for(const key of counts){
  const v=a['draft'+key[0].toUpperCase()+key.slice(1)];
  const type=a['draft'+key[0].toUpperCase()+key.slice(1)+'Type'];
  if(!Number.isInteger(v)||v<0||typeof type!=='string')return null;
  plan[key]=v;plan[key+'Type']=type;
 }
 return plan;
};
const fingerprint=p=>counts.map(key=>p[key]+':'+p[key+'Type']).join('|');

export function companyCabinChoices(overview,aircraftId){
 if(!overview||!Array.isArray(overview.aircraft)||!Array.isArray(overview.seatTypes)||
    !Array.isArray(overview.refitSites)||overview.previewOnly!==true||
    overview.installedLayoutsImmutable!==true)return null;
 const target=overview.aircraft.find(a=>a.aircraftInventoryId===aircraftId);
 if(!target||target.useType==='cargo')return null;
 const choices=[];
 const std=standardCabinPlan(target.standardEconomy);
 const basicQuote=evaluateCabinPlan(std,overview.seatTypes,target.referenceUnits);
 choices.push({
  key:'default',label:'Default',source:'Model standard',
  plan:std,quote:basicQuote,available:basicQuote.valid
 });
 const seen=new Set([fingerprint(std)]);
 for(const source of overview.aircraft){
  if(!sameModel(source,target))continue;
  const plan=savedPlan(source);
  if(!plan)continue;
  const quote=evaluateCabinPlan(plan,overview.seatTypes,target.referenceUnits);
  const finger=fingerprint(plan);
  if(seen.has(finger))continue;
  seen.add(finger);
  choices.push({
   key:source.aircraftInventoryId,
   label:'Company layout · '+safeName(source.registration),
   source:'Saved draft in this airline',
   plan,quote,available:quote.valid
  });
 }
 const sites=overview.refitSites.filter(row=>
  row.aircraftInventoryId===aircraftId && typeof row.airportKey==='string' &&
  typeof row.provider==='string');
 return {aircraftId,manufacturer:target.manufacturer,model:target.model,
  installed:{economy:target.installedEconomy,premium:target.installedPremium,
   business:target.installedBusiness,first:target.installedFirst},
  choices,sites,canBookRefit:false,approvedSlot:null};
}
export function configurationCostPreview(choice,site){
 if(!choice||choice.quote?.valid!==true)return {
  valid:false,message:choice?.quote?.reason||'No valid aircraft layout selected.'
 };
 const q=choice.quote;
 const siteName=site?(safeName(site.airportName)||safeName(site.airportCode)||'Approved facility')+
  ' · '+safeName(site.provider):null;
 return {valid:true,seatCount:q.count,spaceUsed:q.used,
  spaceAvailable:q.available,
  equipmentUsd:q.equipmentUsd,downtimeHours:q.refitHours,
  siteName,labourCostUsd:null,totalFinalCostUsd:null,
  firstAvailableSlot:null,canBook:false,
  status:'Planning estimate only. Labour, flight availability and refit slots are not confirmed.'};
}
