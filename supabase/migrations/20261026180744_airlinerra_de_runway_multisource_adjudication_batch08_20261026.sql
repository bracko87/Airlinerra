CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_multisource_adjudications (
 batch_key text NOT NULL,
 airport_key text NOT NULL,
 airport_code text NOT NULL,
 resolution text NOT NULL CHECK (resolution IN ('MULTISOURCE_PAVED_RUNWAY_SCREEN_PASSES_RELEASE_HOLD','CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED')),
 evidence_grade text NOT NULL,
 runway_pair text,
 paved_length_m numeric,
 paved_width_m numeric,
 runway_surface text,
 primary_evidence_url text NOT NULL,
 corroboration_url text,
 third_evidence_url text,
 evidence_summary text NOT NULL,
 unresolved_question text NOT NULL,
 runways_only_screen_boolean boolean,
 commercial_permission_verified boolean NOT NULL DEFAULT false CHECK(NOT commercial_permission_verified),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 game_activation_allowed boolean NOT NULL DEFAULT false CHECK(NOT game_activation_allowed),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),
 UNIQUE(batch_key,airport_code)
);
ALTER TABLE airlinerra.airport_expansion_de_multisource_adjudications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_multisource_adjudications FROM PUBLIC,anon,authenticated;