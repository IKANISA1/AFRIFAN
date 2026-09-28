-- Isolated staging candidate only. Apply to a NEW dedicated database.
-- This is not a Supabase migration and does not change any current writer.
PRAGMA foreign_keys = ON;
CREATE TABLE pa_settings (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 purpose TEXT NOT NULL CHECK(purpose='africlub-payment-allocation'),
 writer_mode TEXT NOT NULL DEFAULT 'disabled' CHECK(writer_mode IN ('disabled','isolated-staging')),
 source_reconciled INTEGER NOT NULL DEFAULT 0 CHECK(source_reconciled IN (0,1)),
 historical_claims_verified INTEGER NOT NULL DEFAULT 0 CHECK(historical_claims_verified IN (0,1)),
 evidence_ref TEXT NOT NULL DEFAULT ''
) STRICT;
INSERT INTO pa_settings(singleton,purpose) VALUES(1,'africlub-payment-allocation');
CREATE TABLE pa_clubs (
 club_id INTEGER PRIMARY KEY CHECK(club_id>0), club_slug TEXT NOT NULL UNIQUE,
 country TEXT NOT NULL CHECK(length(country)=2 AND country=upper(country)),
 currency TEXT NOT NULL CHECK(length(currency)=3 AND currency=upper(currency)),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)), revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
) STRICT;
CREATE TABLE pa_principals (
 principal_id TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0), expires_at_ms INTEGER NOT NULL CHECK(expires_at_ms>0)
) STRICT;
CREATE TABLE pa_grants (
 principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id), club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id),
 capability TEXT NOT NULL CHECK(capability IN ('ingest','allocate','read','outbox')),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)), revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 PRIMARY KEY(principal_id,club_id,capability)
) STRICT;
CREATE TABLE pa_subjects (
 user_id TEXT NOT NULL, club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)), revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 PRIMARY KEY(user_id,club_id)
) STRICT;
CREATE TABLE pa_receivers (
 receiver_id TEXT PRIMARY KEY, club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id), partner_id TEXT NOT NULL,
 provider TEXT NOT NULL, country TEXT NOT NULL, currency TEXT NOT NULL, recipient TEXT NOT NULL,
 active INTEGER NOT NULL DEFAULT 0 CHECK(active IN (0,1)), revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
) STRICT;
-- Authoritative pending-order snapshots must be imported/reconciled separately.
-- No public API can create a price, choose a recipient, or import a membership.
CREATE TABLE pa_orders (
 order_id TEXT PRIMARY KEY, source_intent_id TEXT NOT NULL UNIQUE,
 kind TEXT NOT NULL CHECK(kind IN ('membership','contribution')),
 user_id TEXT NOT NULL, club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id), partner_id TEXT NOT NULL,
 receiver_id TEXT NOT NULL REFERENCES pa_receivers(receiver_id),
 amount INTEGER NOT NULL CHECK(amount>0 AND amount<=2147483647), currency TEXT NOT NULL, country TEXT NOT NULL,
 provider TEXT NOT NULL, recipient TEXT NOT NULL,
 tier TEXT, initiative_id TEXT, checkout_reference TEXT NOT NULL,
 expires_at_ms INTEGER, created_at_ms INTEGER NOT NULL CHECK(created_at_ms>=0),
 state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','cancelled','fulfilled')),
 source_sha256 TEXT NOT NULL CHECK(length(source_sha256)=64),
 FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id),
 CHECK((kind='membership' AND tier IS NOT NULL AND initiative_id IS NULL AND expires_at_ms IS NOT NULL AND expires_at_ms>created_at_ms) OR
       (kind='contribution' AND tier IS NULL AND initiative_id IS NOT NULL AND currency='RWF' AND amount>=100 AND amount<=5000000))
) STRICT;
CREATE INDEX pa_orders_owner ON pa_orders(club_id,user_id,created_at_ms,order_id);
CREATE TABLE pa_memberships (
 membership_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, club_id INTEGER NOT NULL,
 partner_id TEXT NOT NULL, tier TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('active','suspended','expired')),
 payment_status TEXT NOT NULL CHECK(payment_status IN ('pending','verified')),
 points INTEGER NOT NULL DEFAULT 0 CHECK(points>=0),
 membership_number TEXT NOT NULL UNIQUE, member_code TEXT NOT NULL UNIQUE CHECK(length(member_code)=6 AND member_code NOT GLOB '*[^0-9]*'),
 renewed_at_ms INTEGER, expires_at_ms INTEGER,
 UNIQUE(user_id,club_id), FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id)
) STRICT;
CREATE TABLE pa_commands (
 command_id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id), capability TEXT NOT NULL CHECK(capability IN ('ingest','allocate')),
 request_id TEXT NOT NULL, request_sha256 TEXT NOT NULL CHECK(length(request_sha256)=64),
 principal_revision INTEGER NOT NULL, grant_revision INTEGER NOT NULL, club_revision INTEGER NOT NULL,
 recorded_at_ms INTEGER NOT NULL, UNIQUE(principal_id,club_id,request_id)
) STRICT;
CREATE TABLE pa_raw_evidence (
 raw_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, club_id INTEGER NOT NULL, country TEXT NOT NULL,
 provider TEXT NOT NULL, raw_sha256 TEXT NOT NULL CHECK(length(raw_sha256)=64),
 received_at_ms INTEGER NOT NULL CHECK(received_at_ms>=0), is_mock INTEGER NOT NULL CHECK(is_mock=0),
 FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id)
) STRICT;
CREATE TABLE pa_evidence (
 evidence_id TEXT PRIMARY KEY, raw_id TEXT NOT NULL UNIQUE REFERENCES pa_raw_evidence(raw_id),
 command_id TEXT NOT NULL UNIQUE REFERENCES pa_commands(command_id),
 user_id TEXT NOT NULL, club_id INTEGER NOT NULL, country TEXT NOT NULL,
 provider_reference TEXT NOT NULL CHECK(length(provider_reference)>0), amount INTEGER NOT NULL CHECK(amount>0 AND amount<=2147483647),
 currency TEXT NOT NULL, recipient TEXT NOT NULL,
 direction TEXT NOT NULL CHECK(direction='debit'), parse_status TEXT NOT NULL CHECK(parse_status='parsed'),
 is_mock INTEGER NOT NULL CHECK(is_mock=0), transaction_at_ms INTEGER NOT NULL CHECK(transaction_at_ms>=0),
 attestation_ref TEXT NOT NULL CHECK(length(attestation_ref)>0), source_sha256 TEXT NOT NULL CHECK(length(source_sha256)=64),
 FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id)
) STRICT;
-- One shared authority for all club allocations. Never partition this uniqueness by club.
CREATE TABLE pa_external_claims (
 provider TEXT NOT NULL, provider_reference TEXT NOT NULL,
 origin TEXT NOT NULL CHECK(origin IN ('historical','candidate')),
 claim_ref TEXT NOT NULL, source_sha256 TEXT NOT NULL CHECK(length(source_sha256)=64),
 PRIMARY KEY(provider,provider_reference)
) STRICT;
CREATE TABLE pa_allocations (
 allocation_id TEXT PRIMARY KEY, command_id TEXT NOT NULL UNIQUE REFERENCES pa_commands(command_id),
 order_id TEXT NOT NULL UNIQUE REFERENCES pa_orders(order_id), evidence_id TEXT NOT NULL UNIQUE REFERENCES pa_evidence(evidence_id),
 new_member_id TEXT NOT NULL, new_member_code TEXT NOT NULL CHECK(length(new_member_code)=6 AND new_member_code NOT GLOB '*[^0-9]*'),
 recorded_at_ms INTEGER NOT NULL
) STRICT;
CREATE TABLE pa_ledger (
 allocation_id TEXT PRIMARY KEY REFERENCES pa_allocations(allocation_id), order_id TEXT NOT NULL UNIQUE,
 evidence_id TEXT NOT NULL UNIQUE, user_id TEXT NOT NULL, club_id INTEGER NOT NULL,
 entry_type TEXT NOT NULL CHECK(entry_type='debit'), ledger_scope TEXT NOT NULL CHECK(ledger_scope IN ('subscription','partner')),
 amount INTEGER NOT NULL CHECK(amount>0), currency TEXT NOT NULL,
 provider TEXT NOT NULL, provider_reference TEXT NOT NULL, recipient TEXT NOT NULL,
 business_target_fulfilled INTEGER NOT NULL CHECK(business_target_fulfilled IN (0,1)),
 recorded_at_ms INTEGER NOT NULL, UNIQUE(provider,provider_reference)
) STRICT;
CREATE INDEX pa_ledger_owner ON pa_ledger(club_id,user_id,recorded_at_ms DESC,allocation_id DESC);
CREATE TABLE pa_receipts (
 allocation_id TEXT PRIMARY KEY REFERENCES pa_allocations(allocation_id),
 receipt_json TEXT NOT NULL CHECK(json_valid(receipt_json))
) STRICT;
CREATE TABLE pa_outbox (
 event_id TEXT PRIMARY KEY, allocation_id TEXT NOT NULL UNIQUE REFERENCES pa_allocations(allocation_id),
 club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id), event_type TEXT NOT NULL CHECK(event_type='payment.evidence_allocated'),
 payload_json TEXT NOT NULL CHECK(json_valid(payload_json)), recorded_at_ms INTEGER NOT NULL
) STRICT;
CREATE TABLE pa_outbox_delivery (
 event_id TEXT PRIMARY KEY REFERENCES pa_outbox(event_id), club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id),
 state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','leased','delivered')),
 lease_id TEXT, lease_principal TEXT REFERENCES pa_principals(principal_id), lease_until_ms INTEGER,
 attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts>=0), acknowledged_lease TEXT, delivered_at_ms INTEGER,
 CHECK((state='pending' AND lease_id IS NULL AND lease_until_ms IS NULL AND acknowledged_lease IS NULL AND delivered_at_ms IS NULL) OR
       (state='leased' AND lease_id IS NOT NULL AND lease_until_ms IS NOT NULL AND lease_principal IS NOT NULL AND acknowledged_lease IS NULL AND delivered_at_ms IS NULL) OR
       (state='delivered' AND lease_id IS NULL AND lease_until_ms IS NULL AND acknowledged_lease IS NOT NULL AND delivered_at_ms IS NOT NULL))
) STRICT;
CREATE INDEX pa_outbox_due ON pa_outbox_delivery(club_id,state,lease_until_ms,event_id);

