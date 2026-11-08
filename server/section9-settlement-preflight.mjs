/**
 * Section 9 PRE-SETTLEMENT ONLY.
 *
 * The Section 9 daily forecast worker looks at yesterday, today and tomorrow
 * to find connections, so different daily forecasts can consume the SAME
 * physical flight. Adding all jobs' passenger/revenue outputs without
 * reconciliation would double-book that leg and potentially double-credit it.
 *
 * This module reconciles the three completed neighboring preview windows,
 * counts occupied seats/cargo on each physical occurrence ONCE per distinct
 * origin-date market allocation, and generates stable READ-ONLY future ledger
 * intent keys. It never writes bookings or airline money.
 *
 * Future activation must atomically reserve these quantities in one shared
 * occurrence-capacity ledger, and must recheck the authoritative schedule
 * version before any actual financial settlement.
 */
const ISO_DAY=/^\d{4}-\d{2}-\d{2}$/;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const round=(x,p)=>Math.round((x+Number.EPSILON)*p)/p;
const validDay=s=>typeof s==='string'&&ISO_DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
function addDay(day,n){
 return new Date(Date.parse(day+'T00:00:00Z')+n*86400000)
  .toISOString().slice(0,10);
}
function money(n){return typeof n==='number'&&Number.isFinite(n)&&n>=0&&
 n<=1e12&&Math.abs(round(n,100)-n)<=0.001;}
function tonnes(n){return typeof n==='number'&&Number.isFinite(n)&&n>=0&&n<=1000;}
function validateFlight(f){
 if(!f||typeof f!=='object'||Array.isArray(f)||
    !UUID.test(f.scheduleId||'')||!Number.isInteger(f.weeklyEntry)||
    f.weeklyEntry<1||f.weeklyEntry>10000||
    !Number.isSafeInteger(f.scheduleVersion)||f.scheduleVersion<1||
    !Number.isSafeInteger(f.commercialPlanVersion)||f.commercialPlanVersion<1||
    f.capacitySource!=='verified_activated_schedule'||
    typeof f.verificationSource!=='string'||f.verificationSource.length<6||
    !validDay(f.marketDate)||!UUID.test(f.airlineId||'')||
    f.flightId!==f.scheduleId+':'+f.marketDate+':'+f.weeklyEntry||
    !Number.isSafeInteger(f.passengerSeats)||f.passengerSeats<0||
    !Number.isSafeInteger(f.passengers)||f.passengers<0||
    f.passengers>f.passengerSeats||
    !Number.isSafeInteger(f.directPassengers)||f.directPassengers<0||
    !Number.isSafeInteger(f.connectingPassengers)||f.connectingPassengers<0||
    f.passengers!==f.directPassengers+f.connectingPassengers||
    !tonnes(f.cargoCapacityTonnes)||!tonnes(f.cargoTonnes)||
    f.cargoTonnes>f.cargoCapacityTonnes+0.000001||
    !money(f.ticketRevenueUsd)||!money(f.cargoRevenueUsd)||
    !Number.isFinite(Date.parse(f.departureUtc||''))||
    !Number.isFinite(Date.parse(f.arrivalUtc||''))||
    Date.parse(f.arrivalUtc)<=Date.parse(f.departureUtc))
  throw Error('SECTION9_UNVERIFIED_OR_INVALID_SETTLEMENT_SOURCE');
}
function identity(f){
 return [
  f.flightId,f.airlineId,f.scheduleVersion,
  f.commercialPlanVersion,f.passengerSeats,
  f.cargoCapacityTonnes,f.departureUtc,f.arrivalUtc
 ].join('|');
}
/**
 * @param {Object} params
 * @param {string} params.targetDate target departure local date
 * @param {Array} params.snapshots exactly yesterday/today/tomorrow:
 *   [{gameDate,status:'completed',readOnly:true,flights:[...]}]
 *
 * Note that a flight on targetDate may be in two distinct demand-day jobs;
 * those allocations must be ADDED (after checking the shared capacity), not
 * silently overwritten or treated as two separate flights.
 */
