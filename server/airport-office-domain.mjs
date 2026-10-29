/** Server-side airport office domain rules. Pure validation only; no writes or fees.
 * World and ownership must still be enforced by the authenticated server transaction.
 */
export const OFFICE_TYPES=Object.freeze(['hub','station']);
export const OFFICE_STATES=Object.freeze(['draft','pending_staff','active','suspended','closed']);
const AIRPORT_KEY=/^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/;
const fail=(reason)=>Object.freeze({ok:false,reason});
export function validateAirportOfficeProposal({type,airportKey,worldId,homeAirportKey,approvedAirportWorldId,existingAirportKeys=[]}={}){
 if(!OFFICE_TYPES.includes(type))return fail('Unsupported office type.');
 if(!Number.isSafeInteger(worldId)||worldId<1)return fail('Invalid game world.');
 if(typeof airportKey!=='string'||!AIRPORT_KEY.test(airportKey))return fail('Invalid airport key.');
 if(approvedAirportWorldId!==worldId)return fail('Airport not approved for this game world.');
 if(airportKey===homeAirportKey)return fail('Headquarters cannot become an additional office.');
 if(existingAirportKeys.includes(airportKey))return fail('This airline already has an office at this airport.');
 return Object.freeze({ok:true,type,airportKey,worldId,requiredStaff:type==='station'?1:0,state:'draft'});
}
/** Activation eligibility is not authority to charge or open. Real staff must be assigned
 * by the server and the fee quote must be server-issued, current and explicitly accepted.
 */
export function officeActivationEligibility({office,assignedActiveEmployees=0,feeQuote=null}={}){
 if(!office||!OFFICE_TYPES.includes(office.type)||!['draft','pending_staff'].includes(office.state))return fail('Office is not eligible for activation.');
 if(!Number.isSafeInteger(assignedActiveEmployees)||assignedActiveEmployees<0)return fail('Invalid employee count.');
 if(office.type==='station'&&assignedActiveEmployees<1)return fail('Station requires at least one assigned active employee.');
 if(!feeQuote||feeQuote.verified!==true||!Number.isSafeInteger(feeQuote.openingUsdCents)||feeQuote.openingUsdCents<0||!Number.isSafeInteger(feeQuote.monthlyUsdCents)||feeQuote.monthlyUsdCents<0)return fail('A verified airport-specific fee quote is required.');
 return Object.freeze({ok:true,openingUsdCents:feeQuote.openingUsdCents,monthlyUsdCents:feeQuote.monthlyUsdCents});
}