CREATE TRIGGER pa_command_authorized BEFORE INSERT ON pa_commands BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_principals p JOIN pa_grants g ON g.principal_id=p.principal_id
 JOIN pa_clubs c ON c.club_id=g.club_id CROSS JOIN pa_settings s
 WHERE p.principal_id=NEW.principal_id AND g.club_id=NEW.club_id AND g.capability=NEW.capability
 AND p.enabled=1 AND p.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER) AND g.enabled=1 AND c.enabled=1
 AND s.singleton=1 AND s.purpose='africlub-payment-allocation' AND s.writer_mode='isolated-staging'
 AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0 AND p.revision=NEW.principal_revision AND g.revision=NEW.grant_revision AND c.revision=NEW.club_revision) THEN RAISE(ABORT,'pa_permission_denied') END;
 SELECT CASE WHEN NEW.recorded_at_ms!=CAST(unixepoch('subsec') * 1000 AS INTEGER) THEN RAISE(ABORT,'pa_invalid_time') END;
END;
CREATE TRIGGER pa_evidence_bound BEFORE INSERT ON pa_evidence BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_raw_evidence r JOIN pa_commands c ON c.command_id=NEW.command_id
 WHERE r.raw_id=NEW.raw_id AND r.user_id=NEW.user_id AND r.club_id=NEW.club_id AND r.country=NEW.country
 AND r.is_mock=0 AND c.capability='ingest' AND c.club_id=NEW.club_id
 AND EXISTS(SELECT 1 FROM pa_principals p JOIN pa_grants g ON g.principal_id=p.principal_id
 JOIN pa_clubs ac ON ac.club_id=g.club_id CROSS JOIN pa_settings s
 WHERE p.principal_id=c.principal_id AND g.club_id=c.club_id AND g.capability='ingest'
 AND p.enabled=1 AND p.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER) AND g.enabled=1 AND ac.enabled=1
 AND s.singleton=1 AND s.purpose='africlub-payment-allocation' AND s.writer_mode='isolated-staging'
 AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0 AND p.revision=c.principal_revision AND g.revision=c.grant_revision AND ac.revision=c.club_revision)) THEN RAISE(ABORT,'pa_invalid_evidence') END;
