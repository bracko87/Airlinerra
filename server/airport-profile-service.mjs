/** Read-only World 1 airport profile sourced from approved roster + research tables.
 * No simulation, user ledger, or operations mutation. Only authenticated callers.
 * All provisional and missing data remain explicitly identified.
 */
export const AIRPORT_PROFILE_PATH='/api/v1/player/airport-profile';
const KEY=/^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const CATEGORIES=new Set(['Local','Regional','Medium','Large','Major Hub','Mega Hub']);
export const validAirportKey=value=>typeof value==='string'&&KEY.test(value);
export const AIRPORT_PROFILE_SQL=`
 SELECT a.airport_key,a.airport_name,a.airport_code,a.country_iso,
        a.municipality AS roster_municipality,
        p.game_official_name,p.official_name_verified,
        p.game_municipality,p.region_iso,p.region_display_name,
        p.latitude_deg::text AS latitude_deg,p.longitude_deg::text AS longitude_deg,
        p.coordinates_verification,p.coordinates_source_type,
        p.icao_reported,p.iata_reported,p.game_display_code,
        p.approved_category,p.provisional_category,
        p.timezone_iana,p.timezone_candidate_iana,
        p.game_elevation_ft::text AS game_elevation_ft,
        p.game_elevation_provenance,
        p.airport_kind,
        f.terminal_count,f.passenger_gate_count,f.aircraft_stand_count,
        f.operating_hours_local,f.curfew_details,f.noise_restrictions,
        f.facility_status,
        cap.terminal_stands AS slot_terminal_stands,
        cap.remote_stands AS slot_remote_stands,
        cap.cargo_stands AS slot_cargo_stands,
        cap.terminal_per_direction_10m AS slot_terminal_per_direction_10m,
        cap.remote_per_direction_10m AS slot_remote_per_direction_10m,
        cap.cargo_per_direction_10m AS slot_cargo_per_direction_10m,
        transfer.minimum_transfer_minutes AS game_minimum_transfer_minutes,
        transfer.maximum_transfer_minutes AS game_maximum_transfer_minutes,
        transfer.airport_background AS game_demand_background,
        transfer.seasonal_profile AS game_seasonal_profile,
        ops.game_operating_hours_summary,ops.operating_hours_basis AS game_operating_hours_basis,
        ops.max_day_game_noise_class,ops.max_night_game_noise_class,
        ops.noise_limit_basis,ops.time_restrictions AS game_time_restrictions,
        chapter.research_status AS icao_noise_research_status,
        chapter.documented_prohibited_chapters AS icao_prohibited_chapters,
        chapter.documented_restriction_kind AS icao_rule_kind,
        chapter.cumulative_margin_requirement_epndb AS icao_minimum_margin_epndb,
        chapter.source_url AS icao_noise_source,
        national.minimum_icao_chapter AS national_jet_min_chapter,
        national.country_rule_group AS national_jet_rule_scope,
        national.legal_source_url AS national_jet_rule_source,
        national.permit_exception_note AS national_jet_rule_exceptions,
        curfew.evidence_status AS curfew_research_status,
         restriction.game_restriction_status AS game_restriction_status,
         restriction.operating_condition_screen AS operating_condition_screen,
         restriction.operating_research_note AS operating_research_note,
         restriction.operating_research_source AS operating_research_source,
         restriction.operating_research_checked AS operating_research_checked,
         restriction.noise_condition_screen AS noise_condition_screen,
         restriction.noise_research_note AS noise_research_note,
         restriction.noise_research_source AS noise_research_source,
         restriction.noise_research_checked AS noise_research_checked,
         restriction.total_time_rules AS structured_time_rule_count,
         restriction.enforced_time_rules AS enforced_time_rule_count,
         restriction.review_only_time_rules AS review_time_rule_count,
         restriction.time_rule_details AS precise_time_rule_details,
         restriction.total_runway_rules AS structured_runway_rule_count,
         restriction.enforced_runway_rules AS enforced_runway_rule_count,
         restriction.runway_rule_details AS precise_runway_rule_details,
         restriction.time_research_still_unstructured AS research_still_unstructured,
         simple.nighttime_ban AS simple_game_nighttime_ban,
         simple.noise_restrictions AS simple_game_noise_restrictions,
         simple.permitted_noise_chapters AS simple_game_permitted_chapters,
         simple.simplified_nighttime_window AS simple_game_nighttime_window,
         simple.source_status AS simple_game_source_status,
         simple.source_url AS simple_game_source_url,
        (
          SELECT coalesce(jsonb_agg(jsonb_build_object(
            'code',nr.rule_code,'kind',nr.rule_kind,
            'operation',nr.affected_operations,
            'localStart',nr.window_start_local::text,
            'localEnd',nr.window_end_local::text,
            'chapter',nr.documented_icao_chapter,
            'enforcement',nr.game_enforcement_status,
            'source',nr.evidence_source_url,'notes',nr.evidence_note
          ) ORDER BY nr.rule_code),'[]'::jsonb)
          FROM airlinerra_game.section5_airport_official_noise_rules_v2 nr
          WHERE nr.world_id=a.world_id AND nr.airport_key=a.airport_key
        ) AS icao_airport_noise_rules,
        wx.forecast_status,wx.is_current AS forecast_is_current,
        wx.provider_fetched_at AS weather_provider_fetched_at,
        wx.forecast_valid_through AS weather_valid_through,
        wx.temperature_c AS weather_temperature_c,wx.weather_symbol,
        wx.precipitation_mm AS weather_precipitation_mm,
        wx.wind_speed_kmh AS weather_wind_kmh,
        wx.next_24h_local_3hourly AS weather_next_24h,
        wx.required_attribution AS weather_attribution,
        traffic.daily_outbound_passengers,traffic.daily_outbound_cargo_tonnes,
        traffic.passenger_demand_percentile,traffic.cargo_demand_percentile,
        (SELECT COALESCE(jsonb_agg(jsonb_build_object(
          'key',ne.airport_key,'name',ne.airport_name,
          'iata',ne.iata,'distanceKm',ne.distance_km)
          ORDER BY ne.distance_km,ne.airport_name),'[]'::jsonb)
         FROM (
          SELECT candidates.* FROM (
           SELECT a2.airport_key,a2.airport_name,p2.iata_reported AS iata,
            ROUND((6371.0088*ACOS(LEAST(1,GREATEST(-1,
             SIN(RADIANS(p.latitude_deg::double precision))*
             SIN(RADIANS(p2.latitude_deg::double precision))+
             COS(RADIANS(p.latitude_deg::double precision))*
             COS(RADIANS(p2.latitude_deg::double precision))*
             COS(RADIANS(p2.longitude_deg::double precision-
                         p.longitude_deg::double precision))
            ))))::numeric,1) AS distance_km
           FROM airlinerra_game.approved_game_airports a2
           JOIN airlinerra_game.airport_reference_profiles p2
            ON p2.world_id=a2.world_id AND p2.airport_key=a2.airport_key
           WHERE a2.world_id=a.world_id AND a2.airport_key<>a.airport_key
            AND p.latitude_deg IS NOT NULL AND p.longitude_deg IS NOT NULL
            AND p2.latitude_deg BETWEEN p.latitude_deg-1 AND p.latitude_deg+1
            AND p2.longitude_deg BETWEEN p.longitude_deg-2 AND p.longitude_deg+2
          ) candidates WHERE candidates.distance_km <=100
          ORDER BY candidates.distance_km,candidates.airport_name
          LIMIT 12
         ) ne) AS nearby_airports,
        (SELECT count(*)::integer FROM airlinerra_game.airlines hq
          WHERE hq.world_id=a.world_id AND hq.home_airport_key=a.airport_key)
          AS registered_airline_headquarters_count,
        (SELECT count(*)::integer FROM airlinerra_game.airport_offices ao
          WHERE ao.world_id=a.world_id AND ao.airport_key=a.airport_key
          AND ao.office_type='hub' AND ao.office_status='active')
          AS active_airline_hubs_count,
        (SELECT count(*)::integer FROM airlinerra_game.airport_offices ao
          WHERE ao.world_id=a.world_id AND ao.airport_key=a.airport_key
          AND ao.office_type='station' AND ao.office_status='active')
          AS active_airline_stations_count,
        fd.runway_design_length_m AS game_design_runway_length_m,
        fd.runway_design_surface AS game_design_runway_surface,
        fd.data_status AS game_design_runway_status,
        fw.longest_paved_runway_m AS full_weight_longest_paved_runway_m,
        fw.airport_elevation_ft AS full_weight_airport_elevation_ft,
        fw.total_configurations_screened AS full_weight_aircraft_screened,
        fw.full_weight_both_pass_configurations AS full_weight_both_pass,
        fw.full_weight_takeoff_pass_configurations AS full_weight_takeoff_pass,
        fw.full_weight_landing_pass_configurations AS full_weight_landing_pass,
        fw.site_specific_performance_review_recommended AS full_weight_high_elevation_review,
        fw.calculation_basis AS full_weight_game_calculation_basis,
        (
          SELECT jsonb_agg(
            jsonb_build_object(
              'name',r.runway_designator,
              'lengthM',r.length_m,
              'widthM',r.width_m,
              'surface',r.surface_reported,
              'operationalStatus',r.operational_status,
              'verification',r.verification
            ) ORDER BY r.length_m DESC NULLS LAST,r.runway_designator
          ) FROM airlinerra_game.airport_runway_inventory r
          WHERE r.world_id=a.world_id AND r.airport_key=a.airport_key
        ) AS runways
 FROM airlinerra_game.approved_game_airports a
 LEFT JOIN airlinerra_game.airport_reference_profiles p
    ON p.world_id=a.world_id AND p.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.airport_facilities f
    ON f.world_id=a.world_id AND f.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.airport_fictional_runway_design fd
    ON fd.world_id=a.world_id AND fd.airport_key=a.airport_key
    AND a.airport_key LIKE 'FICTIONAL:%'
 LEFT JOIN airlinerra_game.section9_airport_transfer_policy_v1 transfer
    ON transfer.world_id=a.world_id AND transfer.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section6_airport_slot_capacity_v1 cap
    ON cap.world_id=a.world_id AND cap.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section5_airport_operating_summary_v1 ops
    ON ops.world_id=a.world_id AND ops.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section5_airport_icao_chapter_policy_v2 chapter
    ON chapter.world_id=a.world_id AND chapter.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section5_country_civil_jet_chapter_minimum_v1 national
    ON national.country_iso=a.country_iso
    AND (a.country_iso<>'FR'
      OR (p.latitude_deg BETWEEN 41 AND 52 AND p.longitude_deg BETWEEN -6 AND 10))
 LEFT JOIN airlinerra_game.section5_airport_curfew_research_audit_v2 curfew
    ON curfew.world_id=a.world_id AND curfew.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section5_airport_game_restriction_catalog_v1 restriction
    ON restriction.world_id=a.world_id AND restriction.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 simple
     ON simple.world_id=a.world_id AND simple.airport_key=a.airport_key
  LEFT JOIN airlinerra_game.section5_full_weight_airport_summary_v2 fw
    ON fw.world_id=a.world_id AND fw.airport_key=a.airport_key
 LEFT JOIN airlinerra_game.section5_airport_weather_profile_v1 wx
    ON wx.world_id=a.world_id AND wx.airport_key=a.airport_key
 LEFT JOIN (
    SELECT world_id,airport_key,
      COALESCE(gameplay_avg_daily_outbound_passengers,avg_daily_outbound_passengers)
        AS daily_outbound_passengers,
      avg_daily_outbound_cargo_tonnes AS daily_outbound_cargo_tonnes,
      ROUND(100 * PERCENT_RANK() OVER (
        ORDER BY COALESCE(gameplay_avg_daily_outbound_passengers,avg_daily_outbound_passengers)
      ))::integer AS passenger_demand_percentile,
      ROUND(100 * PERCENT_RANK() OVER (
        ORDER BY COALESCE(avg_daily_outbound_cargo_tonnes,0)
      ))::integer AS cargo_demand_percentile
    FROM airlinerra_game.airport_daily_traffic_pool_baselines
    WHERE world_id=1
 ) traffic ON traffic.world_id=a.world_id AND traffic.airport_key=a.airport_key
 WHERE a.world_id=1 AND a.airport_key=$1::text
 LIMIT 1`;
