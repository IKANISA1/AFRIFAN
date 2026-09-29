-- A SEPARATE, isolated operations-inbox database. Not the identity or financial database.
CREATE TABLE adi_control (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1), purpose TEXT NOT NULL CHECK(purpose='africlub-allocation-inbox'),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)), consumer_id TEXT NOT NULL, approval_ref TEXT NOT NULL
) STRICT;
CREATE TABLE adi_clubs(club_id INTEGER PRIMARY KEY,enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1))) STRICT;
CREATE TABLE adi_events (
 event_id TEXT PRIMARY KEY,consumer_id TEXT NOT NULL,club_id INTEGER NOT NULL REFERENCES adi_clubs(club_id),
 envelope_sha256 TEXT NOT NULL CHECK(length(envelope_sha256)=64),
 envelope_json TEXT NOT NULL CHECK(json_valid(envelope_json)),stored_at_ms INTEGER NOT NULL
) STRICT;
CREATE INDEX adi_club_events ON adi_events(club_id,stored_at_ms DESC,event_id DESC);
CREATE TRIGGER adi_event_authority BEFORE INSERT ON adi_events BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM adi_control c JOIN adi_clubs cl ON cl.club_id=NEW.club_id
  WHERE c.singleton=1 AND c.enabled=1 AND cl.enabled=1 AND c.consumer_id=NEW.consumer_id AND length(c.approval_ref)>0)
  THEN RAISE(ABORT,'delivery_permission_denied') END;
 SELECT CASE WHEN NEW.stored_at_ms!=CAST(unixepoch('subsec') * 1000 AS INTEGER) THEN RAISE(ABORT,'delivery_conflict') END;
END;
CREATE TRIGGER adi_no_update BEFORE UPDATE ON adi_events BEGIN SELECT RAISE(ABORT,'delivery_immutable'); END;
CREATE TRIGGER adi_no_delete BEFORE DELETE ON adi_events BEGIN SELECT RAISE(ABORT,'delivery_immutable'); END;
