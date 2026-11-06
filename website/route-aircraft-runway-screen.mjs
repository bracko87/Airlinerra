/** Aircraft-to-airport runway feasibility for ROUTE DRAFTS only.
 * A confirmed too-short longest usable paved runway blocks selection immediately.
 * Missing figures are REVIEW, never invented performance or real dispatch approval.
 * Server remains authoritative for any precise runway/curfew/noise restriction.
 */
const distance=value=>typeof value==='number'&&Number.isFinite(value)&&value>0?value:null;
const paved=value=>{
 const s=String(value||'').trim().toUpperCase();
 return /^(ASP|ASPH|CON|CONC|PEM|BIT|TAR|PAV)/.test(s)||
   /ASPHALT|CONCRETE|PAVED|BITUMEN/.test(s);
};
const closed=value=>/^(CLOSED|INACTIVE|ABANDONED|DECOMMISSIONED)$/i.test(String(value||''));
export const requiredAircraftRunwayM=(aircraft,operation)=>{
 if(!aircraft||!['departure','arrival'].includes(operation))return null;
 const primary=operation==='departure'?'fullWeightTakeoffReferenceM':'fullWeightLandingReferenceM';
 const fallback=operation==='departure'?'takeoffM':'landingM';
 return distance(aircraft[primary])??distance(aircraft[fallback]);
};
export function screenAirportRunway({airport,aircraft,operation,airportLabel='Airport'}={}){
 const requiredM=requiredAircraftRunwayM(aircraft,operation);
 const candidate=Array.isArray(airport?.runways)?airport.runways.filter(r=>
   paved(r?.surface)&&!closed(r?.operationalStatus)&&distance(r?.lengthM)!==null):[];
 const longest=candidate.length?Math.max(...candidate.map(r=>r.lengthM)):null;
 const roundedLength=longest===null?null:Math.floor(longest);
 const roundedRequired=requiredM===null?null:Math.ceil(requiredM);
 const purpose=operation==='arrival'?'landing':'takeoff';
 if(requiredM===null)return {
  status:'REVIEW',requiredM:null,availableM:roundedLength,
  reason:airportLabel+': verified '+purpose+' distance not available for this aircraft.'
 };
 if(!airport||!Array.isArray(airport.runways)||!candidate.length)return {
  status:'REVIEW',requiredM:roundedRequired,availableM:null,
  reason:airportLabel+': paved runway length not verified.'
 };
 if(longest<requiredM)return {
  status:'BLOCKED',requiredM:roundedRequired,availableM:roundedLength,
  deficitM:Math.ceil(requiredM-longest),
  reason:airportLabel+': longest recorded paved runway '+roundedLength.toLocaleString('en-US')+
   ' m; aircraft needs '+roundedRequired.toLocaleString('en-US')+' m for '+purpose+
   ' (short by '+Math.ceil(requiredM-longest).toLocaleString('en-US')+' m).'
 };
 return {
  status:'PASS',requiredM:roundedRequired,availableM:roundedLength,
  reason:airportLabel+': paved runway length suitable for game '+purpose+' screening.'
 };
}
export function assessAircraftRouteRunways({aircraft,origin,destination}={}){
 const from=screenAirportRunway({airport:origin,aircraft,operation:'departure',airportLabel:'Origin'});
 const to=screenAirportRunway({airport:destination,aircraft,operation:'arrival',airportLabel:'Destination'});
 const status=from.status==='BLOCKED'||to.status==='BLOCKED'?'BLOCKED':
  from.status==='REVIEW'||to.status==='REVIEW'?'REVIEW':'PASS';
 return Object.freeze({
  status,origin:from,destination:to,
  blockingReasons:[from,to].filter(x=>x.status==='BLOCKED').map(x=>x.reason),
  reviewReasons:[from,to].filter(x=>x.status==='REVIEW').map(x=>x.reason),
  officialDispatchApproved:false
 });
}
