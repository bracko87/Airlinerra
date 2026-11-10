/**
 * Section 9 market orchestrator. Pure and deterministic: no database writes,
 * no flight activation, no global search over theoretical airport pairs.
 *
 * INPUT CONTRACT (from a trusted flight-operations snapshot only):
 * flights: operationally verified flight occurrences, UTC instants, origin
 * departure *local* marketDate (YYYY-MM-DD), declared seat/cargo capacities.
 * markets: Section 7/9 origin-destination demand for that local marketDate.
 * airports: authoritative game MCT and cargo-handling capabilities.
 * agreements: bilateral, authorized active interline permissions.
 *
 * OUTPUT: passengers/cargo on each actual occurrence (not per-person records);
 * connecting travellers are counted once but occupy both legs. Neither the
 * browser nor a scheduled draft may write these results to the game ledger.
 */
import {section9AllocatePassengers,section9AllocateCargo}
 from './section9-demand-allocation.mjs';

const MINUTE=60000,MAX_TRANSFER=720,DAY=/^\d{4}-\d{2}-\d{2}$/;
const num=v=>typeof v==='number'&&Number.isFinite(v);
const id=v=>typeof v==='string'&&v.length>0&&v.length<=160;
const time=v=>typeof v==='string'&&Number.isFinite(Date.parse(v))?
 Date.parse(v):NaN;
const key=(a,b)=>a+'|'+b;
const cap=(v,n)=>num(v)?Math.max(0,Math.min(n,v)):0;
const validDate=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const sortByDeparture=(a,b)=>a.depMs-b.depMs||a.id.localeCompare(b.id);
const lowerBound=(xs,minimum)=>{
 let lo=0,hi=xs.length;
 while(lo<hi){const mid=(lo+hi)>>1;
  if(xs[mid].depMs<minimum)lo=mid+1;else hi=mid;}
 return lo;
};
function partnershipAllowed(a,b,journeyStart,journeyEnd,agreements,holdingGroups){
 if(a===b)return true;
 if(holdingGroups.get(a)&&holdingGroups.get(a)===holdingGroups.get(b))return true;
 const p=agreements.get(a<b?key(a,b):key(b,a));
 return !!(p&&p.agreementStatus==='active'&&p.leftApproved===true&&
  p.rightApproved===true&&time(p.validFrom)<=journeyStart&&
  (!p.validUntil||time(p.validUntil)>journeyEnd));
}
function cleanFlight(f){
 if(!id(f?.id)||!id(f.airlineId)||!id(f.origin)||!id(f.destination)||
    f.origin===f.destination||!validDate(f.marketDate)||
    f.status!=='operational_verified')
  throw Error('SECTION9_UNVERIFIED_OR_INVALID_FLIGHT');
 const depMs=time(f.departureUtc),arrMs=time(f.arrivalUtc);
 if(!Number.isFinite(depMs)||!Number.isFinite(arrMs)||
    arrMs<=depMs||arrMs-depMs>72*60*MINUTE||
    !num(f.passengerSeats)||f.passengerSeats<0||
    !Number.isSafeInteger(f.passengerSeats)||
    !num(f.cargoTonnes)||f.cargoTonnes<0||f.cargoTonnes>1000)
  throw Error('SECTION9_INVALID_OCCURRENCE_CAPACITY');
 // Only a trusted flight snapshot may identify the already INSTALLED cabin.
 // A draft's comfort score has no operational or booking effect.
 const installedEvidence=f.installedCabinEvidence==='server_verified_installed_v1';
 if(installedEvidence&&(!id(f.aircraftInventoryId)||
    f.installedCabinAircraftId!==f.aircraftInventoryId||
    !Number.isInteger(f.installedCabinComfortRating)||
    f.installedCabinComfortRating<0||f.installedCabinComfortRating>100))
  throw Error('SECTION9_INVALID_INSTALLED_CABIN_EVIDENCE');
 const installedCabinMultiplier=installedEvidence?
  1+(f.installedCabinComfortRating-50)*0.0003:1;
 return {...f,depMs,arrMs,installedCabinMultiplier,
  fareUsd:cap(f.fareUsd,100000),
  cargoRateUsd:cap(f.cargoRateUsd,100000),
  marketingBoost:f.marketingAuthorized===true?cap(f.marketingBoost,0.25):0,
  serviceScore:num(f.serviceScore)?cap(f.serviceScore,1.25):1,
  weeklyDepartures:num(f.weeklyDepartures)?Math.max(1,Math.min(1000,f.weeklyDepartures)):7};
}
const offerForLegs=(market,legs,wait=0,minimum=0,hubBackground='')=>{
 const [one,two]=legs;
 const weightedFare=legs.reduce((sum,f)=>sum+f.fareUsd,0);
 const cargoRate=legs.reduce((sum,f)=>sum+f.cargoRateUsd,0);
 // Transfer at a holiday destination is usually less attractive as a hub.
 const hubFactor=two&&hubBackground==='tourism'?0.4:1;
 const quality=legs.reduce((val,f)=>Math.min(val,f.serviceScore),1.25)*hubFactor;
 const original={
  id:legs.map(f=>f.id).join('>'),flightIds:legs.map(f=>f.id),
  fareUsd:weightedFare,referenceFareUsd:market.referenceFareUsd||100,
  serviceScore:quality,weeklyDepartures:Math.min(...legs.map(f=>f.weeklyDepartures)),
  marketingBoost:Math.min(...legs.map(f=>f.marketingBoost)),
  installedCabinMultiplier:Math.min(...legs.map(f=>f.installedCabinMultiplier)),
  minimumTransferMinutes:minimum,connectionMinutes:wait
 };
 return {passenger:original,cargo:{...original,
  // Passenger cabin comfort must never change freight demand.
  installedCabinMultiplier:1,
  fareUsd:cargoRate,referenceFareUsd:market.referenceCargoRateUsd||100}};
};
/**
 * Build a single-day snapshot by physical origin/destination. Chunk markets by
 * origin/date before invoking at large scale; no event depends on a user being online.
 * The maximum 1000 offered itineraries per market is an explicit fail-closed
 * guard: never silently discard operators and return false demand figures.
 */
