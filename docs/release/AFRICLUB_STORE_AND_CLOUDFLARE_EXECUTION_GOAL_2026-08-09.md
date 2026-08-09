# AFRICLUB store and Cloudflare execution goal

Goal ID: `AFRICLUB-R67-STORE-CLOUDFLARE-SUBMISSION`
Revision: `2026-08-09-R67`
Status: active until the fail-closed completion predicate is proved

## Objective

Implement, validate, evidence, and complete every remaining AFRICLUB task
required to submit the supporter app to Google Play and Apple App Store, submit
the native Android TV app to its approved Google Play track, and serve the
exact release candidate on all governed Cloudflare domains.

The goal preserves the original 87-task denominator. Its 12 release
workstreams organize the 33-task creation baseline; they do not create an
easier replacement definition of done. The tracked machine-readable contract
is
`docs/release/AFRICLUB_STORE_AND_CLOUDFLARE_EXECUTION_GOAL_2026-08-09.json`;
the reconciler writes its current checkpoint to
`output/implementation_goal_20260724/release-submission-execution-goal.json`.

## Non-negotiable evidence rules

1. The live checkout, not a pasted SHA or old preflight, controls candidate
   identity.
2. An exact candidate must be clean, verified on `origin/main`, and linked to a
   retained exact-HEAD CI run. Passing CI additionally requires at least one
   executed job, logs, artifacts, and successful pinned-runtime gates.
3. Every release artifact must name its `source_git_head`, app identity,
   version/build, SHA-256, byte size, signing fingerprint, toolchain, and
   validation results.
4. Local builds, emulators, simulators, route matrices, and generated
   declarations do not prove physical-device, store-console, live-backend,
   Cloudflare custom-domain, or accountable approval completion.
5. A prior-commit AAB, IPA, TV bundle, Worker deployment, CI run, or console
   screenshot remains historical evidence only.
6. No password, key, token, identity-verification material, biometric material,
   or one-time code may enter git, chat history, or evidence files.
7. A workstream is complete only when every mapped original task and every
   named remote, physical, approval, and receipt condition is proved.

## Ordered execution workstreams

### RSG-01 — product, policy, rights, language, and distribution decisions

Mapped tasks: `GOV-01`, `GOV-03`, `GOV-05`, `MOB-08`, `EVID-04`, `EVID-05`,
`TV-01`, `ADMIN-01`, `ADMIN-02`, `REL-08`.

- Decide and document Android TV distribution.
- Classify physical versus digital purchases and the required Play Billing or
  Apple IAP path.
- Classify predictions, trivia, tokens, prizes, contests, age groups, and
  territories.
- Close UGC terms, filtering, reporting, blocking, moderation, and support.
- Approve or replace every club/media asset and onboarding source.
- Complete named French and Kinyarwanda review, including dynamic content.
- Name an accountable owner and due date for every open decision and approval.

### RSG-02 — exact candidate, source review, and pinned CI

Mapped tasks: `GOV-06`, `EVID-03`, `EVID-08`, `REL-01`.

- Review all intended inclusions and deletions before release freeze.
- Regenerate the 87-task manifest, candidate manifest, release preflight,
  evidence index, and remaining-task register from the live checkout.
- Resolve the GitHub Actions pre-job restriction and retain a successful,
  non-empty exact-HEAD run with logs and artifacts.
- Freeze only after all code and configuration changes; rebuild after any
  subsequent commit.

### RSG-03 — production backend, authorization, analytics, and operations

Mapped tasks: `STATE-03`, `STATE-06`, `ADMIN-05`, `REL-06`.

- Verify exact migrations, schema, RLS, grants, RPCs, functions, callbacks,
  webhooks, and external secret configuration.
- Complete the two-client collision, role, cross-club, revoked-role,
  actor/audit, rollback, and recovery matrix across all named flows.
- Verify production consent and minimum-cohort analytics suppression.
- Connect crash/ANR, latency, incident, alert, retention, and rollback controls
  and rehearse recovery.

### RSG-04 — authenticated publication paths

Mapped tasks: `REL-06`, `REL-07`.

- Establish a least-privilege Google Play publisher path.
- Establish an authorized App Store Connect upload/submission path.
- Establish Cloudflare Workers, Pages, Zone Read, and DNS Edit access for only
  the governed account and zone.
- Verify access without committing or recording credential values.

### RSG-05 — store records, identifiers, and signing ownership

Mapped tasks: `REL-02`, `REL-03`, `REL-07`, `TV-09`.

- Verify the Play records for `rw.gikundiro.app` and
  `rw.ikanisa.rayonSports.tv`, Play App Signing, and upload certificates.
- Verify the App Store Connect record for `rw.ikanisa.rayonSports`, Team ID,
  capabilities, agreements, certificate, and provisioning profile.
- Register final store signing fingerprints with Firebase, OAuth, Android App
  Links, and Apple Universal Links.
- Prove each Android version code and Apple build number is unused before
  upload.

### RSG-06 — exact-candidate signed artifacts and privacy reports

Mapped tasks: `EVID-06`, `TV-09`, `REL-02`, `REL-03`, `REL-07`.

- Produce an upload-key-signed mobile AAB, App Store distribution-signed iOS
  archive/IPA, and production-signed native-TV AAB from one frozen SHA.
