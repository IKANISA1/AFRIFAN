-- Forward-only. Run in the EXISTING allocation database after the reviewed 0001-0005 lineage.
-- No automatic enrolment, enablement, financial posting, external call or historic replay.
CREATE TABLE pa_delivery_control (
 club_id INTEGER PRIMARY KEY REFERENCES pa_clubs(club_id),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 consumer_id TEXT NOT NULL,
 max_attempts INTEGER NOT NULL CHECK(max_attempts BETWEEN 1 AND 10),
 lease_ms INTEGER NOT NULL CHECK(lease_ms BETWEEN 10000 AND 60000),
 retry_ms INTEGER NOT NULL CHECK(retry_ms BETWEEN 1000 AND 3600000),
 approval_ref TEXT NOT NULL CHECK(length(approval_ref) BETWEEN 1 AND 128)
) STRICT;
CREATE TABLE pa_delivery_grants (
 principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 club_id INTEGER NOT NULL REFERENCES pa_delivery_control(club_id),
 role TEXT NOT NULL CHECK(role IN ('dispatch','review')),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 PRIMARY KEY(principal_id,club_id,role)
) STRICT;
CREATE TABLE pa_delivery_commands (
 request_id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 event_id TEXT NOT NULL REFERENCES pa_outbox(event_id), club_id INTEGER NOT NULL,
 action TEXT NOT NULL CHECK(action IN ('enroll','claim','delivered','retry','dead','expire','redrive')),
 expected_revision INTEGER NOT NULL CHECK(expected_revision>=0),
 request_sha256 TEXT NOT NULL CHECK(length(request_sha256)=64),
 lease_id TEXT, reason TEXT NOT NULL CHECK(reason IN ('none','sink_unavailable','sink_timeout','invalid_event','invalid_receipt','lease_expired','dependency_restored','configuration_corrected')),
 receipt_id TEXT, recorded_at_ms INTEGER NOT NULL
) STRICT;
CREATE TABLE pa_delivery_jobs (
 event_id TEXT PRIMARY KEY REFERENCES pa_outbox(event_id), club_id INTEGER NOT NULL,
 consumer_id TEXT NOT NULL, revision INTEGER NOT NULL CHECK(revision>=1),
 state TEXT NOT NULL CHECK(state IN ('pending','leased','retry','dead','delivered')),
 attempts INTEGER NOT NULL CHECK(attempts>=0), cycle_attempts INTEGER NOT NULL CHECK(cycle_attempts>=0),
 next_at_ms INTEGER NOT NULL, lease_id TEXT, lease_principal TEXT, lease_until_ms INTEGER,
 reason TEXT NOT NULL, receipt_id TEXT, last_command_id TEXT NOT NULL REFERENCES pa_delivery_commands(request_id),
 CHECK((state='leased' AND lease_id IS NOT NULL AND lease_principal IS NOT NULL AND lease_until_ms IS NOT NULL)
   OR (state<>'leased' AND lease_id IS NULL AND lease_until_ms IS NULL))
) STRICT;
CREATE INDEX pa_delivery_due ON pa_delivery_jobs(club_id,state,next_at_ms,event_id);
CREATE INDEX pa_delivery_commands_history ON pa_delivery_commands(club_id,event_id,recorded_at_ms,request_id);
CREATE INDEX pa_outbox_enrollment ON pa_outbox(club_id,recorded_at_ms,event_id);

