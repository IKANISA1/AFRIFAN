# BioPay Comparative Analysis

Date: 2026-04-02

Compared repositories:
- AFRICLUB app suite: `/Volumes/PRO-G40/AFRICLUB`
- Standalone BioPay: `/Volumes/PRO-G40/BioPay`

## Executive Summary

AFRICLUB already contains a substantial, production-oriented BioPay implementation as a reusable white-label Flutter feature package backed by Supabase Edge Functions, App Check attestation, signed QR and NFC handoff tokens, multiclub scoping, and payment-routing abstraction. The standalone BioPay repository is a more product-concrete end-to-end app, but it is built as a monolithic standalone Flutter app plus a separate FastAPI backend and a Rwanda-first USSD data model.

The standalone BioPay app is not a drop-in replacement for AFRICLUB BioPay.

The main reason is architectural shape, not just feature variance:
- AFRICLUB BioPay is a reusable feature package consumed by 20 club apps.
- Standalone BioPay is a full app, not a reusable package.
- AFRICLUB runtime is Supabase Edge Functions plus App Check.
- Standalone runtime is FastAPI plus Supabase service-role access.
- AFRICLUB data model is multitenant and generic.
- Standalone BioPay data model is single-product and USSD-string-centric.

If the business decision is that standalone BioPay becomes the long-term source of truth, the correct move is not to import the standalone app into AFRICLUB as-is. The correct move is to extract a reusable BioPay package from the standalone repository, align the backend contract, and make AFRICLUB consume that package through a controlled upstream integration path.

Current recommendation:
- Do not replace AFRICLUB BioPay with the standalone app directly.
- Use the standalone app as a future upstream product source only after extracting a shared package and aligning runtime contracts.
- If the immediate requirement is "make BioPay look and feel exactly like the standalone app", port the standalone UI contract into AFRICLUB's `feat_biopay` package instead of importing the standalone host app wholesale.

## Scope Of Analysis

This analysis compares:
- Flutter packaging and ownership model
- UI contract and navigation shape
- Backend/runtime architecture
- Database and vector-search schema
- Auth, attestation, and security boundaries
- NFC/QR/handoff behavior
- White-label readiness
- Testing depth and operational maturity
- Migration feasibility

## Verification Performed

Repository reading:
- AFRICLUB BioPay Flutter feature package, Supabase migrations, Edge Functions, and platform integration files
- Standalone BioPay Flutter mobile app, FastAPI backend, Supabase migrations, and platform integration files

Automated verification run:
- `flutter test packages/features/feat_biopay/test`
- `deno test --allow-env supabase/functions/biopay-match/index_test.ts`
- `python3 -m pytest /Volumes/PRO-G40/BioPay/backend/tests -q`
- `cd /Volumes/PRO-G40/BioPay/mobile && flutter test`

Observed sizing and distribution:
- AFRICLUB `feat_biopay` source: 8,108 LOC
- Standalone BioPay mobile source: 4,223 LOC
- Standalone `biopay_app.dart`: 2,573 LOC
- Standalone `biopay_services.dart`: 1,381 LOC
- AFRICLUB `feat_biopay` is referenced by 20 club app `pubspec.yaml` files

## What AFRICLUB BioPay Is Today

### Packaging and reuse

AFRICLUB BioPay is already designed as a reusable white-label feature package:
- `packages/features/feat_biopay/...`
- It is consumed by 20 club apps across the suite.

This is a critical property. BioPay in AFRICLUB is not "Rayon-only". It already sits in the shared product layer.

### UX contract

AFRICLUB BioPay is a club-branded "hub" experience with clear receive/pay segmentation:
- `BIOPAY`
- `PAY OR RECEIVE`
- `RECEIVE`
- `PAY`
- `ENROLL FACE ID`
- `NFC RECEIVE`
- `QR RECEIVE`
- `PAY BY FACE`
- `SCAN QR`
- `SCAN NFC`