END;
CREATE TRIGGER pa_allocation_guard BEFORE INSERT ON pa_allocations BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_commands c WHERE c.command_id=NEW.command_id AND c.capability='allocate'
 AND EXISTS(SELECT 1 FROM pa_principals p JOIN pa_grants g ON g.principal_id=p.principal_id
 JOIN pa_clubs ac ON ac.club_id=g.club_id CROSS JOIN pa_settings s
 WHERE p.principal_id=c.principal_id AND g.club_id=c.club_id AND g.capability='allocate'
 AND p.enabled=1 AND p.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER) AND g.enabled=1 AND ac.enabled=1
 AND s.singleton=1 AND s.purpose='africlub-payment-allocation' AND s.writer_mode='isolated-staging'
 AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0 AND p.revision=c.principal_revision AND g.revision=c.grant_revision AND ac.revision=c.club_revision)) THEN RAISE(ABORT,'pa_permission_denied') END;
 SELECT CASE WHEN NEW.recorded_at_ms!=CAST(unixepoch('subsec') * 1000 AS INTEGER) THEN RAISE(ABORT,'pa_invalid_time') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_orders o JOIN pa_commands c ON c.command_id=NEW.command_id
 JOIN pa_subjects u ON u.user_id=o.user_id AND u.club_id=o.club_id
 JOIN pa_evidence e ON e.evidence_id=NEW.evidence_id JOIN pa_raw_evidence r ON r.raw_id=e.raw_id
 JOIN pa_receivers a ON a.receiver_id=o.receiver_id JOIN pa_clubs club ON club.club_id=o.club_id
 WHERE o.order_id=NEW.order_id AND o.club_id=c.club_id AND o.state='pending' AND u.enabled=1
 AND (o.expires_at_ms IS NULL OR o.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER))
 AND e.user_id=o.user_id AND r.user_id=o.user_id AND e.club_id=o.club_id AND r.club_id=o.club_id
 AND e.country=o.country AND r.country=o.country AND club.country=o.country AND club.currency=o.currency
 AND e.amount=o.amount AND e.currency=o.currency AND e.recipient=o.recipient
 AND r.provider=o.provider AND e.direction='debit' AND e.parse_status='parsed' AND e.is_mock=0 AND r.is_mock=0
 AND a.active=1 AND a.club_id=o.club_id AND a.partner_id=o.partner_id AND a.recipient=o.recipient
 AND a.provider=o.provider AND a.country=o.country AND a.currency=o.currency)
 THEN RAISE(ABORT,'pa_binding_conflict') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM pa_external_claims x JOIN pa_evidence e ON e.evidence_id=NEW.evidence_id
 JOIN pa_raw_evidence r ON r.raw_id=e.raw_id WHERE x.provider=r.provider AND x.provider_reference=e.provider_reference)
 THEN RAISE(ABORT,'pa_transaction_used') END;
