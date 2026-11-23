CREATE TABLE IF NOT EXISTS airlinerra.airport_world1_review_20261027 (
 airport_key text PRIMARY KEY REFERENCES airlinerra.airport_registry(airport_key),
 world_number smallint NOT NULL DEFAULT 1 CHECK (world_number=1),
 review_decision text NOT NULL CHECK(review_decision IN ('KEEP_ORIGINAL_3140','SAFE_BY_ICAO_PAVED_RULE','ACCEPT_HISTORICAL_REVIEW','REJECT_CONFIRMED')),
 reason text NOT NULL,
 source_reported_icao text,
 source_identifier text,
 historical_runway_m numeric,
 historical_surface text,
 game_category_provisional text,
 existing_quality_flags integer NOT NULL DEFAULT 0,
 evidence_basis text NOT NULL,
 reviewed_at timestamptz NOT NULL DEFAULT now()
);