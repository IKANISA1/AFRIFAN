-- Forward-only. Releases a journal reservation, NEVER a payment, claim or order.
-- Only the NEW journal can establish that no claim was recorded. Manual/legacy
-- payments remain outside this guarantee and must still be reconciled separately.
CREATE TABLE pa_handoff_release_settings(
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN(0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
) STRICT;
INSERT INTO pa_handoff_release_settings(singleton) VALUES(1);
CREATE TABLE pa_handoff_releases(
 handoff_id TEXT PRIMARY KEY REFERENCES pa_handoff_reservations(handoff_id),
 principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 user_id TEXT NOT NULL,club_id INTEGER NOT NULL,request_id TEXT NOT NULL,
 released_at_ms INTEGER NOT NULL,reason TEXT NOT NULL CHECK(reason='never_claimed'),
 FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id),
 UNIQUE(user_id,club_id,request_id)
) STRICT;
CREATE INDEX pa_handoff_release_owner ON pa_handoff_releases(user_id,club_id,released_at_ms);
CREATE TRIGGER pa_handoff_release_identity BEFORE UPDATE ON pa_handoff_release_settings
 WHEN NEW.singleton<>OLD.singleton OR NEW.revision<OLD.revision BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_release_revision AFTER UPDATE OF enabled ON pa_handoff_release_settings
 WHEN NEW.enabled<>OLD.enabled AND NEW.revision=OLD.revision
 BEGIN UPDATE pa_handoff_release_settings SET revision=OLD.revision+1 WHERE singleton=1; END;
CREATE TRIGGER pa_handoff_release_control_retain BEFORE DELETE ON pa_handoff_release_settings
 BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_release_guard BEFORE INSERT ON pa_handoff_releases BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_handoff_reservations r JOIN pa_orders o ON o.order_id=r.order_id
  JOIN pa_handoff_heads h ON h.handoff_id=r.handoff_id
  WHERE r.handoff_id=NEW.handoff_id AND r.user_id=NEW.user_id AND r.club_id=NEW.club_id
  AND NEW.released_at_ms>=r.created_at_ms AND o.state<>'fulfilled')
  OR EXISTS(SELECT 1 FROM pa_handoff_claims c WHERE c.handoff_id=NEW.handoff_id)
  THEN RAISE(ABORT,'handoff_not_releasable') END;
END;
-- Both directions serialize in the same database. No later stale client can claim
-- a released reservation, even after a different current head has been installed.
CREATE TRIGGER pa_handoff_claim_release_guard BEFORE INSERT ON pa_handoff_claims
 WHEN EXISTS(SELECT 1 FROM pa_handoff_releases r WHERE r.handoff_id=NEW.handoff_id)
 BEGIN SELECT RAISE(ABORT,'handoff_released'); END;
CREATE TRIGGER pa_handoff_release_no_update BEFORE UPDATE ON pa_handoff_releases
 BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
CREATE TRIGGER pa_handoff_release_no_delete BEFORE DELETE ON pa_handoff_releases
 BEGIN SELECT RAISE(ABORT,'handoff_immutable'); END;
