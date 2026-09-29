-- Forward-only companion schema in the EXISTING isolated payment-allocation DB.
-- No paid membership, receipt, claim or existing migration is changed by installation.
PRAGMA foreign_keys=ON;
CREATE TABLE pa_checkout_settings (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 catalog_reconciled INTEGER NOT NULL DEFAULT 0 CHECK(catalog_reconciled IN (0,1)),
 evidence_ref TEXT NOT NULL DEFAULT '', revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
) STRICT;
INSERT INTO pa_checkout_settings(singleton) VALUES(1);
CREATE TABLE pa_checkout_grants (
 principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id), club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id),
 capability TEXT NOT NULL CHECK(capability IN ('prepare','read')),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)), revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 PRIMARY KEY(principal_id,club_id,capability)
) STRICT;
CREATE TABLE pa_checkout_clubs (
 club_id INTEGER PRIMARY KEY REFERENCES pa_clubs(club_id),
 ussd_template TEXT NOT NULL CHECK(length(ussd_template) BETWEEN 1 AND 128),
 active INTEGER NOT NULL DEFAULT 0 CHECK(active IN (0,1)), revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 source_sha256 TEXT NOT NULL CHECK(length(source_sha256)=64)
) STRICT;
CREATE TABLE pa_checkout_packages (
 package_id TEXT PRIMARY KEY, club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id), partner_id TEXT NOT NULL,
 tier TEXT NOT NULL CHECK(length(tier) BETWEEN 1 AND 32 AND tier NOT GLOB '*[^a-z0-9_-]*'),
 annual_price INTEGER CHECK(annual_price IS NULL OR annual_price BETWEEN 0 AND 2147483647),
 price INTEGER CHECK(price IS NULL OR price BETWEEN 0 AND 2147483647), sort_order INTEGER NOT NULL,
 active INTEGER NOT NULL DEFAULT 0 CHECK(active IN (0,1)), revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 source_sha256 TEXT NOT NULL CHECK(length(source_sha256)=64)
) STRICT;
CREATE INDEX pa_checkout_packages_choice ON pa_checkout_packages(club_id,tier,active,sort_order,package_id);
CREATE TABLE pa_checkout_routes (
 route_id TEXT PRIMARY KEY, club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id), partner_id TEXT NOT NULL,
 provider TEXT NOT NULL CHECK(length(provider) BETWEEN 1 AND 64 AND provider NOT GLOB '*[^a-z0-9_-]*'),
 country TEXT NOT NULL CHECK(length(country)=2 AND country NOT GLOB '*[^A-Z]*'),
 recipient TEXT NOT NULL CHECK(length(recipient) BETWEEN 3 AND 32 AND recipient NOT GLOB '*[^0-9]*'),
 active INTEGER NOT NULL DEFAULT 0 CHECK(active IN (0,1)), revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 source_sha256 TEXT NOT NULL CHECK(length(source_sha256)=64)
) STRICT;
CREATE INDEX pa_checkout_routes_choice ON pa_checkout_routes(club_id,partner_id,active,route_id);
CREATE INDEX pa_checkout_receiver_lookup ON pa_receivers(partner_id,recipient,active,club_id,receiver_id);
CREATE INDEX pa_checkout_pending_membership ON pa_orders(club_id,user_id,kind,state,created_at_ms DESC,order_id DESC);
CREATE VIEW pa_checkout_authorizations AS
 SELECT p.principal_id,g.club_id,g.capability,u.user_id,p.revision principal_revision,g.revision grant_revision,
 c.revision club_revision,u.revision subject_revision,x.revision control_revision
 FROM pa_principals p JOIN pa_checkout_grants g ON g.principal_id=p.principal_id
 JOIN pa_clubs c ON c.club_id=g.club_id JOIN pa_subjects u ON u.club_id=c.club_id
 CROSS JOIN pa_settings s CROSS JOIN pa_checkout_settings x
 WHERE p.enabled=1 AND p.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER) AND g.enabled=1 AND c.enabled=1 AND u.enabled=1
 AND s.singleton=1 AND s.purpose='africlub-payment-allocation' AND s.writer_mode='isolated-staging'
 AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0
 AND x.singleton=1 AND x.enabled=1 AND x.catalog_reconciled=1 AND length(x.evidence_ref)>0;
