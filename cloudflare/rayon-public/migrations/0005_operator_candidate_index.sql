-- Read-path optimization only. No grants, activation, publication or data rewrite.
-- Matches the bounded tenant candidate list, avoiding a full-table sort in SQLite.
CREATE INDEX public_snapshots_operator_candidates
  ON public_snapshots(source_club_id,captured_at_utc DESC,snapshot_id DESC)
  WHERE status IN ('importing','sealed','verified');
