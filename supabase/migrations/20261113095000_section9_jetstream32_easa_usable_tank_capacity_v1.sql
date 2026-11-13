-- Jetstream Series 3200 / Jetstream 32: authoritative EASA *usable* fuel capacity.
-- Source: EASA type-certificate data sheet EASA.A.191, Issue 3 (2015-01-15),
-- Section 3, III.9.1 on PDF page 12/15:
-- usable 406 UK gal / 488 US gal / 1846 L / 1477 kg / 3256 lb.
-- Total (including unusable): 1491 kg. The game uses the usable amount.
-- No estimate or change to the aircraft's fuel-burn rates. No dispatch approval.
BEGIN;

CREATE TABLE airlinerra_game.section9_fuel_tank_capacity_evidence_v1 (
  configuration_id bigint PRIMARY KEY
    REFERENCES airlinerra.aircraft_configurations(id),
  capacity_basis text NOT NULL CHECK(capacity_basis='USABLE_FUEL'),
  usable_capacity_kg numeric(13,2) NOT NULL CHECK(usable_capacity_kg>0),
  usable_capacity_litres numeric(13,2) NOT NULL CHECK(usable_capacity_litres>0),
  type_certificate text NOT NULL,
  source_issuer text NOT NULL,
  source_title text NOT NULL,
  source_issue_date date NOT NULL,
  source_page integer NOT NULL CHECK(source_page>0),
  source_section text NOT NULL,
  source_url text NOT NULL CHECK(source_url LIKE 'https://%'),
  game_use_scope text NOT NULL DEFAULT 'GAME_FUEL_CALCULATION_ONLY'
    CHECK(game_use_scope='GAME_FUEL_CALCULATION_ONLY'),
  recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_fuel_tank_capacity_evidence_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_fuel_tank_capacity_evidence_v1
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON TABLE airlinerra_game.section9_fuel_tank_capacity_evidence_v1 IS
 'Source-specific usable aircraft tank capacity. Does not approve fuel burn, aircraft dispatch, refuelling or financial accounting.';

DO $guard$
DECLARE changed integer;
BEGIN
 IF (SELECT count(*) FROM airlinerra.aircraft_technical_specs
     WHERE id=136 AND configuration_id=98
       AND manufacturer_usable_fuel_mass_kg IS NULL
       AND maximum_fuel_capacity_kg IS NULL
       AND gameplay_placeholder_fuel_capacity_kg IS NULL
       AND fuel_capacity_reference_note IS NULL
       AND review_status='research')<>1
 OR (SELECT count(*) FROM airlinerra_game.aircraft_fuel_planning_profiles_v1
     WHERE configuration_id=98 AND model_name='Jetstream 32'
       AND fuel_tank_capacity_kg IS NULL
       AND approved_for_dispatch=false AND approved_for_accounting=false
       AND requires_further_evidence=true)<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
     WHERE configuration_id=98 AND model_name='Jetstream 32'
       AND tank_capacity_kg IS NULL
       AND game_calculation_ready=false
       AND operational_dispatch_release='NOT_RELEASED'
       AND financial_settlement_release='NOT_RELEASED')<>1
 THEN RAISE EXCEPTION 'SECTION9_JETSTREAM32_SOURCE_BASELINE_CHANGED';
 END IF;

 INSERT INTO airlinerra_game.section9_fuel_tank_capacity_evidence_v1 (
  configuration_id,capacity_basis,usable_capacity_kg,usable_capacity_litres,
  type_certificate,source_issuer,source_title,source_issue_date,
  source_page,source_section,source_url
 ) VALUES (
  98,'USABLE_FUEL',1477,1846,'EASA.A.191',
  'European Aviation Safety Agency',
  'Type-Certificate Data Sheet: Jetstream 3100 / 3200 Series',
  DATE '2015-01-15',12,'Section 3: Jetstream Series 3200, III.9.1 Fuel Capacity',
  'https://www.easa.europa.eu/sites/default/files/dfu/TCDS%20EASA.A.191_Jetstream_3100_3200_Iss_03_20150115.pdf'
 );

 UPDATE airlinerra.aircraft_technical_specs
 SET manufacturer_usable_fuel_mass_kg=1477,
     fuel_capacity_reference_note=
      'EASA.A.191 Issue 3 (2015-01-15) Section 3 III.9.1 Jetstream Series 3200: usable fuel 1477 kg / 1846 L; total 1491 kg including unusable. Type-level source, not airframe-specific release. Game calculation only; rate/dispatch/settlement remain unverified.'
 WHERE id=136 AND configuration_id=98
   AND manufacturer_usable_fuel_mass_kg IS NULL
   AND maximum_fuel_capacity_kg IS NULL
   AND gameplay_placeholder_fuel_capacity_kg IS NULL
   AND review_status='research';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'SECTION9_JETSTREAM32_SOURCE_SPEC_UPDATE_NOT_EXACT'; END IF;

 UPDATE airlinerra_game.section9_game_fuel_model_snapshot_v1
 SET tank_capacity_kg=1477,snapshot_at=clock_timestamp()
 WHERE configuration_id=98 AND model_name='Jetstream 32'
   AND tank_capacity_kg IS NULL
   AND operational_dispatch_release='NOT_RELEASED'
   AND financial_settlement_release='NOT_RELEASED';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'SECTION9_JETSTREAM32_SNAPSHOT_UPDATE_NOT_EXACT'; END IF;

 IF (SELECT count(*) FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
     WHERE game_calculation_ready=true)<>271
 OR EXISTS (SELECT 1 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
            WHERE operational_dispatch_release<>'NOT_RELEASED'
               OR financial_settlement_release<>'NOT_RELEASED')
 THEN RAISE EXCEPTION 'SECTION9_JETSTREAM32_MODEL_COUNTS_OR_RELEASE_FLAGS_UNEXPECTED';
 END IF;
END $guard$;
COMMIT;
