-- Case metadata only. Apply to a NEW isolated case database, never the allocation database.
-- No payment, membership, reward, provider, handoff or refund tables are created or changed.
PRAGMA foreign_keys = ON;
CREATE TABLE px_settings (
 id INTEGER PRIMARY KEY CHECK(id=1), enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN(0,1)),
 account_id TEXT NOT NULL DEFAULT '' CHECK(length(account_id) IN(0,32)),
 audience TEXT NOT NULL DEFAULT '' CHECK(length(audience) IN(0,64)),
 environment TEXT NOT NULL DEFAULT 'disabled' CHECK(environment IN('disabled','isolated-staging','production'))
) STRICT;
INSERT INTO px_settings(id) VALUES(1);
CREATE TABLE px_clubs (club_id INTEGER PRIMARY KEY CHECK(club_id>0), enabled INTEGER NOT NULL CHECK(enabled IN(0,1))) STRICT;
CREATE TABLE px_operators (
 subject TEXT PRIMARY KEY, account_id TEXT NOT NULL, audience TEXT NOT NULL,
 enabled INTEGER NOT NULL CHECK(enabled IN(0,1)), expires_at_ms INTEGER NOT NULL
) STRICT;
CREATE TABLE px_grants (
 subject TEXT NOT NULL REFERENCES px_operators(subject), club_id INTEGER NOT NULL REFERENCES px_clubs(club_id),
 role TEXT NOT NULL CHECK(role IN('reader','maker','checker')), enabled INTEGER NOT NULL CHECK(enabled IN(0,1)),
 PRIMARY KEY(subject,club_id,role)
) STRICT;
CREATE TABLE px_cases (
 case_id TEXT PRIMARY KEY, club_id INTEGER NOT NULL REFERENCES px_clubs(club_id),
 category TEXT NOT NULL CHECK(category IN('late','partial','duplicate','ambiguous','missing_reference','cancelled_order','refund_request')),
 order_id TEXT, evidence_id TEXT, state TEXT NOT NULL CHECK(state IN('open','investigating','awaiting_review','reviewed','closed')),
 revision INTEGER NOT NULL CHECK(revision>0), head_event_id TEXT NOT NULL UNIQUE,
 disposition TEXT, proposer_subject TEXT, proposal_digest TEXT, reviewer_subject TEXT, review_event_id TEXT,
 created_at_ms INTEGER NOT NULL, updated_at_ms INTEGER NOT NULL,
 CHECK(order_id IS NOT NULL OR evidence_id IS NOT NULL)
) STRICT;
CREATE INDEX px_cases_club_page ON px_cases(club_id,case_id);
CREATE INDEX px_cases_club_state_page ON px_cases(club_id,state,case_id);
CREATE TABLE px_events (
 event_id TEXT PRIMARY KEY, case_id TEXT NOT NULL, club_id INTEGER NOT NULL REFERENCES px_clubs(club_id),
 operation_id TEXT NOT NULL, request_hash TEXT NOT NULL CHECK(length(request_hash)=64),
 expected_revision INTEGER NOT NULL CHECK(expected_revision>=0), actor_subject TEXT NOT NULL REFERENCES px_operators(subject),
 account_id TEXT NOT NULL, audience TEXT NOT NULL, environment TEXT NOT NULL CHECK(environment IN('isolated-staging','production')),
 action TEXT NOT NULL CHECK(action IN('open','triage','propose','approve','reject','close','reopen')),
 reason_code TEXT NOT NULL CHECK(reason_code IN('support_request','evidence_received','needs_investigation','review_complete','insufficient_evidence','external_referral','new_evidence')),
 evidence_digest TEXT CHECK(evidence_digest IS NULL OR length(evidence_digest)=64),
 category TEXT, order_id TEXT, evidence_id TEXT, disposition TEXT,
 created_at_ms INTEGER NOT NULL DEFAULT (CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)),
 UNIQUE(case_id,expected_revision), UNIQUE(club_id,actor_subject,operation_id),
 CHECK(disposition IS NULL OR disposition IN('no_financial_change','refer_reconciliation','refer_refund_review'))
) STRICT;
CREATE INDEX px_events_case_history ON px_events(club_id,case_id,expected_revision);
CREATE TRIGGER px_events_guard BEFORE INSERT ON px_events BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM px_settings s JOIN px_clubs c ON c.club_id=NEW.club_id
  WHERE s.id=1 AND s.enabled=1 AND s.environment=NEW.environment AND c.enabled=1
    AND s.account_id=NEW.account_id AND s.audience=NEW.audience)
  THEN RAISE(ABORT,'px_disabled') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM px_operators o JOIN px_grants g ON g.subject=o.subject
  WHERE o.subject=NEW.actor_subject AND o.enabled=1 AND o.account_id=NEW.account_id AND o.audience=NEW.audience
   AND o.expires_at_ms>CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)
   AND g.club_id=NEW.club_id AND g.enabled=1 AND g.role=CASE WHEN NEW.action IN('approve','reject') THEN 'checker' ELSE 'maker' END)
  THEN RAISE(ABORT,'px_forbidden') END;
 SELECT CASE WHEN NEW.action='open' AND (NEW.expected_revision<>0 OR EXISTS(SELECT 1 FROM px_cases WHERE case_id=NEW.case_id))
  THEN RAISE(ABORT,'px_case_conflict') END;
 SELECT CASE WHEN NEW.action<>'open' AND NOT EXISTS(SELECT 1 FROM px_cases
  WHERE case_id=NEW.case_id AND club_id=NEW.club_id AND revision=NEW.expected_revision)
  THEN RAISE(ABORT,'px_stale_revision') END;
 SELECT CASE WHEN NEW.action<>'open' AND NOT EXISTS(SELECT 1 FROM px_cases c WHERE c.case_id=NEW.case_id AND c.club_id=NEW.club_id AND (
    (NEW.action='triage' AND c.state='open') OR (NEW.action='propose' AND c.state IN('open','investigating')) OR
    (NEW.action IN('approve','reject') AND c.state='awaiting_review') OR
    (NEW.action='close' AND c.state='reviewed' AND c.review_event_id IS NOT NULL) OR (NEW.action='reopen' AND c.state='closed')))
  THEN RAISE(ABORT,'px_invalid_transition') END;
 SELECT CASE WHEN NEW.action IN('approve','reject') AND EXISTS(SELECT 1 FROM px_cases WHERE case_id=NEW.case_id AND proposer_subject=NEW.actor_subject)
  THEN RAISE(ABORT,'px_self_review') END;
 SELECT CASE WHEN (NEW.action='open' AND (NEW.category IS NULL OR (NEW.order_id IS NULL AND NEW.evidence_id IS NULL)))
  OR (NEW.action<>'open' AND (NEW.category IS NOT NULL OR NEW.order_id IS NOT NULL OR NEW.evidence_id IS NOT NULL))
  OR (NEW.action='propose' AND (NEW.disposition IS NULL OR NEW.evidence_digest IS NULL))
  OR (NEW.action<>'propose' AND NEW.disposition IS NOT NULL)
  OR (NEW.action='close' AND NEW.evidence_digest IS NULL)
  THEN RAISE(ABORT,'px_invalid_event') END;
