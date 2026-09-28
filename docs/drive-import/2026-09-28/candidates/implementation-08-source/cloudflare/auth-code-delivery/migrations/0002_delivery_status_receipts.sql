-- Forward-only companion evidence; do not alter existing dispatch or identity records.
-- A binding is created BEFORE the provider call and intentionally can precede a dispatch row.
CREATE TABLE delivery_receipt_bindings (
  challenge_id TEXT PRIMARY KEY,
  club_id INTEGER NOT NULL CHECK(club_id > 0),
  business_account_id TEXT NOT NULL,
  phone_number_id TEXT NOT NULL,
  recipient_commitment TEXT NOT NULL CHECK(length(recipient_commitment) = 64),
  binding_commitment TEXT NOT NULL CHECK(length(binding_commitment) = 64),
  key_version TEXT NOT NULL CHECK(key_version = '1'),
  created_at INTEGER NOT NULL
);
CREATE TRIGGER receipt_binding_no_update BEFORE UPDATE ON delivery_receipt_bindings
BEGIN SELECT RAISE(ABORT, 'immutable receipt binding'); END;
CREATE TRIGGER receipt_binding_no_delete BEFORE DELETE ON delivery_receipt_bindings
BEGIN SELECT RAISE(ABORT, 'retain receipt binding'); END;
CREATE TABLE delivery_status_events (
  event_id TEXT PRIMARY KEY CHECK(length(event_id) = 64),
  business_account_id TEXT NOT NULL,
  phone_number_id TEXT NOT NULL,
  provider_message_id TEXT NOT NULL,
  recipient_commitment TEXT NOT NULL CHECK(length(recipient_commitment) = 64),
  key_version TEXT NOT NULL CHECK(key_version = '1'),
  status TEXT NOT NULL CHECK(status IN ('sent','delivered','read','failed','deleted')),
  provider_at INTEGER NOT NULL CHECK(provider_at >= 0),
  received_at INTEGER NOT NULL CHECK(received_at >= 0),
  error_codes_json TEXT NOT NULL CHECK(json_valid(error_codes_json) AND json_type(error_codes_json) = 'array')
);
CREATE INDEX delivery_status_by_message ON delivery_status_events(provider_message_id, received_at, event_id);
CREATE INDEX delivery_status_received ON delivery_status_events(received_at, event_id);
CREATE TRIGGER status_event_no_update BEFORE UPDATE ON delivery_status_events
BEGIN SELECT RAISE(ABORT, 'immutable status observation'); END;
CREATE TRIGGER status_event_no_delete BEFORE DELETE ON delivery_status_events
BEGIN SELECT RAISE(ABORT, 'retained status observation'); END;
CREATE TABLE delivery_status_links (
  event_id TEXT PRIMARY KEY REFERENCES delivery_status_events(event_id),
  challenge_id TEXT NOT NULL REFERENCES delivery_receipt_bindings(challenge_id),
  club_id INTEGER NOT NULL CHECK(club_id > 0),
  matched_at INTEGER NOT NULL
);
CREATE INDEX delivery_status_links_challenge ON delivery_status_links(challenge_id, event_id);
-- Defense in depth: a signed provider callback cannot be linked on phone alone.
CREATE TRIGGER status_link_guard BEFORE INSERT ON delivery_status_links
WHEN NOT EXISTS (
  SELECT 1 FROM delivery_status_events e
  JOIN delivery_dispatches d ON d.provider_message_id=e.provider_message_id AND d.state='accepted'
  JOIN delivery_receipt_bindings b ON b.challenge_id=d.challenge_id
  WHERE e.event_id=NEW.event_id AND d.challenge_id=NEW.challenge_id
    AND d.club_id=NEW.club_id AND b.club_id=d.club_id
    AND e.business_account_id=b.business_account_id AND e.phone_number_id=b.phone_number_id
    AND e.recipient_commitment=b.recipient_commitment AND e.key_version=b.key_version
    AND e.provider_at>=d.created_at-300000 AND e.provider_at<=d.created_at+691200000
)
BEGIN SELECT RAISE(ABORT, 'receipt correlation mismatch'); END;
CREATE TRIGGER status_link_no_update BEFORE UPDATE ON delivery_status_links
BEGIN SELECT RAISE(ABORT, 'immutable status link'); END;
CREATE TRIGGER status_link_no_delete BEFORE DELETE ON delivery_status_links
BEGIN SELECT RAISE(ABORT, 'retained status link'); END;
