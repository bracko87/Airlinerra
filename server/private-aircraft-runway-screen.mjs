/**
 * Airlinerra private research-only aircraft/runway distance screening.
 *
 * Not a flight performance calculator, dispatch clearance, route planner, or
 * legal operating authorization. The caller must supply externally calculated
 * aircraft-specific required distances for the actual mass and conditions.
 * No weather, elevation, slope, contamination, NOTAM, PPR, owner authorization,
 * or flight/aircraft registry integration is supplied by this module.
 *
 * IMPORTANT: Even if a numeric check passes, schedulingAllowed is ALWAYS false.
 * No Netlify Function/HTTP export. Never import into the public website.
 */

const PHASE_KEYS = Object.freeze({
  TAKEOFF: Object.freeze(['toraM', 'todaM', 'asdaM']),
  LANDING: Object.freeze(['ldaM'])
});
const AIRCRAFT_CODE = /^[A-Z0-9][A-Z0-9-]{1,31}$/u;
const AIRPORT_KEY = /^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const AIRSTRIP_PAIR = /^[0-9]{2}[LRC]?\/[0-9]{2}[LRC]?$/u;
const DIRECTION = /^[0-9]{2}[LRC]?$/u;
const DIRECTION_STATES = new Set(['UNVERIFIED','PROHIBITED','CONDITIONAL','PERMITTED_BY_AIP']);
const VERIFIED_SURFACES = new Set(['ASPHALT','CONCRETE','MIXED_VERIFIED']);

function positive(value, max) {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 && value <= max;
}

export function validatePerformanceScenario(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('An explicit aircraft performance scenario is required.');
  }
  const {aircraftCode, phase, operatingMassKg, calculationReference, requiredDistancesM} = value;
  if (typeof aircraftCode !== 'string' || !AIRCRAFT_CODE.test(aircraftCode)) {
    throw new Error('Invalid aircraft identifier.');
  }
  if (!Object.hasOwn(PHASE_KEYS, phase)) throw new Error('Invalid flight phase.');
  if (!positive(operatingMassKg, 1_000_000)) throw new Error('Invalid aircraft operating mass.');
  if (typeof calculationReference !== 'string' ||
      calculationReference.trim().length < 5 || calculationReference.length > 256) {
    throw new Error('A traceable external performance calculation reference is required.');
  }
  if (!requiredDistancesM || typeof requiredDistancesM !== 'object' ||
      Array.isArray(requiredDistancesM)) {
    throw new Error('Explicit calculated required distances are needed.');
  }
  const keys = PHASE_KEYS[phase];
  if (Object.keys(requiredDistancesM).length !== keys.length ||
      Object.keys(requiredDistancesM).some(key => !keys.includes(key)) ||
      keys.some(key => !positive(requiredDistancesM[key], 20_000))) {
    throw new Error('Incomplete or invalid directional performance requirements.');
  }
  return Object.freeze({
    aircraftCode, phase, operatingMassKg,
    calculationReference:calculationReference.trim(),
    requiredDistancesM:Object.freeze(Object.fromEntries(keys.map(k=>[k,requiredDistancesM[k]])))
  });
}

function inspectedRow(row, phase, required) {
  if (!row || !AIRSTRIP_PAIR.test(row.runwayPair || '') ||
      !positive(row.physicalLengthM, 20_000) ||
      !Array.isArray(row.directions)) {
    throw new Error('Invalid private runway inspection data.');
  }
  const directionNames=row.runwayPair.split('/');
  const seen=new Set();
  return row.directions.map(d=>{
    if (!d || !DIRECTION.test(d.direction || '') ||
        !directionNames.includes(d.direction) || seen.has(d.direction) ||
        !DIRECTION_STATES.has(d.takeoffStatus) ||
        !DIRECTION_STATES.has(d.landingStatus)) {
      throw new Error('Invalid or conflicting runway direction data.');
    }
    seen.add(d.direction);
    const checks=Object.entries(required).map(([key, requiredM])=>{
      const observed=d[key];
      if (observed == null) return Object.freeze({distance:key,requiredM,availableM:null,result:'NOT_PUBLISHED'});
      if (typeof observed !== 'number' || !Number.isFinite(observed) || observed < 0 || observed > 100_000) {
        throw new Error('Invalid published runway distance.');
      }
      return Object.freeze({
        distance:key,requiredM,availableM:observed,
        result:observed >= requiredM ? 'SUFFICIENT' : 'INSUFFICIENT'
      });
    });
    const numericStatus=checks.some(c=>c.result==='INSUFFICIENT') ? 'INSUFFICIENT' :
      checks.some(c=>c.result==='NOT_PUBLISHED') ? 'INCOMPLETE' : 'SUFFICIENT';
    const directionState=phase==='TAKEOFF'?d.takeoffStatus:d.landingStatus;
    const holds=[];
    if (row.physicalLengthM < 1200 || row.materialVerified !== true ||
        !VERIFIED_SURFACES.has(row.normalizedSurface)) holds.push('RUNWAY_PAVEMENT_NOT_INDEPENDENTLY_QUALIFIED');
    if (row.operationalStatus !== 'OPEN') holds.push('RUNWAY_NOT_CONFIRMED_UNRESTRICTED_OPEN');
    if (row.researchAdmission !== 'APPROVED') holds.push('RESEARCH_AIRPORT_NOT_ADMITTED');
    if (row.scheduledPermission !== 'PERMITTED') holds.push('SCHEDULED_AIRLINE_PERMISSION_NOT_VERIFIED');
    if (directionState==='PROHIBITED') holds.push('DIRECTION_OPERATION_PROHIBITED');
    else if (directionState!=='PERMITTED_BY_AIP') holds.push('DIRECTION_OPERATION_NOT_UNCONDITIONALLY_VERIFIED');
    if (numericStatus==='INCOMPLETE') holds.push('DECLARED_DISTANCES_INCOMPLETE');
    if (numericStatus==='INSUFFICIENT') holds.push('REQUIRED_DISTANCE_EXCEEDS_DECLARED_DISTANCE');
    return Object.freeze({
      runwayPair:row.runwayPair,direction:d.direction,phase,
      physicalLengthM:row.physicalLengthM,
      numericStatus,directionState,
      checks:Object.freeze(checks),
      blockers:Object.freeze(holds),
      schedulingAllowed:false
    });
  });
}