END;
CREATE TRIGGER px_events_no_update BEFORE UPDATE ON px_events BEGIN SELECT RAISE(ABORT,'px_immutable'); END;
CREATE TRIGGER px_events_no_delete BEFORE DELETE ON px_events BEGIN SELECT RAISE(ABORT,'px_immutable'); END;
CREATE TRIGGER px_cases_no_delete BEFORE DELETE ON px_cases BEGIN SELECT RAISE(ABORT,'px_immutable'); END;
CREATE TRIGGER px_cases_insert_guard BEFORE INSERT ON px_cases BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM px_events e WHERE e.event_id=NEW.head_event_id AND e.action='open'
  AND e.case_id=NEW.case_id AND e.club_id=NEW.club_id AND NEW.revision=1 AND NEW.state='open'
  AND e.category=NEW.category AND e.order_id IS NEW.order_id AND e.evidence_id IS NEW.evidence_id
  AND NEW.disposition IS NULL AND NEW.proposer_subject IS NULL AND NEW.proposal_digest IS NULL
  AND NEW.reviewer_subject IS NULL AND NEW.review_event_id IS NULL
  AND e.created_at_ms=NEW.created_at_ms AND e.created_at_ms=NEW.updated_at_ms)
  THEN RAISE(ABORT,'px_immutable') END;
