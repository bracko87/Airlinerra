/** Human-readable, read-only explanation of the protected draft readiness
 * check. This check covers aircraft status and the Section 5 restriction gate;
 * it is NOT the five-source operational certification decision.
 */
const unavailable=Object.freeze({
 state:'unavailable',
 title:'Readiness could not be verified',
 summary:'The airline server did not return a valid read-only check. No approval is implied.',
 checks:[],
 actions:[],
});
const action=(page,label)=>Object.freeze({page,label});
export function summarizeProtectedRouteReadiness(result){
 if(!result||typeof result!=='object'||result.canActivateNormalFlight!==false||
  typeof result.status!=='string')return unavailable;
 const status=result.status;
 if(!['BLOCKED_AIRCRAFT_UNAVAILABLE','BLOCKED_AIRPORT_AIRCRAFT_RESTRICTIONS',
  'BLOCKED_OPERATIONAL_SYSTEMS_NOT_CONNECTED'].includes(status))return unavailable;
 const fleetBlocked=status==='BLOCKED_AIRCRAFT_UNAVAILABLE';
 const restrictionsFailed=status==='BLOCKED_AIRPORT_AIRCRAFT_RESTRICTIONS';
 const restrictionsPassed=status==='BLOCKED_OPERATIONAL_SYSTEMS_NOT_CONNECTED'&&
  result.restrictionPreflightPassed===true;
 const checks=Object.freeze([
  Object.freeze({label:'Aircraft in service',state:fleetBlocked?'blocked':'checked',
   explanation:fleetBlocked?'Aircraft is not in service or its configuration changed.':
    'The draft passed the aircraft-availability check.'}),
  Object.freeze({label:'Airport and aircraft restrictions',
   state:restrictionsFailed?'blocked':restrictionsPassed?'checked':'unknown',
   explanation:restrictionsFailed?'The timetable, runway, curfew or noise screen did not pass.':
    restrictionsPassed?'The initial airport/aircraft restriction screen passed.':
    'Not verified because an earlier check failed.'}),
  Object.freeze({label:'Full flight certification',state:'unverified',
   explanation:'AOC, traffic rights, booked slots, crew, maintenance and the five signed approvals are not certified by this limited check.'})
 ]);
 const summary=fleetBlocked?
  'Flight cannot proceed: the assigned aircraft needs attention.':
  restrictionsFailed?
  'Flight cannot proceed: its airport/aircraft restriction screen failed.':
  'The basic fleet and airport screens passed, but the route is not approved for flight by this check.';
 const actions=fleetBlocked?[action('fleet','Open Fleet'),action('maintenance','Open Maintenance')]:
  restrictionsFailed?[action('routes','Review route and times'),action('airports','Airport information')]:
  [action('licenses','Licences'),action('staff','Crew and staff'),action('schedule','Flight schedule')];
 return Object.freeze({
  state:'blocked',title:'Operational checks · not flight approval',
  summary,checks,actions:Object.freeze(actions),
  note:'Read-only preliminary check. Active commercial flights require separate current certifications and operational records; this screen never activates a route.'
 });
}
