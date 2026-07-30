# Release Readiness Matrix

| Area | Required proof | Current status | Evidence | Next accountable action |
|---|---|---|---|---|
| Authority and approvals | DEC-01 to DEC-06; APR-01 to APR-09 as applicable | Red | Goal registers | Product/repository owner records decisions and approvals |
| Controlled candidate | Branch, commit, clean ownership boundary, preserved user changes | Red | E-005 shows uncontrolled dirty baseline | Complete LG-000 |
| Backend schema/RLS | Additive migration, policy isolation, rollback/staging proof | Red | None | LG-100 to LG-105 and LG-600 |
| Participant mobile | Code-free discovery, synchronization, all route states | Red | Current architecture contradicts target | LG-200 to LG-202 and LG-601 |
| Owner/organizer mobile | Scoped role routes, My TVs, Games I Manage | Red | Not implemented | LG-300 to LG-302 and LG-601 |
| Native TV | Owner-claim pairing, full live projection, native package, D-pad | Red | Current reduced projection only | LG-400 to LG-402 and LG-601 |
| Admin and AI | Content Studio, Planner, Live Control, human review, authenticated evidence | Red | Partial source only; authenticated flow unverified | LG-500 to LG-502 and LG-602 |
| Cross-client correctness | Multi-client staging, latency, reconnect, duplicates, stale events | Red | None | LG-603 |
| Security/privacy | Cross-club/role isolation, no answer leak, TV payload/privacy | Red | Target tests not implemented | LG-600 and security review |
| Accessibility/performance | Mobile/admin/TV exact-build evidence and service levels | Red | Target evidence absent | LG-601 to LG-604 |
| iOS build | Clean exact-source build with compatible target | Red | Current Firebase/iOS target mismatch | LG-604 |
| Android mobile build | Clean exact-source build/device proof | Red | Not current for V2 | LG-604 |
| Android TV build | Installable exact-source native package/device proof | Red | Not current for V2 | LG-604 |
| Web/admin build | Clean build plus authenticated route proof | Red | V2 not implemented | LG-602/LG-604 |
| Staging migration/UAT | Authorized staging execution and rollback | Red | Not authorized or run | APR-07, LG-603/LG-604 |
| Physical-device UAT | Phones and TV with exact candidate | Red | None | LG-604 |
| Signing/store/deployment | Current accountable external evidence | Red | Not authorized | APR-08/APR-09, LG-604 |
| Legacy sunset | Adoption evidence, rollback window, owner decision | Red | DEC-06 pending | LG-503 |
| Closeout | 27/27 tasks and 13/13 gates verified | Red | 0/27, 0/13 | Complete and audit full goal |
