-- Forward-only control plane for the SINGLE Rayon public-source database.
-- No existing business data is rewritten, no operator/grant is auto-provisioned.
-- Apply after 0001, 0002, 0003. Both publisher switches default disabled.
CREATE TABLE public_operator_tenants (
 club_id INTEGER PRIMARY KEY CHECK(club_id>0),
 club_slug TEXT NOT NULL UNIQUE,
 source_club_id TEXT NOT NULL UNIQUE,
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)
);
CREATE TABLE public_operator_principals (
 principal_id TEXT PRIMARY KEY,
 access_account_id TEXT NOT NULL CHECK(length(access_account_id)=32),
 access_subject TEXT NOT NULL CHECK(length(access_subject)=36),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 UNIQUE(access_account_id,access_subject)
);
CREATE TABLE public_operator_grants (
 principal_id TEXT NOT NULL REFERENCES public_operator_principals(principal_id),
 club_id INTEGER NOT NULL REFERENCES public_operator_tenants(club_id),
 can_review INTEGER NOT NULL DEFAULT 0 CHECK(can_review IN (0,1)),
 can_publish INTEGER NOT NULL DEFAULT 0 CHECK(can_publish IN (0,1)),
 enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
 expires_at_ms INTEGER NOT NULL CHECK(expires_at_ms>0),
 revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
 PRIMARY KEY(principal_id,club_id)
);
CREATE TABLE public_operator_reviews (
 review_id TEXT PRIMARY KEY,
 principal_id TEXT NOT NULL REFERENCES public_operator_principals(principal_id),
 club_id INTEGER NOT NULL REFERENCES public_operator_tenants(club_id),
 snapshot_id TEXT NOT NULL REFERENCES public_snapshots(snapshot_id),
 expected_previous_id TEXT REFERENCES public_snapshots(snapshot_id),
 review_ref TEXT NOT NULL,
 reviewed_at_ms INTEGER NOT NULL,
 expires_at_ms INTEGER NOT NULL CHECK(expires_at_ms>reviewed_at_ms),
 principal_revision INTEGER NOT NULL,
 grant_revision INTEGER NOT NULL,
 tenant_revision INTEGER NOT NULL,
 state TEXT NOT NULL DEFAULT 'ready' CHECK(state IN ('ready','consumed','invalidated'))
);
CREATE INDEX public_operator_reviews_by_actor ON public_operator_reviews(principal_id,club_id,state);
CREATE TABLE public_operator_publications (
 operation_id TEXT PRIMARY KEY,
 principal_id TEXT NOT NULL REFERENCES public_operator_principals(principal_id),
 club_id INTEGER NOT NULL REFERENCES public_operator_tenants(club_id),
 key_sha256 TEXT NOT NULL CHECK(length(key_sha256)=64),
 request_sha256 TEXT NOT NULL CHECK(length(request_sha256)=64),
 review_id TEXT NOT NULL UNIQUE REFERENCES public_operator_reviews(review_id),
 snapshot_id TEXT NOT NULL REFERENCES public_snapshots(snapshot_id),
 previous_id TEXT REFERENCES public_snapshots(snapshot_id),
 published_at_ms INTEGER NOT NULL,
 result_json TEXT NOT NULL CHECK(json_valid(result_json)),
 UNIQUE(principal_id,club_id,key_sha256)
);
CREATE TABLE public_operator_audit (
 event_id TEXT PRIMARY KEY,
 event_type TEXT NOT NULL CHECK(event_type IN ('snapshot_reviewed','snapshot_published')),
 principal_id TEXT NOT NULL,
 club_id INTEGER NOT NULL,
 review_id TEXT NOT NULL,
 operation_id TEXT,
 snapshot_id TEXT NOT NULL,
 previous_id TEXT,
 happened_at_ms INTEGER NOT NULL,
 reference TEXT NOT NULL
);
CREATE TABLE public_operator_rate_windows (
 principal_id TEXT NOT NULL, club_id INTEGER NOT NULL,
 window_start_ms INTEGER NOT NULL, calls INTEGER NOT NULL CHECK(calls>0),
 PRIMARY KEY(principal_id,club_id,window_start_ms)
);
CREATE TABLE public_operator_guards(nonce TEXT PRIMARY KEY,passed INTEGER NOT NULL CHECK(passed=1));
CREATE TRIGGER public_operator_reviews_identity BEFORE UPDATE OF review_id,principal_id,club_id,snapshot_id,expected_previous_id,review_ref,reviewed_at_ms,expires_at_ms,principal_revision,grant_revision,tenant_revision ON public_operator_reviews
BEGIN SELECT RAISE(ABORT,'review_immutable'); END;
CREATE TRIGGER public_operator_reviews_state BEFORE UPDATE OF state ON public_operator_reviews
WHEN NOT(OLD.state=NEW.state OR (OLD.state='ready' AND NEW.state IN ('consumed','invalidated')))
BEGIN SELECT RAISE(ABORT,'review_terminal'); END;
CREATE TRIGGER public_operator_reviews_retention BEFORE DELETE ON public_operator_reviews
BEGIN SELECT RAISE(ABORT,'review_retention_required'); END;
CREATE TRIGGER public_operator_publications_update BEFORE UPDATE ON public_operator_publications
BEGIN SELECT RAISE(ABORT,'publication_receipt_immutable'); END;
CREATE TRIGGER public_operator_publications_delete BEFORE DELETE ON public_operator_publications
BEGIN SELECT RAISE(ABORT,'publication_receipt_retention_required'); END;
CREATE TRIGGER public_operator_audit_update BEFORE UPDATE ON public_operator_audit
BEGIN SELECT RAISE(ABORT,'audit_immutable'); END;
CREATE TRIGGER public_operator_audit_delete BEFORE DELETE ON public_operator_audit
BEGIN SELECT RAISE(ABORT,'audit_retention_required'); END;
CREATE TRIGGER public_operator_principal_changed AFTER UPDATE OF enabled,access_account_id,access_subject ON public_operator_principals
BEGIN
 UPDATE public_operator_principals SET revision=OLD.revision+1 WHERE principal_id=NEW.principal_id;
 UPDATE public_operator_reviews SET state='invalidated' WHERE principal_id=NEW.principal_id AND state='ready';
