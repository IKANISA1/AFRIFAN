-- Forward-only companion in the SAME isolated allocation database as 0001/0002.
-- No remote calls, payment allocation or automatic release of uncertain handoffs.
PRAGMA foreign_keys=ON;
CREATE TABLE pa_handoff_settings (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 legacy_attempts_reconciled INTEGER NOT NULL DEFAULT 0 CHECK(legacy_attempts_reconciled IN (0,1)),
 evidence_ref TEXT NOT NULL DEFAULT '', revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
) STRICT;
INSERT INTO pa_handoff_settings(singleton) VALUES(1);
CREATE TABLE pa_handoff_grants (
 principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id),
 capability TEXT NOT NULL CHECK(capability IN ('reserve','read')),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 PRIMARY KEY(principal_id,club_id,capability)
) STRICT;
CREATE VIEW pa_handoff_authorizations AS
 SELECT p.principal_id,g.club_id,g.capability,u.user_id,p.revision principal_revision,
 g.revision grant_revision,c.revision club_revision,u.revision subject_revision,
 x.revision checkout_revision,h.revision control_revision
 FROM pa_principals p JOIN pa_handoff_grants g ON g.principal_id=p.principal_id
 JOIN pa_clubs c ON c.club_id=g.club_id JOIN pa_subjects u ON u.club_id=c.club_id
 CROSS JOIN pa_settings s CROSS JOIN pa_checkout_settings x CROSS JOIN pa_handoff_settings h
 WHERE p.enabled=1 AND p.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER)
 AND g.enabled=1 AND c.enabled=1 AND u.enabled=1
 AND s.singleton=1 AND s.writer_mode='isolated-staging' AND s.purpose='africlub-payment-allocation'
 AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0
 AND x.singleton=1 AND x.enabled=1 AND x.catalog_reconciled=1 AND length(x.evidence_ref)>0
 AND h.singleton=1 AND h.enabled=1 AND h.legacy_attempts_reconciled=1 AND length(h.evidence_ref)>0;
CREATE TABLE pa_handoff_reservations (
 handoff_id TEXT PRIMARY KEY,request_id TEXT NOT NULL,order_id TEXT NOT NULL UNIQUE REFERENCES pa_checkout_order_details(order_id),
 club_id INTEGER NOT NULL,user_id TEXT NOT NULL,session_id TEXT NOT NULL,
 principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 request_sha256 TEXT NOT NULL CHECK(length(request_sha256)=64),review_sha256 TEXT NOT NULL CHECK(length(review_sha256)=64),
 snapshot_json TEXT NOT NULL CHECK(json_valid(snapshot_json)),
 principal_revision INTEGER NOT NULL,grant_revision INTEGER NOT NULL,club_revision INTEGER NOT NULL,
 subject_revision INTEGER NOT NULL,checkout_revision INTEGER NOT NULL,control_revision INTEGER NOT NULL,
 reserved_at_ms INTEGER NOT NULL,invoke_before_ms INTEGER NOT NULL,
 FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id),
 UNIQUE(club_id,user_id,request_id),CHECK(invoke_before_ms>reserved_at_ms AND invoke_before_ms<=reserved_at_ms+5000)
) STRICT;
CREATE INDEX pa_handoff_owner_history ON pa_handoff_reservations(club_id,user_id,reserved_at_ms,handoff_id);
CREATE TABLE pa_handoff_slots (
 club_id INTEGER NOT NULL,user_id TEXT NOT NULL,handoff_id TEXT NOT NULL UNIQUE REFERENCES pa_handoff_reservations(handoff_id),
 PRIMARY KEY(club_id,user_id),FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id)
) STRICT;
CREATE TABLE pa_handoff_audit (
 handoff_id TEXT PRIMARY KEY REFERENCES pa_handoff_reservations(handoff_id),
 event_type TEXT NOT NULL CHECK(event_type='membership.handoff_reserved'),recorded_at_ms INTEGER NOT NULL
) STRICT;
-- Resolution requires the existing atomic membership allocation, not a client status.
CREATE VIEW pa_handoff_resolution AS
 SELECT h.handoff_id,EXISTS(SELECT 1 FROM pa_allocations a
 JOIN pa_ledger l ON l.allocation_id=a.allocation_id JOIN pa_receipts r ON r.allocation_id=a.allocation_id
 JOIN pa_orders o ON o.order_id=a.order_id
 WHERE a.order_id=h.order_id AND o.club_id=h.club_id AND o.user_id=h.user_id AND o.kind='membership'
 AND o.state='fulfilled' AND l.order_id=o.order_id AND l.club_id=h.club_id AND l.user_id=h.user_id
 AND l.business_target_fulfilled=1 AND json_extract(r.receipt_json,'$.businessTargetFulfilled')=1
 AND json_extract(r.receipt_json,'$.orderId')=h.order_id) payment_allocated
 FROM pa_handoff_reservations h;
CREATE VIEW pa_handoff_unresolved AS
 SELECT h.* FROM pa_handoff_slots s JOIN pa_handoff_reservations h ON h.handoff_id=s.handoff_id
 JOIN pa_handoff_resolution z ON z.handoff_id=h.handoff_id WHERE z.payment_allocated=0;