export function section9ReconcileAdjacentForecasts({
 targetDate,snapshots=[],maxRows=300000,maxConflicts=25
}={}){
 if(!validDay(targetDate)||!Array.isArray(snapshots)||snapshots.length>3||
    !Number.isInteger(maxRows)||maxRows<1||maxRows>900000||
    !Number.isInteger(maxConflicts)||maxConflicts<1||maxConflicts>100)
  throw Error('SECTION9_INVALID_RECONCILIATION_REQUEST');
 const needed=[addDay(targetDate,-1),targetDate,addDay(targetDate,1)];
 const byDay=new Map();
 for(const s of snapshots){
  if(!validDay(s?.gameDate)||byDay.has(s.gameDate))
   throw Error('SECTION9_DUPLICATE_OR_INVALID_FORECAST_DAY');
  byDay.set(s.gameDate,s);
 }
 const missing=needed.filter(d=>!byDay.has(d)||
  byDay.get(d).status!=='completed'||byDay.get(d).readOnly!==true||
  !Array.isArray(byDay.get(d).flights));
 if(missing.length)return {
  status:'blocked_incomplete_neighboring_forecasts',targetDate,
  missingCompletedDates:missing,capacityReconciled:false,
  ledgerPostingAllowed:false,readOnly:true
 };
 const combined=new Map(),issues=[],byDate=new Map();
 let processed=0,overlappingFlights=0;
 for(const date of needed){
  const snapshot=byDay.get(date),seen=new Set();
  byDate.set(date,snapshot.flights.length);
  for(const f of snapshot.flights){
   if(++processed>maxRows)throw Error('SECTION9_RECONCILIATION_REQUIRES_SHARDING');
   validateFlight(f);
   if(seen.has(f.flightId))
    throw Error('SECTION9_DUPLICATE_FLIGHT_WITHIN_FORECAST');
   seen.add(f.flightId);
   let a=combined.get(f.flightId);
   if(!a){
    a={flightId:f.flightId,airlineId:f.airlineId,
     departureLocalDate:f.marketDate,version:f.scheduleVersion,
     identity:identity(f),seats:f.passengerSeats,cargoCapacity:f.cargoCapacityTonnes,
     usedSeats:0,usedCargo:0,ticketUsd:0,cargoUsd:0,
     contributingForecasts:0};
    combined.set(f.flightId,a);
   }else if(a.identity!==identity(f)){
    if(issues.length<maxConflicts)issues.push({
     flightId:f.flightId,reason:'INCONSISTENT_SCHEDULE_OR_CAPACITY_VERSION'});
   }
   a.contributingForecasts++;
   if(a.contributingForecasts===2)overlappingFlights++;
   a.usedSeats+=f.passengers;
   a.usedCargo+=f.cargoTonnes;
   a.ticketUsd+=f.ticketRevenueUsd;
   a.cargoUsd+=f.cargoRevenueUsd;
  }
 }
 let overbookedFlights=0,otherIssueCount=0;
 const proposalKeys=new Set(),proposals=[];
 for(const a of combined.values()){
  if(a.usedSeats>a.seats||a.usedCargo>a.cargoCapacity+0.000001){
   overbookedFlights++;
   if(issues.length<maxConflicts)issues.push({
    flightId:a.flightId,reason:'SHARED_FLIGHT_CAPACITY_EXCEEDED',
    passengers:Math.round(a.usedSeats),seats:a.seats,
    cargoTonnes:round(a.usedCargo,1000),cargoCapacityTonnes:a.cargoCapacity
   });
  }
  if(a.departureLocalDate!==targetDate)continue;
  for(const [kind,amount] of [
   ['PASSENGER_REVENUE',round(a.ticketUsd,100)],
   ['CARGO_REVENUE',round(a.cargoUsd,100)]
  ]){
   if(amount===0)continue;
   const idempotencyKey='section9:'+a.flightId+':'+kind+':v1';
   if(proposalKeys.has(idempotencyKey)){
    otherIssueCount++;
    if(issues.length<maxConflicts)issues.push({
     flightId:a.flightId,reason:'DUPLICATE_LEDGER_INTENT_KEY'});
   }
   proposalKeys.add(idempotencyKey);
   proposals.push({idempotencyKey,flightId:a.flightId,
    airlineId:a.airlineId,kind,amountUsd:amount,readOnly:true});
  }
 }
 const collisionFree=overbookedFlights===0&&otherIssueCount===0&&
  !issues.some(i=>i.reason==='INCONSISTENT_SCHEDULE_OR_CAPACITY_VERSION');
 const result={
  status:collisionFree?'preview_reconciled':'blocked_conflicting_flight_usage',
  targetDate,completedForecastDates:needed,capacityReconciled:collisionFree,
  totalFlightRowsChecked:processed,uniqueFlightOccurrences:combined.size,
  overlappingFlightOccurrences:overlappingFlights,overbookedFlights,
  conflicts:issues,
  futureLedgerIntents:collisionFree?proposals:[],
  ledgerPostingAllowed:false,readOnly:true,
  settlementRequires:[
   'atomic_shared_occurrence_reservations',
   'real_flight_activation_and_schedule_version_check',
   'single_transaction_idempotent_airline_ledger_posting'
  ]
 };
 return result;
}
