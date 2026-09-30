-- Independent telemetry database. No identity, financial receipt, queue ownership or provider capabilities.
CREATE TABLE private_metrics (
 record_id TEXT PRIMARY KEY,metric_json TEXT NOT NULL CHECK(json_valid(metric_json) AND length(metric_json)<=2048),
 event TEXT NOT NULL CHECK(event IN('service_operation','service_queue')),
 service TEXT NOT NULL CHECK(service IN('supporter_auth','supporter_browser','supporter_membership','auth_code_delivery','allocation_delivery',
  'payment_allocation','payment_exceptions','operator_api','rayon_public','frontend_router','receipt_delivery')),
 trace_id TEXT,recorded_at_ms INTEGER NOT NULL,expires_at_ms INTEGER NOT NULL CHECK(expires_at_ms>recorded_at_ms AND expires_at_ms-recorded_at_ms<=31622400000)
) STRICT;
CREATE INDEX private_metrics_expiry ON private_metrics(expires_at_ms,record_id);
CREATE INDEX private_metrics_trace ON private_metrics(trace_id,expires_at_ms,record_id);
CREATE INDEX private_metrics_service ON private_metrics(service,recorded_at_ms,record_id);
CREATE TRIGGER private_metrics_no_update BEFORE UPDATE ON private_metrics BEGIN SELECT RAISE(ABORT,'metrics_immutable');END;