CREATE TRIGGER pa_handoff_reserve_guard BEFORE INSERT ON pa_handoff_reservations BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_handoff_authorizations z
 WHERE z.principal_id=NEW.principal_id AND z.club_id=NEW.club_id AND z.user_id=NEW.user_id AND z.capability='reserve'
 AND z.principal_revision=NEW.principal_revision AND z.grant_revision=NEW.grant_revision
 AND z.club_revision=NEW.club_revision AND z.subject_revision=NEW.subject_revision
 AND z.checkout_revision=NEW.checkout_revision AND z.control_revision=NEW.control_revision)
 THEN RAISE(ABORT,'handoff_permission_denied') END;
 SELECT CASE WHEN NEW.reserved_at_ms!=CAST(unixepoch('subsec') * 1000 AS INTEGER)
 THEN RAISE(ABORT,'handoff_invalid_time') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM pa_handoff_unresolved z WHERE z.club_id=NEW.club_id AND z.user_id=NEW.user_id)
 THEN RAISE(ABORT,'handoff_unresolved') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_orders o JOIN pa_checkout_order_details d ON d.order_id=o.order_id
 JOIN pa_checkout_reusable v ON v.order_id=o.order_id
 WHERE o.order_id=NEW.order_id AND o.club_id=NEW.club_id AND o.user_id=NEW.user_id AND o.kind='membership'
 AND d.snapshot_json=NEW.snapshot_json AND o.expires_at_ms>=NEW.invoke_before_ms+15000)
 THEN RAISE(ABORT,'handoff_order_changed') END;
END;
CREATE TRIGGER pa_handoff_slot_insert BEFORE INSERT ON pa_handoff_slots BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_handoff_reservations h
 WHERE h.handoff_id=NEW.handoff_id AND h.club_id=NEW.club_id AND h.user_id=NEW.user_id)
 THEN RAISE(ABORT,'handoff_binding_conflict') END;
END;
CREATE TRIGGER pa_handoff_slot_update BEFORE UPDATE ON pa_handoff_slots BEGIN
 SELECT CASE WHEN NEW.club_id IS NOT OLD.club_id OR NEW.user_id IS NOT OLD.user_id
 OR NOT EXISTS(SELECT 1 FROM pa_handoff_resolution WHERE handoff_id=OLD.handoff_id AND payment_allocated=1)
 OR NOT EXISTS(SELECT 1 FROM pa_handoff_reservations h WHERE h.handoff_id=NEW.handoff_id AND h.club_id=NEW.club_id AND h.user_id=NEW.user_id)
 THEN RAISE(ABORT,'handoff_unresolved') END;
END;
CREATE TRIGGER pa_handoff_reserve_effects AFTER INSERT ON pa_handoff_reservations BEGIN
 INSERT INTO pa_handoff_slots(club_id,user_id,handoff_id) VALUES(NEW.club_id,NEW.user_id,NEW.handoff_id)
 ON CONFLICT(club_id,user_id) DO UPDATE SET handoff_id=excluded.handoff_id;
 INSERT INTO pa_handoff_audit VALUES(NEW.handoff_id,'membership.handoff_reserved',NEW.reserved_at_ms);
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_handoff_authorizations z WHERE z.principal_id=NEW.principal_id
 AND z.club_id=NEW.club_id AND z.user_id=NEW.user_id AND z.capability='reserve'
 AND z.principal_revision=NEW.principal_revision AND z.grant_revision=NEW.grant_revision
 AND z.club_revision=NEW.club_revision AND z.subject_revision=NEW.subject_revision
 AND z.checkout_revision=NEW.checkout_revision AND z.control_revision=NEW.control_revision)
 THEN RAISE(ABORT,'handoff_permission_denied') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_checkout_reusable v WHERE v.order_id=NEW.order_id)
 THEN RAISE(ABORT,'handoff_order_changed') END;
END;
-- Cannot silently replace/cancel a pending checkout while payment may be in flight.
-- Existing exact-key checkout recovery is a read and remains available.
-- This guard remains even when the handoff kill switch is disabled.
CREATE TRIGGER pa_checkout_handoff_block BEFORE INSERT ON pa_checkout_requests
 WHEN EXISTS(SELECT 1 FROM pa_handoff_unresolved z WHERE z.club_id=NEW.club_id AND z.user_id=NEW.user_id)
 BEGIN SELECT RAISE(ABORT,'handoff_unresolved'); END;
CREATE TRIGGER pa_handoff_reservation_no_update BEFORE UPDATE ON pa_handoff_reservations BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_reservation_no_delete BEFORE DELETE ON pa_handoff_reservations BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_slot_no_delete BEFORE DELETE ON pa_handoff_slots BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_audit_no_update BEFORE UPDATE ON pa_handoff_audit BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_audit_no_delete BEFORE DELETE ON pa_handoff_audit BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_settings_identity BEFORE UPDATE ON pa_handoff_settings
 WHEN NEW.singleton IS NOT OLD.singleton OR NEW.revision<OLD.revision BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_settings_revision AFTER UPDATE ON pa_handoff_settings WHEN NEW.revision=OLD.revision
 AND (NEW.enabled IS NOT OLD.enabled OR NEW.legacy_attempts_reconciled IS NOT OLD.legacy_attempts_reconciled OR NEW.evidence_ref IS NOT OLD.evidence_ref)
 BEGIN UPDATE pa_handoff_settings SET revision=OLD.revision+1 WHERE singleton=NEW.singleton; END;
CREATE TRIGGER pa_handoff_settings_no_delete BEFORE DELETE ON pa_handoff_settings BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_grants_identity BEFORE UPDATE ON pa_handoff_grants WHEN NEW.principal_id IS NOT OLD.principal_id
 OR NEW.club_id IS NOT OLD.club_id OR NEW.capability IS NOT OLD.capability OR NEW.revision<OLD.revision BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_grants_revision AFTER UPDATE ON pa_handoff_grants WHEN NEW.revision=OLD.revision AND NEW.enabled IS NOT OLD.enabled
 BEGIN UPDATE pa_handoff_grants SET revision=OLD.revision+1 WHERE principal_id=NEW.principal_id AND club_id=NEW.club_id AND capability=NEW.capability; END;
CREATE TRIGGER pa_handoff_grants_no_delete BEFORE DELETE ON pa_handoff_grants BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