-- Source selection: first active package by sort/id, then first active route with a
-- receiver by id. A bad first choice fails; it does not fall back to a different price.
CREATE VIEW pa_checkout_offers AS
 SELECT p.package_id,p.club_id,p.partner_id,p.tier,p.revision package_revision,
 coalesce(nullif(p.annual_price,0),p.price,0) amount,c.currency,c.country,
 r.route_id,r.revision route_revision,r.provider,r.recipient,a.receiver_id,a.revision receiver_revision,
 cc.revision checkout_club_revision,c.revision club_revision,
 replace(replace(replace(replace(cc.ussd_template,'{amount}',
 CAST(coalesce(nullif(p.annual_price,0),p.price,0) AS TEXT)),
 '{momo}',r.recipient),'{recipient}',r.recipient),'{code}',r.recipient) ussd_code,
 cc.ussd_template
 FROM pa_checkout_packages p JOIN pa_clubs c ON c.club_id=p.club_id
 JOIN pa_checkout_clubs cc ON cc.club_id=p.club_id
 JOIN pa_checkout_routes r ON r.club_id=p.club_id AND r.partner_id=p.partner_id
 JOIN pa_receivers a ON a.partner_id=r.partner_id AND a.recipient=r.recipient AND a.active=1
 WHERE p.active=1 AND c.enabled=1 AND cc.active=1 AND r.active=1
 AND p.package_id=(SELECT p2.package_id FROM pa_checkout_packages p2
  WHERE p2.club_id=p.club_id AND p2.tier=p.tier AND p2.active=1 ORDER BY p2.sort_order,p2.package_id LIMIT 1)
 AND r.route_id=(SELECT r2.route_id FROM pa_checkout_routes r2 WHERE r2.club_id=p.club_id
  AND r2.partner_id=p.partner_id AND r2.active=1 AND EXISTS(SELECT 1 FROM pa_receivers a2
   WHERE a2.partner_id=r2.partner_id AND a2.recipient=r2.recipient AND a2.active=1)
  ORDER BY r2.route_id LIMIT 1)
 AND (SELECT count(*) FROM pa_receivers a3 WHERE a3.partner_id=r.partner_id AND a3.recipient=r.recipient AND a3.active=1)=1
 AND a.club_id=p.club_id AND a.provider=r.provider AND a.country=c.country AND r.country=c.country AND a.currency=c.currency;