END;

CREATE TRIGGER pa_allocation_effects AFTER INSERT ON pa_allocations BEGIN
 INSERT INTO pa_external_claims(provider,provider_reference,origin,claim_ref,source_sha256)
 SELECT r.provider,e.provider_reference,'candidate',NEW.allocation_id,e.source_sha256
 FROM pa_evidence e JOIN pa_raw_evidence r ON r.raw_id=e.raw_id WHERE e.evidence_id=NEW.evidence_id;
 INSERT INTO pa_memberships(membership_id,user_id,club_id,partner_id,tier,status,payment_status,points,membership_number,member_code,renewed_at_ms,expires_at_ms)
 SELECT NEW.new_member_id,o.user_id,o.club_id,o.partner_id,o.tier,'active','verified',0,
 'MEM-'||replace(NEW.new_member_id,'-',''),NEW.new_member_code,CAST(unixepoch('subsec') * 1000 AS INTEGER),CAST(round(unixepoch((CAST(unixepoch('subsec') * 1000 AS INTEGER))/1000.0,'unixepoch','+1 year','floor','subsec')*1000) AS INTEGER)
 FROM pa_orders o WHERE o.order_id=NEW.order_id AND o.kind='membership'
 ON CONFLICT(user_id,club_id) DO UPDATE SET
 tier=excluded.tier,payment_status='verified',
 status=CASE WHEN pa_memberships.status='suspended' THEN 'suspended' ELSE 'active' END,
 renewed_at_ms=CAST(unixepoch('subsec') * 1000 AS INTEGER),expires_at_ms=CAST(round(unixepoch((CASE WHEN pa_memberships.tier=excluded.tier THEN max(CAST(unixepoch('subsec') * 1000 AS INTEGER),coalesce(pa_memberships.expires_at_ms,CAST(unixepoch('subsec') * 1000 AS INTEGER))) ELSE CAST(unixepoch('subsec') * 1000 AS INTEGER) END)/1000.0,'unixepoch','+1 year','floor','subsec')*1000) AS INTEGER);
 SELECT CASE WHEN EXISTS(SELECT 1 FROM pa_orders o JOIN pa_memberships m ON m.user_id=o.user_id AND m.club_id=o.club_id
  WHERE o.order_id=NEW.order_id AND o.kind='membership' AND (m.expires_at_ms IS NULL OR m.expires_at_ms<=m.renewed_at_ms OR m.expires_at_ms>253402300799999))
  THEN RAISE(ABORT,'pa_invalid_membership_expiry') END;
 -- No contribution totals, point awards, or referrals are skipped: that business step is deliberately NOT performed.
 INSERT INTO pa_ledger(allocation_id,order_id,evidence_id,user_id,club_id,entry_type,ledger_scope,
 amount,currency,provider,provider_reference,recipient,business_target_fulfilled,recorded_at_ms)
 SELECT NEW.allocation_id,o.order_id,e.evidence_id,o.user_id,o.club_id,'debit',
 CASE WHEN o.kind='membership' THEN 'subscription' ELSE 'partner' END,
 o.amount,o.currency,o.provider,e.provider_reference,o.recipient,CASE WHEN o.kind='membership' THEN 1 ELSE 0 END,CAST(unixepoch('subsec') * 1000 AS INTEGER)
 FROM pa_orders o JOIN pa_evidence e ON e.evidence_id=NEW.evidence_id WHERE o.order_id=NEW.order_id;
 UPDATE pa_orders SET state='fulfilled' WHERE order_id=NEW.order_id;
 INSERT INTO pa_receipts(allocation_id,receipt_json)
 SELECT NEW.allocation_id,json_object('schemaVersion',1,'allocationId',NEW.allocation_id,'clubId',o.club_id,
 'orderId',o.order_id,'sourceIntentId',o.source_intent_id,'evidenceId',NEW.evidence_id,'userId',o.user_id,
 'kind',o.kind,'amount',o.amount,'currency',o.currency,'recordedAt',NEW.recorded_at_ms,
 'allocationPersisted',json('true'),'businessTargetFulfilled',json(CASE WHEN o.kind='membership' THEN 'true' ELSE 'false' END),
 'membership',CASE WHEN o.kind='membership' THEN json_object('id',m.membership_id,'tier',m.tier,'status',m.status,
 'paymentStatus',m.payment_status,'expiresAt',m.expires_at_ms) ELSE NULL END)
 FROM pa_orders o LEFT JOIN pa_memberships m ON m.user_id=o.user_id AND m.club_id=o.club_id WHERE o.order_id=NEW.order_id;
 INSERT INTO pa_outbox(event_id,allocation_id,club_id,event_type,payload_json,recorded_at_ms)
 SELECT NEW.allocation_id,NEW.allocation_id,o.club_id,'payment.evidence_allocated',r.receipt_json,NEW.recorded_at_ms
 FROM pa_receipts r JOIN pa_orders o ON o.order_id=NEW.order_id WHERE r.allocation_id=NEW.allocation_id;
 INSERT INTO pa_outbox_delivery(event_id,club_id) SELECT NEW.allocation_id,club_id FROM pa_orders WHERE order_id=NEW.order_id;
