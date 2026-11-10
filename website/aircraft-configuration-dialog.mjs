/** Aircraft Profile configuration dialog. All choices are owner-verified data.
 * Saves proposals only — NEVER changes installed cabins, flight slots, or cash. */
import {companyCabinChoices,configurationCostPreview} from './aircraft-configuration-options.mjs';

const dollars=n=>Number.isFinite(n)&&n>=0?
 '$'+new Intl.NumberFormat('en-US',{maximumFractionDigits:0}).format(n):'Not available';

export function createAircraftConfigurationDialog({
 doc,getAirline,getAircraft,getFleetClient,onDesign,onSaved
}={}){
 if(!doc?.getElementById||typeof getAirline!=='function'||
  typeof getAircraft!=='function'||typeof getFleetClient!=='function')
  throw Error('Aircraft dialog requires live owner readers');
 const $=id=>doc.getElementById(id),dialog=$('fleet-configuration-dialog');
 if(!dialog)return Object.freeze({open:async()=>false,close:()=>{},destroy:()=>{}});
 const choice=$('fleet-configuration-choice'),site=$('fleet-configuration-facility'),
  save=$('fleet-configuration-save-draft'),quoteButton=$('fleet-configuration-prepare-quote');
 let sequence=0,context=null,ownerId=null,aircraftId=null,busy=false;
 let savedLayoutJson=null,quoteRequest=null;
 const say=(id,message)=>{const target=$(id);if(target)target.textContent=message;};
 const listOption=(root,value,text,disabled=false)=>{
  const item=doc.createElement('option');item.value=value;item.textContent=text;
  item.disabled=disabled;root.append(item);
 };
 const isSame=()=>ownerId&&ownerId===getAirline()?.id&&
  aircraftId===getAircraft()?.id&&dialog.open;
 const reset=()=>{
  ++sequence;context=null;ownerId=null;aircraftId=null;busy=false;
  savedLayoutJson=null;quoteRequest=null;
  if(save)save.disabled=true;if(quoteButton)quoteButton.disabled=true;
 };
 const close=()=>{if(dialog.open)dialog.close();reset();};
 const row=(label,value)=>{
  const entry=doc.createElement('div');entry.className='fleet-detail-row';
  const title=doc.createElement('span');title.textContent=label;
  const detail=doc.createElement('strong');detail.textContent=value;
  entry.append(title,detail);return entry;
 };
 const preview=()=>{
  const holder=$('fleet-configuration-preview');if(!holder)return;
  holder.replaceChildren();if(save)save.disabled=true;
  if(quoteButton)quoteButton.disabled=true;
  if(!context||!isSame())return;
  const selected=context.choices.find(c=>c.key===choice?.value);
  const selectedSite=context.sites.find(s=>
   s.airportKey+'|'+(s.providerKey||'')===site?.value);
  const installedSeats=['economy','premium','business','first'].reduce((n,key)=>
   n+Number(context.installed?.[key]||0),0);
  const quote=configurationCostPreview(selected,selectedSite,installedSeats);
  if(!quote.valid){
   holder.append(row('Layout',quote.message));return;
  }
  const currentDefault=selected?.key==='default'&&
   context.installed.economy===selected.plan.economy &&
   ['premium','business','first'].every(key=>context.installed[key]===0) &&
   (selected.plan.extraLegroomCm??0)===0;
  holder.append(row('Total passenger seats',String(quote.seatCount)),
   row('Cabin space used',quote.spacePct+'%'),
   row('Extra row legroom',quote.extraLegroomCm+' cm'),
   row('Cabin comfort (game preview)',quote.comfortRating+'/100'),
   row('New seat equipment',currentDefault?'$0 — already installed':dollars(quote.equipmentUsd)),
   row('Removal + installation',currentDefault?'$0':dollars(quote.labourCostUsd)),
   row('Indicative refit total',currentDefault?'$0':dollars(quote.indicativeTotalUsd)),
   row('Indicative refit downtime',currentDefault?'None':quote.downtimeHours+' hours'),
   row('Final provider quote','Not confirmed · no payment'),
   row('Available refit slot / installation date','Not available yet'));
  say('fleet-configuration-slot-status',quote.siteName?
   'Compatible facility: '+quote.siteName+'. Availability not confirmed. No booking is created.':
   'No facility selected. Refit appointment slots are not connected.');
  if(save)save.disabled=busy||currentDefault||!selected.available||
   typeof getFleetClient()?.saveCabinDraft!=='function';
  if(quoteButton)quoteButton.disabled=busy||currentDefault||!selected.available||
   !selectedSite?.providerKey||savedLayoutJson!==JSON.stringify(selected.plan)||
   typeof getFleetClient()?.prepareCabinRefitQuote!=='function';
 };
 const open=async()=>{
  const airframe=getAircraft(),airline=getAirline(),client=getFleetClient();
  if(!airframe?.id||!airline?.id||typeof client?.cabinOverview!=='function')return false;
  reset();const ticket=sequence;
  ownerId=airline.id;aircraftId=airframe.id;
  say('fleet-configuration-aircraft-label',
   [airframe.manufacturer,airframe.model,airframe.registration].filter(Boolean).join(' · '));
  say('fleet-configuration-load-status','Loading your company configurations…');
  say('fleet-configuration-slot-status','No confirmed refit bookings or slots.');
  say('fleet-configuration-feedback','');
  choice?.replaceChildren();site?.replaceChildren();
  if(choice)choice.disabled=true;if(site)site.disabled=true;
  $('fleet-configuration-preview')?.replaceChildren();
  if(!dialog.open)dialog.showModal();
  try{
   const result=await client.cabinOverview(ownerId);
   if(ticket!==sequence||!isSame())return false;
   if(result?.airlineId!==ownerId)throw Error('Different airline');
   const found=companyCabinChoices(result,aircraftId);
   if(!found)throw Error('Configuration reference data unavailable');
   context=found;
   // A valid saved draft on THIS airframe is already persisted on the server.
   // Do not force another save merely because the dialog was reopened.
   const ownSaved=found.choices.find(c=>c.key===aircraftId &&
    c.available && c.source==='Saved draft in this airline');
   savedLayoutJson=ownSaved?JSON.stringify(ownSaved.plan):null;
   for(const option of found.choices)listOption(choice,option.key,
    option.label+(option.available?'':' (not compatible)'),!option.available);
   choice.value='default';choice.disabled=false;
   listOption(site,'','Choose approved refit facility');
   const unique=new Set();
   for(const refit of found.sites){
    const key=refit.airportKey+'|'+(refit.providerKey||'');
    if(unique.has(key))continue;unique.add(key);
    listOption(site,key,
     (refit.airportCode||refit.airportKey)+' · '+refit.provider);
   }
   site.disabled=!unique.size;
   say('fleet-configuration-load-status',found.choices.length>1?
    (found.choices.length-1)+' saved company cabin layout(s) for this model.':
    'No alternative company layouts saved for this model yet. Design one using the existing cabin editor.');
   preview();
   if(typeof client.cabinRefitQuoteStatus==='function'){
    try{
     const previous=await client.cabinRefitQuoteStatus({
      airlineId:ownerId,aircraftInventoryId:aircraftId
     });
     if(ticket!==sequence||!isSame())return false;
     if(previous?.status==='prepared_not_booked' &&
      previous.airlineId===ownerId &&
      previous.aircraftInventoryId===aircraftId &&
      previous.appointmentBooked===false && previous.moneyCharged===false){
      const amount=dollars(Number(previous.estimatedTotalUsd));
      const suffix=previous.matchesCurrentDraft===true?
       'It is still a non-binding estimate; no slot is booked.':
       'Your saved design has changed since this quote. Prepare a new estimate.';
      say('fleet-configuration-feedback',
       'Last saved refit estimate: '+amount+'. '+suffix);
     }
    }catch{
     if(ticket===sequence&&isSame())
      say('fleet-configuration-feedback',
       'Previous refit quote is unavailable. Installed cabin and airline cash are unchanged.');
    }
   }
   return true;
  }catch{
   if(ticket===sequence&&isSame())
    say('fleet-configuration-load-status',
     'Could not load owner-verified configuration choices. Installed seats and airline money were not changed.');
   return false;
  }
 };
 const saveDraft=async()=>{
  if(busy||!context||!isSame()||save?.disabled)return;
  const current=context.choices.find(c=>c.key===choice.value),client=getFleetClient();
  if(!current?.available||!client?.saveCabinDraft)return;
  const ticket=sequence,company=ownerId,tail=aircraftId;
  busy=true;save.disabled=true;
  say('fleet-configuration-feedback','Saving a proposal only, not a refit booking…');
  try{
   const result=await client.saveCabinDraft({
    airlineId:company,aircraftInventoryId:tail,...current.plan
   });
   if(ticket!==sequence||!isSame())return;
   if(result?.aircraftInventoryId!==tail||result?.status!=='draft_saved_not_installed')
    throw Error('Unverified draft');
   savedLayoutJson=JSON.stringify(current.plan);
   quoteRequest=null;
   say('fleet-configuration-feedback',
    'Configuration proposal saved. Select a refit facility and choose Prepare refit quote. No seat installation or payment has occurred.');
   onSaved?.();
  }catch{
   if(ticket===sequence&&isSame())
    say('fleet-configuration-feedback',
     'Proposal could not be saved. Aircraft and finances are unchanged.');
  }finally{
   if(ticket===sequence){busy=false;preview();}
  }
 };
 const prepareQuote=async()=>{
  if(busy||!context||!isSame()||quoteButton?.disabled)return;
  const selected=context.choices.find(c=>c.key===choice?.value);
  const chosenSite=context.sites.find(s=>s.airportKey+'|'+(s.providerKey||'')===site?.value);
  const client=getFleetClient();
  if(!selected?.available||!chosenSite?.providerKey||
   savedLayoutJson!==JSON.stringify(selected.plan)||
   typeof client?.prepareCabinRefitQuote!=='function')return;
  const token=sequence,company=ownerId,airframe=aircraftId;
  const key=company+'|'+airframe+'|'+site.value+'|'+savedLayoutJson;
  const requestId=quoteRequest?.key===key?quoteRequest.id:globalThis.crypto?.randomUUID?.();
  if(!requestId){
   say('fleet-configuration-feedback','Secure quote request ID unavailable. No booking was made.');
   return;
  }
  quoteRequest={key,id:requestId};
  busy=true;preview();
  say('fleet-configuration-feedback','Preparing a verified estimate only. No payment or appointment…');
  try{
   const result=await client.prepareCabinRefitQuote({
    airlineId:company,aircraftInventoryId:airframe,
    airportKey:chosenSite.airportKey,providerKey:chosenSite.providerKey,requestId
   });
   if(token!==sequence||!isSame())return;
   if(result?.status!=='prepared_not_booked'||
    result.airlineId!==company||result.aircraftInventoryId!==airframe||
    result.moneyCharged!==false||result.appointmentBooked!==false||
    result.installedSeatsChanged!==false||result.aircraftGrounded!==false)
    throw Error('Unsafe quote response');
   say('fleet-configuration-feedback',
    'Non-binding quote saved: '+dollars(Number(result.estimatedTotalUsd))+
    '. Estimated work: '+result.estimatedDowntimeHours+
    ' hours. No appointment, aircraft grounding, seat installation or payment.');
  }catch{
   if(token===sequence&&isSame())
    say('fleet-configuration-feedback',
     'Quote could not be prepared. Check the saved design and approved facility. No booking, seat installation or payment occurred.');
  }finally{if(token===sequence){busy=false;preview();}}
 };
 const changed=()=>preview();
 const closeClicked=()=>close();
 const designClicked=()=>{const tail=aircraftId;if(!tail)return;close();onDesign?.(tail)};
 const dialogClosed=()=>reset();
 choice?.addEventListener('change',changed);
 site?.addEventListener('change',changed);
 save?.addEventListener('click',saveDraft);
 quoteButton?.addEventListener('click',prepareQuote);
 $('fleet-configuration-close')?.addEventListener('click',closeClicked);
 $('fleet-configuration-create')?.addEventListener('click',designClicked);
 dialog.addEventListener('close',dialogClosed);
 return Object.freeze({
  open,close,
  destroy:()=>{
   close();choice?.removeEventListener('change',changed);
   site?.removeEventListener('change',changed);
   save?.removeEventListener('click',saveDraft);
   quoteButton?.removeEventListener('click',prepareQuote);
   $('fleet-configuration-close')?.removeEventListener('click',closeClicked);
   $('fleet-configuration-create')?.removeEventListener('click',designClicked);
   dialog.removeEventListener('close',dialogClosed);
  }
 });
}
