-- Additive read index only. No history rewrite, authorization change or live enablement.
-- Reconcile the actual hosted migration lineage before applying any forward migration.
CREATE INDEX pa_membership_history_owner
 ON pa_ledger(club_id,user_id,recorded_at_ms DESC,allocation_id DESC)
 WHERE ledger_scope='subscription';
