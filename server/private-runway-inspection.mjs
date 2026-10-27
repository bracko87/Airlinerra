/**
 * Server-only World 1 runway research inspection.
 * This module DOES NOT authorize routes, aircraft, airlines, airports or game launch.
 * No public HTTP handler, Netlify Function, browser import or automatic deployment.
 *
 * The query scopes all research to the owner's private World 1 approved-game
 * airport roster, and ignores sources not yet effective at the supplied date.
 * Research facts cannot create a game airport or change its approval.
 */
export const WORLD1_RUNWAY_INSPECTION_SQL = `
WITH latest_effective AS (
  SELECT DISTINCT ON (sv.runway_pair)
    sv.id, sv.airport_key, sv.runway_pair, sv.source_effective_date
  FROM airlinerra.runway_source_versions sv
  WHERE sv.airport_key = $2::text
    AND sv.source_effective_date IS NOT NULL
    AND sv.source_effective_date <= $3::date
  ORDER BY sv.runway_pair, sv.source_effective_date DESC, sv.id DESC
)
SELECT a.world_id, a.airport_key, g.enabled AS release_enabled,
  sv.runway_pair, sv.source_effective_date,
  p.physical_length_m, p.normalized_surface, p.material_verification,
  p.runway_operational_status,
  rv.game_admission_status AS research_admission,
  ps.permission_state AS scheduled_permission,
  COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'direction', d.direction_code,
      'tora_m', d.tora_m, 'toda_m', d.toda_m,
      'asda_m', d.asda_m, 'lda_m', d.lda_m,
      'takeoff_status', d.takeoff_status,
      'landing_status', d.landing_status
    ) ORDER BY d.direction_code)
    FROM airlinerra.runway_direction_facts d
    WHERE d.source_version_id = sv.id
  ), '[]'::jsonb) AS directions
FROM airlinerra_game.approved_game_airports a
JOIN airlinerra_game.platform_release_gate g ON g.id = true
LEFT JOIN latest_effective sv ON sv.airport_key = a.airport_key
LEFT JOIN airlinerra.runway_physical_facts p ON p.source_version_id = sv.id
LEFT JOIN airlinerra.airport_access_reviews rv ON rv.airport_key = a.airport_key
LEFT JOIN airlinerra.runway_permission_facts ps
  ON ps.source_version_id = sv.id AND ps.operation_type = 'SCHEDULED_PASSENGER'
WHERE a.world_id = $1::smallint
  AND a.airport_key = $2::text
ORDER BY sv.runway_pair
`;

const AIRPORT_KEY = /^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const ISO_DATE = /^20[2-9][0-9]-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])$/u;
const SURFACES = new Set([
  'ASPHALT', 'CONCRETE', 'MIXED_VERIFIED', 'PAVED_UNSPECIFIED',
  'MACADAM_UNRESOLVED', 'UNKNOWN', 'NON_PAVED'
]);
const OPERATIONS = new Set(['OPEN', 'RESTRICTED', 'CLOSED', 'UNVERIFIED']);

export function validateRunwayInspectionRequest({worldId, airportKey, asOfDate}={}) {
  if (worldId !== 1) throw new Error('Only World 1 airport inspection is supported.');
  if (typeof airportKey !== 'string' || !AIRPORT_KEY.test(airportKey)) {
    throw new Error('Invalid airport key.');
  }
  if (typeof asOfDate !== 'string' || !ISO_DATE.test(asOfDate) ||
      new Date(asOfDate + 'T00:00:00Z').toISOString().slice(0,10) !== asOfDate) {
    throw new Error('Explicit valid UTC source inspection date is required.');
  }
  return Object.freeze({worldId:1,airportKey,asOfDate});
}