END;
CREATE TRIGGER pa_order_initial BEFORE INSERT ON pa_orders WHEN NEW.state<>'pending'
 BEGIN SELECT RAISE(ABORT,'pa_only_pending_import'); END;
CREATE TRIGGER pa_order_state BEFORE UPDATE ON pa_orders BEGIN
 SELECT CASE WHEN NEW.order_id IS NOT OLD.order_id OR NEW.source_intent_id IS NOT OLD.source_intent_id
 OR NEW.kind IS NOT OLD.kind OR NEW.user_id IS NOT OLD.user_id OR NEW.club_id IS NOT OLD.club_id
 OR NEW.partner_id IS NOT OLD.partner_id OR NEW.receiver_id IS NOT OLD.receiver_id OR NEW.amount IS NOT OLD.amount
 OR NEW.currency IS NOT OLD.currency OR NEW.country IS NOT OLD.country OR NEW.provider IS NOT OLD.provider
 OR NEW.recipient IS NOT OLD.recipient OR NEW.tier IS NOT OLD.tier OR NEW.initiative_id IS NOT OLD.initiative_id
 OR NEW.checkout_reference IS NOT OLD.checkout_reference OR NEW.expires_at_ms IS NOT OLD.expires_at_ms
 OR NEW.created_at_ms IS NOT OLD.created_at_ms OR NEW.source_sha256 IS NOT OLD.source_sha256
 OR OLD.state<>'pending' OR NEW.state NOT IN ('cancelled','fulfilled') THEN RAISE(ABORT,'pa_immutable_order') END;
 SELECT CASE WHEN NEW.state='fulfilled' AND NOT EXISTS(SELECT 1 FROM pa_allocations a JOIN pa_ledger l ON l.allocation_id=a.allocation_id
 WHERE a.order_id=NEW.order_id) THEN RAISE(ABORT,'pa_receipt_required') END;
