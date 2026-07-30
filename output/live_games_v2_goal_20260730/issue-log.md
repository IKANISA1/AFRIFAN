# Issue Log

| ID | Issue | Severity | Evidence | Recommendation | Owner | Status | Escalation required |
|---|---|---|---|---|---|---|---|
| ISS-001 | The implementation branch preserves 870 pre-existing dirty entries and overlapping mobile, TV, admin, and backend work | Critical | E-005, E-007 | Complete LG-000 before overlapping source edits; checkpoint and assign file ownership without reset | Repository owner | mitigated_in_progress | Yes |
| ISS-002 | Migrations and RLS required by the plan are protected | Critical | `RULES.md`, APR-01/APR-02 | Record explicit approval before implementation or execution | Repository owner/security owner | open | Yes |
| ISS-003 | Existing rules prohibit venue/admin operations in supporter mobile | Critical | `RULES.md` quick reference | Approve a narrow owner/organizer role amendment under APR-03 | Product/repository owner | open | Yes |
| ISS-004 | Clean iOS build is blocked by Firebase iOS 15 requirements versus target iOS 13 | High | E-002 | Reconcile all iOS deployment targets and prove clean build under LG-604 | Mobile/release owner | open | Yes if protected config changes are needed |
| ISS-005 | Authenticated admin games UI and real multi-client session were not verified | High | E-002 | Obtain authorized staging/authenticated evidence under LG-602/LG-603 | Admin/QA owner | open | Yes |
| ISS-006 | Current participant and TV flows preserve TV/session-code architecture | Critical | E-002, E-011, E-013 | Isolated code-free participant contracts are implemented; complete protected backend/UI/native-TV integration under LG-104, LG-202, LG-401 and LG-402; use code only for owner pairing | Product/mobile/TV owners | mitigated_in_progress | Yes, owner approval is now required |
| ISS-007 | Native TV currently has reduced state and slow polling | Critical | E-002 | Implement full projection and Realtime reconciliation | TV/backend owners | open | No, once approvals exist |
| ISS-008 | Existing mobile production flow still depends on manual refresh | Critical | E-002, E-011, E-012 | Isolated monotonic synchronization is implemented; wire it to the protected projection/Realtime gateway and Riverpod lifecycle | Mobile/backend owners | mitigated_in_progress | Yes, owner approval and file ownership are required |
