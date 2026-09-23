# Rayon Sports Release Checklist

This checklist covers the AFRICLUB football-platform candidate only. Local
validation is necessary but does not authorize deployment or store release.

## 1. Repository Gates

- dependency resolution succeeds from the root workspace;
- strict Flutter analysis passes across every registered package;
- every Flutter and Dart test-bearing package passes;
- web typecheck, unit tests, zero-warning lint, and production build pass;
- repository-boundary, golden, privacy, provenance, store, secret, and shell
  validators pass;
- no generated dependency, cache, build, coverage, or evidence-output
  directory is tracked in the candidate commit;
- the exact candidate commit and configuration are recorded.

## 2. Database Gates

- a fresh local Supabase reset applies the baseline, forward migrations, and governed seed;
- all pgTAP contract tests pass;
- database lint reports no schema errors;
- schema diff for `public` and `football` is empty;
- prediction, membership, contribution, ticket, shop, privacy, storage,
  schedule and security contracts pass;
- the production reconciliation, backup, observation, and rollback plan is
  approved before any live database action.

## 3. Secrets And Credentials

Provision outside git and restrict by environment:

- Android and iOS signing credentials;
- App Store Connect and Google Play credentials;
- Supabase publishable and secret keys;
- Firebase configuration and service credentials;
- football data-provider credentials;
- notification, messaging, storage, analytics, and deployment credentials.

No secret key is embedded in a mobile bundle, public web bundle, committed
configuration, build log, screenshot, or evidence artifact.

## 4. Android Candidate

1. Build the production flavor from the exact candidate.
2. Verify package ID, version, build number, SDK levels, permissions, network
   security, app links, Firebase project, and signing identity.
3. Run install, cold start, auth restore, navigation, predictions, membership,
   contributions, tickets, shop, notifications, offline, upgrade, and
   rollback smoke tests on representative physical devices.
4. Complete accessibility, performance, privacy, battery, crash, and ANR
   checks.
5. Upload only after the artifact hash and Play App Signing identity are tied
   to the validated commit.

## 5. iOS Candidate

1. Archive the production scheme from the exact candidate.
2. Verify bundle ID, version, build number, minimum OS, entitlements,
   associated domains, Firebase project, privacy manifests, and signing.
3. Run install, cold start, auth restore, navigation, predictions, membership,
   contributions, tickets, shop, notifications, offline, upgrade, and
   rollback smoke tests on representative physical devices.
4. Complete VoiceOver, Dynamic Type, contrast, performance, privacy, crash,
   and energy checks.
5. Upload only after the archive hash and distribution identity are tied to
   the validated commit.

## 6. Web And Domain Gates

- public site and admin routes serve the exact candidate;
- privacy, terms, support, and account-deletion routes are public and correct;
- App Link and Universal Link association files validate;
- TLS, redirects, CORS, CSP/security headers, cache rules, robots, sitemap,
  callbacks, logs, alerts, and rollback are verified;
- the public site remains discovery and handoff only for private supporter
  journeys;
- named admin users pass scoped live-data UAT.

## 7. Store And Compliance Gates

- descriptions, screenshots, ratings, privacy answers, data safety, reviewer
  access, support, and account deletion match the exact product;
- screenshots contain only approved imagery and synthetic or masked data;
- predictions, contests, prizes, age groups, and territories match the approved
  legal and product position;
- payments for physical goods/services and any digital content use the approved
  platform and legal route;
- accessibility, privacy, security, language, brand, and content-rights owners
  approve the submitted candidate.

## 8. Rollout Decision

Release only when:

- all local and pinned-CI gates are green for the exact commit;
- production signing and artifact provenance are complete;
- physical-device and live scoped-data UAT are approved;
- database reconciliation and rollback are approved and rehearsed;
- staged deployment, monitoring, alerting, observation, and rollback owners are
  named;
- Google Play and App Store Connect submission receipts are retained;
- product, design, QA, accessibility, privacy, security, legal/policy,
  operations, brand, rights, language, and final release approvals are
  recorded.

If any required gate is red or unproved, do not ship.
