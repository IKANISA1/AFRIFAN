-- Independent private observational database. Never share a domain/financial database.
CREATE TABLE private_web_observations (
 record_id TEXT PRIMARY KEY,
 club_id INTEGER NOT NULL CHECK(club_id IN(6,24,26,44,1001)),
 event TEXT NOT NULL CHECK(event IN('web_vital','pwa_event')),
 observation_json TEXT NOT NULL CHECK(json_valid(observation_json) AND length(observation_json)<=1024),
 recorded_at_ms INTEGER NOT NULL,
 expires_at_ms INTEGER NOT NULL CHECK(expires_at_ms-recorded_at_ms BETWEEN 3600000 AND 31622400000)
) STRICT;
CREATE INDEX private_web_observations_expiry ON private_web_observations(expires_at_ms,record_id);
CREATE INDEX private_web_observations_quota ON private_web_observations(club_id,recorded_at_ms);
CREATE TRIGGER private_web_observations_no_update BEFORE UPDATE ON private_web_observations
 BEGIN SELECT RAISE(ABORT,'web_observations_immutable'); END;
