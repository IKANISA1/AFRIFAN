-- Forward-only, same isolated allocation database; disabled by default.
-- Local app-data loss must not erase the record of an external handoff claim.
PRAGMA foreign_keys=ON;
CREATE TABLE pa_handoff_settings (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN(0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
) STRICT;
INSERT INTO pa_handoff_settings(singleton) VALUES(1);
CREATE TABLE pa_handoff_reservations (
 handoff_id TEXT PRIMARY KEY,principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id),user_id TEXT NOT NULL,
 request_id TEXT NOT NULL,order_id TEXT NOT NULL REFERENCES pa_orders(order_id),
 snapshot_sha256 TEXT NOT NULL CHECK(length(snapshot_sha256)=64),created_at_ms INTEGER NOT NULL,
 FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id),
 UNIQUE(club_id,user_id,request_id)
) STRICT;
CREATE TABLE pa_handoff_heads (
 user_id TEXT NOT NULL,club_id INTEGER NOT NULL,handoff_id TEXT NOT NULL UNIQUE REFERENCES pa_handoff_reservations(handoff_id),
 PRIMARY KEY(user_id,club_id),FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id)
) STRICT;
CREATE TABLE pa_handoff_claims (
 handoff_id TEXT PRIMARY KEY REFERENCES pa_handoff_reservations(handoff_id),
 principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 user_id TEXT NOT NULL,club_id INTEGER NOT NULL,request_id TEXT NOT NULL,claimed_at_ms INTEGER NOT NULL,
 FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id),UNIQUE(user_id,club_id,request_id)
) STRICT;
CREATE TABLE pa_handoff_audit (
 event_id TEXT PRIMARY KEY,handoff_id TEXT NOT NULL REFERENCES pa_handoff_reservations(handoff_id),
 principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 kind TEXT NOT NULL CHECK(kind IN('reserved','claimed')),created_at_ms INTEGER NOT NULL
) STRICT;
CREATE TABLE pa_handoff_guards (guard_id TEXT PRIMARY KEY,ok INTEGER NOT NULL CHECK(ok=1)) STRICT;
CREATE INDEX pa_handoff_owner_history ON pa_handoff_reservations(user_id,club_id,created_at_ms,handoff_id);
CREATE TRIGGER pa_handoff_settings_identity BEFORE UPDATE ON pa_handoff_settings
 WHEN NEW.singleton IS NOT OLD.singleton OR NEW.revision<OLD.revision
 BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_settings_revision AFTER UPDATE ON pa_handoff_settings
 WHEN NEW.revision=OLD.revision AND NEW.enabled IS NOT OLD.enabled
 BEGIN UPDATE pa_handoff_settings SET revision=OLD.revision+1 WHERE singleton=1; END;
CREATE TRIGGER pa_handoff_settings_retain BEFORE DELETE ON pa_handoff_settings
 BEGIN SELECT RAISE(ABORT,'handoff_retain_control'); END;
CREATE TRIGGER pa_handoff_reservation_update BEFORE UPDATE ON pa_handoff_reservations
 BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_reservation_delete BEFORE DELETE ON pa_handoff_reservations
 BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_claim_update BEFORE UPDATE ON pa_handoff_claims
 BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_claim_delete BEFORE DELETE ON pa_handoff_claims
 BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_claim_owner BEFORE INSERT ON pa_handoff_claims BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_handoff_reservations r WHERE r.handoff_id=NEW.handoff_id
 AND r.user_id=NEW.user_id AND r.club_id=NEW.club_id) THEN RAISE(ABORT,'handoff_owner_mismatch') END;
END;
CREATE TRIGGER pa_handoff_head_insert BEFORE INSERT ON pa_handoff_heads BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_handoff_reservations r WHERE r.handoff_id=NEW.handoff_id
 AND r.user_id=NEW.user_id AND r.club_id=NEW.club_id) THEN RAISE(ABORT,'handoff_owner_mismatch') END;
END;
CREATE TRIGGER pa_handoff_head_update BEFORE UPDATE ON pa_handoff_heads BEGIN
 SELECT CASE WHEN NEW.user_id IS NOT OLD.user_id OR NEW.club_id IS NOT OLD.club_id OR
 NOT EXISTS(SELECT 1 FROM pa_handoff_reservations r WHERE r.handoff_id=NEW.handoff_id
 AND r.user_id=NEW.user_id AND r.club_id=NEW.club_id) THEN RAISE(ABORT,'handoff_owner_mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM pa_handoff_claims c JOIN pa_handoff_reservations r ON r.handoff_id=c.handoff_id
 JOIN pa_orders o ON o.order_id=r.order_id WHERE c.handoff_id=OLD.handoff_id AND o.state<>'fulfilled')
 THEN RAISE(ABORT,'unresolved_payment_handoff') END;
END;
CREATE TRIGGER pa_handoff_head_delete BEFORE DELETE ON pa_handoff_heads BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_audit_update BEFORE UPDATE ON pa_handoff_audit BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_audit_delete BEFORE DELETE ON pa_handoff_audit BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
-- Existing checkout cancellation and handoff claims now serialize in this SAME DB.
-- Expiry is never evidence that a claimed external payment was not made.
CREATE TRIGGER pa_handoff_prevent_claimed_cancellation BEFORE UPDATE OF state ON pa_orders
 WHEN NEW.state='cancelled' AND OLD.state<>'cancelled' AND EXISTS(
 SELECT 1 FROM pa_handoff_reservations r JOIN pa_handoff_claims c ON c.handoff_id=r.handoff_id WHERE r.order_id=OLD.order_id)
 BEGIN SELECT RAISE(ABORT,'unresolved_payment_handoff'); END;
