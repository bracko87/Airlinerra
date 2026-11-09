/**
 * Protected Route Details financials: planning estimate and verified actuals.
 * The private DB supplies trusted Section8 fees and ledger-backed history.
 * Never label route forecasts as booked revenue or realized net profit.
 */
const DOLLARS=new Intl.NumberFormat('en-US',{
 style:'currency',currency:'USD',minimumFractionDigits:2,maximumFractionDigits:2
});
const FEES=Object.freeze([
 ['departureAirportMovementUsd','Airport departure / takeoff'],
 ['arrivalLandingUsd','Destination landing'],
 ['departureGroundHandlingUsd','Departure ground handling'],
 ['arrivalStandParkingUsd','Arrival parking / stand'],
 ['departureTerminalAirTrafficControlUsd','Tower / terminal ATC'],
 ['enrouteAirTrafficControlUsd','En-route ATC / navigation'],
 ['departingPassengerFacilityUsd','Passenger terminal charge'],
 ['departingPassengerSecurityUsd','Passenger security'],
 ['internationalPassengerProcessingUsd','International passenger processing'],
 ['originCargoHandlingUsd','Cargo handling at origin'],
 ['destinationCargoHandlingUsd','Cargo handling at destination']
]);
const OTHER_COSTS=Object.freeze([
 ['fuelCostsUsd','Fuel'],
 ['crewCostsUsd','Crew'],
 ['maintenanceCostsUsd','Maintenance'],
 ['ownershipCostsUsd','Lease / aircraft ownership'],
 ['otherCostsUsd','Other expenses']
]);
const FLIGHT_INCOME=Object.freeze([
 ['ticketIncomeUsd','Ticket income'],
 ['cargoIncomeUsd','Cargo income'],
 ['otherIncomeUsd','Other income']
]);
const number=x=>{
 if(x===null||x===undefined||x==='')return null;
 if(typeof x!=='number'&&typeof x!=='string')return null;
 const n=Number(x);
 return Number.isFinite(n)&&Math.abs(n)<=1e12?n:null;
};
const money=x=>number(x)===null?'Not calculated':DOLLARS.format(number(x));
const add=(doc,tag,value='',cls='')=>{
 const item=doc.createElement(tag);
 item.textContent=String(value);
 if(cls)item.className=cls;
 return item;
};
const line=(doc,root,label,value,cls='')=>{
 const row=add(doc,'div','','route-finance-line'+(cls?' '+cls:''));
 row.append(add(doc,'span',label),add(doc,'strong',value));
 root.append(row);
 return row;
};
function safeDashboard(v,route,airlineId){
 if(!v||v.status!=='route_financial_dashboard_read_only'||
   v.readOnly!==true||v.cashPosted!==false||
   v.bookingsCreated!==false||v.flightActivated!==false||
   v.worldId!==1||v.scheduleId!==route.serverScheduleId||
   v.airlineId!==airlineId||
   v.estimate?.status!=='draft_not_earned'||
   v.estimate?.actualNetProfitKnown!==false||
   v.estimate?.airportFeeQuote?.status!=='game_operating_fee_preview_only'||
   v.estimate?.airportFeeQuote?.canPostToLedger!==false||
   v.estimate?.airportFeeQuote?.cashPosted!==false||
   v.estimate?.airportFeeQuote?.fuelIncluded!==false||
   v.history?.source!=='verified_arrival_and_posted_airline_ledger_only'||
   !Array.isArray(v.history.lastSevenFlights)||
   v.history.lastSevenFlights.length>7||
   !Number.isInteger(v.history.completedFlightCount)||
   v.history.completedFlightCount<0||
   !Number.isInteger(v.history.olderFlightCount)||
   v.history.olderFlightCount!==Math.max(0,v.history.completedFlightCount-7)||
   !v.estimate.airportFeeQuote.fees||
   FEES.some(([key])=>number(v.estimate.airportFeeQuote.fees[key])===null)||
   number(v.estimate.knownAirportNavigationCostsUsd)===null||
   !Array.isArray(v.estimate.notIncludedCosts))
  throw Error('Unverified or incomplete route financial data');
 const sumFees=FEES.reduce((sum,[key])=>
  sum+number(v.estimate.airportFeeQuote.fees[key]),0);
 if(Math.abs(sumFees-number(v.estimate.knownAirportNavigationCostsUsd))>0.06)
  throw Error('Route fee components did not reconcile');
 if(v.history.lastSevenFlights.length!==
   Math.min(7,v.history.completedFlightCount))
  throw Error('Incomplete last-seven financial history');
 for(const flight of v.history.lastSevenFlights){
  if(flight.source!=='verified_arrival_and_posted_ledger'||
     number(flight.revenueUsd)===null||number(flight.totalCostsUsd)===null||
     number(flight.profitLossUsd)===null||
     Math.abs(number(flight.revenueUsd)-number(flight.totalCostsUsd)-
       number(flight.profitLossUsd))>0.02)
   throw Error('Unverified completed-flight accounting');
 }
 return v;
}
export {safeDashboard as validateRouteFinancialDashboard};