-- A single command insertion is the transaction boundary. Authorization and revision are checked
-- inside SQLite, then both the retained command and job head commit or roll back together.
CREATE TRIGGER pa_delivery_command_guard BEFORE INSERT ON pa_delivery_commands BEGIN
 SELECT CASE WHEN NOT EXISTS(
  SELECT 1 FROM pa_principals p JOIN pa_grants g ON g.principal_id=p.principal_id
   JOIN pa_clubs c ON c.club_id=g.club_id JOIN pa_delivery_control dc ON dc.club_id=c.club_id
   JOIN pa_delivery_grants dg ON dg.principal_id=p.principal_id AND dg.club_id=c.club_id
   CROSS JOIN pa_settings s
  WHERE p.principal_id=NEW.principal_id AND c.club_id=NEW.club_id
   AND g.capability='outbox' AND g.enabled=1 AND p.enabled=1 AND c.enabled=1 AND dc.enabled=1 AND dg.enabled=1
   AND dg.role=CASE WHEN NEW.action='redrive' THEN 'review' ELSE 'dispatch' END
   AND p.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER)
   AND s.singleton=1 AND s.purpose='africlub-payment-allocation' AND s.writer_mode='isolated-staging'
   AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0
 ) THEN RAISE(ABORT,'delivery_permission_denied') END;
 SELECT CASE WHEN NEW.recorded_at_ms!=CAST(unixepoch('subsec') * 1000 AS INTEGER)
  THEN RAISE(ABORT,'delivery_conflict') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_outbox WHERE event_id=NEW.event_id AND club_id=NEW.club_id)
  THEN RAISE(ABORT,'delivery_conflict') END;
 SELECT CASE WHEN NEW.action='enroll' AND (
  NEW.expected_revision<>0 OR EXISTS(SELECT 1 FROM pa_delivery_jobs WHERE event_id=NEW.event_id) OR
  NOT EXISTS(SELECT 1 FROM pa_outbox_delivery WHERE event_id=NEW.event_id AND club_id=NEW.club_id AND state='pending' AND attempts=0)
 ) THEN RAISE(ABORT,'delivery_conflict') END;
 SELECT CASE WHEN NEW.action<>'enroll' AND NOT EXISTS(
  SELECT 1 FROM pa_delivery_jobs j JOIN pa_delivery_control dc ON dc.club_id=j.club_id
  WHERE j.event_id=NEW.event_id AND j.club_id=NEW.club_id AND j.revision=NEW.expected_revision AND j.consumer_id=dc.consumer_id
  AND (
   (NEW.action='claim' AND j.state IN ('pending','retry') AND j.next_at_ms<=CAST(unixepoch('subsec') * 1000 AS INTEGER)
     AND j.cycle_attempts<dc.max_attempts AND NEW.lease_id=NEW.request_id)
   OR (NEW.action IN ('delivered','retry','dead') AND j.state='leased' AND j.lease_id=NEW.lease_id
     AND j.lease_principal=NEW.principal_id AND j.lease_until_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER))
   OR (NEW.action='expire' AND j.state='leased' AND j.lease_until_ms<=CAST(unixepoch('subsec') * 1000 AS INTEGER))
   OR (NEW.action='redrive' AND j.state='dead' AND j.lease_principal IS NOT NEW.principal_id)
  )
 ) THEN RAISE(ABORT,'delivery_conflict') END;
 SELECT CASE WHEN NOT (
  (NEW.action IN ('enroll','claim') AND NEW.reason='none' AND NEW.receipt_id IS NULL) OR
  (NEW.action='delivered' AND NEW.reason='none' AND NEW.receipt_id=NEW.event_id) OR
  (NEW.action IN ('retry','dead') AND NEW.reason IN ('sink_unavailable','sink_timeout','invalid_event','invalid_receipt') AND NEW.receipt_id IS NULL) OR
  (NEW.action='expire' AND NEW.reason='lease_expired' AND NEW.receipt_id IS NULL) OR
  (NEW.action='redrive' AND NEW.reason IN ('dependency_restored','configuration_corrected') AND NEW.receipt_id IS NULL)
 ) THEN RAISE(ABORT,'delivery_conflict') END;
