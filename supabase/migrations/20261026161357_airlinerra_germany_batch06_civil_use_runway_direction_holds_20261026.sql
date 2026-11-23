-- German expansion Batch06 explicit civil usable-distance limitations, separate from runway-only physical collection.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_german_civil_runway_end_holds (
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 icao_code text NOT NULL,
 runway_pair text NOT NULL,
 source_physical_length_m numeric NOT NULL CHECK(source_physical_length_m>=1200),
 source_width_m numeric NOT NULL CHECK(source_width_m>0),
 source_landing_end_a_m numeric NOT NULL CHECK(source_landing_end_a_m>0),
 source_landing_end_b_m numeric NOT NULL CHECK(source_landing_end_b_m>0),
 current_source_check text NOT NULL CHECK(current_source_check IN ('CURRENT_AIRPORT_OPERATOR','HISTORICAL_OPERATOR_HOSTED_AIRFIELD_CHART')),
 issue text NOT NULL,
 source_url text NOT NULL,
 evidence_note text NOT NULL,
 resolution text NOT NULL,
 review_status text NOT NULL DEFAULT 'DIRECTIONAL_USABLE_DISTANCE_MANUAL_REVIEW'
 CHECK(review_status='DIRECTIONAL_USABLE_DISTANCE_MANUAL_REVIEW'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 game_world_activated boolean NOT NULL DEFAULT false CHECK(NOT game_world_activated),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key)
);
ALTER TABLE airlinerra.airport_expansion_german_civil_runway_end_holds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_german_civil_runway_end_holds FROM PUBLIC,anon,authenticated;