export const GROUP2_AIRPORT_PROFILE_SQL=`
SELECT c.airport_key,c.airport_name,l.airport_code,c.country_iso,
 l.municipality AS roster_municipality,
 c.latitude_deg::text AS latitude_deg,c.longitude_deg::text AS longitude_deg,
 'game_estimate'::text AS coordinates_verification,
 'merged_sections1_8'::text AS coordinates_source_type,
 c.game_category AS provisional_category,
 c.timezone_iana,c.game_elevation_ft::text AS game_elevation_ft,
 'group2_game_estimate'::text AS game_elevation_provenance,
 'real'::text AS airport_kind,
 c.game_terminal_stands AS slot_terminal_stands,
 c.game_remote_stands AS slot_remote_stands,
 c.game_cargo_stands AS slot_cargo_stands,
 c.game_terminal_slot_per_10m AS slot_terminal_per_direction_10m,
 c.game_remote_slot_per_10m AS slot_remote_per_direction_10m,
 c.game_cargo_slot_per_10m AS slot_cargo_per_direction_10m,
 c.game_nighttime_ban AS simple_game_nighttime_ban,
 c.game_noise_restrictions AS simple_game_noise_restrictions,
 'GROUP2_GAME_ESTIMATE_NOT_FLIGHT_APPROVED'::text AS simple_game_source_status,
 'GROUP2_PREPARED_NOT_ADMITTED'::text AS game_restriction_status,
 '[]'::jsonb AS icao_airport_noise_rules,
 jsonb_build_array(jsonb_build_object('name','Game runway reference',
 'lengthM',c.game_runway_length_m,'widthM',NULL,'surface',NULL,
 'operationalStatus','planning_only','verification','game_estimate')) AS runways
FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 c
JOIN airlinerra_game.airport_location_eligibility_v1 l
 ON l.world_id=1 AND l.airport_key=c.airport_key
WHERE c.world_id=1 AND c.airport_key=$1::text
 AND c.source_group='GROUP_2'
 AND c.commercial_access_scope='GROUP2_PREPARED_NOT_ADMITTED'
 AND l.source_group='GROUP_2' AND NOT l.commercial_airport_admitted
LIMIT 1`;

