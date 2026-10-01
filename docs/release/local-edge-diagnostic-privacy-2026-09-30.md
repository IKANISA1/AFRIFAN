# Local Supabase Edge diagnostic privacy — 2026-09-30

Local implementation and mocked-runtime verification completed. Provider delivery, deployment and distributed tracing acceptance remain open.

66 raw console calls across 25 production files now use a finite event catalog. The console sink serializes one bounded object containing a fixed event code, reviewed metrics/enums and a safe error class. Raw message/stack text, actors, recipient addresses, phone numbers, URLs, credentials and arbitrary metadata never enter that sink. HTTP status and retry metrics remain available.

`operational_health_events` stores fixed messages, catalog codes, status/severity, safe metadata and timestamps. Actor/subject identifiers are null in diagnostic rows. `football_sync_log` keeps governed sync configuration linkage and counts while replacing provider error text and raw summary errors/notes/access issues with fixed messages and numeric counts.

The actual SMS/AI parse, audit, transaction, rate-limit enforcement, payment, notification and receipt records retain their authorised data. A TypeScript AST comparison across 24 caller files confirmed the business statements and control flow against HEAD after diagnostic calls and the two diagnostic writer bodies were excluded.

Validation: 306 Edge tests passed with 13 new privacy tests; all 91 TypeScript files checked. Tests used Deno 2.9.6, the frozen import map/lock and cached dependencies, with provider requests substituted locally. Cases cover every log level, identity/message/stack/URL leakage, hostile getters and serializers, cyclic metadata, unsafe names/enums/metrics, insert errors/exceptions and real football handler persistence paths. The source regression checks all 66 diagnostic codes and rejects raw console bypasses.

The existing Google Workspace bridge remains a provider gap: its document/Drive/calendar methods return generated placeholder identifiers, and `sendGmail` returns true without contacting a provider. These existing results do not prove delivery or integration acceptance. Historical diagnostics were not purged and no provider, deployment, key rotation or production tracing verification occurred.

The companion JSON records every changed source file SHA256, the 66 event codes, diagnostic storage policy and test/proof log SHA256 values.