function checkedRunway(row) {
  if (typeof row.runway_pair !== 'string' ||
      !/^[0-9]{2}[LRC]?\/[0-9]{2}[LRC]?$/u.test(row.runway_pair)) {
    throw new Error('Invalid source runway identity.');
  }
  const length=Number(row.physical_length_m);
  if (!Number.isFinite(length) || length <= 0 ||
      !SURFACES.has(row.normalized_surface) ||
      !['VERIFIED','UNVERIFIED'].includes(row.material_verification) ||
      !OPERATIONS.has(row.runway_operational_status) ||
      !Array.isArray(row.directions)) {
    throw new Error('Invalid or incomplete runway research facts.');
  }
  const directions = row.directions.map(d => {
    if (!d || !/^[0-9]{2}[LRC]?$/u.test(d.direction || '')) {
      throw new Error('Invalid runway direction.');
    }
    return Object.freeze({
      direction: d.direction,
      toraM: d.tora_m === null ? null : Number(d.tora_m),
      todaM: d.toda_m === null ? null : Number(d.toda_m),
      asdaM: d.asda_m === null ? null : Number(d.asda_m),
      ldaM: d.lda_m === null ? null : Number(d.lda_m),
      takeoffStatus:d.takeoff_status,
      landingStatus:d.landing_status
    });
  });
  // An exact material and sufficient physical length are a technical
  // precondition, NOT operational availability or an airline permit.
  const materialPass = length >= 1200 &&
    row.material_verification === 'VERIFIED' &&
    ['ASPHALT','CONCRETE','MIXED_VERIFIED'].includes(row.normalized_surface);
  return Object.freeze({
    runwayPair:row.runway_pair,
    physicalLengthM:length,
    normalizedSurface:row.normalized_surface,
    materialVerified:materialPass,
    operationalStatus:row.runway_operational_status,
    researchAdmission:row.research_admission || 'UNVERIFIED',
    scheduledPermission:row.scheduled_permission || 'UNVERIFIED',
    directions:Object.freeze(directions),
    mayScheduleFlights:false
  });
}

/**
 * Requires a privileged private server PostgreSQL pool, never a browser
 * client. Disabled by default. Even if enabled it returns observations only,
 * and NEVER a scheduling authorization.
 */
export function createPrivateRunwayInspectionService({database,enabled=false}={}) {
  if (!database || typeof database.connect!=='function') {
    throw new Error('A private server-side PostgreSQL pool is required.');
  }
  return Object.freeze({
    async inspect(request) {
      const req=validateRunwayInspectionRequest(request);
      if (!enabled) throw new Error('Private runway inspection is disabled.');
      const client=await database.connect();
      let rows;
      try {
        const result=await client.query(WORLD1_RUNWAY_INSPECTION_SQL,
          [req.worldId,req.airportKey,req.asOfDate]);
        if (!result || !Array.isArray(result.rows)) {
          throw new Error('Invalid private runway database result.');
        }
        rows=result.rows;
      } finally {
        client.release();
      }
      if (!rows.length) return Object.freeze({
        ...req,inApprovedWorld:false,releaseEnabled:false,
        status:'NOT_IN_APPROVED_WORLD',runways:Object.freeze([]),
        mayScheduleFlights:false
      });
      if (rows.some(row => Number(row.world_id)!==1 ||
          row.airport_key!==req.airportKey ||
          typeof row.release_enabled!=='boolean' ||
          row.release_enabled!==rows[0].release_enabled)) {
        throw new Error('Inconsistent private airport release boundary.');
      }
      const seen=new Set();
      const runways=rows.filter(row=>row.runway_pair!==null).map(row=>{
        const item=checkedRunway(row);
        if (seen.has(item.runwayPair)) throw new Error('Duplicate effective runway.');
        seen.add(item.runwayPair);
        return item;
      });
      const releaseEnabled=rows[0].release_enabled;
      return Object.freeze({
        ...req,inApprovedWorld:true,releaseEnabled,
        status:!releaseEnabled?'PRELAUNCH_LOCKED':
          !runways.length?'NO_EFFECTIVE_RUNWAY_SOURCES':'RESEARCH_ONLY',
        runways:Object.freeze(runways),
        // Aircraft performance, carrier permissions, NOTAMs and a separately
        // approved game-side publication do NOT exist in this service.
        mayScheduleFlights:false
      });
    }
  });
}