CREATE TABLE pa_checkout_requests (
 command_id TEXT PRIMARY KEY,principal_id TEXT NOT NULL REFERENCES pa_principals(principal_id),
 club_id INTEGER NOT NULL REFERENCES pa_clubs(club_id),user_id TEXT NOT NULL,request_id TEXT NOT NULL,
 request_sha256 TEXT NOT NULL CHECK(length(request_sha256)=64),tier TEXT NOT NULL,
 principal_revision INTEGER NOT NULL,grant_revision INTEGER NOT NULL,club_revision INTEGER NOT NULL,
 subject_revision INTEGER NOT NULL,control_revision INTEGER NOT NULL,
 package_id TEXT NOT NULL REFERENCES pa_checkout_packages(package_id),package_revision INTEGER NOT NULL,
 route_id TEXT NOT NULL REFERENCES pa_checkout_routes(route_id),route_revision INTEGER NOT NULL,
 receiver_id TEXT NOT NULL REFERENCES pa_receivers(receiver_id),receiver_revision INTEGER NOT NULL,
 checkout_club_revision INTEGER NOT NULL,offer_sha256 TEXT NOT NULL CHECK(length(offer_sha256)=64),
 proposed_order_id TEXT NOT NULL UNIQUE,proposed_intent_id TEXT NOT NULL UNIQUE,recorded_at_ms INTEGER NOT NULL,
 FOREIGN KEY(user_id,club_id) REFERENCES pa_subjects(user_id,club_id),
 UNIQUE(principal_id,club_id,user_id,request_id)
) STRICT;
CREATE INDEX pa_checkout_request_budget ON pa_checkout_requests(club_id,user_id,recorded_at_ms);
CREATE TABLE pa_checkout_order_details (
 order_id TEXT PRIMARY KEY REFERENCES pa_orders(order_id),package_id TEXT NOT NULL REFERENCES pa_checkout_packages(package_id),
 route_id TEXT NOT NULL REFERENCES pa_checkout_routes(route_id),ussd_code TEXT NOT NULL,
 created_command_id TEXT NOT NULL UNIQUE REFERENCES pa_checkout_requests(command_id),
 snapshot_json TEXT NOT NULL CHECK(json_valid(snapshot_json))
) STRICT;
CREATE TABLE pa_checkout_results (
 command_id TEXT PRIMARY KEY REFERENCES pa_checkout_requests(command_id),
 order_id TEXT NOT NULL REFERENCES pa_checkout_order_details(order_id),reused INTEGER NOT NULL CHECK(reused IN (0,1))
) STRICT;
CREATE TABLE pa_checkout_audit (
 command_id TEXT PRIMARY KEY REFERENCES pa_checkout_requests(command_id),order_id TEXT NOT NULL REFERENCES pa_orders(order_id),
 event_type TEXT NOT NULL CHECK(event_type='membership.checkout_prepared'),recorded_at_ms INTEGER NOT NULL
) STRICT;
CREATE VIEW pa_checkout_reusable AS
 SELECT o.order_id,o.club_id,o.user_id,o.tier,d.package_id,o.created_at_ms
 FROM pa_orders o JOIN pa_checkout_order_details d ON d.order_id=o.order_id
 JOIN pa_checkout_offers v ON v.package_id=d.package_id AND v.route_id=d.route_id
 WHERE o.kind='membership' AND o.state='pending' AND o.expires_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER)
 AND o.club_id=v.club_id AND o.partner_id=v.partner_id AND o.receiver_id=v.receiver_id
 AND o.amount=v.amount AND o.currency=v.currency AND o.country=v.country AND o.provider=v.provider
 AND o.recipient=v.recipient AND o.tier=v.tier AND d.ussd_code=v.ussd_code;
CREATE TRIGGER pa_checkout_request_guard BEFORE INSERT ON pa_checkout_requests BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_checkout_authorizations z
 WHERE z.principal_id=NEW.principal_id AND z.club_id=NEW.club_id AND z.user_id=NEW.user_id AND z.capability='prepare'
 AND z.principal_revision=NEW.principal_revision AND z.grant_revision=NEW.grant_revision
 AND z.club_revision=NEW.club_revision AND z.subject_revision=NEW.subject_revision AND z.control_revision=NEW.control_revision)
 THEN RAISE(ABORT,'checkout_permission_denied') END;
 SELECT CASE WHEN NEW.recorded_at_ms!=CAST(unixepoch('subsec') * 1000 AS INTEGER) THEN RAISE(ABORT,'checkout_invalid_time') END;
 SELECT CASE WHEN (SELECT count(*) FROM pa_checkout_requests q
  WHERE q.club_id=NEW.club_id AND q.user_id=NEW.user_id AND q.recorded_at_ms>CAST(unixepoch('subsec') * 1000 AS INTEGER)-900000)>=20
 THEN RAISE(ABORT,'checkout_rate_limited') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_checkout_offers v
 WHERE v.club_id=NEW.club_id AND v.tier=NEW.tier AND v.package_id=NEW.package_id AND v.package_revision=NEW.package_revision
 AND v.route_id=NEW.route_id AND v.route_revision=NEW.route_revision AND v.receiver_id=NEW.receiver_id
 AND v.receiver_revision=NEW.receiver_revision AND v.checkout_club_revision=NEW.checkout_club_revision AND v.club_revision=NEW.club_revision
 AND v.amount BETWEEN 1 AND 2147483647 AND length(v.ussd_code) BETWEEN 3 AND 128
 AND substr(v.ussd_code,1,1)='*' AND substr(v.ussd_code,-1,1)='#'
 AND substr(v.ussd_code,2,length(v.ussd_code)-2) NOT GLOB '*[^0-9*]*'
 AND instr(v.ussd_template,'{amount}')>0
 AND (instr(v.ussd_template,'{recipient}')>0 OR instr(v.ussd_template,'{momo}')>0 OR instr(v.ussd_template,'{code}')>0))
 THEN RAISE(ABORT,'checkout_offer_changed') END;
