# Rayon Sports Full-Stack UAT Matrix

Status: local validation contract. Production activation requires separate
approval and evidence.

## Cross-Cutting Rules

- Every app request and database mutation is scoped to the authenticated club.
- Predictions are free, selected-match only, and server-authoritative.
- No client calculates an official result, settlement, points award, ticket
  status, membership activation, stock change, or contribution allocation.
- Sensitive data is absent from public responses, screenshots, analytics, and
  logs.
- Loading, empty, offline, error, retry, permission, conflict, and timeout
  states fail clearly and recover without duplicate mutations.
- Rights-gated images fail closed to approved placeholders.

## Surface Matrix

| Surface | Required journeys | Local gate | External gate |
| --- | --- | --- | --- |
| Supporter app | Auth restore; Home; Club; news; squad; fixtures; results; standings; predictions; membership; groups; contributions; tickets; shop; Profile and Settings | Strict analysis, package tests, route tests, goldens, Android build, iOS simulator build | Physical Android/iOS accessibility, real-network UAT, production signing, store review |
| Public club site | Host/slug resolution; home; club; news; squad; fixtures; standings; ticket and shop discovery; support; privacy; account deletion | Typecheck, unit tests, lint, production build, responsive and accessibility checks | Deployed-domain, cache, analytics, consent, and performance verification |
| Club admin | Auth; tenant selection; content; fixtures; predictions settlement; membership; contributions; tickets; shop; notifications; audit | Server authorization tests, database contracts, web tests, responsive desktop/tablet/compact checks | Named operator UAT with live scoped data and accountable approval |
| Supabase | Fresh baseline; seed; RLS; ACL; functions; storage; schedules; prediction, ticket, shop, membership, contribution, and privacy contracts | Local reset, full pgTAP suite, lint, empty schema drift | Approved production reconciliation, backup, staged rollout, monitoring, rollback |

## Supporter Journeys

| ID | Journey | Expected result |
| --- | --- | --- |
| MOB-01 | Cold start and auth restore | Correct club resolves; session restores or guest state appears without a loop. |
| MOB-02 | Club discovery | Team, news, fixtures, results, standings, and history use approved club-scoped data. |
| MOB-03 | Prediction placement | Eligible fixture and market lock correctly; retry is idempotent; no odds or staking language appears. |
| MOB-04 | Prediction settlement | Official result drives status, points, badges, leaderboard, and notification exactly once. |
| MOB-05 | Membership | Application, pending, active, renewal, benefits, and statement states are authoritative and privacy-safe. |
| MOB-06 | Contribution | Intent, receipt, allocation, ledger, reconciliation, and statement remain balanced and traceable. |
| MOB-07 | Ticket purchase | Price, capacity, payment status, ticket state, cancellation, and audit remain server-authoritative. |
| MOB-08 | Shop order | Server prices items, reserves stock, prevents tenant crossover, and recovers expired reservations. |
| MOB-10 | Privacy and deletion | Export and deletion explain scope, require reauthentication where needed, and do not leak private data. |

## Web And Operator Journeys

| ID | Journey | Expected result |
| --- | --- | --- |
| WEB-01 | Public host resolution | Unknown hosts fail safely; known hosts render only approved club data. |
| WEB-02 | Public content | Images, metadata, canonical URLs, language, and empty states are accurate and accessible. |
| ADM-01 | Club authorization | Authentication without the required club role cannot read or mutate operator data. |
| ADM-02 | Fixture and prediction operations | Scheduling, market state, lock, settlement, correction, and audit are scoped and idempotent. |
| ADM-03 | Membership and contribution operations | Review actions require reason, actor, tenant, and immutable audit evidence. |
| ADM-04 | Ticket and shop operations | Prices, capacity, stock, rights approvals, refunds/cancellation, and destructive confirmations fail closed. |

## Database Acceptance

The local database gate passes only when:

1. `supabase db reset --local` rebuilds from the committed baseline, forward migrations,
   and seed;
2. every pgTAP file passes;
3. schema lint reports no errors;
4. schema diff for `public` and `football` is empty;
5. unsupported schemas, relations, routines, policies, publications, and seed
   records are absent;
6. prediction relations and routines remain present and tested;
7. storage buckets and scheduled jobs exactly match the governed contract.

## Release Stop Conditions

Stop release when any of these is true:

- an unscoped query, policy, function, storage path, or realtime subscription
  is detected;
- a supporter can directly mutate server-authoritative tables;
- prediction copy resembles betting, paid entry, or guaranteed return;
- ticket, shop, membership, or contribution state can be duplicated by
  retry;
- a screenshot or log exposes personal, payment, member, ticket, or operator
  data;
- a signed artifact cannot be tied to the validated commit and configuration;
- production reconciliation, rollback, monitoring, or accountable approval is
  missing.
