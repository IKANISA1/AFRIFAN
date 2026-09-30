-- Optional forward-only source migration, AFTER payment-allocation 0006.
-- Disabled by default. No event enrolment, message send, financial posting, deletion or rollback.
CREATE TABLE pa_recovery_control (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1), enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN(0,1)),
 decision_ms INTEGER NOT NULL CHECK(decision_ms BETWEEN 1000 AND 300000),
 approval_ref TEXT NOT NULL CHECK(length(approval_ref) BETWEEN 1 AND 64)
) STRICT;
INSERT INTO pa_recovery_control VALUES(1,0,300000,'UNAPPROVED');
CREATE TABLE pa_recovery_decisions (
 decision_id TEXT PRIMARY KEY, operation_id TEXT NOT NULL UNIQUE,
 maker_id TEXT NOT NULL REFERENCES pa_principals(principal_id), checker_id TEXT REFERENCES pa_principals(principal_id),
 club_id INTEGER NOT NULL, event_id TEXT NOT NULL REFERENCES pa_outbox(event_id), expected_revision INTEGER NOT NULL CHECK(expected_revision>0),
 reason TEXT NOT NULL CHECK(reason IN('dependency_restored','configuration_corrected')),
 evidence_sha256 TEXT NOT NULL CHECK(length(evidence_sha256)=64), evidence_ref TEXT NOT NULL CHECK(length(evidence_ref) BETWEEN 4 AND 64),
 request_sha256 TEXT NOT NULL CHECK(length(request_sha256)=64), command_sha256 TEXT NOT NULL CHECK(length(command_sha256)=64),
 created_at_ms INTEGER NOT NULL, expires_at_ms INTEGER NOT NULL, confirmed_at_ms INTEGER,
 state TEXT NOT NULL CHECK(state IN('prepared','confirmed')),
 CHECK((state='prepared' AND checker_id IS NULL AND confirmed_at_ms IS NULL) OR
       (state='confirmed' AND checker_id IS NOT NULL AND checker_id<>maker_id AND confirmed_at_ms IS NOT NULL)),
 CHECK(expires_at_ms>created_at_ms AND expires_at_ms-created_at_ms<=300000)
) STRICT;
CREATE INDEX pa_recovery_decisions_scope ON pa_recovery_decisions(club_id,event_id,created_at_ms,decision_id);
CREATE TRIGGER pa_recovery_prepare_guard BEFORE INSERT ON pa_recovery_decisions BEGIN
 SELECT CASE WHEN NEW.state<>'prepared' OR NEW.created_at_ms<>CAST(unixepoch('subsec') * 1000 AS INTEGER)
  OR NEW.expires_at_ms<>NEW.created_at_ms+(SELECT decision_ms FROM pa_recovery_control WHERE singleton=1 AND enabled=1)
  OR NOT EXISTS(SELECT 1 FROM pa_recovery_control WHERE singleton=1 AND enabled=1)
  THEN RAISE(ABORT,'delivery_conflict') END;
 SELECT CASE WHEN NOT EXISTS(
  SELECT 1 FROM pa_principals p JOIN pa_grants g ON g.principal_id=p.principal_id
  JOIN pa_clubs c ON c.club_id=g.club_id JOIN pa_delivery_control dc ON dc.club_id=c.club_id
  JOIN pa_delivery_grants dg ON dg.principal_id=p.principal_id AND dg.club_id=c.club_id CROSS JOIN pa_settings s
  WHERE p.principal_id=NEW.maker_id AND c.club_id=NEW.club_id AND p.enabled=1 AND p.expires_at_ms>NEW.created_at_ms
  AND g.capability='outbox' AND g.enabled=1 AND c.enabled=1 AND dc.enabled=1 AND dg.role='review' AND dg.enabled=1
  AND s.singleton=1 AND s.writer_mode='isolated-staging' AND s.purpose='africlub-payment-allocation'
  AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0
 ) THEN RAISE(ABORT,'delivery_permission_denied') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_delivery_jobs j JOIN pa_delivery_control dc ON dc.club_id=j.club_id
  WHERE j.event_id=NEW.event_id AND j.club_id=NEW.club_id AND j.consumer_id=dc.consumer_id
  AND j.state='dead' AND j.revision=NEW.expected_revision AND j.lease_principal IS NOT NEW.maker_id)
  THEN RAISE(ABORT,'delivery_conflict') END;