END;
CREATE TRIGGER public_operator_grant_changed AFTER UPDATE OF enabled,can_review,can_publish,expires_at_ms ON public_operator_grants
BEGIN
 UPDATE public_operator_grants SET revision=OLD.revision+1 WHERE principal_id=NEW.principal_id AND club_id=NEW.club_id;
 UPDATE public_operator_reviews SET state='invalidated' WHERE principal_id=NEW.principal_id AND club_id=NEW.club_id AND state='ready';
END;
CREATE TRIGGER public_operator_tenant_changed AFTER UPDATE OF enabled,club_slug,source_club_id ON public_operator_tenants
BEGIN
 UPDATE public_operator_tenants SET revision=OLD.revision+1 WHERE club_id=NEW.club_id;
 UPDATE public_operator_reviews SET state='invalidated' WHERE club_id=NEW.club_id AND state='ready';
END;

CREATE TRIGGER public_operator_principal_identity BEFORE UPDATE OF principal_id ON public_operator_principals
BEGIN SELECT RAISE(ABORT,'principal_identity_immutable'); END;
CREATE TRIGGER public_operator_grant_identity BEFORE UPDATE OF principal_id,club_id ON public_operator_grants
BEGIN SELECT RAISE(ABORT,'grant_identity_immutable'); END;
CREATE TRIGGER public_operator_tenant_identity BEFORE UPDATE OF club_id ON public_operator_tenants
BEGIN SELECT RAISE(ABORT,'tenant_identity_immutable'); END;
CREATE TRIGGER public_operator_grant_deleted BEFORE DELETE ON public_operator_grants
BEGIN UPDATE public_operator_reviews SET state='invalidated' WHERE principal_id=OLD.principal_id AND club_id=OLD.club_id AND state='ready'; END;