END;
CREATE TRIGGER pa_outbox_transition BEFORE UPDATE ON pa_outbox_delivery BEGIN
 SELECT CASE WHEN NEW.event_id IS NOT OLD.event_id OR NEW.club_id IS NOT OLD.club_id OR OLD.state='delivered'
 THEN RAISE(ABORT,'pa_outbox_conflict') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_principals p JOIN pa_grants g ON g.principal_id=p.principal_id
 JOIN pa_clubs c ON c.club_id=g.club_id CROSS JOIN pa_settings s
 WHERE p.principal_id=NEW.lease_principal AND g.club_id=NEW.club_id AND g.capability='outbox'
 AND p.enabled=1 AND p.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER) AND g.enabled=1 AND c.enabled=1
 AND s.singleton=1 AND s.purpose='africlub-payment-allocation' AND s.writer_mode='isolated-staging'
 AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0)
 THEN RAISE(ABORT,'pa_permission_denied') END;
 SELECT CASE WHEN NOT (
   (NEW.state='leased' AND (OLD.state='pending' OR (OLD.state='leased' AND OLD.lease_until_ms<=CAST(unixepoch('subsec') * 1000 AS INTEGER)))
    AND NEW.attempts=OLD.attempts+1 AND NEW.lease_until_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER) AND NEW.lease_until_ms<=CAST(unixepoch('subsec') * 1000 AS INTEGER)+60000)
   OR (NEW.state='delivered' AND OLD.state='leased' AND OLD.lease_until_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER)
    AND NEW.lease_principal=OLD.lease_principal AND NEW.acknowledged_lease=OLD.lease_id AND NEW.attempts=OLD.attempts
    AND NEW.delivered_at_ms=CAST(unixepoch('subsec') * 1000 AS INTEGER))
 ) THEN RAISE(ABORT,'pa_outbox_conflict') END;
