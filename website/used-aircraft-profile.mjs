/** Owner-verified, read-only detail page for one physical used aircraft.
 * Supplied record comes fresh from protected fleet-acquisition API by listing UUID.
 * Never infer model specifications from a seller name or a different aircraft.
 */
import {aircraftDisplayName,aircraftImagePath} from './aircraft-library.mjs';

const node=(doc,tag,className='',value=null)=>{
 const e=doc.createElement(tag);
 if(className)e.className=className;
 if(value!==null)e.textContent=String(value);
 return e;
};
const known=value=>value!==null&&value!==undefined&&String(value).trim()!=='';
export const usedAircraftNumber=(value,unit='')=>{
 const n=Number(value);
 return known(value)&&Number.isFinite(n)?
  new Intl.NumberFormat('en-US',{maximumFractionDigits:1}).format(n)+(unit?' '+unit:''):'Not recorded';
};
const money=value=>{
 const n=Number(value);
 return known(value)&&Number.isFinite(n)&&n>=0?
  new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',
   minimumFractionDigits:0,maximumFractionDigits:0}).format(n):'Not recorded';
};
const day=value=>{
 if(!known(value))return 'Not recorded';
 const date=new Date(value);
 return Number.isFinite(date.getTime())?
  date.toLocaleString('en-GB',{dateStyle:'medium',timeStyle:'short'}):'Not recorded';
};
const line=(doc,name,value)=>{
 const el=node(doc,'div','used-aircraft-profile-row');
 el.append(node(doc,'span','',name),node(doc,'strong','',known(value)?value:'Not recorded'));
 return el;
};
const group=(doc,title,items)=>{
 const section=node(doc,'section','used-aircraft-profile-group');
 section.append(node(doc,'h3','',title));
 for(const [name,value] of items)section.append(line(doc,name,value));
 return section;
};
const cabinCounts=cabin=>['economy','premium','business','first'].every(k=>
  Number.isInteger(Number(cabin?.[k]))&&Number(cabin[k])>=0)?
  ['economy','premium','business','first'].reduce((sum,k)=>sum+Number(cabin[k]),0):null;

