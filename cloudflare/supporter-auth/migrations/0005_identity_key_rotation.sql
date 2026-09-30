-- Forward-only key lifecycle support. No keys, users, gates or public routes are enabled.
-- Canonical phone hashes and user IDs remain unchanged. An alias under each current
-- HMAC key permits lookup after its old key retires without merging identities.
CREATE TABLE auth_phone_aliases (
 key_version TEXT NOT NULL CHECK(length(key_version) BETWEEN 1 AND 3 AND key_version NOT GLOB '*[^0-9]*' AND substr(key_version,1,1)<>'0'),
 phone_hash TEXT NOT NULL CHECK(length(phone_hash)=64 AND phone_hash NOT GLOB '*[^0-9a-f]*'),
 user_id TEXT NOT NULL REFERENCES auth_accounts(user_id),
 created_at_ms INTEGER NOT NULL,
 PRIMARY KEY(key_version,phone_hash),
 UNIQUE(key_version,user_id)
);
INSERT INTO auth_phone_aliases SELECT '1',phone_hash,user_id,created_at_ms FROM auth_accounts;
CREATE TRIGGER auth_phone_alias_immutable BEFORE UPDATE ON auth_phone_aliases
BEGIN SELECT RAISE(ABORT,'phone_alias_immutable'); END;
CREATE TRIGGER auth_phone_alias_retained BEFORE DELETE ON auth_phone_aliases
BEGIN SELECT RAISE(ABORT,'phone_alias_retained'); END;
ALTER TABLE auth_challenges ADD COLUMN hmac_key_version TEXT NOT NULL DEFAULT '1';
ALTER TABLE auth_browser_sessions ADD COLUMN cookie_key_version TEXT NOT NULL DEFAULT '1';
CREATE TABLE auth_key_rotations (
 to_version TEXT PRIMARY KEY,
 from_version TEXT NOT NULL,
 evidence TEXT NOT NULL CHECK(length(evidence) BETWEEN 1 AND 256),
 activated_at_ms INTEGER NOT NULL
);
CREATE TRIGGER auth_key_rotation_immutable BEFORE UPDATE ON auth_key_rotations
BEGIN SELECT RAISE(ABORT,'key_rotation_immutable'); END;
CREATE TRIGGER auth_key_rotation_retained BEFORE DELETE ON auth_key_rotations
BEGIN SELECT RAISE(ABORT,'key_rotation_retained'); END;
-- Fingerprints bind a version to its originally registered secret material. The
-- registry contains hashes only and cannot repair missing secrets.
CREATE TABLE auth_key_versions (
 key_version TEXT PRIMARY KEY,
 hmac_fingerprint TEXT NOT NULL CHECK(length(hmac_fingerprint)=64),
 encryption_fingerprint TEXT NOT NULL CHECK(length(encryption_fingerprint)=64),
 evidence TEXT NOT NULL CHECK(length(evidence) BETWEEN 1 AND 128),
 registered_at_ms INTEGER NOT NULL
);
CREATE TRIGGER auth_key_version_immutable BEFORE UPDATE ON auth_key_versions
BEGIN SELECT RAISE(ABORT,'key_version_immutable'); END;
CREATE TRIGGER auth_key_version_retained BEFORE DELETE ON auth_key_versions
BEGIN SELECT RAISE(ABORT,'key_version_retained'); END;
ALTER TABLE auth_key_rotations ADD COLUMN retained_versions_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE auth_key_rotations ADD COLUMN policy_activated_at_ms INTEGER NOT NULL DEFAULT 0;
CREATE TRIGGER auth_settings_key_version_monotonic BEFORE UPDATE OF key_version ON auth_settings
WHEN NEW.key_version GLOB '*[^0-9]*' OR length(NEW.key_version) NOT BETWEEN 1 AND 3
 OR substr(NEW.key_version,1,1)='0' OR CAST(NEW.key_version AS INTEGER)<CAST(OLD.key_version AS INTEGER)
BEGIN SELECT RAISE(ABORT,'key_version_not_forward'); END;
CREATE TRIGGER auth_settings_key_version_registered BEFORE UPDATE OF key_version ON auth_settings
WHEN NOT EXISTS(SELECT 1 FROM auth_key_versions WHERE key_version=NEW.key_version)
BEGIN SELECT RAISE(ABORT,'key_version_not_registered'); END;