const nullableString=x=>typeof x==='string'&&x.trim()?x.trim():null;
const numberOrNull=x=>{
 if(x===null||x===undefined||x==='')return null;
 const n=Number(x);return Number.isFinite(n)?n:null;
};
const isoDateOrNull=x=>x instanceof Date&&!Number.isNaN(x.getTime())?
 x.toISOString():nullableString(x);
const countOrNull=x=>{
 const n=numberOrNull(x);
 return n!==null&&Number.isInteger(n)&&n>=0?n:null;
};
/** Fixed World 1 traffic tiers. Thresholds stay out of the player-facing UI.
 * Passenger: <1k, <10k, <25k, <75k, then above (per day).
 * Cargo: <1, <10, <100, <1000, then above (tonnes per day).
 */
export const passengerTrafficGroup=value=>trafficGroup(value,[1000,10000,25000,75000]);
export const cargoTrafficGroup=value=>trafficGroup(value,[1,10,100,1000]);
function trafficGroup(value,limits){
 const n=numberOrNull(value);
 if(n===null||n<0)return null;
 return 1+limits.filter(limit=>n>=limit).length;
}
const percentageOrNull=x=>{
 const n=numberOrNull(x);
 return n!==null&&Number.isInteger(n)&&n>=0&&n<=100?n:null;
};
export function serializeAirportProfile(row){
 if(!row||!validAirportKey(row.airport_key))throw Error('Invalid airport profile');
 const runways=Array.isArray(row.runways)?row.runways.slice(0,20).map(r=>({
  name:nullableString(r.name),lengthM:numberOrNull(r.lengthM),
  widthM:numberOrNull(r.widthM),surface:nullableString(r.surface),
  operationalStatus:nullableString(r.operationalStatus),
  verification:nullableString(r.verification)
 })):[];
 const category=nullableString(row.approved_category)||nullableString(row.provisional_category);
 return Object.freeze({
  key:row.airport_key,worldId:1,
  name:nullableString(row.game_official_name)||row.airport_name,
  nameChecked:Boolean(nullableString(row.official_name_verified)),
  code:nullableString(row.airport_code),
  icao:nullableString(row.icao_reported),
  iata:nullableString(row.iata_reported),
  countryIso:nullableString(row.country_iso),
  municipality:nullableString(row.game_municipality)||nullableString(row.roster_municipality),
  region:nullableString(row.region_display_name)||nullableString(row.region_iso),
  latitude:numberOrNull(row.latitude_deg),longitude:numberOrNull(row.longitude_deg),
  coordinatesStatus:nullableString(row.coordinates_verification),
  coordinatesSource:nullableString(row.coordinates_source_type),
  category:CATEGORIES.has(category)?category:null,
  categoryStatus:nullableString(row.approved_category)?'approved':'provisional',
  timezone:nullableString(row.timezone_iana)||nullableString(row.timezone_candidate_iana),
  timezoneStatus:nullableString(row.timezone_iana)?'checked':'candidate',
  elevationFt:numberOrNull(row.game_elevation_ft),
  elevationStatus:nullableString(row.game_elevation_provenance),
  airportKind:nullableString(row.airport_kind),
  runways,
  // A fictional model airport may have a stored GAME design but no real
  // observed runway. Expose it separately, never as an official runway.
  gameRunwayDesign:row.airport_key.startsWith('FICTIONAL:')&&
   row.game_design_runway_status==='fictional_game_only'&&
   numberOrNull(row.game_design_runway_length_m)>0?
   {lengthM:numberOrNull(row.game_design_runway_length_m),
    surface:nullableString(row.game_design_runway_surface),
    status:'fictional_game_only'}:null,
  facilities:{
   terminals:countOrNull(row.terminal_count),
   gates:countOrNull(row.passenger_gate_count),
   stands:countOrNull(row.aircraft_stand_count),
   operatingHours:nullableString(row.game_operating_hours_summary)||
     nullableString(row.operating_hours_local),
   curfew:nullableString(row.curfew_details)||
     (Array.isArray(row.game_time_restrictions)&&row.game_time_restrictions.length?
      row.game_time_restrictions.map(r=>[r.localStart,r.localEnd].join('-')+
       ' '+(r.operation||'both')+' ('+(r.kind||'restriction')+')').join('; '):null),
   noise:'ICAO Annex 16 aircraft certification Chapters; airport noise-rule verification: '+
     (nullableString(row.icao_noise_research_status)||'NOT_INDIVIDUALLY_VERIFIED')+
     '. See operations.icaoNoiseRules for sourced restrictions. Prior five-class noise scale retired.',
   historicalNoiseNotes:nullableString(row.noise_restrictions),
   status:nullableString(row.facility_status)
  },
  connectionPolicy:{
   minimumMinutes:countOrNull(row.game_minimum_transfer_minutes),
   maximumMinutes:countOrNull(row.game_maximum_transfer_minutes),
   model:'game_category_base_v1',
   background:nullableString(row.game_demand_background),
   seasonalProfile:nullableString(row.game_seasonal_profile),
   officialAirportMct:false
  },
  slotCapacity:{
   model:'stand_hourly_v1',
   windowMinutes:10,
   // Hourly arrivals and departures have identical independent stand limits.
   terminal:{stands:countOrNull(row.slot_terminal_stands),
    arrivalsPerHour:countOrNull(row.slot_terminal_stands),
    departuresPerHour:countOrNull(row.slot_terminal_stands),
    arrivalsPer10Minutes:countOrNull(row.slot_terminal_per_direction_10m),
    departuresPer10Minutes:countOrNull(row.slot_terminal_per_direction_10m)},
   remote:{stands:countOrNull(row.slot_remote_stands),
    arrivalsPerHour:countOrNull(row.slot_remote_stands),
    departuresPerHour:countOrNull(row.slot_remote_stands),
    arrivalsPer10Minutes:countOrNull(row.slot_remote_per_direction_10m),
    departuresPer10Minutes:countOrNull(row.slot_remote_per_direction_10m)},
   cargo:{stands:countOrNull(row.slot_cargo_stands),
    arrivalsPerHour:countOrNull(row.slot_cargo_stands),
    departuresPerHour:countOrNull(row.slot_cargo_stands),
    arrivalsPer10Minutes:countOrNull(row.slot_cargo_per_direction_10m),
    departuresPer10Minutes:countOrNull(row.slot_cargo_per_direction_10m)}
  },
  operations:{
   // Simplified player-facing game classification. Never grants real-world clearance or
   // changes source-backed airport hard rules used by transactional preflight checks.
   simpleNightNoise:{
    nighttimeBan:row.simple_game_nighttime_ban===true,
    noiseRestrictions:row.simple_game_noise_restrictions===true,
    permittedChapters:Array.isArray(row.simple_game_permitted_chapters)?
     row.simple_game_permitted_chapters.filter(n=>Number.isInteger(n)&&[2,3,4,5,14].includes(n)):[],
    nighttimeWindow:nullableString(row.simple_game_nighttime_window),
    sourceStatus:nullableString(row.simple_game_source_status)||'GAME_DEFAULT_NOT_CHECKED',
    source:nullableString(row.simple_game_source_url),
    dispatchApproval:false
   },
   hoursBasis:nullableString(row.game_operating_hours_basis),
   noiseBasis:nullableString(row.noise_limit_basis),
   dayMaxNoiseClass:null,
   nightMaxNoiseClass:null,
   legacyFiveClassNoiseScaleRetired:true,
   curfewResearchStatus:nullableString(row.curfew_research_status)||'NOT_INDIVIDUALLY_VERIFIED',
    restrictionResearch:{
      status:nullableString(row.game_restriction_status)||'DATA_PENDING',
      operatingScreen:nullableString(row.operating_condition_screen),
      operatingNote:nullableString(row.operating_research_note),
      operatingSource:nullableString(row.operating_research_source),
      operatingChecked:nullableString(row.operating_research_checked),
      noiseScreen:nullableString(row.noise_condition_screen),
      noiseNote:nullableString(row.noise_research_note),
      noiseSource:nullableString(row.noise_research_source),
      noiseChecked:nullableString(row.noise_research_checked),
      timeRulesCount:countOrNull(row.structured_time_rule_count),
      enforcedTimeRules:countOrNull(row.enforced_time_rule_count),
      reviewTimeRules:countOrNull(row.review_time_rule_count),
      runwayRulesCount:countOrNull(row.structured_runway_rule_count),
      enforcedRunwayRules:countOrNull(row.enforced_runway_rule_count),
      timeResearchUnstructured:row.research_still_unstructured===true,
      realWorldDispatchApproved:false
    },
   icaoNoiseRules:{
     researchStatus:nullableString(row.icao_noise_research_status)||'NOT_INDIVIDUALLY_VERIFIED',
     prohibitedChapters:Array.isArray(row.icao_prohibited_chapters)?
       row.icao_prohibited_chapters.filter(n=>Number.isInteger(n)&&[2,3,4,5,6,10,14].includes(n)):[],
     restrictionKind:nullableString(row.icao_rule_kind),
     minimumCumulativeMarginEpndb:numberOrNull(row.icao_minimum_margin_epndb),
     source:nullableString(row.icao_noise_source),
     nationalCivilJetMinimumChapter:countOrNull(row.national_jet_min_chapter),
     nationalCivilJetMinimumScope:nullableString(row.national_jet_rule_scope),
     nationalCivilJetNoiseSource:nullableString(row.national_jet_rule_source),
     nationalCivilJetExceptions:nullableString(row.national_jet_rule_exceptions),
     rules:Array.isArray(row.icao_airport_noise_rules)?
       row.icao_airport_noise_rules.slice(0,20).map(r=>({
         code:nullableString(r.code),kind:nullableString(r.kind),
         operation:nullableString(r.operation),
         localStart:nullableString(r.localStart),localEnd:nullableString(r.localEnd),
         chapter:countOrNull(r.chapter),
         enforcement:nullableString(r.enforcement),
         source:nullableString(r.source),notes:nullableString(r.notes)
       })):[]
   },
   runwayRestrictions:Array.isArray(row.precise_runway_rule_details)?
     row.precise_runway_rule_details.slice(0,30).map(item=>({
       code:nullableString(item.code),kind:nullableString(item.kind),
       operation:nullableString(item.operation),
       runwaySourceId:nullableString(item.runwaySourceId),
       runwayDesignator:nullableString(item.runwayDesignator),
       localStart:nullableString(item.startLocal),localEnd:nullableString(item.endLocal),
       weekdays:Array.isArray(item.weekdays)?item.weekdays.filter(n=>Number.isInteger(n)&&n>=1&&n<=7):null,
       activeFrom:nullableString(item.activeFrom),activeUntil:nullableString(item.activeUntil),
       prohibitedChapters:Array.isArray(item.prohibitedChapters)?item.prohibitedChapters.filter(Number.isInteger):[],
       gameEnforcement:item.hardBlock===true,details:nullableString(item.notes),
       source:nullableString(item.source)
     })) : [],
   timeRestrictions:Array.isArray(row.precise_time_rule_details)?
     row.precise_time_rule_details.slice(0,30).map(item=>({
       code:nullableString(item.code),kind:nullableString(item.kind),
       operation:nullableString(item.operation),
       localStart:nullableString(item.startLocal),localEnd:nullableString(item.endLocal),
       weekdays:Array.isArray(item.weekdays)?item.weekdays.filter(n=>Number.isInteger(n)&&n>=1&&n<=7):null,
       aircraftUseTypes:Array.isArray(item.aircraftUseTypes)?
         item.aircraftUseTypes.filter(s=>['passenger','cargo','combi'].includes(s)):null,
       activeFrom:nullableString(item.activeFrom),activeUntil:nullableString(item.activeUntil),
       source:nullableString(item.source),details:nullableString(item.notes),
       gameEnforcement:item.hardBlock===true,exceptionsExpected:item.exceptionsExpected===true
     })) : Array.isArray(row.game_time_restrictions)?
     row.game_time_restrictions.slice(0,20).map(item=>({
       code:nullableString(item.code),kind:nullableString(item.kind),
       operation:nullableString(item.operation),
       localStart:nullableString(item.localStart),localEnd:nullableString(item.localEnd),
       source:nullableString(item.source),details:nullableString(item.details),
       gameEnforcement:item.gameEnforcement===true,
       exceptionsExpected:item.exceptionsExpected===true
     })):[]
  },
  runwayFullWeight:{
   gameLengthScreenImplemented:row.full_weight_aircraft_screened!==null&&row.full_weight_aircraft_screened!==undefined,
   allAircraftConfigurations:countOrNull(row.full_weight_aircraft_screened),
   passingBothAtStructuralMaximumWeight:countOrNull(row.full_weight_both_pass),
   passingFullWeightTakeoff:countOrNull(row.full_weight_takeoff_pass),
   passingFullWeightLanding:countOrNull(row.full_weight_landing_pass),
   maximumPavedPhysicalRunwayM:numberOrNull(row.full_weight_longest_paved_runway_m),
   referenceAirportElevationFt:numberOrNull(row.full_weight_airport_elevation_ft),
   highElevationSiteStudyRecommended:row.full_weight_high_elevation_review===true,
   dataKind:nullableString(row.full_weight_game_calculation_basis),
   realWorldDispatchApproved:false
  },
  airportActivity:{
   registeredHeadquarters:countOrNull(row.registered_airline_headquarters_count),
   activeHubs:countOrNull(row.active_airline_hubs_count),
   activeStations:countOrNull(row.active_airline_stations_count),
   // Flight schedules and operating-airline movements are not connected.
   dailyFlights:null,
   operatingAirlines:null
  },
  nearbyAirports:Array.isArray(row.nearby_airports)?
   row.nearby_airports.slice(0,12).filter(n=>
    validAirportKey(n?.key)&&numberOrNull(n?.distanceKm)!==null&&
    numberOrNull(n.distanceKm)>=0&&numberOrNull(n.distanceKm)<=100
   ).map(n=>({
    key:n.key,name:nullableString(n.name),iata:nullableString(n.iata),
    distanceKm:numberOrNull(n.distanceKm),
    fictional:n.key.startsWith('FICTIONAL:')
   })):[],
  demand:{
   passengerGroup:passengerTrafficGroup(row.daily_outbound_passengers),
   cargoGroup:cargoTrafficGroup(row.daily_outbound_cargo_tonnes),
   passengerPercent:percentageOrNull(row.passenger_demand_percentile),
   cargoPercent:percentageOrNull(row.cargo_demand_percentile),
   annualDepartingPassengers:countOrNull(row.daily_outbound_passengers)===null?
     null:countOrNull(row.daily_outbound_passengers)*365,
   annualOutboundCargoTonnes:numberOrNull(row.daily_outbound_cargo_tonnes)===null?
     null:numberOrNull(row.daily_outbound_cargo_tonnes)*365,
   indexBasis:'relative_world1_airport_percentile',
   annualBasis:'game_outbound_daily_baseline_365_days'
  },
  weather:{
   status:nullableString(row.forecast_status)||'AWAITING_FIRST_FORECAST',
   isCurrent:row.forecast_is_current===true,
   fetchedAt:isoDateOrNull(row.weather_provider_fetched_at),
   validThrough:isoDateOrNull(row.weather_valid_through),
   temperatureC:numberOrNull(row.weather_temperature_c),
   symbol:nullableString(row.weather_symbol),
   precipitationMm:numberOrNull(row.weather_precipitation_mm),
   windKmh:numberOrNull(row.weather_wind_kmh),
   attribution:nullableString(row.weather_attribution),
   next24h:Array.isArray(row.weather_next_24h)?
    row.weather_next_24h.slice(0,10).map(point=>({
      time:nullableString(point.time),
      temperatureC:numberOrNull(point.temperature_c),
      symbol:nullableString(point.weather_symbol),
      precipitationMm:numberOrNull(point.precipitation_mm),
      windKmh:numberOrNull(point.wind_speed_kmh)
    })):[]
  }
 });
}
