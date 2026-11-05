/**
 * Read-only Airlinerra aircraft catalog for the private manager library.
 * Database data remain in the private project; no browser PostgreSQL access.
 * One row per configuration, including conditional/game-estimated fields.
 */
export const AIRCRAFT_LIBRARY_SQL = `
select c.id::int as id,m.name as manufacturer,f.family_name as family,
 v.model_name as model,c.configuration_code as configuration,c.use_type as use_type,
 c.typical_passenger_seats as seats,c.maximum_passenger_seats as max_seats,
 c.maximum_cargo_payload_kg as cargo_kg,
 v.production_start_year as production_start,v.production_end_year as factual_production_end,
 coverage.game_planning_end_year as planning_production_end,
 coverage.game_planning_newbuild_status as game_production_status,
 v.civilian_service_status as service_status,
 t.maximum_takeoff_weight_kg as mtow_kg,t.maximum_landing_weight_kg as mlw_kg,
 coalesce(t.maximum_fuel_capacity_kg,t.manufacturer_usable_fuel_mass_kg,t.gameplay_placeholder_fuel_capacity_kg,
   (select max(coalesce(other.maximum_fuel_capacity_kg,other.manufacturer_usable_fuel_mass_kg,
      other.gameplay_placeholder_fuel_capacity_kg)) from airlinerra.aircraft_technical_specs other
    where other.configuration_id=c.id)) as fuel_kg,
 t.typical_range_km as range_km,t.cruise_speed_kmh as speed_kmh,
 t.published_takeoff_distance_m as takeoff_m,t.published_landing_distance_m as landing_m,
 t.wingspan_m as wingspan_m,t.fuselage_length_m as length_m,t.height_m as height_m,
 t.review_status as technical_review_status,
 coverage.game_estimation_type as game_estimation_type,
 coverage.amphibious_only_paved_takeoff_m as conditional_takeoff_m,
 coverage.amphibious_only_paved_landing_m as conditional_landing_m,
 coverage.mandatory_equipment as required_equipment,
 ready.route_game_gate as readiness_gate,ready.release_hold_reason as hold_reason,
 cert.official_icao_chapter AS official_icao_chapter,
 cert.noise_certificate_status AS icao_noise_status,
 cert.certification_match_basis AS icao_noise_match_basis,
 cert.evidence_url AS icao_noise_source,
 representative.representative_engine_model AS representative_engine_model,
 representative.representative_engine_count AS representative_engine_count,
 representative.engine_choice_method AS representative_engine_choice_method,
 representative.evidence_strength AS representative_engine_evidence_strength,
 representative.source_url AS representative_engine_source,
 noisegame.game_chapter_assumption AS game_icao_noise_chapter,
 noisegame.chapter_evidence_level AS game_icao_noise_evidence,
 noisegame.chapter_engine_match_status AS game_icao_noise_engine_match,
 fullref.mtow_kg AS full_weight_reference_mtow_kg,
 fullref.mlw_kg AS full_weight_reference_mlw_kg,
 fullref.game_full_weight_takeoff_reference_m AS full_weight_takeoff_reference_m,
 fullref.game_full_weight_landing_reference_m AS full_weight_landing_reference_m,
 fullref.reference_evidence_class AS full_weight_evidence_class,
 fullref.full_weight_assumption AS full_weight_assumption,
 fullref.game_formula_version AS full_weight_formula_version
from airlinerra.aircraft_configurations c
join airlinerra.aircraft_variants v on v.id=c.variant_id
join airlinerra.aircraft_families f on f.id=v.family_id
join airlinerra.aircraft_manufacturers m on m.id=f.manufacturer_id
join airlinerra.aircraft_game_data_coverage_v1 coverage on coverage.configuration_id=c.id
join airlinerra.aircraft_configuration_game_readiness_v1 ready on ready.configuration_id=c.id
left join airlinerra_game.section5_icao_aircraft_certification_v2 cert on cert.configuration_id=c.id
left join airlinerra_game.section5_aircraft_representative_engine_v1 representative on representative.configuration_id=c.id
left join airlinerra_game.section5_aircraft_representative_noise_baseline_v1 noisegame on noisegame.configuration_id=c.id
left join airlinerra_game.section5_full_weight_aircraft_reference_v2 fullref on fullref.configuration_id=c.id
left join lateral (
 select t.* from airlinerra.aircraft_technical_specs t
 where t.configuration_id=c.id
 order by
 ((t.maximum_takeoff_weight_kg is not null)::int+
  (t.maximum_landing_weight_kg is not null)::int+
  (t.typical_range_km is not null)::int+
  (t.cruise_speed_kmh is not null)::int+
  (t.published_takeoff_distance_m is not null)::int+
  (t.published_landing_distance_m is not null)::int+
  (t.wingspan_m is not null)::int+
  (t.fuselage_length_m is not null)::int+
  (t.height_m is not null)::int+
  (coalesce(t.maximum_fuel_capacity_kg,t.manufacturer_usable_fuel_mass_kg,t.gameplay_placeholder_fuel_capacity_kg) is not null)::int) desc,
 t.id asc limit 1
) t on true
order by m.name,f.family_name,v.model_name,c.configuration_code,c.id
limit 1001`;
export const AIRCRAFT_LIBRARY_PATH='/api/v1/player/aircraft-library';
const safeText=(s,max=160)=>typeof s==='string'&&s.length>0&&s.length<=max?s:null;
const num=(n,lo=0,hi=1000000000)=>{
 if(n===null||n===undefined||n==='')return null;
 const value=Number(n);
 return Number.isFinite(value)&&value>=lo&&value<=hi?value:null;
};
export function serializeAircraftLibrary(rows){
 if(!Array.isArray(rows)||rows.length===0||rows.length>1000)throw Error('Invalid aircraft catalog size');
 const ids=new Set();
 const aircraft=rows.map(r=>{
  const id=num(r.id,1,1000000);
  if(!Number.isInteger(id)||ids.has(id)||!safeText(r.manufacturer)||!safeText(r.family)||
     !safeText(r.model)||!safeText(r.configuration)||!['passenger','cargo','combi'].includes(r.use_type))
    throw Error('Invalid aircraft catalog record');
  ids.add(id);
  return {
   id,manufacturer:r.manufacturer,family:r.family,model:r.model,
   configuration:r.configuration,useType:r.use_type,
   seats:num(r.seats,0,1000),maxSeats:num(r.max_seats,0,1000),
   cargoKg:num(r.cargo_kg,0),productionStart:num(r.production_start,1900,2100),
   productionEnd:num(r.planning_production_end,1900,2100),
   productionEndEstimated:r.factual_production_end===null&&r.planning_production_end!==null,
   productionStatus:safeText(r.game_production_status,40),
   serviceStatus:safeText(r.service_status,40),
   mtowKg:num(r.mtow_kg),mlwKg:num(r.mlw_kg),fuelKg:num(r.fuel_kg),
   rangeKm:num(r.range_km),speedKmh:num(r.speed_kmh),
   takeoffM:num(r.takeoff_m),landingM:num(r.landing_m),
   fullWeightReferenceMtowKg:num(r.full_weight_reference_mtow_kg),
   fullWeightReferenceMlwKg:num(r.full_weight_reference_mlw_kg),
   fullWeightTakeoffReferenceM:num(r.full_weight_takeoff_reference_m),
   fullWeightLandingReferenceM:num(r.full_weight_landing_reference_m),
   fullWeightEvidenceClass:safeText(r.full_weight_evidence_class,128),
   fullWeightAssumption:safeText(r.full_weight_assumption,600),
   fullWeightGameFormula:safeText(r.full_weight_formula_version,100),

   wingspanM:num(r.wingspan_m),lengthM:num(r.length_m),heightM:num(r.height_m),
   technicalReview:r.technical_review_status==='verified'?'verified':'research',
   gameEstimate:r.game_estimation_type==='FICTIONAL_GAME_ONLY',
   conditionalTakeoffM:num(r.conditional_takeoff_m),
   conditionalLandingM:num(r.conditional_landing_m),
   requiredEquipment:r.required_equipment==='AMPHIBIOUS_FLOATS_WITH_WHEELS'
     ?'AMPHIBIOUS_FLOATS_WITH_WHEELS':null,
   readinessGate:safeText(r.readiness_gate,80),
   holdReason:safeText(r.hold_reason,100),
   gameNoiseClass:null,
   noiseClassificationConfidence:'LEGACY_FIVE_CLASS_SCALE_RETIRED',
   representativeEngine:safeText(r.representative_engine_model,80),
   representativeEngineCount:num(r.representative_engine_count,1,8),
   representativeEngineSelectionMethod:safeText(r.representative_engine_choice_method,50),
   representativeEngineEvidence:safeText(r.representative_engine_evidence_strength,64),
   representativeEngineSource:safeText(r.representative_engine_source,512),
   gameNoiseChapter:num(r.game_icao_noise_chapter,2,14),
   gameNoiseChapterEvidence:safeText(r.game_icao_noise_evidence,80),
   gameNoiseEngineMatch:safeText(r.game_icao_noise_engine_match,80),
   icaoNoiseChapter:num(r.official_icao_chapter,2,14),
   icaoNoiseStatus:safeText(r.icao_noise_status,64)||'CERTIFICATE_NOT_VERIFIED',
   icaoNoiseMatchBasis:safeText(r.icao_noise_match_basis,128),
   icaoNoiseSource:safeText(r.icao_noise_source,512)
  };
 });
 return Object.freeze({aircraft,total:aircraft.length,readOnly:true,
  note:'Game-planning catalog. Values marked research or estimated are not aircraft certification or flight authorization.'});
}