END;
CREATE TRIGGER pa_checkout_prepare AFTER INSERT ON pa_checkout_requests BEGIN
 -- No reusable bound snapshot: cancel only this owner's pending membership intents.
 UPDATE pa_orders SET state='cancelled'
 WHERE club_id=NEW.club_id AND user_id=NEW.user_id AND kind='membership' AND state='pending'
 AND NOT EXISTS(SELECT 1 FROM pa_checkout_reusable z WHERE z.club_id=NEW.club_id AND z.user_id=NEW.user_id AND z.package_id=NEW.package_id);
 INSERT INTO pa_orders(order_id,source_intent_id,kind,user_id,club_id,partner_id,receiver_id,amount,currency,country,
 provider,recipient,tier,initiative_id,checkout_reference,expires_at_ms,created_at_ms,state,source_sha256)
 SELECT NEW.proposed_order_id,NEW.proposed_intent_id,'membership',NEW.user_id,NEW.club_id,v.partner_id,v.receiver_id,
 v.amount,v.currency,v.country,v.provider,v.recipient,v.tier,NULL,'MEM-'||NEW.proposed_order_id,
 CAST(unixepoch('subsec') * 1000 AS INTEGER)+86400000,CAST(unixepoch('subsec') * 1000 AS INTEGER),'pending',NEW.offer_sha256 FROM pa_checkout_offers v
 WHERE v.package_id=NEW.package_id AND v.route_id=NEW.route_id
 AND NOT EXISTS(SELECT 1 FROM pa_checkout_reusable z WHERE z.club_id=NEW.club_id AND z.user_id=NEW.user_id AND z.package_id=NEW.package_id);
 INSERT INTO pa_checkout_order_details(order_id,package_id,route_id,ussd_code,created_command_id,snapshot_json)
 SELECT o.order_id,v.package_id,v.route_id,v.ussd_code,NEW.command_id,
 json_object('schemaVersion',1,'orderId',o.order_id,'intentId',o.source_intent_id,'userId',o.user_id,'clubId',o.club_id,
 'packageId',v.package_id,'tier',o.tier,'amount',o.amount,'currency',o.currency,'country',o.country,
 'provider',o.provider,'recipient',o.recipient,'ussdCode',v.ussd_code,'createdAt',o.created_at_ms,'expiresAt',o.expires_at_ms,
 'paymentVerified',json('false'),'membershipActivated',json('false'))
 FROM pa_orders o JOIN pa_checkout_offers v ON v.package_id=NEW.package_id AND v.route_id=NEW.route_id
 WHERE o.order_id=NEW.proposed_order_id;
 INSERT INTO pa_checkout_results(command_id,order_id,reused)
 SELECT NEW.command_id,z.order_id,CASE WHEN z.order_id=NEW.proposed_order_id THEN 0 ELSE 1 END
 FROM pa_checkout_reusable z WHERE z.club_id=NEW.club_id AND z.user_id=NEW.user_id AND z.package_id=NEW.package_id
 ORDER BY z.created_at_ms DESC,z.order_id DESC LIMIT 1;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_checkout_results WHERE command_id=NEW.command_id)
 THEN RAISE(ABORT,'checkout_incomplete') END;
 INSERT INTO pa_checkout_audit(command_id,order_id,event_type,recorded_at_ms)
 SELECT NEW.command_id,order_id,'membership.checkout_prepared',CAST(unixepoch('subsec') * 1000 AS INTEGER) FROM pa_checkout_results WHERE command_id=NEW.command_id;
 -- A trigger-induced control mutation must not escape the initial authority check.
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_checkout_authorizations z
 WHERE z.principal_id=NEW.principal_id AND z.club_id=NEW.club_id AND z.user_id=NEW.user_id AND z.capability='prepare'
 AND z.principal_revision=NEW.principal_revision AND z.grant_revision=NEW.grant_revision AND z.club_revision=NEW.club_revision
 AND z.subject_revision=NEW.subject_revision AND z.control_revision=NEW.control_revision)
 THEN RAISE(ABORT,'checkout_permission_denied') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM pa_checkout_offers v WHERE v.club_id=NEW.club_id AND v.tier=NEW.tier
 AND v.package_id=NEW.package_id AND v.package_revision=NEW.package_revision AND v.route_id=NEW.route_id
 AND v.route_revision=NEW.route_revision AND v.receiver_id=NEW.receiver_id AND v.receiver_revision=NEW.receiver_revision
 AND v.checkout_club_revision=NEW.checkout_club_revision AND v.club_revision=NEW.club_revision)
 THEN RAISE(ABORT,'checkout_offer_changed') END;