/** Evaluate numeric published-distance sufficiency, NEVER dispatch authority. */
export function screenAircraftRunways({inspection, scenario}={}) {
  const input=validatePerformanceScenario(scenario);
  if (!inspection || typeof inspection !== 'object' ||
      typeof inspection.inApprovedWorld !== 'boolean' ||
      typeof inspection.releaseEnabled !== 'boolean' ||
      !Array.isArray(inspection.runways) ||
      !AIRPORT_KEY.test(inspection.airportKey || '') ||
      inspection.worldId !== 1) {
    throw new Error('Invalid private approved-world inspection envelope.');
  }
  const candidates=[];
  if (inspection.inApprovedWorld) {
    const seen=new Set();
    for (const runway of inspection.runways) {
      if (seen.has(runway?.runwayPair)) throw new Error('Duplicate runway pair in inspection.');
      seen.add(runway?.runwayPair);
      candidates.push(...inspectedRow(runway,input.phase,input.requiredDistancesM));
    }
  }
  const observed=candidates.some(x=>x.numericStatus==='SUFFICIENT') ? 'ONE_OR_MORE_NUMERIC_PASSES' :
    candidates.some(x=>x.numericStatus==='INCOMPLETE') ? 'INCOMPLETE_DECLARED_DISTANCES' :
      candidates.length ? 'NO_NUMERIC_PASS' : 'NO_ELIGIBLE_SOURCE_RUNWAY';
  const status=!inspection.inApprovedWorld?'AIRPORT_OUTSIDE_APPROVED_WORLD' :
    !inspection.releaseEnabled?'WORLD_PRELAUNCH_LOCKED':'RESEARCH_SCREEN_ONLY';
  const globalBlockers=['NO_DISPATCH_OR_AIRLINE_AUTHORIZATION_INTERFACE'];
  if (!inspection.inApprovedWorld) globalBlockers.push('AIRPORT_OUTSIDE_APPROVED_GAME_CATALOG');
  if (!inspection.releaseEnabled) globalBlockers.push('WORLD_RELEASE_GATE_DISABLED');
  return Object.freeze({
    airportKey:inspection.airportKey,
    worldId:1,
    phase:input.phase,
    trafficType:'SCHEDULED_PASSENGER_RESEARCH_ONLY',
    aircraftCode:input.aircraftCode,
    operatingMassKg:input.operatingMassKg,
    calculationReference:input.calculationReference,
    numericOverview:observed,
    status,
    globalBlockers:Object.freeze(globalBlockers),
    candidates:Object.freeze(candidates),
    schedulingAllowed:false,
    releaseAuthorizationGenerated:false
  });
}

/** Optional integration with the existing private inspection service. */
export function createPrivateAircraftRunwayScreeningService({inspectionService,enabled=false}={}) {
  if (!inspectionService || typeof inspectionService.inspect !== 'function') {
    throw new Error('A private runway inspection service is required.');
  }
  return Object.freeze({
    async screen({request,scenario}={}) {
      const checked=validatePerformanceScenario(scenario);
      if (!enabled) throw new Error('Private aircraft runway screening is disabled.');
      const envelope=await inspectionService.inspect(request);
      return screenAircraftRunways({inspection:envelope,scenario:checked});
    }
  });
}
