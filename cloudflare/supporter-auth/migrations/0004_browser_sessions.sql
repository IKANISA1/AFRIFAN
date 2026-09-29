-- Forward-only browser identity state in the SAME AUTH_DB as auth_accounts/sessions.
-- This file never enables a public route, sends a code, or changes financial data.
CREATE TABLE auth_browser_control (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN(0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 idle_ms INTEGER NOT NULL DEFAULT 1800000 CHECK(idle_ms BETWEEN 60000 AND 3600000),
 absolute_ms INTEGER NOT NULL DEFAULT 28800000 CHECK(absolute_ms BETWEEN 60000 AND 86400000),
 CHECK(idle_ms<=absolute_ms)
);
INSERT INTO auth_browser_control(singleton) VALUES(1);
CREATE TRIGGER auth_browser_control_epoch AFTER UPDATE OF enabled,idle_ms,absolute_ms ON auth_browser_control
BEGIN UPDATE auth_browser_control SET revision=OLD.revision+1 WHERE singleton=1; END;
CREATE TABLE auth_browser_origins (
 origin TEXT PRIMARY KEY,
 club_id INTEGER NOT NULL REFERENCES auth_clubs(club_id),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN(0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
);
CREATE TRIGGER auth_browser_origin_epoch AFTER UPDATE OF enabled,club_id ON auth_browser_origins
BEGIN UPDATE auth_browser_origins SET revision=OLD.revision+1 WHERE origin=OLD.origin; END;
CREATE TRIGGER auth_browser_origin_identity BEFORE UPDATE OF origin ON auth_browser_origins
BEGIN SELECT RAISE(ABORT,'browser_origin_immutable'); END;
CREATE TABLE auth_browser_challenges (
 bootstrap_hash TEXT PRIMARY KEY CHECK(length(bootstrap_hash)=64),
 origin TEXT NOT NULL REFERENCES auth_browser_origins(origin),
 club_id INTEGER NOT NULL REFERENCES auth_clubs(club_id),
 origin_revision INTEGER NOT NULL,
 control_revision INTEGER NOT NULL,
 request_key_hash TEXT NOT NULL CHECK(length(request_key_hash)=64),
 phone_hash TEXT NOT NULL CHECK(length(phone_hash)=64),
 expires_ms INTEGER NOT NULL,
 created_ms INTEGER NOT NULL,
 UNIQUE(club_id,request_key_hash)
);
CREATE TRIGGER auth_browser_challenge_immutable BEFORE UPDATE ON auth_browser_challenges
BEGIN SELECT RAISE(ABORT,'browser_challenge_immutable'); END;
CREATE TABLE auth_browser_sessions (
 browser_id TEXT PRIMARY KEY CHECK(length(browser_id)=36),
 auth_session_id TEXT NOT NULL UNIQUE REFERENCES auth_sessions(session_id),
 origin TEXT NOT NULL REFERENCES auth_browser_origins(origin),
 club_id INTEGER NOT NULL REFERENCES auth_clubs(club_id),
 origin_revision INTEGER NOT NULL,
 control_revision INTEGER NOT NULL,
 bootstrap_hash TEXT NOT NULL UNIQUE REFERENCES auth_browser_challenges(bootstrap_hash),
 verify_key_hash TEXT NOT NULL,
 verify_request_hash TEXT NOT NULL,
 cookie_hash TEXT NOT NULL UNIQUE CHECK(length(cookie_hash)=64),
 generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),
 expires_ms INTEGER NOT NULL,
 absolute_ms INTEGER NOT NULL,
 created_ms INTEGER NOT NULL,
 cookie_response_cipher TEXT,
 replay_until_ms INTEGER NOT NULL,
 revoked_ms INTEGER,
 logout_key_hash TEXT,
 CHECK(expires_ms<=absolute_ms),
 CHECK((revoked_ms IS NULL AND logout_key_hash IS NULL) OR revoked_ms IS NOT NULL)
);
CREATE TRIGGER auth_browser_session_identity BEFORE UPDATE OF browser_id,auth_session_id,origin,club_id,
 origin_revision,control_revision,bootstrap_hash,verify_key_hash,verify_request_hash,absolute_ms,created_ms,replay_until_ms
 ON auth_browser_sessions BEGIN SELECT RAISE(ABORT,'browser_session_identity_immutable'); END;
CREATE TRIGGER auth_browser_revocation_permanent BEFORE UPDATE OF revoked_ms ON auth_browser_sessions
WHEN OLD.revoked_ms IS NOT NULL AND (NEW.revoked_ms IS NULL OR NEW.revoked_ms<>OLD.revoked_ms)
BEGIN SELECT RAISE(ABORT,'browser_revocation_permanent'); END;
CREATE TRIGGER auth_browser_logout_identity BEFORE UPDATE OF logout_key_hash ON auth_browser_sessions
WHEN OLD.logout_key_hash IS NOT NULL AND NEW.logout_key_hash IS NOT OLD.logout_key_hash
BEGIN SELECT RAISE(ABORT,'browser_logout_immutable'); END;
CREATE TABLE auth_browser_rotations (
 browser_id TEXT NOT NULL REFERENCES auth_browser_sessions(browser_id),
 request_key_hash TEXT NOT NULL,
 old_cookie_hash TEXT NOT NULL,
 new_cookie_hash TEXT NOT NULL,
 generation INTEGER NOT NULL CHECK(generation>0),
 response_cipher TEXT,
 replay_until_ms INTEGER NOT NULL,
 created_ms INTEGER NOT NULL,
 PRIMARY KEY(browser_id,request_key_hash),
 UNIQUE(browser_id,old_cookie_hash)
);
CREATE TRIGGER auth_browser_rotation_immutable BEFORE UPDATE OF browser_id,request_key_hash,
 old_cookie_hash,new_cookie_hash,generation,replay_until_ms,created_ms ON auth_browser_rotations
BEGIN SELECT RAISE(ABORT,'browser_rotation_immutable'); END;
CREATE TRIGGER auth_browser_rotation_retained BEFORE DELETE ON auth_browser_rotations
BEGIN SELECT RAISE(ABORT,'browser_rotation_retained'); END;
CREATE INDEX auth_browser_login_secret_expiry ON auth_browser_sessions(replay_until_ms) WHERE cookie_response_cipher IS NOT NULL;
CREATE INDEX auth_browser_rotation_secret_expiry ON auth_browser_rotations(replay_until_ms) WHERE response_cipher IS NOT NULL;
CREATE INDEX auth_browser_owner_session ON auth_browser_sessions(auth_session_id,revoked_ms);