END;
CREATE TRIGGER pa_checkout_settings_identity BEFORE UPDATE ON pa_checkout_settings WHEN NEW.singleton IS NOT OLD.singleton OR NEW.revision<OLD.revision
 BEGIN SELECT RAISE(ABORT,'checkout_immutable_identity'); END;
CREATE TRIGGER pa_checkout_settings_revision AFTER UPDATE ON pa_checkout_settings WHEN NEW.revision=OLD.revision AND (NEW.enabled IS NOT OLD.enabled OR NEW.catalog_reconciled IS NOT OLD.catalog_reconciled OR NEW.evidence_ref IS NOT OLD.evidence_ref)
 BEGIN UPDATE pa_checkout_settings SET revision=OLD.revision+1 WHERE singleton=NEW.singleton; END;
CREATE TRIGGER pa_checkout_settings_no_delete BEFORE DELETE ON pa_checkout_settings BEGIN SELECT RAISE(ABORT,'checkout_retain_control'); END;
CREATE TRIGGER pa_checkout_grants_identity BEFORE UPDATE ON pa_checkout_grants WHEN NEW.principal_id IS NOT OLD.principal_id OR NEW.club_id IS NOT OLD.club_id OR NEW.capability IS NOT OLD.capability OR NEW.revision<OLD.revision
 BEGIN SELECT RAISE(ABORT,'checkout_immutable_identity'); END;
CREATE TRIGGER pa_checkout_grants_revision AFTER UPDATE ON pa_checkout_grants WHEN NEW.revision=OLD.revision AND (NEW.enabled IS NOT OLD.enabled)
 BEGIN UPDATE pa_checkout_grants SET revision=OLD.revision+1 WHERE principal_id=NEW.principal_id AND club_id=NEW.club_id AND capability=NEW.capability; END;
CREATE TRIGGER pa_checkout_grants_no_delete BEFORE DELETE ON pa_checkout_grants BEGIN SELECT RAISE(ABORT,'checkout_retain_control'); END;
CREATE TRIGGER pa_checkout_clubs_identity BEFORE UPDATE ON pa_checkout_clubs WHEN NEW.club_id IS NOT OLD.club_id OR NEW.revision<OLD.revision
 BEGIN SELECT RAISE(ABORT,'checkout_immutable_identity'); END;
CREATE TRIGGER pa_checkout_clubs_revision AFTER UPDATE ON pa_checkout_clubs WHEN NEW.revision=OLD.revision AND (NEW.ussd_template IS NOT OLD.ussd_template OR NEW.active IS NOT OLD.active OR NEW.source_sha256 IS NOT OLD.source_sha256)
 BEGIN UPDATE pa_checkout_clubs SET revision=OLD.revision+1 WHERE club_id=NEW.club_id; END;