END;
CREATE TRIGGER pa_recovery_confirm_guard BEFORE UPDATE ON pa_recovery_decisions BEGIN
 SELECT CASE WHEN OLD.state<>'prepared' OR NEW.state<>'confirmed' OR
  NEW.decision_id IS NOT OLD.decision_id OR NEW.operation_id IS NOT OLD.operation_id OR NEW.maker_id IS NOT OLD.maker_id OR
  NEW.club_id IS NOT OLD.club_id OR NEW.event_id IS NOT OLD.event_id OR NEW.expected_revision IS NOT OLD.expected_revision OR
  NEW.reason IS NOT OLD.reason OR NEW.evidence_sha256 IS NOT OLD.evidence_sha256 OR NEW.evidence_ref IS NOT OLD.evidence_ref OR
  NEW.request_sha256 IS NOT OLD.request_sha256 OR NEW.command_sha256 IS NOT OLD.command_sha256 OR
  NEW.created_at_ms IS NOT OLD.created_at_ms OR NEW.expires_at_ms IS NOT OLD.expires_at_ms OR
  NEW.confirmed_at_ms<>CAST(unixepoch('subsec') * 1000 AS INTEGER) OR NEW.expires_at_ms<=NEW.confirmed_at_ms OR
  NEW.checker_id IS NULL OR NEW.checker_id=NEW.maker_id OR
  NOT EXISTS(SELECT 1 FROM pa_recovery_control WHERE singleton=1 AND enabled=1)
  THEN RAISE(ABORT,'delivery_conflict') END;
 -- Both decision makers must still be authorized at the transaction boundary.
 SELECT CASE WHEN (SELECT count(DISTINCT p.principal_id) FROM pa_principals p
  JOIN pa_grants g ON g.principal_id=p.principal_id JOIN pa_clubs c ON c.club_id=g.club_id
  JOIN pa_delivery_control dc ON dc.club_id=c.club_id JOIN pa_delivery_grants dg ON dg.principal_id=p.principal_id AND dg.club_id=c.club_id
  CROSS JOIN pa_settings s WHERE p.principal_id IN(NEW.maker_id,NEW.checker_id) AND c.club_id=NEW.club_id
  AND p.enabled=1 AND p.expires_at_ms>NEW.confirmed_at_ms AND g.capability='outbox' AND g.enabled=1
  AND c.enabled=1 AND dc.enabled=1 AND dg.role='review' AND dg.enabled=1
  AND s.singleton=1 AND s.writer_mode='isolated-staging' AND s.purpose='africlub-payment-allocation'
  AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0)<>2
  THEN RAISE(ABORT,'delivery_permission_denied') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_delivery_jobs j JOIN pa_delivery_control dc ON dc.club_id=j.club_id
  WHERE j.event_id=NEW.event_id AND j.club_id=NEW.club_id AND j.consumer_id=dc.consumer_id
  AND j.state='dead' AND j.revision=NEW.expected_revision AND j.lease_principal IS NOT NEW.checker_id)
  THEN RAISE(ABORT,'delivery_conflict') END;
END;
-- Applying this migration disables the older direct redrive path even if an old binding remains.
CREATE TRIGGER pa_recovery_redrive_guard BEFORE INSERT ON pa_delivery_commands WHEN NEW.action='redrive' BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_recovery_decisions d WHERE d.operation_id=NEW.request_id
  AND d.state='confirmed' AND d.checker_id=NEW.principal_id AND d.club_id=NEW.club_id AND d.event_id=NEW.event_id
  AND d.expected_revision=NEW.expected_revision AND d.reason=NEW.reason AND d.command_sha256=NEW.request_sha256
  AND d.confirmed_at_ms=NEW.recorded_at_ms) THEN RAISE(ABORT,'delivery_permission_denied') END;
END;
CREATE TRIGGER pa_recovery_confirm_apply AFTER UPDATE ON pa_recovery_decisions BEGIN
 INSERT INTO pa_delivery_commands(request_id,principal_id,event_id,club_id,action,expected_revision,request_sha256,lease_id,reason,receipt_id,recorded_at_ms)
 VALUES(NEW.operation_id,NEW.checker_id,NEW.event_id,NEW.club_id,'redrive',NEW.expected_revision,NEW.command_sha256,NULL,NEW.reason,NULL,NEW.confirmed_at_ms);
END;
CREATE TRIGGER pa_recovery_decision_no_delete BEFORE DELETE ON pa_recovery_decisions BEGIN SELECT RAISE(ABORT,'delivery_immutable'); END;
