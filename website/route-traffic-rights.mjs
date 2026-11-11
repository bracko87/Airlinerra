/** Read-only route-rights reference. Nine internationally recognized freedoms
 * are NOT interchangeable with licences, bilateral grants or a flight permit.
 * This UI makes NO operational authorization decision and never enables a
 * flight. No right is colored approved without an independent verified grant.
 */
export const TRAFFIC_RIGHTS=Object.freeze([
 {number:1,symbol:'↗',name:'Overflight',detail:'Fly over another country without landing; relevant to the actual airspace route.'},
 {number:2,symbol:'⛽',name:'Technical stop',detail:'Land for fuel or maintenance without picking up or setting down commercial passengers or cargo.'},
 {number:3,symbol:'⇗',name:'Outbound international',detail:'Carry traffic from the airline’s home country to a foreign country.'},
 {number:4,symbol:'⇙',name:'Inbound international',detail:'Carry traffic from a foreign country to the airline’s home country.'},
 {number:5,symbol:'⇢',name:'Beyond rights',detail:'Carry foreign-to-foreign traffic on a service linked to the airline’s home country.'},
 {number:6,symbol:'⇄',name:'Via home country',detail:'Carry traffic between foreign countries by connecting through the home country.'},
 {number:7,symbol:'⇆',name:'Foreign-to-foreign',detail:'Operate a service between two foreign countries without calling at the home country.'},
 {number:8,symbol:'↪',name:'Consecutive cabotage',detail:'Carry passengers or cargo between two points inside another country as part of an international service.'},
 {number:9,symbol:'⌂',name:'Standalone cabotage',detail:'Operate a service wholly inside a foreign country.'}
]);
/** Applicability means a possible legal question, NOT the right is granted.
 * The 1st, 2nd, 5th, 6th and 8th require intermediate legs/itinerary data
 * and cannot be inferred from one direct origin/destination airport pair.
 * Domestic home-market routes have domestic permissions separate from these.
 */
export function candidateTrafficFreedoms({homeIso,originIso,destinationIso}={}){
 const sane=x=>typeof x==='string'&&/^[A-Z]{2}$/.test(x);
 if(![homeIso,originIso,destinationIso].every(sane))return [];
 if(originIso===homeIso&&destinationIso!==homeIso)return [3];
 if(destinationIso===homeIso&&originIso!==homeIso)return [4];
 if(originIso!==homeIso&&destinationIso!==homeIso){
  if(originIso===destinationIso)return [9];
  return [7];
 }
 return [];
}
/** Traffic-right applicability and commercial activation are distinct facts.
 * Only source-verified decisions may show a check or a rights-denial cross.
 * A separate airport-admission block may show a cross over an applicable
 * right, but its label must identify the AIRPORT block, not deny that right.
 */
export function trafficRightDisplayState(number,{homeIso=null,originIso=null,
 destinationIso=null,verifiedDecisions=[],routeBlockReason=null}={}){
 const relevant=candidateTrafficFreedoms({
  homeIso,originIso,destinationIso
 }).includes(number);
 if(!relevant)return 'inapplicable';
 if(typeof routeBlockReason==='string'&&routeBlockReason.trim())
  return 'route-blocked';
 const decision=Array.isArray(verifiedDecisions)?
  verifiedDecisions.find(d=>d?.number===number&&d.sourceVerified===true):null;
 if(decision?.status==='granted')return 'approved';
 if(decision?.status==='denied')return 'denied';
 return 'unverified';
}
export function renderTrafficRightIndicators(doc,strip,legend,{
 homeIso=null,originIso=null,destinationIso=null,
 verifiedDecisions=[],routeBlockReason=null
}={}){
 if(!doc||!strip||!legend)return;
 strip.replaceChildren();legend.replaceChildren();
 for(const right of TRAFFIC_RIGHTS){
  const status=trafficRightDisplayState(right.number,{
   homeIso,originIso,destinationIso,verifiedDecisions,routeBlockReason
  });
  const label={
   inapplicable:'Not needed for this direct route',
   unverified:'Relevant; permission not yet confirmed',
   approved:'Confirmed permission for this route',
   denied:'Confirmed permission denied for this route',
   'route-blocked':'Route blocked: '+routeBlockReason+
    '. Traffic-right permission has not been decided.'
  }[status];
  const icon=doc.createElement('span');
  icon.className='route-right-icon is-'+status;
  icon.textContent=right.symbol;
  icon.title=right.name;
  icon.setAttribute('aria-label',right.name+' — '+label);
  icon.setAttribute('data-right-status',status);
  strip.append(icon);
  const row=doc.createElement('div');row.className='route-right-explanation';
  const symbol=doc.createElement('strong');
  symbol.textContent=right.symbol+' · '+right.name;
  const description=doc.createElement('p');
  description.textContent=right.detail+' '+label+'.';
  row.append(symbol,description);legend.append(row);
 }
}
