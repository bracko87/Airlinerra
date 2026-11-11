/** Owner-checked Section 8 airport fee baseline; never a full flight total.
 * Passenger and cargo counts are UNKNOWN during route creation. Server queries
 * zero only to price fixed movement/landing/navigation components, not to say
 * a flight will carry nobody. No browser rates may override private fee tables.
 */
export const FIXED_AIRPORT_FEE_KEYS=Object.freeze([
 ['departureAirportMovementUsd','Origin takeoff / movement'],
 ['arrivalLandingUsd','Destination landing'],
 ['departureGroundHandlingUsd','Origin ground handling'],
 ['arrivalStandParkingUsd','Destination stand parking'],
 ['departureTerminalAirTrafficControlUsd','Departure tower / terminal navigation'],
 ['enrouteAirTrafficControlUsd','En-route navigation']
]);
export const VARIABLE_AIRPORT_FEE_KEYS=Object.freeze([
 ['departingPassengerFacilityUsd','Departing passenger facilities'],
 ['departingPassengerSecurityUsd','Passenger security'],
 ['internationalPassengerProcessingUsd','International passenger processing'],
 ['originCargoHandlingUsd','Cargo handling at origin'],
 ['destinationCargoHandlingUsd','Cargo handling at destination']
]);
const cents=v=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=1e10;
export function checkedRouteFeeBaseline(result,{airlineId,aircraftInventoryId}={}){
 if(result?.status!=='owner_verified_fixed_fee_baseline'||
    result.readOnly!==true||result.cashPosted!==false||
    result.canBookFlight!==false||result.operationAuthorized!==false||
    result.estimatedWholeFlightCost!==false||
    result.airlineId!==airlineId||
    result.aircraftInventoryId!==aircraftInventoryId||
    result.passengersAssumed!==0||result.cargoTonnesAssumed!==0)
   return null;
 const quote=result.airportFeeQuote;
 if(quote?.status!=='game_operating_fee_preview_only'||
    quote.currency!=='USD'||quote.worldId!==1||
    quote.costBasis!=='airlinerra_game_model_only'||
    quote.isOfficialAviationTariff!==false||
    quote.canPostToLedger!==false||quote.cashPosted!==false||
    quote.operationAuthorized!==false||quote.fuelIncluded!==false||
    quote.passengers!==0||Number(quote.cargoTonnes)!==0||
    !cents(quote.totalGameOperatingFeesUsd)||!quote.fees||
    typeof quote.fees!=='object')return null;
 const all=[...FIXED_AIRPORT_FEE_KEYS,...VARIABLE_AIRPORT_FEE_KEYS];
 if(!all.every(([key])=>cents(quote.fees[key])))return null;
 const sum=all.reduce((n,[key])=>n+quote.fees[key],0);
 if(Math.abs(sum-quote.totalGameOperatingFeesUsd)>.07)return null;
 // Cost of known fixed categories. Zero-pax/cargo variable charges are NOT
 // represented as $0 in the UI because their true counts are unknown.
 const fixedSubtotal=FIXED_AIRPORT_FEE_KEYS.reduce(
  (n,[key])=>n+quote.fees[key],0);
 return Object.freeze({
  fixedSubtotalUsd:Math.round(fixedSubtotal*100)/100,
  fixedRows:Object.freeze(FIXED_AIRPORT_FEE_KEYS.map(([key,label])=>Object.freeze({
   label,amountUsd:quote.fees[key],evidence:'Section 8 game fee model'
  }))),
  unknownRows:Object.freeze(VARIABLE_AIRPORT_FEE_KEYS.map(([,label])=>Object.freeze({
   label,amountUsd:null,evidence:'Actual passengers or cargo not known'
  }))),
  modelVersion:quote.modelVersion,
  parkingMinutes:quote.arrivalParkingMinutes,
  departureStand:quote.departureStand,
  arrivalStand:quote.arrivalStand
 });
}
