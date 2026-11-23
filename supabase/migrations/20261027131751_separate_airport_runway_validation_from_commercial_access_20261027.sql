CREATE TABLE IF NOT EXISTS airlinerra.airport_flagged_review_resolution_20261027 (
 airport_key text primary key references airlinerra.airport_registry(airport_key),
 runway_review_status text not null check(runway_review_status in ('FAA_2026_PAVED_LENGTH_VERIFIED','OFFICIAL_NONFAA_PAVED_LENGTH_VERIFIED','OPERATOR_PAVED_LENGTH_VERIFIED','HISTORICAL_EVIDENCE_REQUIRES_FOLLOWUP')),
 access_review_status text not null check(access_review_status in ('CIVIL_ACCESS_CONFIRMED_COMMERCIAL_UNVERIFIED','PRIVATE_OR_MILITARY_RESTRICTIONS','CIVIL_ACCESS_NOT_CONFIRMED')),
 recommended_game_handling text not null,
 verification_source_url text,
 verification_note text not null,
 updated_at timestamptz not null default now()
);