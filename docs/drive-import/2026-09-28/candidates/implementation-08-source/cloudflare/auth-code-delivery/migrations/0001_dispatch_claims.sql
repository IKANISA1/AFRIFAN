-- Dedicated delivery evidence, not identity/member/financial storage.
-- No code, destination, provider body or token is stored here.
CREATE TABLE delivery_dispatches (
 challenge_id TEXT PRIMARY KEY,
 club_id INTEGER NOT NULL CHECK(club_id>0),
 request_commitment TEXT NOT NULL CHECK(length(request_commitment)=64),
 route_commitment TEXT NOT NULL CHECK(length(route_commitment)=64),
 state TEXT NOT NULL CHECK(state IN ('reserved','accepted','rejected','unknown')),
 provider_message_id TEXT UNIQUE,
 reason TEXT CHECK(reason IN ('provider_rejected','provider_unknown','provider_unreachable','provider_timeout',
  'invalid_provider_response','template_not_approved','provider_not_accepted','too_late')),
 created_at INTEGER NOT NULL,
 expires_at INTEGER NOT NULL CHECK(expires_at>created_at),
 completed_at INTEGER,
 CHECK((state='reserved' AND completed_at IS NULL AND provider_message_id IS NULL AND reason IS NULL) OR
       (state='accepted' AND completed_at IS NOT NULL AND provider_message_id IS NOT NULL AND reason IS NULL) OR
       (state IN ('rejected','unknown') AND completed_at IS NOT NULL AND provider_message_id IS NULL AND reason IS NOT NULL))
);
CREATE INDEX delivery_dispatches_state_time ON delivery_dispatches(state,created_at);
CREATE TRIGGER delivery_claim_immutable BEFORE UPDATE ON delivery_dispatches
WHEN NEW.challenge_id<>OLD.challenge_id OR NEW.club_id<>OLD.club_id OR
 NEW.request_commitment<>OLD.request_commitment OR NEW.route_commitment<>OLD.route_commitment OR
 NEW.created_at<>OLD.created_at OR NEW.expires_at<>OLD.expires_at OR OLD.state<>'reserved'
BEGIN SELECT RAISE(ABORT,'immutable dispatch'); END;
CREATE TRIGGER delivery_claim_no_delete BEFORE DELETE ON delivery_dispatches
BEGIN SELECT RAISE(ABORT,'retain deduplication evidence'); END;
