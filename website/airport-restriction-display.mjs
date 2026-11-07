/** Sourced airport operating restrictions. No guess-based flight clearance. */
const days=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
const text=value=>typeof value==='string'&&value.trim()?value.trim():null;
const nonnegative=value=>Number.isInteger(value)&&value>=0?value:null;
const safeRules=value=>Array.isArray(value)?value.filter(x=>x&&typeof x==='object').slice(0,30):[];
export function formatAirportRule(rule,{runway=false}={}){
 if(!rule||typeof rule!=='object')return null;
 const action=rule.gameEnforcement===true?'Normal schedule blocked':'Permission / review required';
 const operation=rule.operation==='arrivals'||rule.operation==='arrival'?'Arrivals':
   rule.operation==='departures'||rule.operation==='departure'?'Departures':'Arrivals and departures';
 const start=text(rule.localStart),end=text(rule.localEnd);
 const time=start&&end?start+'–'+end+' airport local time':'Time to be verified';
 const weekdays=Array.isArray(rule.weekdays)&&rule.weekdays.length?
  rule.weekdays.filter(n=>Number.isInteger(n)&&n>=1&&n<=7).map(n=>days[n-1]).join(', '):'Every day';
 const aircraft=Array.isArray(rule.aircraftUseTypes)&&rule.aircraftUseTypes.length?
  rule.aircraftUseTypes.join(', ')+' aircraft only':'All aircraft types unless specified otherwise';
 const validity=rule.activeFrom||rule.activeUntil?
  'Valid '+(text(rule.activeFrom)||'from start')+' to '+(text(rule.activeUntil)||'open ended'):'';
 const location=runway?'Runway '+(text(rule.runwayDesignator)||'not specified')+' · ':'';
 const chapter=runway&&Array.isArray(rule.prohibitedChapters)&&rule.prohibitedChapters.length?
  ' · Certified Chapter '+rule.prohibitedChapters.filter(Number.isInteger).join(', ')+' restriction':'';
 return {
  title:action+' — '+location+operation,
  detail:[time,weekdays,runway?'Runway-specific':aircraft,validity].filter(Boolean).join(' · ')+chapter,
  note:text(rule.details),
  source:text(rule.source),
  hardBlock:rule.gameEnforcement===true
 };
}
export function summarizeAirportRestrictions(profile){
 const operation=profile?.operations||{},r=operation.restrictionResearch||{};
 const time=safeRules(operation.timeRestrictions).map(x=>formatAirportRule(x)).filter(Boolean);
 const runway=safeRules(operation.runwayRestrictions).map(x=>formatAirportRule(x,{runway:true})).filter(Boolean);
 const hard=nonnegative(r.enforcedTimeRules)??time.filter(x=>x.hardBlock).length;
 const hardRunway=nonnegative(r.enforcedRunwayRules)??runway.filter(x=>x.hardBlock).length;
 const review=nonnegative(r.reviewTimeRules)??time.filter(x=>!x.hardBlock).length;
 const state=r.status;
 const status=(hard+hardRunway)>0?
  'Mandatory game restrictions recorded (only for the listed times, operations and aircraft)':
  state==='RESEARCH_CONDITIONS_REQUIRE_SPECIFIC_RULE_REVIEW'?
    'Restrictions identified in research — precise game rules still need verification':
  state==='SOURCE_SCREENED_GAME_DEFAULT_NO_EXTRA_BAN'?
    'No additional game ban in the reviewed sources — not proof of real-world clearance':
  state==='PROVISIONAL_GAME_DEFAULT_NO_EXTRA_BAN'?
    'Provisional game default — no verified additional ban':
  'Operating conditions not yet fully verified';
 const sources=[
   {label:'Operating-hours / curfew research',url:text(r.operatingSource)},
   {label:'Noise research',url:text(r.noiseSource)},
   {label:'Simplified game source (AirlineSim only)',url:text(operation.simpleNightNoise?.source)},
   ...time.map((x,i)=>({label:'Time rule '+(i+1),url:x.source})),
   ...runway.map((x,i)=>({label:'Runway rule '+(i+1),url:x.source}))
 ].filter(x=>x.url);
 const unique=[];const seen=new Set();
 for(const entry of sources){if(!seen.has(entry.url)){seen.add(entry.url);unique.push(entry)}}
 return {
  status,
  researchOperating:text(r.operatingNote),
  researchNoise:text(r.noiseNote),
  rules:time.concat(runway),
  sources:unique,
  hardCount:hard+hardRunway,
  reviewCount:review+runway.filter(x=>!x.hardBlock).length,
  timezone:text(profile?.timezone)||'Airport local time (time zone unverified)',
  researchPending:r.timeResearchUnstructured===true,
  realWorldClearance:false
 };
}
export function safeEvidenceUrl(value){
 if(typeof value!=='string'||value.length>2048)return null;
 try{const url=new URL(value);return url.protocol==='https:'&&url.hostname?url.href:null;}catch{return null}
}
