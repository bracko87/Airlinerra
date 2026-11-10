/**
 * Section 9: pure, deterministic, unit-based market allocation.
 *
 * One origin/destination market is counted once. A connection (max two legs)
 * consumes capacity on BOTH flights, not two independent traveller pools.
 * These helpers never authorize operations or write financial transactions.
 * Market sizes come from the protected Section 7/9 read model.
 */
const numeric=value=>typeof value==='number'&&Number.isFinite(value)?value:null;
const bounded=(value,min,max,fallback)=>{
 const n=numeric(value);return n===null?fallback:Math.min(max,Math.max(min,n));
};
const label=value=>typeof value==='string'&&value.length>0&&value.length<=160?value:null;

/** Game preference score; all preference multipliers are intentionally bounded. */
export function section9OfferWeight(offer={}){
 const fare=bounded(offer.fareUsd,0,100000,100);
 const reference=bounded(offer.referenceFareUsd,1,100000,100);
 const priceFactor=Math.pow(Math.max(0.25,Math.min(4,(fare+1)/(reference+1))),-1.2);
 const service=bounded(offer.serviceScore,0.75,1.25,1);
 const marketing=1+bounded(offer.marketingBoost,0,0.25,0);
 const frequency=1+Math.min(0.3,0.035*Math.sqrt(bounded(offer.weeklyDepartures,1,1000,7)));
 // Passenger-only cabin multiplier. Caller must derive it from a verified
 // INSTALLED layout, never from a player's saved draft or preview.
 const installedCabin=bounded(offer.installedCabinMultiplier,0.985,1.015,1);
 const minimum=bounded(offer.minimumTransferMinutes,0,720,0);
 const connecting=Array.isArray(offer.flightIds)&&offer.flightIds.length>1;
 const wait=bounded(offer.connectionMinutes,0,720,minimum);
 const waitFactor=connecting?Math.exp(-Math.max(0,wait-minimum)/420):1;
 return Math.max(0.0001,priceFactor*service*marketing*frequency*waitFactor*installedCabin);
}

/**
 * Allocate discrete units (passengers or cargo grams-like milli-tonne units).
 * Only actual offered flight legs constrain supply. Never loops per passenger.
 *
 * @param {Array} markets [{id,demand,offers:[{id,flightIds,...preferenceFields}]}]
 * @param {Object|Map} flightCapacity mapping flightId => passenger seats or cargo tonnes
 * @param {number} precision 1 for passengers, 1000 for cargo tonnes
 */
export function section9AllocateMarkets({markets=[],flightCapacity={},precision=1}={}){
 if(!Array.isArray(markets)||markets.length>100000||
    ![1,1000].includes(precision))throw Error('Invalid market batch');
 const entries=flightCapacity instanceof Map?flightCapacity.entries():
  Object.entries(flightCapacity||{});
 const stock=new Map();
 for(const [id,value] of entries){
  if(!label(id)||numeric(value)===null||value<0)throw Error('Invalid flight capacity');
  stock.set(id,Math.floor(value*precision+1e-9));
 }
 const allocations=[],totals=[],seenMarkets=new Set(),used=new Map();
 const sortedMarkets=[...markets].sort((a,b)=>String(a.id).localeCompare(String(b.id)));
 for(const market of sortedMarkets){
  if(!label(market?.id)||seenMarkets.has(market.id)||
     numeric(market.demand)===null||market.demand<0||
     !Array.isArray(market.offers)||market.offers.length>50000)
   throw Error('Invalid or duplicate market');
  seenMarkets.add(market.id);
  const requested=Math.floor(market.demand*precision+0.5);
  const ids=new Set();
  const offers=market.offers.map(o=>{
   if(!label(o?.id)||ids.has(o.id)||!Array.isArray(o.flightIds)||
      o.flightIds.length<1||o.flightIds.length>2||
      o.flightIds.some(id=>!label(id)||!stock.has(id))||
      new Set(o.flightIds).size!==o.flightIds.length)
    throw Error('Invalid market itinerary');
   ids.add(o.id);
   return {id:o.id,flightIds:o.flightIds,weight:section9OfferWeight(o),units:0};
  }).sort((a,b)=>a.id.localeCompare(b.id));
  let remaining=requested;
  let rounds=0;
  while(remaining>0 && rounds++<=offers.length+1){
   const open=offers.filter(o=>Math.min(...o.flightIds.map(id=>stock.get(id)))>0);
   if(!open.length)break;
   const weightSum=open.reduce((sum,o)=>sum+o.weight,0);
   const wishes=open.map(o=>{const ideal=remaining*o.weight/weightSum;
    return {o,wish:Math.floor(ideal),fraction:ideal%1};});
   wishes.sort((a,b)=>b.fraction-a.fraction||a.o.id.localeCompare(b.o.id));
   // Largest-remainder distribution only across OFFERS, never per passenger.
   let integerTotal=wishes.reduce((n,w)=>n+w.wish,0);
   for(const w of wishes){if(integerTotal>=remaining)break;w.wish++;integerTotal++;}
   let progress=0;
   for(const {o,wish} of wishes){
    const max=Math.min(...o.flightIds.map(id=>stock.get(id)));
    const chosen=Math.min(wish,max);
    if(chosen<1)continue;
    o.units+=chosen;
    for(const flightId of o.flightIds){
     stock.set(flightId,stock.get(flightId)-chosen);
     used.set(flightId,(used.get(flightId)||0)+chosen);
    }
    remaining-=chosen;progress+=chosen;
   }
   if(!progress)break;
  }
  for(const offer of offers)if(offer.units>0)allocations.push({
   marketId:market.id,offerId:offer.id,flightIds:offer.flightIds,
   allocated:offer.units/precision
  });
  totals.push({marketId:market.id,demand:requested/precision,
   allocated:(requested-remaining)/precision,unserved:remaining/precision});
 }
 return {
  marketTotals:totals,allocations,
  flightUsed:Object.fromEntries([...used].map(([key,val])=>[key,val/precision])),
  flightRemaining:Object.fromEntries([...stock].map(([key,val])=>[key,val/precision])),
  units:precision===1?'passengers':'cargoTonnes',
  previewOnly:true
 };
}
export const section9AllocatePassengers=({markets,flightCapacity})=>
 section9AllocateMarkets({markets,flightCapacity,precision:1});
export const section9AllocateCargo=({markets,flightCapacity})=>
 section9AllocateMarkets({markets,flightCapacity,precision:1000});
