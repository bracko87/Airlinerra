CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_batch09_airport_evidence (
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 airport_code text NOT NULL,
 runway_pair text,
 documented_paved_length_m numeric,
 documented_paved_width_m numeric,
 pavement_type text CHECK(pavement_type IN ('ASPHALT','CONCRETE','BITUMEN')),
 evidence_grade text NOT NULL,
 runway_screen_decision text NOT NULL CHECK(runway_screen_decision IN(
 'MULTISOURCE_PAVED_PHYSICAL_RUNWAY_CONFIRMED',
 'PHYSICAL_RUNWAY_NEEDS_CURRENT_SOURCE',
 'TEMPORARY_CLOSURE_OVERRIDES_COLLECTION_RELEASE'
 )),
 primary_evidence_url text NOT NULL,
 corroboration_url text,
 third_source_url text,
 runway_evidence_note text NOT NULL,
 unresolved_next_action text NOT NULL,
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 world_activation_allowed boolean NOT NULL DEFAULT false CHECK(NOT world_activation_allowed),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),UNIQUE(batch_key,airport_code)
);
ALTER TABLE airlinerra.airport_expansion_de_batch09_airport_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_batch09_airport_evidence FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_temp_airfield_closure_watch (
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 notam_reference text NOT NULL,
 issuer_data_origin text NOT NULL,
 reported_start_utc timestamp without time zone NOT NULL,
 reported_end_utc timestamp without time zone NOT NULL,
 daily_windows_utc text NOT NULL,
 aerodrome_closed_during_windows boolean NOT NULL CHECK(aerodrome_closed_during_windows),
 airspace_restriction_from date NOT NULL,
 airspace_restriction_to date NOT NULL,
 reporting_source_url text NOT NULL,
 airspace_authority_url text NOT NULL,
 followup_utc_date date NOT NULL,
 detail_note text NOT NULL,
 latest_review_status text NOT NULL DEFAULT 'TEMPORARY_CLOSURE_REVIEW_REQUIRED' CHECK(latest_review_status='TEMPORARY_CLOSURE_REVIEW_REQUIRED'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 world_activation_allowed boolean NOT NULL DEFAULT false CHECK(NOT world_activation_allowed),
 checked_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(airport_key,notam_reference),
 CHECK (reported_start_utc < reported_end_utc),
 CHECK (airspace_restriction_from <= airspace_restriction_to)
);
ALTER TABLE airlinerra.airport_expansion_de_temp_airfield_closure_watch ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_temp_airfield_closure_watch FROM PUBLIC,anon,authenticated;