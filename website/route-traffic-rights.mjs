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
export function renderTrafficRightIndicators(doc,strip,legend,{
 homeIso=null,originIso=null,destinationIso=null
}={}){
 if(!doc||!strip||!legend)return;
 strip.replaceChildren();legend.replaceChildren();
 const candidate=new Set(candidateTrafficFreedoms({homeIso,originIso,destinationIso}));
 for(const right of TRAFFIC_RIGHTS){
  // No independently verified grants are connected. Color only indicates
  // route relevance, not whether a commercial traffic right has been granted.
  const relevant=candidate.has(right.number);
  const button=doc.createElement('span');
  button.className='route-right-icon'+(relevant?' is-unverified':' is-inapplicable');
  button.textContent=right.symbol;
  const status=relevant?'Potentially relevant; grant not verified':
   'Not identified as relevant from this direct airport pair';
  button.title=right.name;
  button.setAttribute('aria-label',right.name+' — '+status);
  strip.append(button);
  const row=doc.createElement('div');row.className='route-right-explanation';
  const symbol=doc.createElement('strong');
  symbol.textContent=right.symbol+' · '+right.name;
  const description=doc.createElement('p');
  description.textContent=right.detail+' '+(relevant?'This route may require it; not yet verified.':'No route-specific approval recorded.');
  row.append(symbol,description);legend.append(row);
 }
}
