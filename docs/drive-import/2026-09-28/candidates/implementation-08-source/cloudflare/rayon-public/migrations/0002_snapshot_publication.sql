-- Govern publication as an atomic complete snapshot rather than by newest-row time.
CREATE TABLE IF NOT EXISTS source_snapshots (
  snapshot_id TEXT PRIMARY KEY,
  captured_at_utc TEXT NOT NULL,
  row_count INTEGER NOT NULL CHECK (row_count >= 0),
  media_count INTEGER NOT NULL CHECK (media_count >= 0),
  manifest_sha256 TEXT NOT NULL CHECK (length(manifest_sha256) = 64),
  status TEXT NOT NULL CHECK (status IN ('importing', 'validated', 'active', 'retired')),
  activated_at_utc TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS one_active_source_snapshot
  ON source_snapshots(status) WHERE status = 'active';

ALTER TABLE source_records ADD COLUMN snapshot_id TEXT;
ALTER TABLE source_media ADD COLUMN snapshot_id TEXT;

CREATE INDEX IF NOT EXISTS source_records_by_snapshot_table
  ON source_records(snapshot_id, source_table, source_club_id);
CREATE INDEX IF NOT EXISTS source_media_by_snapshot
  ON source_media(snapshot_id, source_asset_id);