- Retain merged manifests, provisioning data, privacy reports, embedded SDK
  manifests/signatures, bundletool results, 16 KB checks, mappings, symbols,
  hashes, toolchains, and build logs.
- Reject any artifact without explicit source-SHA provenance as exact-candidate
  evidence.

### RSG-07 — Cloudflare deployment and public contracts

Mapped tasks: `REL-06`, `REL-07`.

- Snapshot DNS, Pages associations, Worker domains/versions, TLS, and rollback
  state.
- Deploy the exact candidate to `gikundiro-web` and validate `workers.dev`.
- Move `fans`, `admin`, `www`, then the apex to Worker Custom Domains with a
  per-host canary and rollback.
- Prove that all four hosts serve the Worker and that the legacy Pages project
  remains only as controlled rollback infrastructure.
- Validate privacy, terms, support, deletion, `assetlinks.json`,
  `apple-app-site-association`, TLS, redirects, APIs, callbacks, CORS, cache,
  security headers, robots, sitemap, logs, alerts, and observation results.

### RSG-08 — store-distributed physical and cross-surface UAT

Mapped tasks: `MOB-09`, `A11Y-02`, `EVID-06`, `TV-04`, `TV-05`, `TV-07`,
`ADMIN-07`, `ADMIN-08`, `ADMIN-09`, `REL-04`, `REL-05`.

- Install through Play internal testing and TestFlight, not only local tools.
- Complete Android TalkBack/App Links/push/lifecycle/recovery/performance UAT.
- Complete iOS VoiceOver/Universal Links/APNs/App Attest/lifecycle/recovery/
  performance UAT.
- Complete physical-TV D-pad, Menu, focus, QR pairing, overscan, screen-reader,
  network, thermal, burn-in, crash/ANR, and four-hour soak evidence.
- Complete authenticated Admin keyboard, zoom, reflow, screen-reader,
  authorization, and high-volume performance tests.
- Run the authorized two-phone plus TV session through late join, reconnect,
  duplicate/stale events, clock skew, revocation, interruption, and restart.

### RSG-09 — Google Play mobile listing and submission

Mapped tasks: `REL-02`, `REL-04`, `REL-07`, `REL-08`.

- Finish approved icon, feature graphic, screenshots, descriptions, contacts,
  releases, and localizations.
- Complete privacy, Data Safety, deletion, ads, audience, rating, access,
  financial, permission, UGC, payment, contest, and child-safety declarations.
- Provide reusable non-OTP reviewer access.
- Complete internal testing, any required 12-tester/14-day closed test,
  pre-launch report, App Bundle Explorer, 16 KB, integrity, and compatibility
  review.
- Submit the production change and retain the console receipt showing under
  review or a later status.

### RSG-10 — Apple metadata, TestFlight, and App Review submission

Mapped tasks: `REL-03`, `REL-04`, `REL-07`, `REL-08`.

- Finish metadata, screenshots, URLs, categories, availability, pricing,
  release notes, and localizations.
- Complete App Privacy, age rating, content rights, encryption, DSA trader,
  payment, UGC, contest, tracking, and deletion declarations.
- Process the exact build, complete TestFlight physical-device validation, and
  supply durable reviewer access/instructions.
- Attach the build and retain the App Store Connect receipt showing `Waiting
  for Review`, `In Review`, or a later status.

### RSG-11 — Android TV Play delivery

Mapped tasks: `TV-01`, `TV-04`, `TV-05`, `TV-07`, `TV-09`, `REL-05`, `REL-07`.

- Complete the separate app record, signing, privacy/rating declarations,
  reviewer access, banner, and TV screenshots.
- Upload the exact-candidate TV AAB to the approved track.
- Install the store-distributed build on representative hardware and pass the
  full physical-TV matrix.
- Retain processing, review, or approved-track receipts.

### RSG-12 — approvals, submissions, receipts, rollout, and monitoring

Mapped tasks: `GOV-03`, `GOV-05`, `EVID-04`, `EVID-05`, `REL-07`, `REL-08`.

- Obtain dated evidence-linked approval from product, design, privacy,
  security, accessibility, legal/policy, operations, QA, rights, language, and
  final release owners.
- Bind Play mobile, Play TV, Apple, and Cloudflare receipts to exact artifact
  hashes and the exact candidate.
- Record review-response ownership, staged/phased rollout, monitoring,
  incident, and rollback decisions.

## Completion predicate

This goal is complete only when all of the following are simultaneously true:

- all 87 governed tasks are `verified_complete` and the remaining count is
  zero;
- the clean exact candidate is verified on `origin/main`;
- exact-HEAD pinned CI succeeds with executed jobs, logs, and artifacts;
- all three signed artifacts are bound to that SHA and validate;
- production backend, analytics, operations, and rollback evidence passes;
- physical Android, iOS, native-TV, cross-surface, accessibility, performance,
  and Admin UAT passes;
- all four Cloudflare hosts serve the exact candidate and all public contracts
  pass;
- Google Play mobile shows the production change submitted for review;
- App Store Connect shows the attached build submitted for review;
- Android TV has the approved-track submission receipt; and
- every named accountable approval is recorded.

The reconciler must keep `completion_proven=false` if any element is missing,
stale, indirect, or tied to another source commit.