END;

CREATE TRIGGER px_cases_update_guard BEFORE UPDATE ON px_cases BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM px_events e WHERE e.event_id=NEW.head_event_id
  AND e.action<>'open' AND e.case_id=OLD.case_id AND e.club_id=OLD.club_id AND e.expected_revision=OLD.revision
  AND NEW.case_id=OLD.case_id AND NEW.club_id=OLD.club_id AND NEW.category=OLD.category
  AND NEW.order_id IS OLD.order_id AND NEW.evidence_id IS OLD.evidence_id AND NEW.created_at_ms=OLD.created_at_ms
  AND NEW.revision=OLD.revision+1 AND NEW.updated_at_ms=e.created_at_ms AND
  NEW.state IS (CASE e.action WHEN 'open' THEN 'open' WHEN 'triage' THEN 'investigating' WHEN 'propose' THEN 'awaiting_review' WHEN 'approve' THEN 'reviewed' WHEN 'reject' THEN 'investigating' WHEN 'close' THEN 'closed' WHEN 'reopen' THEN 'investigating' END) AND
  NEW.disposition IS (CASE WHEN e.action='propose' THEN e.disposition WHEN e.action IN ('reject','reopen') THEN NULL ELSE OLD.disposition END) AND
  NEW.proposer_subject IS (CASE WHEN e.action='propose' THEN e.actor_subject WHEN e.action IN ('reject','reopen') THEN NULL ELSE OLD.proposer_subject END) AND
  NEW.proposal_digest IS (CASE WHEN e.action='propose' THEN e.evidence_digest WHEN e.action IN ('reject','reopen') THEN NULL ELSE OLD.proposal_digest END) AND
  NEW.reviewer_subject IS (CASE WHEN e.action='approve' THEN e.actor_subject WHEN e.action IN ('propose','reject','reopen') THEN NULL ELSE OLD.reviewer_subject END) AND
  NEW.review_event_id IS (CASE WHEN e.action='approve' THEN e.event_id WHEN e.action IN ('propose','reject','reopen') THEN NULL ELSE OLD.review_event_id END)) THEN RAISE(ABORT,'px_immutable') END;
END;
CREATE TRIGGER px_events_apply AFTER INSERT ON px_events BEGIN
 INSERT INTO px_cases(case_id,club_id,category,order_id,evidence_id,state,revision,head_event_id,created_at_ms,updated_at_ms)
  SELECT NEW.case_id,NEW.club_id,NEW.category,NEW.order_id,NEW.evidence_id,'open',1,NEW.event_id,NEW.created_at_ms,NEW.created_at_ms
  WHERE NEW.action='open';
 UPDATE px_cases SET
 state=CASE NEW.action WHEN 'open' THEN 'open' WHEN 'triage' THEN 'investigating' WHEN 'propose' THEN 'awaiting_review' WHEN 'approve' THEN 'reviewed' WHEN 'reject' THEN 'investigating' WHEN 'close' THEN 'closed' WHEN 'reopen' THEN 'investigating' END,
 disposition=CASE WHEN NEW.action='propose' THEN NEW.disposition WHEN NEW.action IN ('reject','reopen') THEN NULL ELSE px_cases.disposition END,
 proposer_subject=CASE WHEN NEW.action='propose' THEN NEW.actor_subject WHEN NEW.action IN ('reject','reopen') THEN NULL ELSE px_cases.proposer_subject END,
 proposal_digest=CASE WHEN NEW.action='propose' THEN NEW.evidence_digest WHEN NEW.action IN ('reject','reopen') THEN NULL ELSE px_cases.proposal_digest END,
 reviewer_subject=CASE WHEN NEW.action='approve' THEN NEW.actor_subject WHEN NEW.action IN ('propose','reject','reopen') THEN NULL ELSE px_cases.reviewer_subject END,
 review_event_id=CASE WHEN NEW.action='approve' THEN NEW.event_id WHEN NEW.action IN ('propose','reject','reopen') THEN NULL ELSE px_cases.review_event_id END,
 revision=NEW.expected_revision+1, head_event_id=NEW.event_id, updated_at_ms=NEW.created_at_ms
 WHERE NEW.action<>'open' AND case_id=NEW.case_id AND club_id=NEW.club_id;
END;