END;
CREATE TRIGGER pa_delivery_command_apply AFTER INSERT ON pa_delivery_commands BEGIN
 INSERT INTO pa_delivery_jobs(event_id,club_id,consumer_id,revision,state,attempts,cycle_attempts,next_at_ms,reason,last_command_id)
 SELECT NEW.event_id,NEW.club_id,consumer_id,1,'pending',0,0,NEW.recorded_at_ms,'none',NEW.request_id
 FROM pa_delivery_control WHERE club_id=NEW.club_id AND NEW.action='enroll';
 UPDATE pa_delivery_jobs SET revision=revision+1,state='leased',attempts=attempts+1,cycle_attempts=cycle_attempts+1,
  lease_id=NEW.request_id,lease_principal=NEW.principal_id,
  lease_until_ms=NEW.recorded_at_ms+(SELECT lease_ms FROM pa_delivery_control WHERE club_id=NEW.club_id),
  reason='none',last_command_id=NEW.request_id WHERE event_id=NEW.event_id AND NEW.action='claim';
 UPDATE pa_delivery_jobs SET revision=revision+1,
  state=CASE WHEN NEW.action='delivered' THEN 'delivered' WHEN NEW.action='dead' OR cycle_attempts>=(SELECT max_attempts FROM pa_delivery_control WHERE club_id=NEW.club_id) THEN 'dead' ELSE 'retry' END,
  next_at_ms=NEW.recorded_at_ms+min(3600000,(SELECT retry_ms FROM pa_delivery_control WHERE club_id=NEW.club_id)*(1 << min(cycle_attempts-1,9))),
  lease_id=NULL,lease_until_ms=NULL,reason=NEW.reason,receipt_id=NEW.receipt_id,last_command_id=NEW.request_id
 WHERE event_id=NEW.event_id AND NEW.action IN ('delivered','retry','dead','expire');
 UPDATE pa_delivery_jobs SET revision=revision+1,state='pending',cycle_attempts=0,next_at_ms=NEW.recorded_at_ms,
  reason=NEW.reason,last_command_id=NEW.request_id WHERE event_id=NEW.event_id AND NEW.action='redrive';
END;
-- New ownership and legacy claiming are mutually exclusive, including their race at cutover.
CREATE TRIGGER pa_delivery_blocks_legacy BEFORE UPDATE ON pa_outbox_delivery
 WHEN EXISTS(SELECT 1 FROM pa_delivery_jobs WHERE event_id=OLD.event_id)
 BEGIN SELECT RAISE(ABORT,'delivery_managed_event'); END;
CREATE TRIGGER pa_delivery_commands_no_update BEFORE UPDATE ON pa_delivery_commands BEGIN SELECT RAISE(ABORT,'delivery_immutable'); END;
CREATE TRIGGER pa_delivery_commands_no_delete BEFORE DELETE ON pa_delivery_commands BEGIN SELECT RAISE(ABORT,'delivery_immutable'); END;
CREATE TRIGGER pa_delivery_jobs_no_delete BEFORE DELETE ON pa_delivery_jobs BEGIN SELECT RAISE(ABORT,'delivery_immutable'); END;
CREATE TRIGGER pa_delivery_jobs_guard BEFORE UPDATE ON pa_delivery_jobs BEGIN
 SELECT CASE WHEN NEW.event_id IS NOT OLD.event_id OR NEW.club_id IS NOT OLD.club_id OR NEW.consumer_id IS NOT OLD.consumer_id
 OR NEW.revision<>OLD.revision+1 OR NEW.last_command_id=OLD.last_command_id OR NOT EXISTS(
  SELECT 1 FROM pa_delivery_commands WHERE request_id=NEW.last_command_id AND event_id=OLD.event_id
   AND expected_revision=OLD.revision AND action<>'enroll') THEN RAISE(ABORT,'delivery_conflict') END;
END;

CREATE TRIGGER pa_delivery_control_identity BEFORE UPDATE ON pa_delivery_control
 WHEN EXISTS(SELECT 1 FROM pa_delivery_jobs WHERE club_id=OLD.club_id) AND
 (NEW.club_id IS NOT OLD.club_id OR NEW.consumer_id IS NOT OLD.consumer_id OR NEW.max_attempts IS NOT OLD.max_attempts)
 BEGIN SELECT RAISE(ABORT,'delivery_conflict'); END;
