-- Forward-only: preserve legacy source_records/source_media/source_snapshots.
-- No existing source data is deleted, rewritten, or silently approved.
CREATE TABLE public_snapshots (
  snapshot_id TEXT PRIMARY KEY CHECK(length(snapshot_id)=64),
  source_club_id TEXT NOT NULL,
  captured_at_utc TEXT NOT NULL,
  manifest_json TEXT NOT NULL CHECK(json_valid(manifest_json)),
  status TEXT NOT NULL DEFAULT 'importing'
    CHECK(status IN ('importing','sealed','verified','active','retired','rejected')),
  approved_by TEXT,
  approval_ref TEXT,
  verified_at_utc TEXT,
  activated_at_utc TEXT
);
CREATE UNIQUE INDEX public_snapshots_one_active ON public_snapshots(status) WHERE status='active';
CREATE TABLE public_snapshot_records (
  snapshot_id TEXT NOT NULL REFERENCES public_snapshots(snapshot_id),
  source_table TEXT NOT NULL,
  source_id TEXT NOT NULL,
  source_club_id TEXT NOT NULL,
  payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
  row_sha256 TEXT NOT NULL CHECK(length(row_sha256)=64),
  PRIMARY KEY(snapshot_id,source_table,source_id)
);
CREATE INDEX public_snapshot_records_scope ON public_snapshot_records(snapshot_id,source_table,source_club_id);
CREATE TABLE public_snapshot_media (
  snapshot_id TEXT NOT NULL REFERENCES public_snapshots(snapshot_id),
  source_asset_id TEXT NOT NULL,
  source_bucket TEXT NOT NULL,
  source_path TEXT NOT NULL,
  bytes INTEGER NOT NULL CHECK(bytes>=0 AND bytes<=33554432),
  sha256 TEXT NOT NULL CHECK(length(sha256)=64),
  usage_scopes_json TEXT NOT NULL CHECK(json_valid(usage_scopes_json)),
  usage_rights TEXT NOT NULL,
  r2_key TEXT NOT NULL,
  PRIMARY KEY(snapshot_id,source_asset_id),
  UNIQUE(snapshot_id,source_bucket,source_path)
);
CREATE TABLE public_snapshot_head (
  singleton INTEGER PRIMARY KEY CHECK(singleton=1),
  snapshot_id TEXT NOT NULL UNIQUE REFERENCES public_snapshots(snapshot_id)
);
-- A CHECK constraint makes a failed compare-and-swap abort the entire D1 batch.
CREATE TABLE public_snapshot_publish_guards (
  nonce TEXT PRIMARY KEY,
  passed INTEGER NOT NULL CHECK(passed=1)
);
CREATE TRIGGER public_snapshots_identity_immutable BEFORE UPDATE OF snapshot_id,source_club_id,captured_at_utc,manifest_json ON public_snapshots
BEGIN SELECT RAISE(ABORT,'snapshot_identity_immutable'); END;
CREATE TRIGGER public_snapshots_state_machine BEFORE UPDATE OF status ON public_snapshots
WHEN NOT (OLD.status=NEW.status OR
 (OLD.status='importing' AND NEW.status IN ('sealed','rejected')) OR
 (OLD.status='sealed' AND NEW.status IN ('verified','rejected')) OR
 (OLD.status='verified' AND NEW.status IN ('active','rejected')) OR
 (OLD.status='active' AND NEW.status='retired'))
BEGIN SELECT RAISE(ABORT,'invalid_snapshot_transition'); END;
CREATE TRIGGER public_snapshots_no_delete BEFORE DELETE ON public_snapshots
BEGIN SELECT RAISE(ABORT,'snapshot_retention_required'); END;
CREATE TRIGGER public_snapshots_approval_immutable BEFORE UPDATE OF approved_by,approval_ref,verified_at_utc,activated_at_utc ON public_snapshots
WHEN OLD.status IN ('active','retired','rejected')
BEGIN SELECT RAISE(ABORT,'snapshot_approval_immutable'); END;
CREATE TRIGGER public_snapshot_head_insert BEFORE INSERT ON public_snapshot_head
WHEN COALESCE((SELECT status FROM public_snapshots WHERE snapshot_id=NEW.snapshot_id),'')!='active'
BEGIN SELECT RAISE(ABORT,'snapshot_not_active'); END;
CREATE TRIGGER public_snapshot_head_update BEFORE UPDATE ON public_snapshot_head
WHEN COALESCE((SELECT status FROM public_snapshots WHERE snapshot_id=NEW.snapshot_id),'')!='active'
BEGIN SELECT RAISE(ABORT,'snapshot_not_active'); END;
CREATE TRIGGER public_snapshot_records_insert_only_importing BEFORE INSERT ON public_snapshot_records
WHEN COALESCE((SELECT status FROM public_snapshots WHERE snapshot_id=NEW.snapshot_id),'')!='importing'
BEGIN SELECT RAISE(ABORT,'immutable_snapshot'); END;
CREATE TRIGGER public_snapshot_records_update_only_importing BEFORE UPDATE ON public_snapshot_records
WHEN COALESCE((SELECT status FROM public_snapshots WHERE snapshot_id=OLD.snapshot_id),'')!='importing'
BEGIN SELECT RAISE(ABORT,'immutable_snapshot'); END;
CREATE TRIGGER public_snapshot_records_delete_only_importing BEFORE DELETE ON public_snapshot_records
WHEN COALESCE((SELECT status FROM public_snapshots WHERE snapshot_id=OLD.snapshot_id),'')!='importing'
BEGIN SELECT RAISE(ABORT,'immutable_snapshot'); END;
CREATE TRIGGER public_snapshot_records_identity_immutable BEFORE UPDATE OF snapshot_id ON public_snapshot_records
BEGIN SELECT RAISE(ABORT,'snapshot_identity_immutable'); END;
CREATE TRIGGER public_snapshot_media_insert_only_importing BEFORE INSERT ON public_snapshot_media
WHEN COALESCE((SELECT status FROM public_snapshots WHERE snapshot_id=NEW.snapshot_id),'')!='importing'
BEGIN SELECT RAISE(ABORT,'immutable_snapshot'); END;
CREATE TRIGGER public_snapshot_media_update_only_importing BEFORE UPDATE ON public_snapshot_media
WHEN COALESCE((SELECT status FROM public_snapshots WHERE snapshot_id=OLD.snapshot_id),'')!='importing'
BEGIN SELECT RAISE(ABORT,'immutable_snapshot'); END;
CREATE TRIGGER public_snapshot_media_delete_only_importing BEFORE DELETE ON public_snapshot_media
WHEN COALESCE((SELECT status FROM public_snapshots WHERE snapshot_id=OLD.snapshot_id),'')!='importing'
BEGIN SELECT RAISE(ABORT,'immutable_snapshot'); END;
CREATE TRIGGER public_snapshot_media_identity_immutable BEFORE UPDATE OF snapshot_id ON public_snapshot_media
BEGIN SELECT RAISE(ABORT,'snapshot_identity_immutable'); END;

-- Bounded import fragments avoid putting a many-thousand-row hash manifest in
-- one oversized SQL statement. These are untrusted staging bytes. Only the
-- complete manifest whose SHA-256 equals snapshot_id can be published.
CREATE TABLE public_snapshot_import_chunks (
  snapshot_id TEXT NOT NULL CHECK(length(snapshot_id)=64),
  sequence INTEGER NOT NULL CHECK(sequence >= 0),
  chunk TEXT NOT NULL,
  PRIMARY KEY(snapshot_id, sequence)
);
