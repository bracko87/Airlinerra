/**
 * Research-only aircraft performance reference-point evaluator.
 * NOT a certified AFM computation, flight clearance or scheduling authority.
 * Inputs MUST originate from independently reviewed manufacturer/AFM tables.
 * Never estimate temperature, altitude, wind, slope or wet-runway corrections.
 * Only exact condition-grid matches and, when explicitly source-approved,
 * conservative next-higher-mass reference points are permitted.
 */

const DATE = /^20[0-9]{2}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])$/u;
const VARIANT = /^[A-Z0-9][A-Z0-9_-]{2,31}$/u;
const CONDITIONS = ['pressureAltitudeFt','outsideAirTemperatureC',
  'headwindComponentKt','runwaySlopePct','runwayCondition'];
const DISTANCES = Object.freeze({
  TAKEOFF:Object.freeze(['toraM','todaM','asdaM']),
  LANDING:Object.freeze(['ldaM'])
});
const LIMITS = {
  pressureAltitudeFt:[-2000,20000],
  outsideAirTemperatureC:[-60,65],
  headwindComponentKt:[-60,100],
  runwaySlopePct:[-5,5]
};

function number(v) {
  if (typeof v === 'number') return v;
  if (typeof v === 'string' && /^-?[0-9]+(?:\.[0-9]+)?$/u.test(v)) return Number(v);
  return NaN;
}
function bounded(value,lo,hi) {
  const n=number(value);
  return Number.isFinite(n) && n>=lo && n<=hi;
}
function isoDay(value) {
  return typeof value === 'string' && DATE.test(value) &&
    !Number.isNaN(Date.parse(value+'T00:00:00Z')) &&
    new Date(value+'T00:00:00Z').toISOString().slice(0,10)===value;
}
function blocked(status,details=[]) {
  return Object.freeze({
    status,requiredDistancesM:null,referencePointMassKg:null,
    calculationMethod:null,blockers:Object.freeze(details),
    schedulingAllowed:false
  });
}

export function validateAircraftOperatingScenario(scenario) {
  if (!scenario || typeof scenario!=='object' || Array.isArray(scenario)) {
    throw new Error('An explicit aircraft operating scenario is required.');
  }
  const {aircraftVariantKey,phase,aircraftConfigurationCode,
    operatingMassKg,asOfDate,conditions}=scenario;
  if (typeof aircraftVariantKey!=='string' || !VARIANT.test(aircraftVariantKey) ||
      typeof aircraftConfigurationCode!=='string' ||
      !/^[A-Z0-9_-]{2,40}$/u.test(aircraftConfigurationCode)) {
    throw new Error('Aircraft variant and configuration must be explicit.');
  }
  if (!Object.hasOwn(DISTANCES,phase) ||
      !bounded(operatingMassKg,1,1000000) ||
      !isoDay(asOfDate)) throw new Error('Invalid phase, mass or reference date.');
  if (!conditions || typeof conditions!=='object' || Array.isArray(conditions) ||
      Object.keys(conditions).length!==CONDITIONS.length ||
      CONDITIONS.some(key=>!Object.hasOwn(conditions,key))) {
    throw new Error('Complete sourced runway operating conditions are required.');
  }
  const c={};
  for(const [key,limits] of Object.entries(LIMITS)) {
    if(!bounded(conditions[key],limits[0],limits[1])) {
      throw new Error('Invalid altitude, temperature, wind or runway slope.');
    }
    c[key]=number(conditions[key]);
  }
  if (!['DRY','WET'].includes(conditions.runwayCondition)) {
    throw new Error('Only explicit DRY/WET source-grid points are supported.');
  }
  c.runwayCondition=conditions.runwayCondition;
  return Object.freeze({
    aircraftVariantKey,phase,aircraftConfigurationCode,
    operatingMassKg:number(operatingMassKg),asOfDate,
    conditions:Object.freeze(c)
  });
}

function sameEnvironment(point,scenario) {
  return point.phase===scenario.phase &&
    point.aircraftConfigurationCode===scenario.aircraftConfigurationCode &&
    Object.entries(scenario.conditions).every(([key,val])=>
      key==='runwayCondition' ? point[key]===val : number(point[key])===val);
}
function sourceDistance(point,key) {
  const n=number(point[key]);
  return Number.isFinite(n) && n>0 && n<=20000 ? n : null;
}
function checkedGrid(points,scenario) {
  const relevant=[];
  for(const row of points) {
    if(!row || !sameEnvironment(row,scenario)) continue;
    if(row.reviewStatus!=='PRIMARY_SOURCE_REVIEWED' ||
       typeof row.sourceTableReference!=='string' ||
       row.sourceTableReference.trim().length<3) continue;
    if(!bounded(row.operatingMassKg,1,1000000)) {
      throw new Error('Invalid reviewed point mass.');
    }
    const distances={};
    for(const key of DISTANCES[scenario.phase]) {
      distances[key]=sourceDistance(row,key);
      if(distances[key]===null) throw new Error('Incomplete reviewed source performance point.');
    }
    relevant.push({mass:number(row.operatingMassKg),distances,ref:row.sourceTableReference});
  }
  relevant.sort((a,b)=>a.mass-b.mass);
  for(let i=1;i<relevant.length;i++){
    if(relevant[i].mass===relevant[i-1].mass) {
      throw new Error('Conflicting duplicate reviewed reference mass.');
    }
    for(const key of DISTANCES[scenario.phase]){
      if(relevant[i].distances[key]<relevant[i-1].distances[key]) {
        throw new Error('Non-monotonic reviewed reference mass curve.');
      }
    }
  }
  return relevant;
}