export function section9SimulateDay({
 flights=[],markets=[],airports={},agreements=[],holdingGroups={},
 maxItinerariesPerMarket=1000
}={}){
 if(!Array.isArray(flights)||!Array.isArray(markets)||
   !Array.isArray(agreements)||flights.length>300000||markets.length>100000||
   !Number.isInteger(maxItinerariesPerMarket)||
   maxItinerariesPerMarket<1||maxItinerariesPerMarket>10000)
  throw Error('SECTION9_INVALID_BATCH');
 const flightsById=new Map(),byOriginDate=new Map(),byPair=new Map();
 for(const raw of flights){
  const f=cleanFlight(raw);
  if(flightsById.has(f.id))throw Error('SECTION9_DUPLICATE_FLIGHT_OCCURRENCE');
  flightsById.set(f.id,f);
  const orig=key(f.origin,f.marketDate),pair=key(f.origin,f.destination);
  if(!byOriginDate.has(orig))byOriginDate.set(orig,[]);
  if(!byPair.has(pair))byPair.set(pair,[]);
  byOriginDate.get(orig).push(f);byPair.get(pair).push(f);
 }
 for(const xs of byOriginDate.values())xs.sort(sortByDeparture);
 for(const xs of byPair.values())xs.sort(sortByDeparture);
 const agreementMap=new Map(),holdingMap=new Map(Object.entries(holdingGroups||{}));
 for(const a of agreements){
  if(!id(a?.leftAirlineId)||!id(a?.rightAirlineId)||
   a.leftAirlineId===a.rightAirlineId)throw Error('SECTION9_INVALID_AGREEMENT');
  const k=a.leftAirlineId<a.rightAirlineId?
   key(a.leftAirlineId,a.rightAirlineId):key(a.rightAirlineId,a.leftAirlineId);
  agreementMap.set(k,a);
 }
 const passengerMarkets=[],cargoMarkets=[],allOffers=new Map(),marketIds=new Set();
 let candidateChecks=0,connectionsFound=0;
 for(const market of markets){
  if(!id(market?.id)||marketIds.has(market.id)||
    !id(market.origin)||!id(market.destination)||
    market.origin===market.destination||!validDate(market.marketDate)||
    !num(market.passengers)||market.passengers<0||
    !num(market.cargoTonnes)||market.cargoTonnes<0)
   throw Error('SECTION9_INVALID_MARKET');
  marketIds.add(market.id);
  const outgoing=byOriginDate.get(key(market.origin,market.marketDate))||[];
  const paxOffers=[],cargoOffers=[],offerIds=new Set();
  const push=(legs,wait=0,minimum=0,hubBackground='')=>{
   const offer=offerForLegs(market,legs,wait,minimum,hubBackground);
   if(offerIds.has(offer.passenger.id))return;
   offerIds.add(offer.passenger.id);
   if(offerIds.size>maxItinerariesPerMarket)
    throw Error('SECTION9_MARKET_TOO_MANY_ITINERARIES_SPLIT_OR_SHARD_REQUIRED');
   allOffers.set(key(market.id,offer.passenger.id),
    {marketId:market.id,legs,wait,minimum,passenger:offer.passenger,cargo:offer.cargo});
   if(legs.every(f=>f.passengerSeats>0))paxOffers.push(offer.passenger);
   if(legs.every(f=>f.cargoTonnes>0)&&
     (legs.length===1||airports[legs[0].destination]?.cargoHandling===true))
    cargoOffers.push(offer.cargo);
  };
  for(const first of outgoing){
   if(first.destination===market.destination)push([first]);
  }
  for(const first of outgoing){
   if(first.destination===market.destination)continue;
   const hub=first.destination,policy=airports[hub]||{};
   const mct=policy.minimumTransferMinutes;
   if(!Number.isInteger(mct)||mct<0||mct>MAX_TRANSFER)continue;
   const secondLegs=byPair.get(key(hub,market.destination))||[];
   const earliest=first.arrMs+mct*MINUTE;
   const latest=first.arrMs+MAX_TRANSFER*MINUTE;
   for(let i=lowerBound(secondLegs,earliest);i<secondLegs.length;i++){
    const second=secondLegs[i];
    if(second.depMs>latest)break;
    candidateChecks++;
    if(!partnershipAllowed(first.airlineId,second.airlineId,
       first.depMs,second.arrMs,agreementMap,holdingMap))continue;
    const wait=Math.round((second.depMs-first.arrMs)/MINUTE);
    if(wait<mct||wait>MAX_TRANSFER)continue;
    push([first,second],wait,mct,policy.background||'');
    connectionsFound++;
   }
  }
  passengerMarkets.push({id:market.id,demand:market.passengers,offers:paxOffers});
  cargoMarkets.push({id:market.id,demand:market.cargoTonnes,offers:cargoOffers});
 }
 const capacitiesP=new Map(),capacitiesC=new Map();
 for(const f of flightsById.values()){
  capacitiesP.set(f.id,f.passengerSeats);
  capacitiesC.set(f.id,f.cargoTonnes);
 }
 const passengers=section9AllocatePassengers({markets:passengerMarkets,flightCapacity:capacitiesP});
 const cargo=section9AllocateCargo({markets:cargoMarkets,flightCapacity:capacitiesC});
 const revenueByFlight=new Map([...flightsById.keys()].map(k=>[k,{ticketUsd:0,cargoUsd:0,
  directPassengers:0,connectingPassengers:0}]));
 for(const [result,kind] of [[passengers,'passenger'],[cargo,'cargo']]){
  for(const allocation of result.allocations){
   const itinerary=allOffers.get(key(allocation.marketId,allocation.offerId));
   if(!itinerary)throw Error('SECTION9_INTERNAL_ALLOCATION_MISMATCH');
   const legs=itinerary.legs;
   const isConnection=legs.length===2;
   const totalRate=legs.reduce((sum,f)=>sum+
    (kind==='passenger'?f.fareUsd:f.cargoRateUsd),0);
   legs.forEach(f=>{
    const stats=revenueByFlight.get(f.id);
    const rate=kind==='passenger'?f.fareUsd:f.cargoRateUsd;
    // Price already belongs to the leg: connecting itineraries do not
    // receive the entire combined fare once per leg.
    if(kind==='passenger'){
     stats.ticketUsd+=allocation.allocated*rate;
     if(isConnection)stats.connectingPassengers+=allocation.allocated;
     else stats.directPassengers+=allocation.allocated;
    }else stats.cargoUsd+=allocation.allocated*rate;
   });
   if(isConnection&&totalRate<0)throw Error('SECTION9_INVALID_REVENUE');
  }
 }
 const flightResults=[...flightsById.values()].sort((a,b)=>a.id.localeCompare(b.id)).map(f=>{
  const totals=revenueByFlight.get(f.id), pax=passengers.flightUsed[f.id]||0,
   cargoUsed=cargo.flightUsed[f.id]||0;
  return {flightId:f.id,scheduleId:f.scheduleId||null,
   weeklyEntry:f.weeklyEntry??null,
   scheduleVersion:f.scheduleVersion??null,
   commercialPlanVersion:f.commercialPlanVersion??null,
   capacitySource:f.capacitySource||null,
   verificationSource:f.verificationSource||null,
   departureUtc:f.departureUtc,arrivalUtc:f.arrivalUtc,
   airlineId:f.airlineId,marketDate:f.marketDate,
   origin:f.origin,destination:f.destination,
   passengerSeats:f.passengerSeats,passengers:pax,
   directPassengers:totals.directPassengers,connectingPassengers:totals.connectingPassengers,
   loadFactor:f.passengerSeats>0?Math.round(pax/f.passengerSeats*10000)/100:null,
   cargoCapacityTonnes:f.cargoTonnes,cargoTonnes:cargoUsed,
   ticketRevenueUsd:Math.round(totals.ticketUsd*100)/100,
   cargoRevenueUsd:Math.round(totals.cargoUsd*100)/100};
 });
 return {version:'section9_network_simulator_v1',previewOnly:true,
  passengers:{markets:passengers.marketTotals,flightUsed:passengers.flightUsed,
   allocations:passengers.allocations},
  cargo:{markets:cargo.marketTotals,flightUsed:cargo.flightUsed,
   allocations:cargo.allocations},
  flights:flightResults,diagnostics:{flights:flights.length,markets:markets.length,
   candidateChecks,connectionsFound},
  writesToAirlineLedger:false,authorizesFlightActivation:false};
}

