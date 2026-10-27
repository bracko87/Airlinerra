/**
 * Privileged, default-off AFM/OEM performance loader.
 * No public HTTP route, no Netlify Function, no game scheduling.
 */
import {
  validateAircraftOperatingScenario, calculateReviewedAircraftPerformance
} from './private-aircraft-performance-reference.mjs';

export const AIRCRAFT_PERFORMANCE_REFERENCE_READ_SQL = [
  'WITH newest AS (',
  ' SELECT s.* FROM airlinerra.aircraft_performance_reference_sets s',
  ' WHERE s.aircraft_variant_key=$1::text AND s.source_effective_date<=$2::date',
  ' ORDER BY s.source_effective_date DESC,s.id DESC LIMIT 1',
  ')',
  'SELECT s.id AS reference_set_id,s.aircraft_variant_key,',
  ' s.max_takeoff_mass_kg,s.max_landing_mass_kg,s.min_reference_mass_kg,',
  ' s.wingspan_m,s.source_authority,s.source_document_ref,s.source_revision,',
  ' s.source_effective_date,s.review_status AS reference_review_status,',
  ' s.allow_conservative_mass_upper_envelope,',
  ' p.id AS point_id,p.phase,p.aircraft_configuration_code,',
  ' p.operating_mass_kg,p.pressure_altitude_ft,p.outside_air_temperature_c,',
  ' p.headwind_component_kt,p.runway_slope_pct,p.runway_condition,',
  ' p.required_tora_m,p.required_toda_m,p.required_asda_m,p.required_lda_m,',
  ' p.source_table_reference,p.review_status AS point_review_status',
  'FROM newest s LEFT JOIN airlinerra.aircraft_performance_reference_points p',
  ' ON p.reference_set_id=s.id AND p.phase=$3::text',
  ' AND p.aircraft_configuration_code=$4::text',
  ' AND p.pressure_altitude_ft=$5::integer',
  ' AND p.outside_air_temperature_c=$6::numeric',
  ' AND p.headwind_component_kt=$7::numeric',
  ' AND p.runway_slope_pct=$8::numeric AND p.runway_condition=$9::text',
  'ORDER BY p.operating_mass_kg,p.id'
].join('\n');

function convert(rows) {
  if(!Array.isArray(rows) || rows.length===0) return {reference:null,points:[]};
  const first=rows[0], refId=String(first.reference_set_id);
  if(rows.some(row=>String(row.reference_set_id)!==refId)) {
    throw new Error('Conflicting aircraft reference set identities.');
  }
  const date=first.source_effective_date;
  const reference={
    aircraftVariantKey:first.aircraft_variant_key,
    maxTakeoffMassKg:first.max_takeoff_mass_kg,
    maxLandingMassKg:first.max_landing_mass_kg,
    minReferenceMassKg:first.min_reference_mass_kg,
    wingspanM:first.wingspan_m,
    sourceAuthority:first.source_authority,
    sourceDocumentRef:first.source_document_ref,
    sourceRevision:first.source_revision,
    sourceEffectiveDate:date instanceof Date?date.toISOString().slice(0,10):String(date),
    reviewStatus:first.reference_review_status,
    allowConservativeMassUpperEnvelope:first.allow_conservative_mass_upper_envelope
  };
  const points=rows.filter(row=>row.point_id!=null).map(row=>({
    phase:row.phase,
    aircraftConfigurationCode:row.aircraft_configuration_code,
    operatingMassKg:row.operating_mass_kg,
    pressureAltitudeFt:row.pressure_altitude_ft,
    outsideAirTemperatureC:row.outside_air_temperature_c,
    headwindComponentKt:row.headwind_component_kt,
    runwaySlopePct:row.runway_slope_pct,
    runwayCondition:row.runway_condition,
    toraM:row.required_tora_m,todaM:row.required_toda_m,
    asdaM:row.required_asda_m,ldaM:row.required_lda_m,
    sourceTableReference:row.source_table_reference,
    reviewStatus:row.point_review_status
  }));
  return {reference,points};
}

export function createPrivateAircraftPerformanceReferenceLoader({database,enabled=false}={}) {
  if(!database || typeof database.connect!=='function') {
    throw new Error('Privileged private PostgreSQL pool required.');
  }
  return Object.freeze({
    async calculate(input) {
      const s=validateAircraftOperatingScenario(input);
      if(!enabled) throw new Error('Private aircraft reference loading disabled.');
      const client=await database.connect();
      let rows;
      try {
        const result=await client.query(AIRCRAFT_PERFORMANCE_REFERENCE_READ_SQL,[
          s.aircraftVariantKey,s.asOfDate,s.phase,s.aircraftConfigurationCode,
          s.conditions.pressureAltitudeFt,s.conditions.outsideAirTemperatureC,
          s.conditions.headwindComponentKt,s.conditions.runwaySlopePct,
          s.conditions.runwayCondition
        ]);
        if(!result || !Array.isArray(result.rows)) {
          throw new Error('Invalid reviewed source query result.');
        }
        rows=result.rows;
      } finally { client.release(); }
      return calculateReviewedAircraftPerformance({scenario:s,...convert(rows)});
    }
  });
}

export function createPrivateAircraftPerformanceRunwayResearchService({
  referenceLoader,runwayScreeningService,enabled=false
}={}) {
  if(!referenceLoader || typeof referenceLoader.calculate!=='function' ||
     !runwayScreeningService || typeof runwayScreeningService.screen!=='function') {
    throw new Error('Private reference and runway screening services required.');
  }
  return Object.freeze({
    async evaluate({request,aircraftScenario}={}) {
      const s=validateAircraftOperatingScenario(aircraftScenario);
      if(!enabled) throw new Error('Private aircraft runway composition disabled.');
      const result=await referenceLoader.calculate(s);
      if(result.status!=='REVIEWED_REFERENCE_POINT_SELECTED') {
        return Object.freeze({
          referenceStatus:result.status,referenceBlockers:result.blockers,
          aircraftVariantKey:s.aircraftVariantKey,
          runwayResearch:null,schedulingAllowed:false
        });
      }
      const runwayResearch=await runwayScreeningService.screen({
        request,scenario:{
          aircraftCode:s.aircraftVariantKey,phase:s.phase,
          operatingMassKg:s.operatingMassKg,
          calculationReference:result.calculationReference,
          requiredDistancesM:result.requiredDistancesM
        }
      });
      return Object.freeze({
        aircraftVariantKey:s.aircraftVariantKey,
        referenceStatus:result.status,
        requiredDistancesM:result.requiredDistancesM,
        referencePointMassKg:result.referencePointMassKg,
        calculationMethod:result.calculationMethod,
        runwayResearch,schedulingAllowed:false
      });
    }
  });
}