END;
CREATE TRIGGER pa_commands_update_blocked BEFORE UPDATE ON pa_commands BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_commands_delete_blocked BEFORE DELETE ON pa_commands BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_raw_evidence_update_blocked BEFORE UPDATE ON pa_raw_evidence BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_raw_evidence_delete_blocked BEFORE DELETE ON pa_raw_evidence BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_evidence_update_blocked BEFORE UPDATE ON pa_evidence BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_evidence_delete_blocked BEFORE DELETE ON pa_evidence BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_external_claims_update_blocked BEFORE UPDATE ON pa_external_claims BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_external_claims_delete_blocked BEFORE DELETE ON pa_external_claims BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_allocations_update_blocked BEFORE UPDATE ON pa_allocations BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_allocations_delete_blocked BEFORE DELETE ON pa_allocations BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_ledger_update_blocked BEFORE UPDATE ON pa_ledger BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_ledger_delete_blocked BEFORE DELETE ON pa_ledger BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_receipts_update_blocked BEFORE UPDATE ON pa_receipts BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_receipts_delete_blocked BEFORE DELETE ON pa_receipts BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_outbox_update_blocked BEFORE UPDATE ON pa_outbox BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_outbox_delete_blocked BEFORE DELETE ON pa_outbox BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_orders_delete_blocked BEFORE DELETE ON pa_orders BEGIN SELECT RAISE(ABORT,'pa_immutable_order'); END;
CREATE TRIGGER pa_outbox_delivery_delete_blocked BEFORE DELETE ON pa_outbox_delivery BEGIN SELECT RAISE(ABORT,'pa_immutable_evidence'); END;
CREATE TRIGGER pa_clubs_identity BEFORE UPDATE ON pa_clubs WHEN NEW.club_id IS NOT OLD.club_id OR NEW.club_slug IS NOT OLD.club_slug OR NEW.revision<OLD.revision BEGIN SELECT RAISE(ABORT,'pa_immutable_identity'); END;
CREATE TRIGGER pa_clubs_revision AFTER UPDATE ON pa_clubs WHEN NEW.revision=OLD.revision AND (NEW.country IS NOT OLD.country OR NEW.currency IS NOT OLD.currency OR NEW.enabled IS NOT OLD.enabled) BEGIN UPDATE pa_clubs SET revision=OLD.revision+1 WHERE club_id=NEW.club_id AND club_slug=NEW.club_slug; END;
CREATE TRIGGER pa_principals_identity BEFORE UPDATE ON pa_principals WHEN NEW.principal_id IS NOT OLD.principal_id OR NEW.revision<OLD.revision BEGIN SELECT RAISE(ABORT,'pa_immutable_identity'); END;
CREATE TRIGGER pa_principals_revision AFTER UPDATE ON pa_principals WHEN NEW.revision=OLD.revision AND (NEW.enabled IS NOT OLD.enabled OR NEW.expires_at_ms IS NOT OLD.expires_at_ms) BEGIN UPDATE pa_principals SET revision=OLD.revision+1 WHERE principal_id=NEW.principal_id; END;
CREATE TRIGGER pa_grants_identity BEFORE UPDATE ON pa_grants WHEN NEW.principal_id IS NOT OLD.principal_id OR NEW.club_id IS NOT OLD.club_id OR NEW.capability IS NOT OLD.capability OR NEW.revision<OLD.revision BEGIN SELECT RAISE(ABORT,'pa_immutable_identity'); END;
CREATE TRIGGER pa_grants_revision AFTER UPDATE ON pa_grants WHEN NEW.revision=OLD.revision AND (NEW.enabled IS NOT OLD.enabled) BEGIN UPDATE pa_grants SET revision=OLD.revision+1 WHERE principal_id=NEW.principal_id AND club_id=NEW.club_id AND capability=NEW.capability; END;
CREATE TRIGGER pa_subjects_identity BEFORE UPDATE ON pa_subjects WHEN NEW.user_id IS NOT OLD.user_id OR NEW.club_id IS NOT OLD.club_id OR NEW.revision<OLD.revision BEGIN SELECT RAISE(ABORT,'pa_immutable_identity'); END;
CREATE TRIGGER pa_subjects_revision AFTER UPDATE ON pa_subjects WHEN NEW.revision=OLD.revision AND (NEW.enabled IS NOT OLD.enabled) BEGIN UPDATE pa_subjects SET revision=OLD.revision+1 WHERE user_id=NEW.user_id AND club_id=NEW.club_id; END;
CREATE TRIGGER pa_receivers_identity BEFORE UPDATE ON pa_receivers WHEN NEW.receiver_id IS NOT OLD.receiver_id OR NEW.club_id IS NOT OLD.club_id OR NEW.partner_id IS NOT OLD.partner_id OR NEW.revision<OLD.revision BEGIN SELECT RAISE(ABORT,'pa_immutable_identity'); END;
CREATE TRIGGER pa_receivers_revision AFTER UPDATE ON pa_receivers WHEN NEW.revision=OLD.revision AND (NEW.provider IS NOT OLD.provider OR NEW.country IS NOT OLD.country OR NEW.currency IS NOT OLD.currency OR NEW.recipient IS NOT OLD.recipient OR NEW.active IS NOT OLD.active) BEGIN UPDATE pa_receivers SET revision=OLD.revision+1 WHERE receiver_id=NEW.receiver_id AND club_id=NEW.club_id AND partner_id=NEW.partner_id; END;