/**
 * Discover only markets reachable by actual verified services, including
 * one-stop-only destinations. The market batch SQL then fetches the Section 7
 * demand for these pairs in groups instead of querying every airport pair.
 * Unapproved airline connections are excluded before market generation.
 */
export function section9DiscoverReachableMarkets({
 flights=[],airports={},agreements=[],holdingGroups={},marketDate,
 maxMarketPairs=100000
}={}){
 if(!validDate(marketDate)||!Array.isArray(flights)||!Array.isArray(agreements)||
  flights.length>300000||!Number.isInteger(maxMarketPairs)||
  maxMarketPairs<1||maxMarketPairs>100000)
  throw Error('SECTION9_INVALID_DISCOVERY_INPUT');
 const verified=flights.map(cleanFlight),byOrigin=new Map(),ids=new Set();
 const allowed=new Map(),groups=new Map(Object.entries(holdingGroups||{}));
 for(const x of verified){
  if(ids.has(x.id))throw Error('SECTION9_DUPLICATE_FLIGHT_OCCURRENCE');
  ids.add(x.id);
  if(!byOrigin.has(x.origin))byOrigin.set(x.origin,[]);
  byOrigin.get(x.origin).push(x);
 }
 for(const list of byOrigin.values())list.sort(sortByDeparture);
 for(const a of agreements){
  if(!id(a?.leftAirlineId)||!id(a?.rightAirlineId)||
     a.leftAirlineId===a.rightAirlineId)
   throw Error('SECTION9_INVALID_AGREEMENT');
  const k=a.leftAirlineId<a.rightAirlineId?
   key(a.leftAirlineId,a.rightAirlineId):key(a.rightAirlineId,a.leftAirlineId);
  allowed.set(k,a);
 }
 const unique=new Map();let examined=0;
 const add=(origin,destination)=>{
  if(origin===destination)return;
  const k=key(origin,destination);
  if(!unique.has(k)){
   unique.set(k,{origin,destination});
   if(unique.size>maxMarketPairs)throw Error('SECTION9_TOO_MANY_REACHABLE_MARKETS_SHARD_REQUIRED');
  }
 };
 for(const first of verified){
  if(first.marketDate!==marketDate||(!first.passengerSeats&&!first.cargoTonnes))continue;
  add(first.origin,first.destination);
  const hub=first.destination,rule=airports[hub]||{},mct=rule.minimumTransferMinutes;
  if(!Number.isInteger(mct)||mct<0||mct>MAX_TRANSFER)continue;
  const onward=byOrigin.get(hub)||[];
  for(let n=lowerBound(onward,first.arrMs+mct*MINUTE);n<onward.length;n++){
   const second=onward[n];
   if(second.depMs>first.arrMs+MAX_TRANSFER*MINUTE)break;
   examined++;
   if(second.destination===first.origin||
      (!first.passengerSeats||!second.passengerSeats)&&
      (!first.cargoTonnes||!second.cargoTonnes||rule.cargoHandling!==true))
    continue;
   if(!partnershipAllowed(first.airlineId,second.airlineId,
    first.depMs,second.arrMs,allowed,groups))continue;
   add(first.origin,second.destination);
  }
 }
 return {marketDate,pairs:[...unique.values()].sort((a,b)=>
  key(a.origin,a.destination).localeCompare(key(b.origin,b.destination))),
  diagnostics:{verifiedFlightOccurrences:verified.length,
   discoveredMarketPairs:unique.size,candidateConnectionsExamined:examined}};
}
