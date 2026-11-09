/**
 * Section 9 commercial planning editor for a protected route draft.
 * Marketing budgets are PLANNED only and cannot increase demand until a paid,
 * authoritative campaign activation is implemented elsewhere.
 */
export function createSection9CommercialPlanEditor({doc,host,getServer,onSaved}={}){
 if(!doc||!host)return Object.freeze({open:async()=>{}});
 let serial=0;
 const el=(tag,value='')=>{const node=doc.createElement(tag);
  node.textContent=value;return node};
 const labeled=(text,min,max,step='0.01')=>{
  const wrap=el('label');wrap.className='workspace-label';wrap.textContent=text;
  const input=el('input');input.type='number';input.min=String(min);
  input.max=String(max);input.step=step;input.inputMode='decimal';
  wrap.append(input);return {wrap,input};
 };
 async function open(route,airlineId){
  const own=++serial;
  host.replaceChildren();
  const title=el('h4','Commercial plan');host.append(title);
  const note=el('p','Fares and marketing amounts are draft plans only. No payments, bookings, advertising or revenue occur here.');
  note.className='hint';host.append(note);
  const server=getServer?.()||{};
  if(!route?.serverScheduleId||!airlineId||
     typeof server.scheduler?.commercialRead!=='function'||
     typeof server.scheduler?.commercialSave!=='function'){
   const unavailable=el('p','Save a protected route schedule to plan its fares.');unavailable.className='hint';
   host.append(unavailable);return;
  }
  const fare=labeled('Economy ticket price (USD)',1,100000);
  const cargo=labeled('Cargo rate per tonne (USD)',0,1000000);
  const marketing=labeled('Planned daily marketing budget (USD)',0,100000);
  const save=el('button','Save commercial plan');save.className='primary';save.type='button';
  save.disabled=true;
  const status=el('p','Loading fare plan...');status.className='hint';
  host.append(fare.wrap,cargo.wrap,marketing.wrap,save,status);
  try{
   const current=await server.scheduler.commercialRead({
    airlineId,scheduleId:route.serverScheduleId});
   if(own!==serial)return;
   fare.input.value=current.economyFareUsd??'';
   cargo.input.value=current.cargoRateUsdPerTonne??'0';
   marketing.input.value=current.marketingBudgetUsdPerDay??'0';
   save.disabled=false;
   status.textContent='Draft commercial settings ready. Marketing remains inactive.';
  }catch{
   if(own===serial)status.textContent='Commercial plan service unavailable. Nothing was changed.';
   return;
  }
  save.addEventListener('click',async()=>{
   const amount=x=>x.value.trim()===''?NaN:Number(x.value);
   const economyFareUsd=amount(fare.input),cargoRateUsdPerTonne=amount(cargo.input),
    marketingBudgetUsdPerDay=amount(marketing.input);
   if(![[economyFareUsd,1,100000],[cargoRateUsdPerTonne,0,1000000],
     [marketingBudgetUsdPerDay,0,100000]].every(([value,min,max])=>
      Number.isFinite(value)&&value>=min&&value<=max&&
      Math.round(value*100)/100===value)){
    status.textContent='Enter valid non-negative amounts with at most two decimals.';return;
   }
   save.disabled=true;
   try{
    const result=await server.scheduler.commercialSave({
     airlineId,scheduleId:route.serverScheduleId,
     economyFareUsd,cargoRateUsdPerTonne,marketingBudgetUsdPerDay
    });
    if(result.scheduleId!==route.serverScheduleId||result.paidMarketingActive!==false)
     throw Error('Commercial plan verification failed');
    status.textContent='Fare plan saved (version '+String(result.version)+
     '). Marketing remains planned and unpaid. No flight was activated.';
    if(typeof onSaved==='function')void Promise.resolve().then(onSaved).catch(()=>{});
   }catch{status.textContent='Commercial plan was not confirmed. No fares were activated.';}
   finally{save.disabled=false;}
  });
 }
 return Object.freeze({open});
}
