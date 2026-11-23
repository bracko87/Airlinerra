CREATE TABLE IF NOT EXISTS airlinerra.airport_world1_nonfoundation_approval_archive_20261027 (
 world_id smallint NOT NULL,
 airport_key text NOT NULL,
 approval_reference text NOT NULL,
 airport_name text,
 airport_code text,
 country_iso text,
 municipality text,
 approved_at timestamptz NOT NULL,
 archived_at timestamptz NOT NULL DEFAULT now(),
 archive_reason text NOT NULL,
 PRIMARY KEY (world_id,airport_key)
);
COMMENT ON TABLE airlinerra.airport_world1_nonfoundation_approval_archive_20261027 IS 'Snapshot of previously live non-foundation World 1 approved_game_airports, deactivated to restore original foundation-only game catalog while manual preapprovals are staged separately.';