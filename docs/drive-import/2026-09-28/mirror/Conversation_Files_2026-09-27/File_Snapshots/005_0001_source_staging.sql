-- Staging only: preserve approved public source rows before domain mapping.
-- This is not the final app API or its transaction schema.
CREATE TABLE IF NOT EXISTS source_records (
  source_table TEXT NOT NULL,
  source_id TEXT NOT NULL,
  source_club_id TEXT NOT NULL,
  payload_json TEXT NOT NULL CHECK (json_valid(payload_json)),
  row_sha256 TEXT NOT NULL CHECK (length(row_sha256) = 64),
  captured_at_utc TEXT NOT NULL,
  PRIMARY KEY (source_table, source_id)
);

CREATE INDEX IF NOT EXISTS source_records_by_table
  ON source_records (source_table, source_club_id);

CREATE TABLE IF NOT EXISTS source_media (
  source_asset_id TEXT PRIMARY KEY,
  source_bucket TEXT NOT NULL,
  source_path TEXT NOT NULL,
  bytes INTEGER NOT NULL CHECK (bytes >= 0),
  sha256 TEXT NOT NULL CHECK (length(sha256) = 64),
  usage_scopes_json TEXT NOT NULL CHECK (json_valid(usage_scopes_json)),
  usage_rights TEXT NOT NULL,
  captured_at_utc TEXT NOT NULL,
  UNIQUE (source_bucket, source_path)
);