export function renderUsedAircraftProfile({
 doc,host,offer,marketOpen=false,serverNowUtc=null,
 onBack,onRefresh,onCabin,message='Loading the selected aircraft from the game database…'
}={}){
 if(!doc||!host)throw Error('Used aircraft profile host not available');
 host.replaceChildren();
 const back=()=>onBack?.();
 const reload=()=>onRefresh?.();
 const nav=node(doc,'div','used-aircraft-profile-navigation');
 const backButton=node(doc,'button','secondary used-aircraft-profile-back','← Back to used aircraft auctions');
 backButton.type='button';backButton.addEventListener('click',back);
 const refreshButton=node(doc,'button','secondary','Refresh aircraft information');
 refreshButton.type='button';refreshButton.addEventListener('click',reload);
 nav.append(backButton,refreshButton);host.append(nav);
 if(!offer){
  host.append(node(doc,'p','hint',message));
  return;
 }
 const name=aircraftDisplayName(offer.manufacturer,offer.model);
 const heading=node(doc,'div','used-aircraft-profile-heading');
 heading.append(node(doc,'p','used-aircraft-profile-eyebrow','INDIVIDUAL AIRCRAFT · SECOND-HAND MARKET'),
  node(doc,'h1','',name),
  node(doc,'p','hint',
   String(offer.configuration||'Aircraft configuration not recorded')+
   ' · '+String(offer.offeringType==='lease'?'Lease offer':'Purchase auction')+
   ' · This is an individual aircraft listing, not a model-only profile.'));
 host.append(heading);
 const snapshot=offer.cabinSnapshot;
 const count=offer.useType==='cargo'?null:cabinCounts(snapshot);
 const price=offer.offeringType==='lease'?
  money(offer.highestBidUsd??offer.openingBidUsd)+'/month':
  money(offer.highestBidUsd??offer.openingBidUsd);
 const age=Number.isSafeInteger(Number(offer.manufactureYear))&&Number(offer.manufactureYear)>1900?
  String((serverNowUtc&&Number.isFinite(Date.parse(serverNowUtc))?
   new Date(serverNowUtc):new Date()).getUTCFullYear()-Number(offer.manufactureYear))+' years':'Not recorded';
 const hero=node(doc,'div','used-aircraft-profile-hero');
 const pictureBox=node(doc,'div','used-aircraft-profile-image');
 const image=aircraftImagePath(offer);
 if(image){
  const img=node(doc,'img','');
  img.loading='lazy';img.decoding='async';img.src=image;img.alt=name+' · generic model artwork, not a photograph of this used airframe';
  img.addEventListener('error',()=>{
   img.remove();pictureBox.append(node(doc,'p','hint','Aircraft artwork not available'));
  },{once:true});
  pictureBox.append(img);
 }else pictureBox.append(node(doc,'p','hint','No approved aircraft artwork is available'));
 pictureBox.append(node(doc,'small','','Model illustration · individual airframe appearance not verified'));
 const highlights=node(doc,'div','used-aircraft-profile-highlights');
 for(const [label,value] of [
  ['Role',offer.useType],['Installed passenger seats',offer.useType==='cargo'?'Not applicable':count===null?'Not verified':String(count)],
  ['Condition (game estimate)',known(offer.conditionPct)?usedAircraftNumber(offer.conditionPct,'%'):'Not recorded'],
  ['Aircraft age (game)',age],
  ['Range (model)',usedAircraftNumber(offer.rangeKm,'km')],
  ['Next C check (estimate)',usedAircraftNumber(offer.nextCCheckInHours,'flight hours')],
  [offer.offeringType==='lease'?'Monthly lease game amount':'Auction game amount',price],
  ['Listing status',offer.status==='bidding'?'Bidding':'Listed — awaiting first bid']
 ]) highlights.append(line(doc,label,value));
 hero.append(pictureBox,highlights);host.append(hero);
 if(offer.useType!=='cargo'){
  const cabinSection=node(doc,'section','used-aircraft-profile-cabin');
  const top=node(doc,'div','used-aircraft-profile-cabin-top');
  const intro=node(doc,'div','');
  intro.append(node(doc,'h3','','Installed cabin configuration'),
   node(doc,'p','hint',offer.cabinOrigin==='previous_owner'?
    'Last configuration from the previous owner; unchanged for resale.':
    offer.cabinOrigin==='model_default'?
     'Game-generated used aircraft · standard factory cabin.':
     'Installed configuration needs verification.'));
  const cabinButton=node(doc,'button','secondary','View cabin configuration');
  cabinButton.type='button';
  cabinButton.disabled=!snapshot;
  cabinButton.addEventListener('click',()=>onCabin?.(offer));
  top.append(intro,cabinButton);cabinSection.append(top);
  if(count!==null){
   const seats=node(doc,'div','used-aircraft-profile-cabin-seats');
   for(const [key,label] of [['economy','Economy'],['premium','Premium Economy'],
    ['business','Business'],['first','First Class']]){
    seats.append(line(doc,label,usedAircraftNumber(snapshot[key])));
   }
   seats.append(line(doc,'Total seats',String(count)));
   cabinSection.append(seats);
  }else cabinSection.append(node(doc,'p','hint',
    'The installed seat plan is unavailable. No default is substituted for unknown data.'));
  host.append(cabinSection);
 }
 const specs=node(doc,'div','used-aircraft-profile-groups');
 specs.append(
  group(doc,'Aircraft identity & ownership',[
   ['Manufacturer',offer.manufacturer],['Family',offer.family],['Model',offer.model],
   ['Configuration',offer.configuration],['Role',offer.useType],
   ['Year manufactured',offer.manufactureYear],
   ['Production years',(known(offer.productionStartYear)?offer.productionStartYear:'—')+
     ' – '+(known(offer.productionEndYear)?offer.productionEndYear:'present / unknown')],
   ['Service status',offer.serviceStatus],
   ['Seller',offer.sellerFictional?'Fictional game seller: '+offer.sellerName:
      (offer.sellerName||'Seller not recorded')],
   ['Aircraft listing',offer.listingId]
  ]),
  group(doc,'Passenger, cargo & fuel',[
   ['Installed seats (this airframe)',offer.useType==='cargo'?'Not applicable':count===null?'Not verified':String(count)],
   ['Model seating reference (not installed)',offer.serviceSeats??offer.referenceSeats],
   ['Passenger-only maximum reference',offer.maxSeats],
   ['Combi freight estimate',offer.useType==='combi'?(offer.serviceFreightKg??'Not verified'):'Not applicable'],
   ['Cargo weight reference',offer.cargoKg],
   ['Belly hold (reference)',offer.bellyHoldReferenceKg],
   ['Belly cargo basis',offer.bellyHoldReferenceType],
   ['Fuel tank weight (model)',usedAircraftNumber(offer.fuelTankKg,'kg')]
  ]),
  group(doc,'Flight performance & weights',[
   ['Range',usedAircraftNumber(offer.rangeKm,'km')],
   ['Cruise speed',usedAircraftNumber(offer.cruiseSpeedKmh,'km/h')],
   ['Takeoff runway reference',usedAircraftNumber(offer.takeoffRunwayM,'m')],
   ['Landing runway reference',usedAircraftNumber(offer.landingRunwayM,'m')],
   ['Maximum takeoff weight',usedAircraftNumber(offer.mtowKg,'kg')],
   ['Maximum landing weight',usedAircraftNumber(offer.mlwKg,'kg')],
   ['Engine option',offer.engineOption],
   ['Technical data review',offer.technicalReviewStatus]
  ]),
  group(doc,'Dimensions & maintenance',[
   ['Wingspan',usedAircraftNumber(offer.wingspanM,'m')],
   ['Length',usedAircraftNumber(offer.lengthM,'m')],
   ['Height',usedAircraftNumber(offer.heightM,'m')],
   ['Manufacture year',offer.manufactureYear],
   ['Condition (fictional estimate)',usedAircraftNumber(offer.conditionPct,'%')],
   ['Next C check (fictional estimate)',usedAircraftNumber(offer.nextCCheckInHours,'hours')],
   ['Actual service history','Not recorded'],
   ['Registered previous operator',offer.sourceKind==='player_aircraft'?
    'Previous installed layout preserved':'Not applicable to generated dealer stock']
  ]),
  group(doc,'Auction & purchase information',[
   ['Offer type',offer.offeringType==='lease'?'Lease':'Purchase auction'],
   ['Starting auction price',money(offer.openingBidUsd)],
   ['Current highest offer',money(offer.highestBidUsd??offer.openingBidUsd)],
   ['Minimum bid increase',money(offer.minIncrementUsd)],
   ['Monthly lease amount',offer.offeringType==='lease'?money(offer.highestBidUsd??offer.openingBidUsd):'Not applicable'],
   ['Lease deposit',offer.offeringType==='lease'?money(offer.leaseDepositUsd):'Not applicable'],
   ['Lease term',offer.offeringType==='lease'?usedAircraftNumber(offer.leaseMonths,'months'):'Not applicable'],
   ['Estimated new-market reference',money(offer.provisionalNewValueUsd)],
   ['Historical reference',known(offer.referencePriceUsd)?
    money(offer.referencePriceUsd)+' ('+(offer.referencePriceYear||'year unknown')+')':'Not verified'],
   ['Current bids',offer.bidCount??0]
  ]),
  group(doc,'Market status',[
   ['World market',marketOpen?'Open':'Not open for bidding'],
   ['Listing',offer.status],
   ['Current top bidder',offer.myHighestBid?'Your airline':'Not disclosed'],
   ['Auction ends',offer.closeAfterUtc?day(offer.closeAfterUtc):'No bid yet · no expiry'],
   ['Last checked (server)',day(serverNowUtc)],
   ['Price basis',offer.pricingBasis||'Game market estimate'],
   ['Aircraft location','Not individually verified'],
   ['Flight clearance','Not established by this listing']
  ])
 );
 host.append(specs,node(doc,'p','hint',
  'Aircraft specifications are model-level references. Age, condition, maintenance estimate, offer and cabin are attached to this individual game listing. Viewing this page does not reserve, bid on, purchase or change the aircraft.'));
}
