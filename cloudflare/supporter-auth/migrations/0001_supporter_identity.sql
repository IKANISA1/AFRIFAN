-- New isolated identity database only. No existing backend data is changed.
-- Identity import and club activation remain explicitly disabled by default.
CREATE TABLE auth_settings (
  singleton INTEGER PRIMARY KEY CHECK(singleton=1),
  import_ready INTEGER NOT NULL DEFAULT 0 CHECK(import_ready IN (0,1)),
  import_evidence TEXT,
  key_version TEXT NOT NULL DEFAULT '1'
);
INSERT INTO auth_settings(singleton) VALUES(1);
CREATE TABLE auth_clubs (
  club_id INTEGER PRIMARY KEY CHECK(club_id>0),
  club_slug TEXT NOT NULL UNIQUE,
  enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
  allow_signup INTEGER NOT NULL DEFAULT 0 CHECK(allow_signup IN (0,1)),
  auth_template TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
);
CREATE TRIGGER auth_club_revision AFTER UPDATE OF club_slug,enabled,allow_signup,auth_template ON auth_clubs
BEGIN UPDATE auth_clubs SET revision=OLD.revision+1 WHERE club_id=OLD.club_id; END;
CREATE TABLE auth_accounts (
  user_id TEXT PRIMARY KEY CHECK(length(user_id)=36),
  phone_hash TEXT NOT NULL UNIQUE CHECK(length(phone_hash)=64),
  phone_cipher TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('active','suspended','deletion_pending')),
  auth_epoch INTEGER NOT NULL DEFAULT 1 CHECK(auth_epoch>0),
  verified_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  source_project TEXT,
  source_user_id TEXT,
  CHECK((source_project IS NULL AND source_user_id IS NULL) OR (source_project IS NOT NULL AND source_user_id=user_id)),
  UNIQUE(source_project,source_user_id)
);
CREATE TRIGGER auth_account_status_epoch AFTER UPDATE OF status,phone_hash ON auth_accounts
BEGIN UPDATE auth_accounts SET auth_epoch=OLD.auth_epoch+1 WHERE user_id=OLD.user_id; END;
CREATE TABLE auth_rate_windows (
  rate_key TEXT NOT NULL, window_start_ms INTEGER NOT NULL,
  count INTEGER NOT NULL CHECK(count>=0),
  PRIMARY KEY(rate_key,window_start_ms)
);
CREATE TABLE auth_challenges (
  challenge_id TEXT PRIMARY KEY,
  club_id INTEGER NOT NULL REFERENCES auth_clubs(club_id), club_revision INTEGER NOT NULL,
  request_key_hash TEXT NOT NULL, request_hash TEXT NOT NULL,
  phone_hash TEXT NOT NULL, client_hash TEXT NOT NULL, code_hash TEXT NOT NULL,
  phone_cipher TEXT NOT NULL, delivery_cipher TEXT,
  subject_at_request TEXT, subject_epoch INTEGER,
  created_at_ms INTEGER NOT NULL, expires_at_ms INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5),
  state TEXT NOT NULL DEFAULT 'open' CHECK(state IN ('open','consumed','cancelled')),
  verification_key_hash TEXT, session_id TEXT,
  verification_cipher TEXT, replay_until_ms INTEGER,
  delivery_state TEXT NOT NULL DEFAULT 'queued' CHECK(delivery_state IN ('queued','leased','accepted','retry','failed')),
  delivery_attempts INTEGER NOT NULL DEFAULT 0 CHECK(delivery_attempts BETWEEN 0 AND 3),
  next_attempt_ms INTEGER NOT NULL, lease_id TEXT, lease_until_ms INTEGER,
  provider_message_id TEXT,
  UNIQUE(club_id,request_key_hash)
);
CREATE INDEX auth_challenges_delivery ON auth_challenges(delivery_state,next_attempt_ms,expires_at_ms);
CREATE INDEX auth_challenges_phone ON auth_challenges(phone_hash,state);
CREATE TABLE auth_sessions (
  session_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES auth_accounts(user_id),
  club_id INTEGER NOT NULL REFERENCES auth_clubs(club_id),
  account_epoch INTEGER NOT NULL, club_revision INTEGER NOT NULL,
  access_hash TEXT NOT NULL UNIQUE, refresh_hash TEXT NOT NULL UNIQUE,
  generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),
  authenticated_at_ms INTEGER NOT NULL, created_at_ms INTEGER NOT NULL,
  access_expires_ms INTEGER NOT NULL, refresh_expires_ms INTEGER NOT NULL,
  absolute_expires_ms INTEGER NOT NULL, revoked_at_ms INTEGER,
  CHECK(access_expires_ms<=absolute_expires_ms AND refresh_expires_ms<=absolute_expires_ms)
);
CREATE INDEX auth_sessions_owner ON auth_sessions(user_id,revoked_at_ms);
CREATE TABLE auth_refresh_receipts (
  session_id TEXT NOT NULL REFERENCES auth_sessions(session_id),
  old_refresh_hash TEXT NOT NULL, request_key_hash TEXT NOT NULL,
  new_generation INTEGER NOT NULL, response_cipher TEXT,
  replay_until_ms INTEGER NOT NULL, created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(session_id,old_refresh_hash)
);
CREATE TABLE auth_deletion_requests (
  request_id TEXT PRIMARY KEY, user_id TEXT NOT NULL UNIQUE REFERENCES auth_accounts(user_id),
  request_key_hash TEXT NOT NULL, requested_at_ms INTEGER NOT NULL,
  session_id TEXT NOT NULL REFERENCES auth_sessions(session_id), club_id INTEGER NOT NULL REFERENCES auth_clubs(club_id), access_hash TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'pending_external_erasure' CHECK(state IN ('pending_external_erasure','completed'))
);
CREATE TABLE auth_outbox (
  event_id TEXT PRIMARY KEY, kind TEXT NOT NULL CHECK(kind='identity.deletion_requested'),
  user_id TEXT NOT NULL REFERENCES auth_accounts(user_id),
  created_at_ms INTEGER NOT NULL, delivered_at_ms INTEGER,
  UNIQUE(kind,user_id)
);
CREATE TABLE auth_audit (
  event_id TEXT PRIMARY KEY, kind TEXT NOT NULL,
  user_id TEXT, club_id INTEGER, session_id TEXT, created_at_ms INTEGER NOT NULL
);
CREATE TRIGGER auth_audit_no_update BEFORE UPDATE ON auth_audit BEGIN SELECT RAISE(ABORT,'immutable_audit'); END;
CREATE TRIGGER auth_audit_no_delete BEFORE DELETE ON auth_audit BEGIN SELECT RAISE(ABORT,'immutable_audit'); END;
-- Transaction-local assertions. The helper removes its rows before committing.
CREATE TABLE auth_assertions(assertion_id TEXT PRIMARY KEY, ok INTEGER NOT NULL CHECK(ok=1));