/**
 * Conservative source-grid calculation ONLY.
 * No cross-condition interpolation. No below/above-grid extrapolation.
 * For off-grid mass, the next higher approved point is used without
 * interpolation ONLY if the cited source has reviewed monotonicity.
 */
export function calculateReviewedAircraftPerformance({scenario,reference,points}={}) {
  const s=validateAircraftOperatingScenario(scenario);
  if(!reference || !Array.isArray(points) ||
     reference.reviewStatus!=='PRIMARY_SOURCE_REVIEWED' ||
     reference.aircraftVariantKey!==s.aircraftVariantKey ||
     !isoDay(reference.sourceEffectiveDate) ||
     reference.sourceEffectiveDate>s.asOfDate ||
     typeof reference.sourceDocumentRef!=='string' ||
     reference.sourceDocumentRef.trim().length<3 ||
     typeof reference.sourceAuthority!=='string' ||
     reference.sourceAuthority.trim().length<3) {
    return blocked('REVIEWED_REFERENCE_NOT_AVAILABLE',['NO_EFFECTIVE_REVIEWED_AFM_OR_OEM_SOURCE']);
  }
  if(!bounded(reference.maxTakeoffMassKg,1,1000000) ||
     !bounded(reference.maxLandingMassKg,1,1000000) ||
     !bounded(reference.minReferenceMassKg,1,1000000) ||
     !bounded(reference.wingspanM,1,150) ||
     number(reference.minReferenceMassKg)>number(reference.maxLandingMassKg) ||
     number(reference.maxLandingMassKg)>number(reference.maxTakeoffMassKg)) {
    return blocked('INVALID_SOURCE_LIMITS',['CERTIFIED_MASS_LIMITS_NOT_VERIFIED']);
  }
  const max=s.phase==='TAKEOFF'?
    number(reference.maxTakeoffMassKg):number(reference.maxLandingMassKg);
  if(s.operatingMassKg>max || s.operatingMassKg<number(reference.minReferenceMassKg)) {
    return blocked('AIRCRAFT_MASS_OUTSIDE_REFERENCE_LIMITS',['MASS_LIMIT_EXCEEDED_OR_UNDERFLOW']);
  }
  const grid=checkedGrid(points,s);
  if(!grid.length) return blocked('CONDITIONS_NOT_COVERED',['NO_EXACT_CERTIFIED_WEATHER_ELEVATION_SLOPE_SURFACE_POINT']);
  if(s.operatingMassKg<grid[0].mass ||
     s.operatingMassKg>grid[grid.length-1].mass) {
    return blocked('WEIGHT_OUTSIDE_SOURCE_GRID',['EXTRAPOLATION_PROHIBITED']);
  }
  const exact=grid.find(p=>p.mass===s.operatingMassKg);
  const selected=exact || grid.find(p=>p.mass>s.operatingMassKg);
  if(!exact && reference.allowConservativeMassUpperEnvelope!==true){
    return blocked('OFF_GRID_MASS_REQUIRES_REVIEWED_ENVELOPE',['NO_UNAPPROVED_INTERPOLATION']);
  }
  const trace=[reference.sourceDocumentRef,reference.sourceRevision||'no-revision',selected.ref].join(' / ');
  if(trace.length>256) return blocked('REFERENCE_TRACE_TOO_LONG',['SOURCE_IDENTITY_NOT_PORTABLE']);
  return Object.freeze({
    status:'REVIEWED_REFERENCE_POINT_SELECTED',
    requiredDistancesM:Object.freeze({...selected.distances}),
    referencePointMassKg:selected.mass,
    actualOperatingMassKg:s.operatingMassKg,
    calculationMethod:exact?'EXACT_GRID_POINT':'SOURCE_APPROVED_NEXT_HIGHER_MASS',
    aircraftVariantKey:s.aircraftVariantKey,
    aircraftConfigurationCode:s.aircraftConfigurationCode,
    phase:s.phase,
    sourceAuthority:reference.sourceAuthority,
    sourceDocumentRef:reference.sourceDocumentRef,
    sourceEffectiveDate:reference.sourceEffectiveDate,
    calculationReference:trace,
    verifiedConditions:s.conditions,
    blockers:Object.freeze([]),
    schedulingAllowed:false
  });
}
