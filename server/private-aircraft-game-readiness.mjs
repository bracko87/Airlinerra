/**
 * Private, prelaunch Airlinerra aircraft catalog eligibility gate.
 * Queries the Batch 57 readiness view. NEVER authorizes scheduling or flight.
 * No HTTP handler, browser import, service credentials, or dynamic SQL.
 */
export const AIRCRAFT_GAME_READINESS_SQL = [
  'SELECT g.configuration_id, v.variant_key AS aircraft_variant_key,',
  ' g.route_game_gate,g.essential_fields_populated,',
  ' g.release_hold_reason,g.runway_surface_mode,',
  ' g.paved_runway_game_eligible,g.passenger_cargo_loading_mode,',
  ' g.civilian_service_status',
  'FROM airlinerra.aircraft_configuration_game_readiness_v1 g',
  'JOIN airlinerra.aircraft_variants v ON v.id=g.variant_id',
  'WHERE g.configuration_id=$1::bigint AND v.variant_key=$2::text'
].join('\n');

const KEY=/^[A-Z0-9][A-Z0-9_-]{2,31}$/u;
const GATES=new Set([
  'PROVISIONAL_DATA_ONLY','HOLD_GAME_RULE_NOT_INTEGRATED',
  'HOLD_PAVED_RUNWAY_UNVERIFIED','HOLD_MAINTENANCE',
  'HOLD_REQUIRED_FIELDS_MISSING','HOLD_SERVICE_UNVERIFIED'
]);
function blocked(status,blocker) {
  return Object.freeze({catalogStatus:status,
    researchScreeningAllowed:false,schedulingAllowed:false,
    blockers:Object.freeze([blocker])});
}

/** Strictly a private research gate: even the provisional path cannot release flights. */
export function assessAircraftGameReadiness(row,{configurationId,aircraftVariantKey}={}) {
  if (!row) return blocked('CATALOG_CONFIGURATION_NOT_FOUND','NO_MATCHING_CATALOG_CONFIGURATION');
  const id=Number(row.configuration_id);
  if(id!==configurationId||row.aircraft_variant_key!==aircraftVariantKey||
     !GATES.has(row.route_game_gate)||
     typeof row.essential_fields_populated!=='boolean'||
     !['active','temporarily_grounded','unverified'].includes(row.civilian_service_status)) {
    return blocked('CATALOG_DATA_INVALID','CATALOG_STATUS_INCONSISTENT');
  }
  const ready=row.route_game_gate==='PROVISIONAL_DATA_ONLY' &&
    row.essential_fields_populated===true &&
    row.release_hold_reason==null &&
    row.civilian_service_status==='active';
  if (!ready) {
    const reason=row.release_hold_reason===null?row.route_game_gate:
      typeof row.release_hold_reason==='string' &&
      /^[A-Z][A-Z0-9_]{2,95}$/u.test(row.release_hold_reason)?
        row.release_hold_reason:'CATALOG_STATUS_INCONSISTENT';
    return blocked(row.route_game_gate,reason);
  }
  return Object.freeze({
    catalogStatus:'PROVISIONAL_DATA_ONLY',
    researchScreeningAllowed:true,
    schedulingAllowed:false,
    blockers:Object.freeze(['NO_LIVE_GAME_OR_DISPATCH_AUTHORIZATION'])
  });
}

export function createPrivateAircraftGameReadinessService({database,enabled=false}={}) {
  if(typeof database?.connect!=='function')
    throw Error('Privileged private database connection required.');
  return Object.freeze({
    async inspect({configurationId,aircraftVariantKey}={}) {
      if(!Number.isSafeInteger(configurationId)||configurationId<1||configurationId>1_000_000||
         typeof aircraftVariantKey!=='string'||!KEY.test(aircraftVariantKey))
        throw Error('Valid catalog configuration ID and variant key required.');
      if(!enabled)throw Error('Private aircraft game readiness research disabled.');
      let client;
      try {
        client=await database.connect();
        const result=await client.query(AIRCRAFT_GAME_READINESS_SQL,[configurationId,aircraftVariantKey]);
        if(!Array.isArray(result?.rows)||result.rows.length>1)
          return blocked('CATALOG_DATA_INVALID','CATALOG_AMBIGUOUS_OR_UNAVAILABLE');
        return assessAircraftGameReadiness(result.rows[0],{configurationId,aircraftVariantKey});
      } catch {
        return blocked('CATALOG_UNAVAILABLE','PRIVATE_CATALOG_QUERY_FAILED');
      } finally {
        try{client?.release();}catch{/* do not expose private database details */}
      }
    }
  });
}
