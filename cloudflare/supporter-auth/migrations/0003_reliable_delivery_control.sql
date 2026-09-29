-- Same isolated identity database. Forward-only; creates no user/session or provider call.
PRAGMA foreign_keys=ON;
CREATE TABLE auth_delivery_control(
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN(0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 sequence INTEGER NOT NULL DEFAULT 0 CHECK(sequence>=0)
) STRICT;
INSERT INTO auth_delivery_control(singleton) VALUES(1);
CREATE TABLE auth_delivery_turns(
 club_id INTEGER PRIMARY KEY REFERENCES auth_clubs(club_id),
 last_sequence INTEGER NOT NULL CHECK(last_sequence>=0)
) STRICT;
CREATE TABLE auth_delivery_attempts(
 lease_id TEXT PRIMARY KEY,
 challenge_id TEXT NOT NULL REFERENCES auth_challenges(challenge_id),
 club_id INTEGER NOT NULL REFERENCES auth_clubs(club_id),
 attempt INTEGER NOT NULL CHECK(attempt BETWEEN 1 AND 3),
 started_at_ms INTEGER NOT NULL,
 lease_until_ms INTEGER NOT NULL CHECK(lease_until_ms>started_at_ms),
 UNIQUE(challenge_id,attempt)
) STRICT;
CREATE TABLE auth_delivery_outcomes(
 lease_id TEXT PRIMARY KEY REFERENCES auth_delivery_attempts(lease_id),
 outcome TEXT NOT NULL CHECK(outcome IN('accepted','unconfirmed','lease_expired','invalidated')),
 observed_at_ms INTEGER NOT NULL
) STRICT;
CREATE TABLE auth_delivery_quarantine(
 challenge_id TEXT PRIMARY KEY REFERENCES auth_challenges(challenge_id),
 reason TEXT NOT NULL CHECK(reason IN('legacy_unconfirmed','attempts_exhausted')),
 observed_at_ms INTEGER NOT NULL
) STRICT;
CREATE INDEX auth_delivery_attempt_expiry ON auth_delivery_attempts(lease_until_ms,lease_id);
CREATE INDEX auth_delivery_attempt_club ON auth_delivery_attempts(club_id,started_at_ms);
CREATE INDEX auth_delivery_outcome_time ON auth_delivery_outcomes(observed_at_ms);
CREATE TRIGGER auth_delivery_control_identity BEFORE UPDATE ON auth_delivery_control
 WHEN NEW.singleton<>OLD.singleton OR NEW.revision<OLD.revision OR NEW.sequence<OLD.sequence
 BEGIN SELECT RAISE(ABORT,'delivery_control_invalid'); END;
CREATE TRIGGER auth_delivery_control_revision AFTER UPDATE OF enabled ON auth_delivery_control
 WHEN NEW.enabled<>OLD.enabled AND NEW.revision=OLD.revision
 BEGIN UPDATE auth_delivery_control SET revision=OLD.revision+1 WHERE singleton=1; END;
CREATE TRIGGER auth_delivery_control_retain BEFORE DELETE ON auth_delivery_control
 BEGIN SELECT RAISE(ABORT,'delivery_control_retained'); END;
CREATE TRIGGER auth_delivery_attempt_identity BEFORE INSERT ON auth_delivery_attempts BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM auth_challenges q WHERE q.challenge_id=NEW.challenge_id
 AND q.club_id=NEW.club_id AND q.lease_id=NEW.lease_id AND q.delivery_attempts=NEW.attempt
 AND q.delivery_state='leased') THEN RAISE(ABORT,'delivery_attempt_mismatch') END;
END;
CREATE TRIGGER auth_delivery_attempt_no_update BEFORE UPDATE ON auth_delivery_attempts
 BEGIN SELECT RAISE(ABORT,'delivery_history_immutable'); END;
CREATE TRIGGER auth_delivery_attempt_no_delete BEFORE DELETE ON auth_delivery_attempts
 BEGIN SELECT RAISE(ABORT,'delivery_history_retained'); END;
CREATE TRIGGER auth_delivery_outcome_no_update BEFORE UPDATE ON auth_delivery_outcomes
 BEGIN SELECT RAISE(ABORT,'delivery_history_immutable'); END;
CREATE TRIGGER auth_delivery_outcome_no_delete BEFORE DELETE ON auth_delivery_outcomes
 BEGIN SELECT RAISE(ABORT,'delivery_history_retained'); END;
CREATE TRIGGER auth_delivery_quarantine_no_update BEFORE UPDATE ON auth_delivery_quarantine
 BEGIN SELECT RAISE(ABORT,'delivery_history_immutable'); END;
CREATE TRIGGER auth_delivery_quarantine_no_delete BEFORE DELETE ON auth_delivery_quarantine
 BEGIN SELECT RAISE(ABORT,'delivery_history_retained'); END;

-- Cover bounded aggregate health reads without traversing another tenant.
CREATE INDEX auth_delivery_health_state ON auth_challenges(club_id,delivery_state,challenge_id);