CREATE TRIGGER pa_checkout_clubs_no_delete BEFORE DELETE ON pa_checkout_clubs BEGIN SELECT RAISE(ABORT,'checkout_retain_control'); END;
CREATE TRIGGER pa_checkout_packages_identity BEFORE UPDATE ON pa_checkout_packages WHEN NEW.package_id IS NOT OLD.package_id OR NEW.club_id IS NOT OLD.club_id OR NEW.partner_id IS NOT OLD.partner_id OR NEW.revision<OLD.revision
 BEGIN SELECT RAISE(ABORT,'checkout_immutable_identity'); END;
CREATE TRIGGER pa_checkout_packages_revision AFTER UPDATE ON pa_checkout_packages WHEN NEW.revision=OLD.revision AND (NEW.tier IS NOT OLD.tier OR NEW.annual_price IS NOT OLD.annual_price OR NEW.price IS NOT OLD.price OR NEW.sort_order IS NOT OLD.sort_order OR NEW.active IS NOT OLD.active OR NEW.source_sha256 IS NOT OLD.source_sha256)
 BEGIN UPDATE pa_checkout_packages SET revision=OLD.revision+1 WHERE package_id=NEW.package_id AND club_id=NEW.club_id AND partner_id=NEW.partner_id; END;
CREATE TRIGGER pa_checkout_packages_no_delete BEFORE DELETE ON pa_checkout_packages BEGIN SELECT RAISE(ABORT,'checkout_retain_control'); END;
CREATE TRIGGER pa_checkout_routes_identity BEFORE UPDATE ON pa_checkout_routes WHEN NEW.route_id IS NOT OLD.route_id OR NEW.club_id IS NOT OLD.club_id OR NEW.partner_id IS NOT OLD.partner_id OR NEW.revision<OLD.revision
 BEGIN SELECT RAISE(ABORT,'checkout_immutable_identity'); END;
CREATE TRIGGER pa_checkout_routes_revision AFTER UPDATE ON pa_checkout_routes WHEN NEW.revision=OLD.revision AND (NEW.provider IS NOT OLD.provider OR NEW.country IS NOT OLD.country OR NEW.recipient IS NOT OLD.recipient OR NEW.active IS NOT OLD.active OR NEW.source_sha256 IS NOT OLD.source_sha256)
 BEGIN UPDATE pa_checkout_routes SET revision=OLD.revision+1 WHERE route_id=NEW.route_id AND club_id=NEW.club_id AND partner_id=NEW.partner_id; END;
CREATE TRIGGER pa_checkout_routes_no_delete BEFORE DELETE ON pa_checkout_routes BEGIN SELECT RAISE(ABORT,'checkout_retain_control'); END;
CREATE TRIGGER pa_checkout_requests_no_update BEFORE UPDATE ON pa_checkout_requests BEGIN SELECT RAISE(ABORT,'checkout_immutable_history'); END;
CREATE TRIGGER pa_checkout_requests_no_delete BEFORE DELETE ON pa_checkout_requests BEGIN SELECT RAISE(ABORT,'checkout_immutable_history'); END;
CREATE TRIGGER pa_checkout_order_details_no_update BEFORE UPDATE ON pa_checkout_order_details BEGIN SELECT RAISE(ABORT,'checkout_immutable_history'); END;
CREATE TRIGGER pa_checkout_order_details_no_delete BEFORE DELETE ON pa_checkout_order_details BEGIN SELECT RAISE(ABORT,'checkout_immutable_history'); END;
CREATE TRIGGER pa_checkout_results_no_update BEFORE UPDATE ON pa_checkout_results BEGIN SELECT RAISE(ABORT,'checkout_immutable_history'); END;
CREATE TRIGGER pa_checkout_results_no_delete BEFORE DELETE ON pa_checkout_results BEGIN SELECT RAISE(ABORT,'checkout_immutable_history'); END;
CREATE TRIGGER pa_checkout_audit_no_update BEFORE UPDATE ON pa_checkout_audit BEGIN SELECT RAISE(ABORT,'checkout_immutable_history'); END;
CREATE TRIGGER pa_checkout_audit_no_delete BEFORE DELETE ON pa_checkout_audit BEGIN SELECT RAISE(ABORT,'checkout_immutable_history'); END;
