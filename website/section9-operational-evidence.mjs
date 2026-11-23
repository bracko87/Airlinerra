/** Present only authenticated, read-only operational diagnostics.
 * No "ready to fly" status exists here: no source can activate flights.
 */
const humanize=s=>String(s).replace(/_/g,' ').toLowerCase().replace(/^./,x=>x.toUpperCase());
export function summarizeOperationalEvidence(data){
 if(data?.status!=='read_only_operational_diagnostics'||
  data.readOnly!==true||data.canActivateNormalFlight!==false||
  data.flightActivated!==false||
  !Number.isInteger(data.scheduleVersion)||
  !Array.isArray(data.activationBlockers)||data.activationBlockers.length>40||
  typeof data.scheduleId!=='string')return null;
 const checklist=data.activationChecklist;
 const crew=data.crew,maintenance=data.maintenance;
 const rows=[];
 const add=(label,good,page,detail)=>rows.push(Object.freeze({
  label,state:good===true?'checked':good===false?'blocked':'unverified',
  page,detail
 }));
 add('Game clock',checklist?.worldClockConnected,'schedule',
  'Authoritative game calendar available for this preflight');
 add('Airport restrictions',checklist?.airportRestrictionPreviewPassed,'airports',
  'Runway, curfew and operating restrictions preview');
 add('Aircraft rotation',checklist?.aircraftRotationPreviewConflictFree,'fleet',
  'Overlaps and aircraft positions checked in the planning window');
 add('Airport slot records',checklist?.departureArrivalSlotRecordsPresent,'schedule',
  'Recorded departure and arrival slots; not final capacity certification');
 add('Crew assignments',checklist?.proposedCrewAssignmentsComplete,'staff',
  'Qualified registered employees assigned in the preview');
 add('Crew duty and rest',checklist?.crewRestPreviewConflictFree,'staff',
  'Preview of duty overlaps and minimum rest, not crew certification');
 add('Operator licence evidence',checklist?.operatorLicenceEvidenceRecorded,'licenses',
  'Licence evidence recorded, not independent release');
 add('Route traffic rights evidence',checklist?.routePermissionEvidenceComplete,'licenses',
  'Rights evidence recorded, not independent release');
 add('Aircraft maintenance',maintenance?.maintenanceReady===true?true:
  maintenance?.maintenanceReady===false?false:null,'maintenance',
  'Verified condition, usage, check history and grounding availability');
 const blocked=[...data.activationBlockers,...(Array.isArray(maintenance?.blockers)?
  maintenance.blockers:[])].filter(x=>typeof x==='string'&&/^[A-Z][A-Z0-9_]{2,100}$/.test(x))
  .slice(0,60).map(humanize);
 return Object.freeze({
  summary:'Operational preflight diagnostics only. Certificates, crew, maintenance and airport availability must be independently cleared before flight operations.',
  rows:Object.freeze(rows),blockers:Object.freeze(blocked),
  gameDate:data.verifiedGameDate||null,
  crewRequired:checklist?.crewRequired===true,
  crewDeferred:checklist?.crewDeferredPhase1===true
 });
}