Evidence:
- [biopay_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_biopay/lib/src/screens/biopay_screen.dart#L11)
- [biopay_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_biopay/lib/src/screens/biopay_screen.dart#L54)
- [biopay_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_biopay/lib/src/screens/biopay_screen.dart#L145)
- [biopay_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_biopay/lib/src/screens/biopay_screen.dart#L198)

### Runtime and security model

AFRICLUB BioPay operations run through a centralized repository that talks to Supabase Edge Functions and attaches Firebase App Check attestation headers:
- `_buildAttestedHeaders()` sends `X-Firebase-AppCheck`
- enrollment, matching, revoke, and payment-intent creation all use attested calls

Evidence:
- [biopay_repository.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_biopay/lib/src/repositories/biopay_repository.dart#L16)
- [biopay_repository.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_biopay/lib/src/repositories/biopay_repository.dart#L43)
- [biopay_repository.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_biopay/lib/src/repositories/biopay_repository.dart#L80)
- [biopay_repository.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_biopay/lib/src/repositories/biopay_repository.dart#L123)

The Edge Functions explicitly require App Check and bind behavior to club metadata:
- enrollment validates App Check and liveness before RPC
- matching validates App Check, liveness, abuse protection, and club scoping
- handoff token issuance requires App Check and produces signed short-lived resolver tokens

Evidence:
- [biopay-enroll/index.ts](/Volumes/PRO-G40/AFRICLUB/supabase/functions/biopay-enroll/index.ts#L69)
- [biopay-enroll/index.ts](/Volumes/PRO-G40/AFRICLUB/supabase/functions/biopay-enroll/index.ts#L105)
- [biopay-match/index.ts](/Volumes/PRO-G40/AFRICLUB/supabase/functions/biopay-match/index.ts#L240)
- [biopay-match/index.ts](/Volumes/PRO-G40/AFRICLUB/supabase/functions/biopay-match/index.ts#L276)
- [biopay-create-handoff-token/index.ts](/Volumes/PRO-G40/AFRICLUB/supabase/functions/biopay-create-handoff-token/index.ts#L110)
- [biopay-create-handoff-token/index.ts](/Volumes/PRO-G40/AFRICLUB/supabase/functions/biopay-create-handoff-token/index.ts#L146)

### Data model

AFRICLUB uses a country-agnostic, route-based model:
- `biopay_profiles`
- `public_id`
- `user_id`
- `route_type`
- `recipient_value`
- `country_code`
- `active`, `revoked_at`, `deleted_at`
- 192-dimensional embeddings

Evidence:
- [20260330160000_biopay_foundation.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations/20260330160000_biopay_foundation.sql#L18)
- [20260330160000_biopay_foundation.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations/20260330160000_biopay_foundation.sql#L35)
- [20260330160000_biopay_foundation.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations/20260330160000_biopay_foundation.sql#L135)
- [20260330160000_biopay_foundation.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations/20260330160000_biopay_foundation.sql#L151)

This is materially aligned with white-label club distribution because payment routing is abstracted instead of hardcoded to one MoMo convention.

### NFC and handoff behavior

AFRICLUB supports more than simple NFC tag read/write. It also supports Android Host Card Emulation style phone-to-phone receive behavior:
- `MainActivity` exposes a method channel for HCE support and request activation
- `BiopayNfcHostApduService` emulates an NDEF-capable endpoint and returns the signed request URI

Evidence:
- [MainActivity.kt](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/android/app/src/main/kotlin/rw/ikanisa/rayon_sports/MainActivity.kt#L9)
- [MainActivity.kt](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/android/app/src/main/kotlin/rw/ikanisa/rayon_sports/MainActivity.kt#L27)
- [BiopayNfcHostApduService.kt](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/android/app/src/main/kotlin/rw/ikanisa/rayon_sports/BiopayNfcHostApduService.kt#L9)
- [BiopayNfcHostApduService.kt](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/android/app/src/main/kotlin/rw/ikanisa/rayon_sports/BiopayNfcHostApduService.kt#L55)

## What Standalone BioPay Is Today

### Packaging shape

Standalone BioPay is a complete product repository with:
- a Flutter mobile app under `mobile/`
- a FastAPI backend under `backend/`
- database migrations under `supabase/migrations/`

The repository explicitly says the current BioPay screen contract is the source of truth and the frontend is frozen.

Evidence:
- [README.md](/Volumes/PRO-G40/BioPay/README.md#L1)
- [README.md](/Volumes/PRO-G40/BioPay/README.md#L7)
- [README.md](/Volumes/PRO-G40/BioPay/README.md#L17)

### UX contract

The standalone mobile app home screen is a direct tile-based application shell:
- `Profile`
- `Register Face Recognition`
- `Scan to Pay`
- `Get QR`
- `Scan QR`
- `NFC Tap`
- `Admin`

Evidence:
- [biopay_app.dart](/Volumes/PRO-G40/BioPay/mobile/lib/src/biopay_app.dart#L689)

This is not the same interaction model as AFRICLUB’s "PAY OR RECEIVE" hub.

### Runtime architecture

Standalone BioPay mobile calls a separate API base URL using `dio`, authenticates with a Supabase bearer token, and does not attach App Check headers. It also still exposes a mock fallback compile-time flag.

Evidence:
- [biopay_services.dart](/Volumes/PRO-G40/BioPay/mobile/lib/src/biopay_services.dart#L22)
- [biopay_services.dart](/Volumes/PRO-G40/BioPay/mobile/lib/src/biopay_services.dart#L49)
- [biopay_services.dart](/Volumes/PRO-G40/BioPay/mobile/lib/src/biopay_services.dart#L149)
- [biopay_services.dart](/Volumes/PRO-G40/BioPay/mobile/lib/src/biopay_services.dart#L164)

The backend is a standalone FastAPI service that uses a Supabase service-role admin client.

Evidence:
- [main.py](/Volumes/PRO-G40/BioPay/backend/main.py#L95)
- [main.py](/Volumes/PRO-G40/BioPay/backend/main.py#L112)
- [supabase_client.py](/Volumes/PRO-G40/BioPay/backend/supabase_client.py#L13)
- [supabase_client.py](/Volumes/PRO-G40/BioPay/backend/supabase_client.py#L18)

### Data model

Standalone BioPay is USSD-string-first:
- `biopay_payees`
- `biopay_id`
- `display_name`
- `ussd_string`
- `supabase_uid`
- `embedding vector(128)`

Evidence:
- [202604010001_biopay_pgvector.sql](/Volumes/PRO-G40/BioPay/supabase/migrations/202604010001_biopay_pgvector.sql#L16)
- [202604010001_biopay_pgvector.sql](/Volumes/PRO-G40/BioPay/supabase/migrations/202604010001_biopay_pgvector.sql#L29)
- [202604010001_biopay_pgvector.sql](/Volumes/PRO-G40/BioPay/supabase/migrations/202604010001_biopay_pgvector.sql#L76)
- [202604010001_biopay_pgvector.sql](/Volumes/PRO-G40/BioPay/supabase/migrations/202604010001_biopay_pgvector.sql#L137)

### Platform behavior

Standalone Android uses `FlutterFragmentActivity`, which is better aligned with some biometric/auth plugin integration patterns.

Evidence:
- [MainActivity.kt](/Volumes/PRO-G40/BioPay/mobile/android/app/src/main/kotlin/com/biopay/mobile/MainActivity.kt#L1)

### NFC behavior

Standalone BioPay NFC is centered on NDEF read/write token exchange:
- write `application/biopay+json`
- read payment tokens from NFC payloads
- no Android Host Card Emulation service was found

Evidence:
- [biopay_services.dart](/Volumes/PRO-G40/BioPay/mobile/lib/src/biopay_services.dart#L1137)
- [biopay_services.dart](/Volumes/PRO-G40/BioPay/mobile/lib/src/biopay_services.dart#L1144)
- [biopay_services.dart](/Volumes/PRO-G40/BioPay/mobile/lib/src/biopay_services.dart#L1215)

## Comparative Matrix

| Dimension | AFRICLUB Current BioPay | Standalone BioPay | Assessment |
| :-- | :-- | :-- | :-- |
| Delivery shape | Reusable Flutter feature package | Full standalone app | Major incompatibility |
| Reuse model | Shared across 20 club apps | Single app repo | AFRICLUB stronger for white-label |
| UI contract | Club-branded pay/receive hub | Standalone tile dashboard | Major UX mismatch |
| Backend | Supabase Edge Functions | FastAPI on separate API base URL | Major runtime mismatch |
| Attestation | Firebase App Check enforced | Bearer token only | AFRICLUB stronger |
| Data model | `route_type` + `recipient_value` + country-aware | `ussd_string` hardcoded | Standalone narrower |
| Embedding size | 192-dimensional | 128-dimensional | Not schema-compatible |
| Multitenancy | Club-aware | Single-product | AFRICLUB stronger |
| QR/NFC handoff | Signed token + resolver URL + HCE path | NDEF token exchange | Different channel contract |
| White-label suitability | High | Low in current form | AFRICLUB stronger |
| UI source-of-truth discipline | Evolving feature package | Frozen frontend contract | Standalone stronger for product consistency |
| Mobile code structure | More modular | More monolithic | AFRICLUB stronger |
| Backend test depth | Good, function-level | Strong backend suite | Standalone strong |
| Operational complexity | Single Supabase runtime plane | Separate mobile + API + DB plane | Standalone higher complexity |

## Direct Replacement Blockers

### 1. The standalone BioPay app is not consumable as a shared module

AFRICLUB needs a package. Standalone BioPay currently ships an app.

This means future updates in standalone cannot "automatically reflect" in AFRICLUB in a clean way because the artifact boundary is wrong. Pulling app code into AFRICLUB would create one of these bad outcomes:
- code copying
- dual-maintained UI logic
- brittle path dependencies to app internals
- forced AFRICLUB adoption of standalone routing and app shell assumptions

### 2. The runtime contract is incompatible

AFRICLUB client code expects Supabase Functions and signed response envelopes. Standalone mobile expects a separate REST API.

If replaced directly, you would either:
- break AFRICLUB’s existing feature integration points
- or maintain duplicate backend adapters in the host app

### 3. The data model is incompatible

AFRICLUB schema:
- 192D embeddings
- generic payout route abstraction
- active/revoked/deleted lifecycle
- club-aware scoping

Standalone schema:
- 128D embeddings
- raw `ussd_string`
- payee table keyed to a more direct face-to-USSD product model

This is not a migration you can hide under the UI. It changes RPCs, indexes, search functions, enrollment payloads, and profile semantics.

### 4. Standalone spec and standalone repo README are internally inconsistent

The spec still says BioPay is a feature module in an existing Flutter app:
- [BioPay_Spec.md](/Volumes/PRO-G40/BioPay/BioPay_Spec.md#L42)
- [BioPay_Spec.md](/Volumes/PRO-G40/BioPay/BioPay_Spec.md#L66)

But the repository itself is now a standalone full app with its own backend and frozen UI contract:
- [README.md](/Volumes/PRO-G40/BioPay/README.md#L3)
- [README.md](/Volumes/PRO-G40/BioPay/README.md#L7)
- [README.md](/Volumes/PRO-G40/BioPay/README.md#L17)

Before it becomes upstream, the standalone repo needs its own architecture and source-of-truth rules cleaned up.

### 5. Replacing AFRICLUB runtime with standalone would be a security regression today

AFRICLUB enforces App Check at the BioPay boundary.
Standalone currently validates bearer auth, but not App Check.

This is the wrong direction for a biometric payment-adjacent flow.

### 6. Replacing AFRICLUB NFC with standalone would lose current HCE-style receive capability

AFRICLUB already supports signed resolver-URL NFC handoff via Android HCE.
Standalone currently supports NDEF token read/write, but no host card emulation path was found.

Direct replacement would reduce capability unless standalone is upgraded first.

## Strengths Worth Preserving From Each Side

### Preserve from AFRICLUB

- White-label-ready package structure
- Supabase Edge runtime integration
- App Check enforcement
- club-aware multitenant model
- generic payout routing
- signed handoff token and resolver flow
- existing integration footprint across 20 club apps
- modular feature decomposition

### Preserve from standalone BioPay

- cleaner single-product UX contract
- explicit frozen frontend rule
- stronger end-to-end product cohesion
- broader backend test coverage in one dedicated product repo
- more opinionated standalone BioPay identity
- `FlutterFragmentActivity` host setup

## Recommended Target Architecture

If standalone BioPay must become the maintained source of truth, use this model:

### Upstream structure

Refactor `/Volumes/PRO-G40/BioPay` into:
- `packages/biopay_flutter`
- `packages/biopay_contract`
- `apps/biopay_mobile`
- `backend/` only if the dedicated API remains strategically necessary

Where:
- `packages/biopay_flutter` holds the shared Flutter UI, flows, state, domain logic, and device integrations
- `packages/biopay_contract` holds DTOs, route/channel enums, token payloads, and integration interfaces
- `apps/biopay_mobile` is only the standalone host app

Then AFRICLUB consumes:
- `biopay_flutter`
- optionally `biopay_contract`

This is the only credible path to "future updates in BioPay automatically reflect here".

### Runtime strategy

Preferred canonical backend:
- Keep AFRICLUB’s Supabase Edge Function runtime as the canonical backend contract

Reason:
- already integrated with AFRICLUB auth and club metadata
- already supports App Check
- already supports signed short-lived handoff flows
- already aligns with white-label distribution

If the FastAPI backend must remain:
- it must add App Check or equivalent device attestation
- it must adopt club-aware multitenancy
- it must support the generic route abstraction instead of raw `ussd_string` only
- it must either emulate AFRICLUB’s signed handoff contract or replace it cleanly across both repos

### UI strategy

If the requirement is that BioPay in AFRICLUB must look exactly like standalone BioPay:
- port the standalone screen contract into `packages/features/feat_biopay`
- preserve AFRICLUB theming hooks, kill switches, localization, and host navigation integration
- do not embed the standalone app shell inside AFRICLUB

## Proposed Migration Path

### Phase 0. Architecture decision

Decide the canonical truth for each layer:
- UI and interaction model
- Flutter shared package
- backend contract
- database schema
- signed token/handoff protocol

Recommended answer:
- UI source of truth: standalone BioPay
- Flutter package source of truth: extracted upstream package from standalone repo
- backend source of truth: AFRICLUB Edge Function contract
- database source of truth: AFRICLUB multitenant schema extended as needed

### Phase 1. Extract reusable upstream package from standalone

In `/Volumes/PRO-G40/BioPay`:
- move reusable mobile code out of `mobile/lib/src/biopay_app.dart`
- split UI, state, services, and device integrations into a package
- isolate app-shell-specific routing and bootstrapping in `apps/biopay_mobile`

Deliverable:
- a published or git-consumable Flutter package

### Phase 2. Define a formal adapter contract

Create explicit interfaces for:
- enrollment
- liveness challenge
- matching
- profile fetch/update
- payment intent
- QR request creation
- NFC request creation and resolution
- audit and admin operations

AFRICLUB should provide the adapter implementation for its Supabase backend.
Standalone host app can either use the same adapter or a dedicated adapter if the backend remains distinct.

### Phase 3. Align data model and token contracts

Standardize:
- embedding dimension
- profile identity model
- payment route model
- QR payload structure
- NFC payload structure
- signed receipt and handoff token structure
- liveness metadata model

Recommended direction:
- move standalone to AFRICLUB’s generalized payout route model
- do not force AFRICLUB backward into a raw `ussd_string`-only schema

### Phase 4. Port standalone UI contract into the shared package

Make the shared BioPay package render the standalone BioPay look and feel while still accepting host-provided:
- theme tokens
- club branding
- localized strings
- runtime capabilities
- feature flags

This gives Rayon and other clubs the same BioPay interaction model without losing white-label control.

### Phase 5. Replace AFRICLUB’s current BioPay UI layer

In AFRICLUB:
- keep the backend adapter stable
- swap current `feat_biopay` screens for the upstream shared package screens
- preserve host routes and deep-link entry points where required
- keep current App Check and Edge Function security boundary intact

### Phase 6. Establish automatic update flow

Once the package exists, future updates can flow automatically through:
- git dependency pinning to tagged releases
- or a private package registry
- CI contract tests between upstream BioPay package and AFRICLUB adapter
- snapshot/golden tests to catch visual drift

Do not use copy-paste sync. Do not use absolute local path dependencies as the long-term model.

## What Should Be Ported, Adapted, Or Dropped

### Port from standalone

- home screen structure
- terminology
- entry-point flow
- profile/admin separation
- overall BioPay visual identity

### Adapt before reuse

- API client layer
- auth and token attachment
- payment route model
- enrollment payload model
- matching response model
- QR/NFC contracts

### Keep from AFRICLUB

- App Check enforcement
- Edge Function orchestration
- club-aware scoping
- generic payout routing
- HCE receive support
- white-label compatibility

### Drop or retire

- standalone mock fallback runtime from production integration path
- duplicate backend logic if AFRICLUB runtime remains canonical
- raw `ussd_string` as the only payment-route abstraction

## Decision

### Can the current standalone BioPay app directly replace AFRICLUB BioPay?

No.

### Can standalone BioPay become the authoritative upstream for BioPay across AFRICLUB?

Yes, but only after:
- extracting a reusable Flutter package from the standalone repo
- aligning backend contracts
- aligning schema and token models
- preserving AFRICLUB’s security and white-label boundaries

### What is the best immediate implementation choice?

For the next implementation step:
- treat standalone BioPay as the design and product-flow source of truth
- do not treat its current app shell or backend as directly consumable
- rebuild AFRICLUB BioPay around an upstream shared package and AFRICLUB backend adapter

## Final Recommendation

The correct long-term architecture is:
- standalone BioPay owns the BioPay product package
- AFRICLUB consumes that package
- AFRICLUB remains the canonical white-label host
- AFRICLUB’s Edge runtime remains the canonical secure backend unless the standalone backend is upgraded to full parity

The wrong architecture is:
- embedding the standalone app into AFRICLUB
- copying screens back and forth
- maintaining two different backend contracts indefinitely

The immediate next deliverable should be a concrete extraction and integration spec for:
- upstream package boundaries
- AFRICLUB adapter interfaces
- schema/token alignment
- rollout sequence for replacing the current `feat_biopay` UI with the standalone BioPay experience