export function createSection9RouteFinancePanel({doc,host,getServer}={}){
 if(!doc?.createElement||!host?.replaceChildren)
  return Object.freeze({open:async()=>{},refresh:async()=>{}});
 let route=null,airlineId=null,version=0;
 let loadPercent=100,parkingMinutes=180;
 const panel=add(doc,'article','','route-finance-panel');
 const kicker=add(doc,'span','ROUTE ECONOMICS','panel-kicker');
 const heading=add(doc,'h3','Income, costs and route profitability');
 const intro=add(doc,'p','Estimated values are not income already earned. Actual results appear only after a verified flight and its financial settlement.','hint');
 panel.append(kicker,heading,intro);
 const controls=add(doc,'div','','route-finance-controls');
 const makeSelect=(label,options)=>{
  const container=add(doc,'label','','route-finance-control');
  container.append(add(doc,'span',label));
  const input=doc.createElement('select');
  for(const [v,t] of options){
   const option=add(doc,'option',t);
   option.value=String(v);input.append(option);
  }
  container.append(input);controls.append(container);
  return input;
 };
 const loadInput=makeSelect('Estimated load',[
  [25,'25%'],[50,'50%'],[75,'75%'],[100,'100%']
 ]);
 const parkInput=makeSelect('Destination parking time',[
  [60,'1 hour'],[180,'3 hours'],[360,'6 hours'],[1440,'24 hours']
 ]);
 loadInput.value='100';parkInput.value='180';
 const status=add(doc,'p','Choose a saved route to view financial figures.','hint route-finance-status');
 status.setAttribute('role','status');
 const estimate=add(doc,'section','','route-finance-estimate');
 const historical=add(doc,'section','','route-finance-history');
 panel.append(controls,status,estimate,historical);host.replaceChildren(panel);

 function render(v){
  const e=v.estimate,q=e.airportFeeQuote,h=v.history;
  estimate.replaceChildren();historical.replaceChildren();
  estimate.append(add(doc,'h4','Estimated cost and potential ticket/cargo income'));
  const metrics=add(doc,'div','','route-finance-metrics');
  for(const [label,value] of [
   ['Potential income at chosen load',money(e.potentialRevenueUsd)],
   ['Known airport + ATC expenses',money(e.knownAirportNavigationCostsUsd)],
   ['Margin before other expenses',money(e.partialMarginBeforeOtherCostsUsd)]
  ]){
   const cell=add(doc,'div','','route-finance-metric');
   cell.append(add(doc,'span',label),add(doc,'strong',value));
   metrics.append(cell);
  }
  estimate.append(metrics);
  if(e.potentialRevenueUsd===null||e.potentialRevenueUsd===undefined){
   estimate.append(add(doc,'p',
    'Save a commercial economy fare (or cargo rate) for this route to calculate potential income. No price has been assumed.','hint'));
  }
  const summary=add(doc,'div','','route-finance-estimate-lines');
  line(doc,summary,'Aircraft',q.aircraftModel||String(v.aircraftConfigurationId));
  line(doc,summary,'Route / model distance',
   String(q.greatCircleDistanceKm)+' km');
  line(doc,summary,'Passenger load',
   String(e.passengers)+' booked only if sold · '+String(e.loadPercent)+'% capacity assumption');
  line(doc,summary,'Cargo load',String(e.cargoTonnes)+' t assumed');
  line(doc,summary,'Planned economy fare',
   money(e.plannedEconomyFareUsd));
  line(doc,summary,'Ticket income if sold',money(e.ticketIncomeIfSoldUsd));
  line(doc,summary,'Cargo income if sold',money(e.cargoIncomeIfSoldUsd));
  const fees=add(doc,'div','','route-finance-fees');
  fees.append(add(doc,'h5','All implemented flight cost components'));
  for(const [key,title] of FEES)
   line(doc,fees,title,money(q.fees[key]));
  line(doc,fees,'Total airport and navigation fees',
   money(e.knownAirportNavigationCostsUsd),'route-finance-total');
  summary.append(fees);
  estimate.append(summary);
  estimate.append(add(doc,'p',
   'Excluded from this estimate: fuel, crew, maintenance, aircraft leasing/ownership, insurance and other unsettled charges. The margin above is NOT final flight profit.','hint'));
  estimate.append(add(doc,'p',
   'Parking is estimated from the selected duration; actual billed stand time will depend on the real rotation. This quote does not charge the airline.','hint'));

  historical.append(add(doc,'h4','Actual route results'));
  const totals=add(doc,'div','','route-finance-metrics');
  for(const [label,value] of [
   ['Completed, financially posted flights',String(h.completedFlightCount)],
   ['Total posted revenue',money(h.totalRevenueUsd)],
   ['Total posted costs',money(h.totalCostsUsd)],
   ['Route profit / loss',money(h.totalProfitLossUsd)]
  ]){
   const box=add(doc,'div','','route-finance-metric');
   box.append(add(doc,'span',label),add(doc,'strong',value));totals.append(box);
  }
  historical.append(totals);
  if(h.completedFlightCount===0){
   historical.append(add(doc,'p',
    'No verified completed flights or posted revenue/expenses yet. This route has no actual profit or loss history.','hint'));
   return;
  }
  historical.append(add(doc,'h5','Latest 7 completed flights'));
  for(const f of h.lastSevenFlights){
   const item=add(doc,'details','','route-finance-flight');
   const head=add(doc,'summary',
    f.gameDate+' · Revenue '+money(f.revenueUsd)+
    ' · Costs '+money(f.totalCostsUsd)+
    ' · Balance '+money(f.profitLossUsd));
   item.append(head);
   const details=add(doc,'div','','route-finance-flight-lines');
   line(doc,details,'Passengers',String(f.passengers));
   line(doc,details,'Cargo',String(f.cargoTonnes)+' t');
   for(const [key,label] of FLIGHT_INCOME)
    line(doc,details,label,money(f[key]));
   line(doc,details,'Revenue total',money(f.revenueUsd),'route-finance-total');
   details.append(add(doc,'h5','Airport and navigation expenses'));
   for(const [key,label] of FEES)
    line(doc,details,label,money(f.fees?.[key]));
   line(doc,details,'Airport and ATC total',money(f.airportNavigationCostsUsd));
   for(const [key,label] of OTHER_COSTS)
    line(doc,details,label,money(f[key]));
   line(doc,details,'Total expenses',money(f.totalCostsUsd),'route-finance-total');
   line(doc,details,'Final profit / loss',money(f.profitLossUsd),'route-finance-total');
   item.append(details);historical.append(item);
  }
  if(h.olderFlightCount>0){
   historical.append(add(doc,'h5','Older flights · totals only'));
   const old=add(doc,'div','','route-finance-estimate-lines');
   line(doc,old,'Older flights included in statistics',String(h.olderFlightCount));
   line(doc,old,'Older flight revenue',money(h.olderRevenueUsd));
   line(doc,old,'Older flight expenses',money(h.olderCostsUsd));
   line(doc,old,'Older flight final balance',money(h.olderProfitLossUsd),'route-finance-total');
   historical.append(old);
  }
 }

 async function open(nextRoute,nextAirline){
  route=nextRoute;airlineId=nextAirline;return refresh();
 }
 async function refresh(){
  const serial=++version;
  const fn=getServer?.()?.scheduler?.routeFinancials;
  estimate.replaceChildren();historical.replaceChildren();
  if(!route?.serverScheduleId||!airlineId||typeof fn!=='function'){
   status.textContent='Save a protected flight schedule to see its full game operating cost estimate and verified history.';
   return;
  }
  const refId=route.serverScheduleId;
  status.textContent='Loading verified route costs and posted-flight history…';
  try{
   const v=await fn({
    airlineId,scheduleId:refId,loadPercent,parkingMinutes
   });
   if(serial!==version)return;
   const checked=safeDashboard(v,route,airlineId);
   status.textContent='Planning estimate above · actual history below. No route charge is posted by this view.';
   render(checked);
  }catch{
   if(serial!==version)return;
   status.textContent='Route financial data is unavailable. No cost, revenue or profit has been invented.';
   estimate.replaceChildren();historical.replaceChildren();
  }
 }
 loadInput.addEventListener('change',()=>{
  loadPercent=Number(loadInput.value);void refresh();
 });
 parkInput.addEventListener('change',()=>{
  parkingMinutes=Number(parkInput.value);void refresh();
 });
 return Object.freeze({open,refresh});
}
