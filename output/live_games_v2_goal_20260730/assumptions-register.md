# Assumptions Register

| ID | Assumption | Source | Rationale | Sensitivity | Owner | Approval status |
|---|---|---|---|---|---|---|
| ASM-01 | “Live streaming” means synchronized trivia state, not video distribution | User clarification and implementation review | No media ingest/distribution pipeline is present | High: video would materially expand architecture, cost, rights, and moderation | Product owner | pending under DEC-05 |
| ASM-02 | A game may target multiple TV displays | Implementation plan recommendation | Supports multi-screen venues and avoids permanent one-to-one coupling | High: affects schema cardinality and assignment UI | Product owner | pending under DEC-01 |
| ASM-03 | Participant public identity remains the governed alias, not free-text name | `RULES.md` privacy contract | Prevents real-name collection and moderation burden | High: affects join UX and payload contracts | Product/privacy owner | pending under DEC-04 |
| ASM-04 | Existing dirty changes are user-owned until proven otherwise | Current git state and repository policy | Prevents destructive overwrite | Critical: affects every implementation file | Repository owner | active default |
| ASM-05 | Local source changes and tests do not authorize staging/production mutation or release | Goal framework and repository rules | Separates engineering evidence from external authority | Critical | Repository owner | active default |
| ASM-06 | No new external package is required for V2 | Current dependency set appears sufficient | Avoids supply-chain change and protected package approval | Medium: must be re-evaluated during design | Engineering owner | unverified |
