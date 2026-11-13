/** Shared read-only seat-plan profile for model, used-lot and owned aircraft.
 * All displayed cabin data come from model defaults or persistent installed
 * snapshots. No editing, bidding, purchasing, refit or finance actions.
 */
import {
 standardCabinPlan,evaluateCabinPlan,renderCabinFloorplan,
 createPassengerRatingGauge,updatePassengerRatingGauge
} from './cabin-configuration-manager.mjs';

const DEFAULT_TYPES=Object.freeze([
 {code:'eco_standard',cabinClass:'economy',pitchInches:'31',spaceUnits:'1',installUsd:0},
 {code:'premium_standard',cabinClass:'premium',pitchInches:'38',spaceUnits:'1.5',installUsd:0},
 {code:'business_standard',cabinClass:'business',pitchInches:'45',spaceUnits:'2',installUsd:0},
 {code:'first_standard',cabinClass:'first',pitchInches:'55',spaceUnits:'3',installUsd:0}
]);
const classes=[['economy','Economy'],['premium','Premium Economy'],
 ['business','Business'],['first','First Class']];
const number=(value,max=850)=>{
 if(value===null||value===undefined||value==='')return null;
 const n=Number(value);
 return Number.isInteger(n)&&n>=0&&n<=max?n:null;
};
const text=(doc,tag,cls,value)=>{
 const node=doc.createElement(tag);
 if(cls)node.className=cls;
 node.textContent=String(value??'');
 return node;
};
/** Return null rather than invent missing per-tail seats. */
export function normalizeCabinPreview({useType,cabin,referenceUnits,seatTypes}={}){
 if(useType==='cargo'||!cabin||typeof cabin!=='object')return null;
 const units=Number(referenceUnits??cabin.referenceUnits);
 if(!Number.isFinite(units)||units<=0||units>850)return null;
 const counts=Object.fromEntries(classes.map(([key])=>[key,number(cabin[key])]));
 if(Object.values(counts).some(x=>x===null)||!Object.values(counts).some(x=>x>0))
  return null;
 const definitions=Array.isArray(seatTypes)&&seatTypes.length?seatTypes:DEFAULT_TYPES;
 const standard=standardCabinPlan(counts.economy,definitions);
 const plan={...standard,...counts,
  extraLegroomCm:Number(cabin.extraLegroomCm??0),
  economyType:cabin.economyType||standard.economyType,
  premiumType:cabin.premiumType||standard.premiumType,
  businessType:cabin.businessType||standard.businessType,
  firstType:cabin.firstType||standard.firstType};
 // For a user cabin, a missing actual seat model is NOT replaced with a guess.
 if(classes.some(([key])=>counts[key]>0&&
  !definitions.some(s=>s.code===plan[key+'Type']&&s.cabinClass===key)))
  return null;
 const evaluation=evaluateCabinPlan(plan,definitions,units);
 return {plan,evaluation,definitions,referenceUnits:units};
}

export function createReadonlyCabinViewer({doc}={}){
 if(!doc?.body)throw Error('Read-only aircraft cabin requires a document body');
 const dialog=doc.createElement('dialog');
 dialog.className='airlinerra-cabin-readonly';
 dialog.setAttribute('aria-label','Aircraft cabin configuration viewer');
 const shell=text(doc,'div','airlinerra-cabin-readonly-shell','');
 dialog.append(shell);
 doc.body.append(dialog);
 dialog.addEventListener('click',event=>{if(event.target===dialog)dialog.close()});
 function show({title='Aircraft cabin',useType,cabin,referenceUnits,seatTypes,
   geometry=null,origin='model_default',details=[]}={}){
  shell.replaceChildren();
  const head=text(doc,'div','airlinerra-cabin-readonly-head','');
  const titles=text(doc,'div','airlinerra-cabin-readonly-titles','');
  titles.append(text(doc,'h2','',title),
   text(doc,'p','hint','Installed cabin configuration · View only'));
  const close=text(doc,'button','secondary','Close');
  close.type='button';close.addEventListener('click',()=>dialog.close());
  head.append(titles,close);shell.append(head);
  const profile=normalizeCabinPreview({useType,cabin,referenceUnits,seatTypes});
  if(useType==='cargo'){
   shell.append(text(doc,'p','hint','Cargo-only aircraft have no passenger cabin.'));
  }else if(!profile){
   shell.append(text(doc,'p','hint',
    'A verified seat-by-class layout is not available for this aircraft. No passenger rating is calculated.'));
  }else{
   const provenance=origin==='previous_owner'||
    (origin&&origin!=='model_default'&&origin!=='catalog_standard_game_layout')?
    'User configuration · Last installed cabin':'Default cabin · Model reference';
   shell.append(text(doc,'p','airlinerra-cabin-readonly-origin',provenance));
   const grid=text(doc,'div','airlinerra-cabin-readonly-grid','');
   const plan=text(doc,'section','airlinerra-cabin-readonly-plan','');
   plan.append(text(doc,'h3','','Seating diagram'));
   const svg=doc.createElementNS('http://www.w3.org/2000/svg','svg');
   svg.classList.add('airlinerra-cabin-readonly-svg');
   renderCabinFloorplan(doc,svg,profile.plan,profile.evaluation,profile.referenceUnits,geometry);
   plan.append(svg);
   const info=text(doc,'section','airlinerra-cabin-readonly-information','');
   info.append(text(doc,'h3','','Seats by class'));
   for(const [key,label] of classes){
    const row=text(doc,'div','airlinerra-cabin-readonly-row','');
    row.append(text(doc,'span','',label),
     text(doc,'strong','',profile.plan[key].toLocaleString('en-US')));
    const seat=profile.evaluation.classes?.find(x=>x.key===key);
    if(seat&&seat.seats>0)row.append(text(doc,'small','',seat.style));
    info.append(row);
   }
   const total=text(doc,'div','airlinerra-cabin-readonly-total','');
   total.append(text(doc,'span','','Total passenger seats'),
    text(doc,'strong','',profile.evaluation.count.toLocaleString('en-US')));
   info.append(total);
   const gauge=createPassengerRatingGauge(doc);
   updatePassengerRatingGauge(gauge,profile.evaluation);
   info.append(gauge.root);
   if(!profile.evaluation.valid){
    info.append(text(doc,'p','hint',
     'This saved layout cannot be validated against the current game space model: '+
     profile.evaluation.reason));
   }
   grid.append(plan,info);shell.append(grid);
  }
  if(Array.isArray(details)&&details.length){
   const facts=text(doc,'section','airlinerra-cabin-readonly-facts','');
   facts.append(text(doc,'h3','','Aircraft details'));
   for(const item of details){
    if(!Array.isArray(item)||item.length!==2)continue;
    const row=text(doc,'div','airlinerra-cabin-readonly-fact','');
    row.append(text(doc,'span','',item[0]),text(doc,'strong','',item[1]??'Not recorded'));
    facts.append(row);
   }
   shell.append(facts);
  }
  shell.append(text(doc,'p','hint',
   'Game seating illustration, not a certified aircraft floor plan. Passenger rating is an estimated game score, not passenger happiness or actual feedback. Viewing does not change this aircraft.'));
  if(!dialog.open){
   if(typeof dialog.showModal==='function')dialog.showModal();
   else dialog.setAttribute('open','');
  }
  return !!profile;
 }
 return Object.freeze({show,close:()=>{if(dialog.open)dialog.close()}});
}