-- Preserve subject/source identity and event lineage. Administrative status may change.
CREATE TRIGGER auth_account_identity_immutable BEFORE UPDATE OF user_id,source_project,source_user_id ON auth_accounts
BEGIN SELECT RAISE(ABORT,'identity_mapping_immutable'); END;
CREATE TRIGGER auth_deletion_immutable BEFORE UPDATE OF request_id,user_id,request_key_hash,requested_at_ms,session_id,club_id,access_hash ON auth_deletion_requests
BEGIN SELECT RAISE(ABORT,'deletion_request_immutable'); END;
CREATE TRIGGER auth_deletion_retained BEFORE DELETE ON auth_deletion_requests
BEGIN SELECT RAISE(ABORT,'deletion_request_retained'); END;
CREATE TRIGGER auth_outbox_identity_immutable BEFORE UPDATE OF event_id,kind,user_id,created_at_ms ON auth_outbox
BEGIN SELECT RAISE(ABORT,'outbox_identity_immutable'); END;
CREATE TRIGGER auth_outbox_retained BEFORE DELETE ON auth_outbox
BEGIN SELECT RAISE(ABORT,'outbox_retained'); END;
-- Bounded maintenance can seek expired rows rather than scan all retained history.
CREATE INDEX auth_rate_expiry ON auth_rate_windows(window_start_ms);
CREATE INDEX auth_code_payload_expiry ON auth_challenges(expires_at_ms) WHERE delivery_cipher IS NOT NULL OR verification_cipher IS NOT NULL;
CREATE INDEX auth_verification_replay_expiry ON auth_challenges(replay_until_ms) WHERE verification_cipher IS NOT NULL;
CREATE INDEX auth_refresh_replay_expiry ON auth_refresh_receipts(replay_until_ms) WHERE response_cipher IS NOT NULL;
CREATE INDEX auth_last_lease_expiry ON auth_challenges(lease_until_ms) WHERE delivery_state='leased' AND delivery_attempts>=3;
